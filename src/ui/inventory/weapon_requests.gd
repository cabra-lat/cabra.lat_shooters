# res://addons/cabra.lat_shooters/src/ui/inventory/weapon_requests.gd
# Handlers for the three inventory request signals that were emitted with zero
# connections and zero handlers anywhere in the tree. Each behaviour below was
# decided in writing by the actor who owns it, on card 38a378, and is restated
# here at the point of implementation so a later reader gets the decision next to
# the code rather than having to reconstruct it from a card.
#
#   EXTRACT rounds   takes rounds from whatever the current feed is and returns
#                    them to the player's inventory as usable items. It NEVER
#                    moves the feed: the magazine stays seated whatever count it
#                    holds, including zero. Removing the magazine is a separate
#                    action (unload). A feed type is not special-cased -- the
#                    source changes, the contract does not -- because a second
#                    path keyed on container type is the divergent-implementation
#                    failure this card exists to end.
#   UNLOAD  magazine returns the feed itself to the player's inventory and leaves
#                    an EMPTY feed in the weapon, and REPORTS that, rather than
#                    succeeding quietly. Only offered, and only permitted, where
#                    the model permits a detach: AmmoFeed.Type.EXTERNAL, which is
#                    the rule WeaponSystem.change_magazine already applies. The
#                    gate is DELEGATED to that rule rather than re-derived here.
#   CYCLE   action delegates to WeaponSystem.cycle_firemode, which already cycles
#                    only the fire modes the weapon itself declares. The added
#                    value here is the SILENCE DETECTOR: that function returns
#                    without doing anything when a weapon declares one mode, and
#                    a live-looking control that does nothing silently is the
#                    defect the owner actually reported. So the no-op is detected
#                    and reported rather than swallowed.
#
# WHY AN OUTCOME SIGNAL RATHER THAN A MESSAGE. Every case reports, including
# every refusal, because silence is the failure being eliminated. There is no
# notification surface anywhere in the project to render a player-facing message
# into, and inventing a toast in the UI layer would be a new UI surface nobody
# scoped. So the outcome is carried as typed data, which a presentation layer can
# bind to later, and no path in this file can complete without reporting.

class_name WeaponRequests
extends RefCounted

## Emitted for EVERY activation, including refusals. `result` is an ActionResult
## and `reason` is a String (a catalogue msgid) or "" for a success.
signal action_performed(action: StringName, target: StringName, result: ActionResult, reason: String)

enum ActionResult { OK, NO_OP, REFUSED }

## UNLOAD leaves an empty feed and says so rather than succeeding quietly.
const EMPTY_FEED_REASON: String = "inventory_empty_feed_left_in_weapon"
const NO_PUMP_OR_BOLT_REASON: String = "inventory_weapon_has_no_cycled_action"
const INTERNAL_FEED_REASON: String = "inventory_internal_feed_cannot_be_detached"
const NO_FEED_REASON: String = "inventory_weapon_has_no_feed"
const NO_BACKPACK_REASON: String = "inventory_no_backpack_to_return_to"
const NOTHING_TO_EXTRACT_REASON: String = "inventory_feed_is_already_empty"
const FEED_FULL_REASON: String = "inventory_cannot_return_feed_it_is_full"

var _player: PlayerController = null


func _init(player: PlayerController = null) -> void:
	_player = player


## Extract rounds. `number` is -1 for "all" and 1 for one, matching the two
## emissions the context menu makes. Returns how many were actually returned,
## which is zero for a refusal -- the count alone is not the report, the signal
## is.
func extract_rounds(source: Item, number: int) -> int:
	var feed: AmmoFeed = _feed_of(source)
	if feed == null:
		_report(&"extract_rounds", &"", ActionResult.REFUSED, NO_FEED_REASON)
		return 0
	var target := _backpack()
	if target == null:
		_report(&"extract_rounds", &"", ActionResult.REFUSED, NO_BACKPACK_REASON)
		return 0
	var wanted: int = feed.capacity if number < 0 else mini(1, feed.capacity)
	var returned := 0
	for _i in wanted:
		var round_item: Item = feed.pop()
		if round_item == null:
			break
		var inv_item: InventoryItem = InventorySystem.create_inventory_item(round_item)
		if not InventorySystem.return_item(target, inv_item):
			# Put it back rather than destroying it: a failed return must not
			# silently delete a cartridge, which is a second data-loss defect
			# wearing the costume of a tidy extraction.
			feed.insert(round_item)
			_report(&"extract_rounds", &"", ActionResult.REFUSED, FEED_FULL_REASON)
			return returned
		returned += 1
	if returned == 0:
		_report(&"extract_rounds", &"", ActionResult.NO_OP, NOTHING_TO_EXTRACT_REASON)
		return 0
	_report(&"extract_rounds", &"", ActionResult.OK, &"")
	return returned


## Return the feed itself to the player, leaving an empty one seated. Delegates
## the permission question to the model rather than re-deriving INTERNAL here.
func unload_magazine(weapon: Weapon) -> bool:
	if weapon == null or weapon.ammo_feed == null:
		_report(&"unload_magazine", &"", ActionResult.REFUSED, NO_FEED_REASON)
		return false
	if not weapon.ammo_feed.is_empty():
		# Unloading with rounds still in it would destroy them, so the rounds go
		# back to the player first. Reporting that they were left behind is the
		# difference between this being reversible and being data loss.
		var moved := extract_rounds(weapon, -1)
		if moved == 0 and not weapon.ammo_feed.is_empty():
			_report(&"unload_magazine", &"", ActionResult.REFUSED, NO_BACKPACK_REASON)
			return false
	if not WeaponSystem.change_magazine(weapon, null):
		_report(&"unload_magazine", &"", ActionResult.REFUSED, INTERNAL_FEED_REASON)
		return false
	# change_magazine installs a fresh feed, so the old one is the item to return.
	var old_feed: AmmoFeed = weapon.ammo_feed
	var target := _backpack()
	if target != null:
		var feed_item: InventoryItem = InventorySystem.create_inventory_item(old_feed)
		if not InventorySystem.return_item(target, feed_item):
			_report(&"unload_magazine", &"", ActionResult.REFUSED, FEED_FULL_REASON)
			return false
	_report(&"unload_magazine", &"", ActionResult.OK, EMPTY_FEED_REASON)
	return true


## Cycle the weapon's action, and REPORT the no-op case that the underlying
## implementation currently swallows.
func cycle_action(weapon: Weapon) -> bool:
	if weapon == null:
		_report(&"cycle_action", &"", ActionResult.REFUSED, NO_FEED_REASON)
		return false
	var before: int = weapon.firemode
	weapon.cycle_firemode()
	if weapon.firemode == before:
		# The model has one action and there is nothing to cycle to. That is a
		# correct outcome, not an error -- but it must be visible.
		_report(&"cycle_action", &"", ActionResult.NO_OP, NO_PUMP_OR_BOLT_REASON)
		return false
	_report(&"cycle_action", &"", ActionResult.OK, &"")
	return true


func _feed_of(source: Item) -> AmmoFeed:
	if source == null:
		return null
	if source is Weapon:
		return (source as Weapon).ammo_feed
	if source is AmmoFeed:
		return source as AmmoFeed
	return null


func _backpack() -> InventoryContainer:
	return _player.get_equipped_backpack() if _player != null else null


func _report(action: StringName, target: StringName, result: ActionResult, reason: String) -> void:
	action_performed.emit(action, target, result, reason)

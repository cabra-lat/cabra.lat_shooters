extends SceneTree

## 38a378's missing half: RUNTIME proof of the three request handlers.
##
## The wiring harness proves the signals are connected and that the handlers
## exist. It does not prove that clicking one CHANGES ANYTHING. Those are
## different claims, and only the second one is the owner's complaint.
##
## So this drives the handlers with real objects -- a real PlayerController, a
## real equipped Backpack, a real Weapon with a real AmmoFeed holding real
## rounds -- and asserts the OBSERVABLE EFFECT in the world, not the return
## value. A handler that returns `true` and moves nothing passes a return-value
## check and fails this one, which is the entire point: the return value is what
## the buggy version of this code would have been written to satisfy.
##
## The refusal and no-op cases are asserted with their REASON, because "it
## declined" and "it declined for a knowable reason" are different products and
## only the second one is debuggable from a player's report.

var _pass := 0
var _fail := 0
var _fail_lines: Array[String] = []


func _initialize() -> void:
	await process_frame
	_run()
	call_deferred("_quit", 0 if _fail == 0 else 1)


func _run() -> void:
	_extract_moves_rounds_and_leaves_the_feed_seated()
	_unload_returns_the_feed_and_leaves_an_empty_one()
	_unload_refuses_an_internal_feed_without_losing_it()
	_cycle_changes_the_action_or_says_why_not()
	_detach_gate_is_not_bypassable()
	_evidence_is_real_objects_not_stubs()
	_summary()


## ── a real player with a real backpack ──────────────────────────────────────

func _player_with_backpack() -> PlayerController:
	var player := PlayerController.new()
	player.name = "RequestsPlayer"
	# PlayerController builds `equipment` in its own setup function, which
	# PlayerController.new() does not call -- a bare .new() leaves it null and
	# the first access fails on "slots of Nil". Constructed explicitly instead of
	# invoking the player's whole setup, which would drag in the input layer and
	# an inventory UI scene for a test that needs neither.
	player.equipment = Equipment.new()
	var pack := Backpack.new()
	pack.name = "TestPack"
	pack.grid_width = 6
	pack.grid_height = 6
	var pack_item: InventoryItem = InventorySystem.create_inventory_item(pack)
	player.equipment.slots["back"].items.append(pack_item)
	return player


func _weapon(feed_type: AmmoFeed.Type, rounds: int) -> Weapon:
	var weapon := Weapon.new()
	weapon.name = "TestWeapon"
	weapon.feed_type = feed_type
	var feed := AmmoFeed.new()
	feed.name = "TestFeed"
	# `capacity` on a Reservoir is DERIVED from len(contents), so assigning it
	# does nothing; `max_capacity` is the settable one. The first draft of this
	# fixture set `capacity` and got a feed that was full the moment it was
	# created -- an extraction that "did not work" because the fixture had no
	# room, which would have read as a product bug.
	feed.max_capacity = rounds + 4
	for _i in rounds:
		# Ammo, not Item: AmmoFeed.insert() type-checks its argument against
		# Ammo, and a plain Item is rejected by is_compatible().
		var round_item := Ammo.new()
		round_item.name = "TestRound"
		feed.insert(round_item)
	weapon.ammo_feed = feed
	return weapon


## Count real Item objects in the player's backpack, so "the rounds arrived" is a
## fact about the world rather than a counter the handler also incremented.
func _rounds_in_backpack(player: PlayerController) -> int:
	var pack: InventoryContainer = player.get_equipped_backpack()
	if pack == null:
		return -1
	return pack.items.size()


## Collect every action_performed emission, so "it reported" is a fact about the
## signal and not about the return value.
func _collect(requests: WeaponRequests) -> Array[Dictionary]:
	var seen: Array[Dictionary] = []
	requests.action_performed.connect(
		func(action: StringName, target: StringName, result: int, reason: String) -> void:
			seen.append({"action": String(action), "result": result, "reason": reason})
	)
	return seen


func _last(seen: Array[Dictionary]) -> Dictionary:
	return seen[seen.size() - 1] if not seen.is_empty() else {}


# ── EXTRACT: rounds move, the feed stays seated ─────────────────────────────

func _extract_moves_rounds_and_leaves_the_feed_seated() -> void:
	var player := _player_with_backpack()
	var weapon := _weapon(AmmoFeed.Type.INTERNAL, 3)
	var feed_before: AmmoFeed = weapon.ammo_feed
	var rounds_before := _rounds_in_backpack(player)
	var feed_count_before: int = feed_before.capacity

	var requests := WeaponRequests.new(player)
	var seen := _collect(requests)
	var returned: int = requests.extract_rounds(weapon, -1)

	_check(returned == 3, "extract: it reports how many rounds went back [got %d]" % returned)
	_check(weapon.ammo_feed == feed_before,
		"extract: the FEED IS STILL SEATED -- extraction must not move the feed, that is the unload action")
	_check(feed_before.capacity == 0, "extract: and it is now empty [count %d of %d before]" % [feed_before.capacity, feed_count_before])
	_check(_rounds_in_backpack(player) == rounds_before + 3,
		"extract: the rounds are PHYSICALLY IN THE BACKPACK, which is the claim a return value cannot make [backpack %d -> %d]" % [rounds_before, _rounds_in_backpack(player)])
	_check(seen.size() == 1 and int(_last(seen).get("result", -1)) == WeaponRequests.ActionResult.OK,
		"extract: and it reported OK once")
	_check(String(_last(seen).get("reason", "")) == "",
		"extract: with no reason, because nothing went wrong")

	# The negative half, and the one the owner would actually hit: an empty feed
	# is a NO-OP, and a NO-OP that reports nothing is the silence being removed.
	var requests2 := WeaponRequests.new(player)
	var seen2 := _collect(requests2)
	var none: int = requests2.extract_rounds(weapon, -1)
	_check(none == 0, "extract on an empty feed returns 0 [got %d]" % none)
	_check(seen2.size() == 1, "and still REPORTS, rather than staying silent [emissions %d]" % seen2.size())
	_check(int(_last(seen2).get("result", -1)) == WeaponRequests.ActionResult.NO_OP,
		"as a NO_OP, which is a different bug from an absent entry")
	_check(String(_last(seen2).get("reason", "")) == WeaponRequests.NOTHING_TO_EXTRACT_REASON,
		"carrying the reason a player can act on [got '%s']" % String(_last(seen2).get("reason", "")))

	player.queue_free()


# ── UNLOAD: the feed goes back, an empty one is left, and it says so ─────────

func _unload_returns_the_feed_and_leaves_an_empty_one() -> void:
	var player := _player_with_backpack()
	var weapon := _weapon(AmmoFeed.Type.EXTERNAL, 2)
	var original_feed: AmmoFeed = weapon.ammo_feed
	var rounds_before := _rounds_in_backpack(player)

	var requests := WeaponRequests.new(player)
	var seen := _collect(requests)
	var ok: bool = requests.unload_magazine(weapon)

	_check(ok, "unload: it succeeds for an EXTERNAL feed, the case the model permits")
	_check(weapon.ammo_feed != original_feed,
		"unload: a DIFFERENT feed is now seated, so the original was genuinely returned and not just emptied")
	_check(weapon.ammo_feed != null and weapon.ammo_feed.is_empty(),
		"unload: and the seated feed is EMPTY, rather than being left loaded")
	_check(_rounds_in_backpack(player) == rounds_before + 3,
		"unload: the two rounds came back too, rather than being destroyed [backpack %d -> %d]" % [rounds_before, _rounds_in_backpack(player)])
	# The distinction the card is really about: this REPORTS the empty feed left
	# behind instead of succeeding quietly, because a quiet success here reads as
	# data loss to the player.
	_check(seen.size() >= 1 and String(_last(seen).get("reason", "")) == WeaponRequests.EMPTY_FEED_REASON,
		"unload: and it REPORTS the empty feed it left in the weapon [got '%s']" % String(_last(seen).get("reason", "")))

	player.queue_free()


# ── UNLOAD refuses an INTERNAL feed, and does not lose it ───────────────────

func _unload_refuses_an_internal_feed_without_losing_it() -> void:
	var player := _player_with_backpack()
	var weapon := _weapon(AmmoFeed.Type.INTERNAL, 2)
	var original_feed: AmmoFeed = weapon.ammo_feed
	# Measured BEFORE the call. The first version of this check sampled the
	# backpack afterwards and then subtracted the sample from itself, so the
	# conservation term was always zero and the check reduced to "the feed still
	# has 2" -- the assertion I had already established was wrong. A conservation
	# check that samples one side only is not a conservation check.
	var pack_before := _rounds_in_backpack(player)

	var requests := WeaponRequests.new(player)
	var seen := _collect(requests)
	var ok: bool = requests.unload_magazine(weapon)

	_check(not ok, "unload: an INTERNAL feed is refused, because the model does not permit detaching it")
	_check(String(_last(seen).get("reason", "")) == WeaponRequests.INTERNAL_FEED_REASON,
		"and says WHY, naming the rule rather than a generic failure [got '%s']" % String(_last(seen).get("reason", "")))
	# THE DATA-LOSS CHECK, and my first version of it was wrong.
	#
	# I asserted the feed still held its two rounds after the refusal. It does
	# not, and it SHOULD not: the handler deliberately returns the rounds to the
	# player BEFORE delegating the permission question, precisely so that a
	# refused detach cannot destroy them. So the invariant is not "the feed is
	# untouched" -- it is "NOTHING IS LOST", wherever the rounds ended up.
	#
	# Asserting the design I imagined rather than the design that prevents data
	# loss would have failed a correct implementation, and the fix would have been
	# to make the handler destroy rounds to satisfy my test.
	_check(weapon.ammo_feed == original_feed, "unload: the ORIGINAL feed is still seated after the refusal, so it was not silently dropped")
	var in_feed: int = original_feed.capacity
	var in_pack := _rounds_in_backpack(player)
	_check(in_feed + (in_pack - pack_before) == 2,
		"unload: CONSERVED -- 2 in, and 2 accounted for afterwards whether they stayed seated or came back [feed %d + backpack gain %d]" % [in_feed, in_pack - pack_before])
	_check(in_pack - pack_before == 2,
		"unload: and specifically the rounds went back to the player rather than being destroyed [gain %d]" % (in_pack - pack_before))

	player.queue_free()


# ── CYCLE: the action changes, or the no-op is reported ─────────────────────

func _cycle_changes_the_action_or_says_why_not() -> void:
	# A weapon that declares two actions must actually change.
	var player := _player_with_backpack()
	var weapon := _weapon(AmmoFeed.Type.INTERNAL, 0)
	weapon.firemodes = Firemode.SEMI | Firemode.AUTO
	weapon.firemode = Firemode.SEMI
	var before: int = weapon.firemode

	var requests := WeaponRequests.new(player)
	var seen := _collect(requests)
	var ok: bool = requests.cycle_action(weapon)

	_check(ok, "cycle: a two-mode weapon cycles")
	_check(weapon.firemode != before, "cycle: and the firemode ACTUALLY CHANGED [%d -> %d]" % [before, weapon.firemode])
	_check(int(_last(seen).get("result", -1)) == WeaponRequests.ActionResult.OK, "cycle: reported OK")

	# A weapon that declares one action cannot cycle, and WeaponSystem's own
	# cycle_firemode returns silently in that case. That silence is the defect the
	# owner reported, so the handler must surface it as a NO_OP with a reason.
	var single := _weapon(AmmoFeed.Type.INTERNAL, 0)
	single.firemodes = Firemode.SEMI
	single.firemode = Firemode.SEMI
	var requests2 := WeaponRequests.new(player)
	var seen2 := _collect(requests2)
	var ok2: bool = requests2.cycle_action(single)

	_check(not ok2, "cycle: a one-mode weapon does not pretend to have cycled")
	_check(single.firemode == Firemode.SEMI, "cycle: and its action is unchanged")
	_check(seen2.size() == 1, "cycle: and it REPORTED rather than returning silently [emissions %d]" % seen2.size())
	_check(int(_last(seen2).get("result", -1)) == WeaponRequests.ActionResult.NO_OP,
		"as a NO_OP")
	_check(String(_last(seen2).get("reason", "")) == WeaponRequests.NO_PUMP_OR_BOLT_REASON,
		"carrying the reason [got '%s']" % String(_last(seen2).get("reason", "")))

	player.queue_free()


# ── the detach gate, isolated at the API the handler delegates to ───────────

## change_magazine() is the rule, and the rule is "an INTERNAL feed cannot be
## detached". The null branch that makes detach WORK lives in the same function,
## immediately after that gate, which is exactly why the gate needs a control of
## its own: a branch added beside a rule is a branch that can come to sit in front
## of it, and the symptom would be an unload that destroys rounds instead of
## refusing.
##
## This drives WeaponSystem.change_magazine DIRECTLY, not the handler, so a
## handler that stopped delegating could not make the model look correct.
func _detach_gate_is_not_bypassable() -> void:
	# INTERNAL + null: refused, cleanly, and nothing moved.
	var internal := _weapon(AmmoFeed.Type.INTERNAL, 2)
	var internal_feed: AmmoFeed = internal.ammo_feed
	var before_refusals: Array[String] = []
	internal.ammo_feed_incompatible.connect(func(_w, _a) -> void: before_refusals.append("incompatible"))
	var refused: bool = WeaponSystem.change_magazine(internal, null)
	_check(not refused, "gate: INTERNAL + null is REFUSED, the permission rule the unload action depends on")
	_check(internal.ammo_feed == internal_feed, "gate: and the feed is still seated, so a refusal moved nothing")
	_check(internal_feed.capacity == 2, "gate: and its rounds are intact [count %d of 2]" % internal_feed.capacity)
	_check(before_refusals.size() == 1,
		"gate: and it announced the refusal rather than declining quietly [signals %d of 1]" % before_refusals.size())

	# EXTERNAL + null: the detach, which is what the whole authorisation is for.
	var external := _weapon(AmmoFeed.Type.EXTERNAL, 2)
	var external_feed: AmmoFeed = external.ammo_feed
	var changes: Array[int] = []
	external.ammo_feed_changed.connect(func(_w, _o, _n) -> void: changes.append(1))
	var detached: bool = WeaponSystem.change_magazine(external, null)
	_check(detached, "gate: EXTERNAL + null DETACHES, which is the branch that was authorised and the reason unload can work at all")
	_check(external.ammo_feed != external_feed, "gate: a different feed is now seated, so the original was genuinely removed")
	_check(external.ammo_feed != null and external.ammo_feed.is_empty(),
		"gate: the seated feed is empty, rather than being nulled -- 'a weapon has a feed' stays true for every caller")
	_check(external.ammo_feed.type == AmmoFeed.Type.EXTERNAL,
		"gate: and it is of the weapon's own feed type [type %d of %d]" % [external.ammo_feed.type, AmmoFeed.Type.EXTERNAL])
	_check(changes.size() == 1,
		"gate: and the change was announced [ammo_feed_changed %d of 1]" % changes.size())

	# The gate must be FIRST, not merely present. A later refactor that moves the
	# null branch in front of it would let INTERNAL detach, and the only symptom
	# would be an unload quietly emptying a sealed feed.
	var internal2 := _weapon(AmmoFeed.Type.INTERNAL, 0)
	var detached_internal: bool = WeaponSystem.change_magazine(internal2, null)
	_check(not detached_internal and internal2.ammo_feed.capacity == 0,
		"gate: an INTERNAL feed with ZERO rounds is still refused -- a guard written as 'only if it holds rounds' would pass every other test here")


# ── the evidence is real, not stubbed ───────────────────────────────────────

## A harness that passes against doubles proves the doubles work. This checks
## the things standing in for the world are the real classes, because a fixture
## that silently degraded to a stub would turn every assertion above into a
## tautology.
func _evidence_is_real_objects_not_stubs() -> void:
	var player := _player_with_backpack()
	_check(player is PlayerController, "fixture: the player is a real PlayerController")
	_check(player.get_equipped_backpack() is Backpack,
		"fixture: and the backpack it resolves to is a real Backpack, not a stand-in")
	var pack: InventoryContainer = player.get_equipped_backpack()
	_check(pack != null and pack.grid_width == 6 and pack.grid_height == 6,
		"fixture: with the dimensions the fixture set, so add_item is really placing into a grid")

	var weapon := _weapon(AmmoFeed.Type.EXTERNAL, 3)
	_check(weapon is Weapon, "fixture: the weapon is a real Weapon")
	_check(weapon.ammo_feed is AmmoFeed, "fixture: holding a real AmmoFeed")
	_check(weapon.ammo_feed.capacity == 3, "fixture: with the round count the fixture set [count %d of 3]" % weapon.ammo_feed.capacity)
	_check(weapon.ammo_feed.max_capacity > 3, "fixture: and room to spare, so a refusal cannot be confused with a full feed")

	# And the control: a real weapon really does hold real Item objects, so
	# "the rounds arrived" is countable.
	var pack2 := _player_with_backpack()
	var before_count := _rounds_in_backpack(pack2)
	var requests := WeaponRequests.new(pack2)
	requests.extract_rounds(weapon, -1)
	_check(_rounds_in_backpack(pack2) == before_count + 3,
		"fixture control: moving 3 rounds really changes the backpack's item count [%d -> %d]" % [before_count, _rounds_in_backpack(pack2)])

	player.queue_free()
	pack2.queue_free()


# ── plumbing ────────────────────────────────────────────────────────────────

func _check(ok: bool, message: String) -> void:
	if ok:
		_pass += 1
		print("  PASS  %s" % message)
	else:
		_fail += 1
		_fail_lines.append(message)
		print("ERROR: FAIL: %s" % message)


func _summary() -> void:
	print("")
	print("=== validate_weapon_requests_runtime summary ===")
	print("  checks passed  %d" % _pass)
	print("  FAILURES       %d" % _fail)
	for l in _fail_lines:
		print("  FAIL  " + l)
	print("RESULT: %s" % ("PASS" if _fail == 0 else "FAIL"))


func _quit(code: int) -> void:
	quit(code)

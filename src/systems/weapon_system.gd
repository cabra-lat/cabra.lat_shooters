# res://addons/cabra.lat_shooters/src/systems/weapon_system.gd
class_name WeaponSystem
extends Resource

# In WeaponSystem.gd
static func pull_trigger(weapon: Weapon) -> bool:
  if not weapon:
    return false

  # An active fault blocks firing until Troubleshooting clears it.
  if weapon.active_malfunction != Weapon.Malfunction.NONE:
    return false

  if not can_fire(weapon):
    _handle_fire_failure(weapon)
    return false

  # Genre-typical malfunction roll happens on the round about to fire. A fault means
  # the shot does NOT happen and the weapon is taken out of action until cleared.
  var sample: Ammo = _next_round(weapon)
  var fault: int = weapon.roll_malfunction(sample)
  if fault != Weapon.Malfunction.NONE:
    weapon.trigger_malfunction(fault)
    return false

  # Get round to fire
  var round_to_fire: Ammo = null
  if weapon.chambered_round:
    round_to_fire = weapon.chambered_round
    weapon.chambered_round = null
  elif weapon.ammo_feed and not weapon.ammo_feed.is_empty():
    round_to_fire = weapon.ammo_feed.eject()

  if not round_to_fire:
    _handle_fire_failure(weapon)
    return false

  # Update firing state
  _update_firing_state(weapon)

  # Wear the weapon (base + the round's durability burn).
  weapon.apply_firing_wear(round_to_fire)

  # Emit firing signals
  weapon.trigger_pressed.emit(weapon)
  weapon.cartridge_fired.emit(weapon, round_to_fire)

  # Auto-chamber next round for automatic weapons
  if weapon.is_automatic() and weapon.ammo_feed and not weapon.ammo_feed.is_empty():
    weapon.chambered_round = weapon.ammo_feed.eject()

  # Eject shell for non-revolver systems
  if weapon.feed_type != AmmoFeed.Type.INTERNAL:
    weapon.shell_ejected.emit(weapon, round_to_fire)

  return true

## The round a firing attempt would consume (chambered, else top of feed).
static func _next_round(weapon: Weapon) -> Ammo:
  if weapon.chambered_round != null:
    return weapon.chambered_round
  if weapon.ammo_feed != null and not weapon.ammo_feed.contents.is_empty():
    return weapon.ammo_feed.contents.back() as Ammo
  return null


static func release_trigger(weapon: Weapon) -> void:
  if not weapon: return
  if weapon.firemode == Firemode.BURST:
    weapon.burst_counter = weapon.burst_count
  weapon.semi_control = false
  weapon.trigger_released.emit(weapon)

static func cycle_weapon(weapon: Weapon) -> void:
  if not weapon: return
  if not weapon.is_cycled and weapon.ammo_feed and not weapon.ammo_feed.is_empty():
    weapon.chambered_round = weapon.ammo_feed.eject()
    weapon.is_cycled = true
    weapon.cartridge_inserted.emit(weapon, weapon.chambered_round)

static func insert_cartridge(weapon: Weapon, new_cartridge: Ammo) -> void:
  if not weapon: return
  if weapon.feed_type != AmmoFeed.Type.INTERNAL:
    weapon.ammo_feed_incompatible.emit(weapon, new_cartridge)
    return
  if not weapon.chambered_round:
    weapon.chambered_round = new_cartridge
    weapon.cartridge_inserted.emit(weapon, new_cartridge)
  elif weapon.ammo_feed:
    weapon.ammo_feed.insert(new_cartridge)

static func change_magazine(weapon: Weapon, new_magazine: AmmoFeed) -> bool:
  if weapon.feed_type == AmmoFeed.Type.INTERNAL or new_magazine.type != weapon.feed_type:
    weapon.ammo_feed_incompatible.emit(weapon, new_magazine)
    return false

  var caliber_compatible = false
  if weapon.ammo_feed:
    for caliber in new_magazine.compatible_calibers:
      if weapon.ammo_feed.compatible_calibers.has(caliber):
        caliber_compatible = true
        break
  else:
    caliber_compatible = not new_magazine.compatible_calibers.is_empty()

  if not caliber_compatible:
    weapon.ammo_feed_incompatible.emit(weapon, new_magazine)
    return false

  var old_magazine = weapon.ammo_feed
  weapon.ammo_feed = _copy_feed(new_magazine)
  if weapon.ammo_feed and not weapon.ammo_feed.is_empty():
    weapon.chambered_round = weapon.ammo_feed.eject()
    weapon.cartridge_inserted.emit(weapon, weapon.chambered_round)
  weapon.ammo_feed_changed.emit(weapon, old_magazine, new_magazine)
  return true

## Deep-copies a magazine so the installed copy never aliases the source's
## contents Array (a shallow Resource.duplicate() shares it, so ejecting from
## the copy would drain the original).
static func _copy_feed(src: AmmoFeed) -> AmmoFeed:
  var copy: AmmoFeed = src.duplicate()
  var fresh: Array[Item] = []
  for round in src.contents:
    fresh.append((round.duplicate(true) as Item) if round != null else null)
  copy.contents = fresh
  return copy

static func cycle_firemode(weapon: Weapon) -> void:
  var available_modes = []
  var priority_order = Firemode.get_priority_order()
  for mode in priority_order:
    if weapon.is_firemode_available(mode):
      available_modes.append(mode)
  if available_modes.is_empty():
    return
  var current_index = available_modes.find(weapon.firemode)
  var next_index = (current_index + 1) % available_modes.size()
  weapon.firemode = available_modes[next_index]
  if weapon.firemode == Firemode.BURST:
    weapon.burst_counter = weapon.burst_count
  weapon.firemode_changed.emit(weapon, weapon.get_firemode_name())

static func can_fire(weapon: Weapon) -> bool:
  match weapon.firemode:
    Firemode.SAFE:
      return false
    Firemode.SEMI:
      if weapon.semi_control: return false
    Firemode.BURST:
      if weapon.burst_counter <= 0: return false
    Firemode.PUMP, Firemode.BOLT:
      if not weapon.is_cycled: return false
  if weapon.chambered_round:
    return true
  if weapon.ammo_feed and not weapon.ammo_feed.is_empty():
    return true
  return false

# ─── INTERNAL HELPERS ───────────────────────────────
static func _update_firing_state(weapon: Weapon) -> void:
  match weapon.firemode:
    Firemode.SEMI:
      weapon.semi_control = true
    Firemode.BURST:
      weapon.burst_counter -= 1
    Firemode.PUMP, Firemode.BOLT:
      weapon.is_cycled = false

static func _handle_fire_failure(weapon: Weapon) -> void:
  if weapon.firemode == Firemode.SAFE:
    if not weapon.semi_control:
      weapon.trigger_locked.emit(weapon)
      weapon.semi_control = true
    return
  if weapon.semi_control:
    return
  # Distinguish a missing magazine from an empty one (the old branch order
  # made ammo_feed_missing unreachable).
  if not weapon.ammo_feed:
    weapon.ammo_feed_missing.emit(weapon)
  elif weapon.ammo_feed.is_empty():
    weapon.ammo_feed_empty.emit(weapon, weapon.ammo_feed)
  weapon.semi_control = true

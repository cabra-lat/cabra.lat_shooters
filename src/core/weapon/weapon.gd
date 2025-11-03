# res://src/core/weapon/weapon.gd
class_name Weapon
extends Item

# ─── SIGNALS ───────────────────────────────────────
signal trigger_locked(weapon: Weapon)
signal trigger_pressed(weapon: Weapon)
signal trigger_released(weapon: Weapon)
signal firemode_changed(weapon: Weapon, mode: String)
signal weapon_racked(weapon: Weapon)
signal attachment_added(weapon: Weapon, attachment: Attachment, point: int)
signal attachment_removed(weapon: Weapon, attachment: Attachment, point: int)
signal shell_ejected(weapon: Weapon, cartridge: Ammo)
signal cartridge_fired(weapon: Weapon, cartridge: Ammo)
signal cartridge_ejected(weapon: Weapon, cartridge: Ammo)
signal cartridge_inserted(weapon: Weapon, cartridge: Ammo)
signal ammo_feed_empty(weapon: Weapon, ammo_feed: AmmoFeed)
signal ammo_feed_changed(weapon: Weapon, old: AmmoFeed, new: AmmoFeed)
signal ammo_feed_missing(weapon: Weapon)
signal ammo_feed_incompatible(weapon: Weapon, ammo_feed: AmmoFeed)

# ─── ENUMS ─────────────────────────────────────────
enum AttachmentPoint {
  MUZZLE     = 1 << 0,
  LEFT_RAIL  = 1 << 1,
  RIGHT_RAIL = 1 << 2,
  TOP_RAIL   = 1 << 3,
  UNDER      = 1 << 4,
}

# ─── METADATA ──────────────────────────────────────
@export_multiline var description: String = "This Weapon is the default one."
@export var fire_sound: AudioStream
@export var feed_sound: AudioStream
@export var empty_sound: AudioStream
@export var extra_sound: AudioStream

# ─── CONFIGURATION ─────────────────────────────────
@export var ammo_feed: AmmoFeed
@export_flags("MUZZLE", "LEFT_RAIL", "RIGHT_RAIL", "TOP_RAIL", "UNDER", "NONE")
var attach_points: int = 0
@export_flags("SAFE", "AUTO", "SEMI", "BURST", "PUMP", "BOLT")
var firemodes: int = Firemode.SEMI
@export var feed_type: AmmoFeed.Type = AmmoFeed.Type.INTERNAL

# ─── BASE STATS ────────────────────────────────────
@export var firerate: float = 600
@export var burst_count: int = 3
@export_custom(PROPERTY_HINT_NONE, "suffix:kg") var base_mass: float = 3.5
@export var base_reload_time: float = 2.5
@export var base_accuracy: float = 2.0

# ─── RECOIL PHYSICS ────────────────────────────────
@export_group("Recoil Physics")
@export var base_recoil_vertical: float = 1.0
@export var base_recoil_horizontal: float = 0.5
@export var base_recoil_tilt = 1.5
@export var base_recoil_kick = 0.04
@export var recoil_damping_factor: float = 0.8
@export var muzzle_rise_factor: float = 0.6
@export var hand_transfer_factor: float = 0.7  # How much recoil transfers to hands vs body

# ─── EJECTION PHYSICS ──────────────────────────────
@export_group("Ejection Physics")
@export var ejection_force_multiplier: float = 1.0
@export var ejection_spin_multiplier: float = 1.0
@export var ejection_direction: Vector3 = Vector3(0.8, 0.3, -0.5)

# ─── STATE ─────────────────────────────────────────
var firemode: int = Firemode.SAFE
var semi_control: bool = false
var burst_counter: int = 0
var chambered_round: Ammo = null
var is_cycled: bool = true
var current_durability: float = 100.0
var attachments: Dictionary = {}

# ─── COMPUTED PROPERTIES ───────────────────────────
var accuracy: float: get = get_current_accuracy
var reload_time: float: get = get_reload_time
var recoil_vertical: float: get = get_current_recoil_vertical
var recoil_horizontal: float: get = get_current_recoil_horizontal
var recoil_tilt: float: get = get_current_recoil_tilt
var recoil_kick: float: get = get_current_recoil_kick
var can_fire: bool:
  get:
    return WeaponSystem.can_fire(self)

var cycle_time: float:
  get: return (60.0 / firerate)

# ─── INIT ──────────────────────────────────────────
func _init():
  firemode = Firemode.get_initial_from_available(firemodes)
  if firemode == Firemode.BURST:
    burst_counter = burst_count

# ─── RECOIL CALCULATION METHODS ────────────────────
func get_recoil_data(cartridge: Ammo) -> Dictionary:
  """Calculate unified recoil forces for the weapon"""
  if not cartridge:
    return {}

    # Base recoil impulse from cartridge (in N·s)
  var base_impulse = cartridge.recoil_impulse

    # Apply weapon-specific damping based on mass
  var mass_damping = 1.0 / (base_mass * recoil_damping_factor * 0.1)
  var effective_impulse = base_impulse * mass_damping

    # Apply attachment modifiers
  var recoil_multiplier = 1.0
  for att in attachments.values():
    recoil_multiplier *= att.recoil_modifier

  effective_impulse *= recoil_multiplier

    # Unified recoil pattern - mostly back, slightly up
  var backward_component = effective_impulse * 1.0
  var vertical_component = effective_impulse * muzzle_rise_factor * 0.6
  var horizontal_component = effective_impulse * (1.0 - muzzle_rise_factor) * randf_range(-0.15, 0.15)

    # Return forces in weapon-relative space
  var recoil_force = Vector3(
    horizontal_component * get_current_recoil_horizontal(),
    vertical_component * get_current_recoil_vertical(),
    -backward_component * get_current_recoil_kick()
  )

    # Calculate rotational forces (pitch up + some yaw)
  var recoil_torque = Vector3(
    -effective_impulse * get_current_recoil_tilt() * 0.4,
    randf_range(-0.1, 0.1) * effective_impulse * 0.08,
    randf_range(-0.05, 0.05) * effective_impulse * 0.05
  )

  return {
    "recoil_force": recoil_force,
    "recoil_torque": recoil_torque,
    "total_impulse": effective_impulse
  }

func get_ejection_data(cartridge: Ammo) -> Dictionary:
  """Calculate ejection forces for spent casing"""
  if not cartridge:
    return {}

  var base_velocity = cartridge.ejection_velocity
  var casing_mass = cartridge.cartridge_mass / 1000.0

    # Stronger ejection for VR visibility
  var ejection_velocity = base_velocity * ejection_force_multiplier * 2.0
  var ejection_momentum = ejection_velocity * casing_mass

    # Convert to force
  var ejection_force = ejection_momentum / 0.01

    # Ejection direction in weapon-relative space (right, up, back)
  var ejection_direction_normalized = Vector3(1.0, 0.3, -0.2).normalized()

  var final_force = ejection_direction_normalized * ejection_force

    # Stronger spin for VR visibility
  var spin_force = Vector3(
    randf_range(-15.0, 15.0),
    randf_range(-8.0, 8.0),
    randf_range(-20.0, 20.0)
  ) * casing_mass * ejection_spin_multiplier * 2.0

  return {
    "linear_force": final_force,
    "spin_force": spin_force,
    "casing_mass": casing_mass,
    "ejection_direction": ejection_direction_normalized
  }
# ─── ATTACHMENTS ───────────────────────────────────
func attach_attachment(point: int, attachment: Attachment) -> bool:
  if not (attach_points & point) or attachments.has(point):
    return false
  if not attachment.attach_to_weapon(self):
    return false
  attachments[point] = attachment
  attachment_added.emit(self, attachment, point)
  return true

func detach_attachment(point: int) -> bool:
  if not attachments.has(point):
    return false
  var attachment = attachments[point]
  attachment.detach_from_weapon()
  attachments.erase(point)
  attachment_removed.emit(self, attachment, point)
  return true

func get_attachment(point: int) -> Attachment:
  return attachments.get(point)

func get_all_attachments() -> Array:
  return attachments.values()

# ─── FIREMODE ──────────────────────────────────────
func cycle_firemode():
  WeaponSystem.cycle_firemode(self)

func safe_firemode():
  firemode = Firemode.SAFE
  firemode_changed.emit(self, "SAFE")

func is_firemode_available(mode: int) -> bool:
  return bool(firemodes & mode)

# ─── STATE HELPERS ─────────────────────────────────
func is_automatic() -> bool:
  return Firemode.is_automatic(firemode)

func get_firemode_name() -> String:
  return Firemode.get_mode(firemode)

# ─── AMMO & MAGAZINE ───────────────────────────────
func cycle_weapon() -> void:
  WeaponSystem.cycle_weapon(self)

func insert_cartridge(cartridge: Ammo) -> void:
  WeaponSystem.insert_cartridge(self, cartridge)

func change_magazine(new_mag: AmmoFeed) -> bool:
  return WeaponSystem.change_magazine(self, new_mag)

# ─── STATS ─────────────────────────────────────────
func get_current_accuracy() -> float:
  var mult = 1.0 + (100.0 - current_durability) / 200.0
  var acc = base_accuracy * mult
  for att in attachments.values():
    acc *= att.accuracy_modifier
  return acc

func get_current_recoil_vertical() -> float:
  var rec = base_recoil_vertical
  for att in attachments.values():
    rec *= att.recoil_modifier
  return rec

func get_current_recoil_horizontal() -> float:
  var rec = base_recoil_horizontal
  for att in attachments.values():
    rec *= att.recoil_modifier
  return rec

func get_current_recoil_kick() -> float:
  var rec = base_recoil_kick
  for att in attachments.values():
    rec *= att.recoil_modifier
  return rec

func get_current_recoil_tilt() -> float:
  var rec = base_recoil_tilt
  for att in attachments.values():
    rec *= att.recoil_modifier
  return rec

func get_reload_time() -> float:
  var mult = 1.5 if ammo_feed and not ammo_feed.is_empty() else 1.0
  var time = base_reload_time * mult
  for att in attachments.values():
    time *= att.reload_speed_modifier
  return time

func get_mass() -> float:
  var total = base_mass
  if ammo_feed:
    total += ammo_feed.mass
  for att in attachments.values():
    total += att.mass
  return total

func get_recoil_vector() -> Vector2:
  return Vector2(
    randf_range(-recoil_horizontal, recoil_horizontal),
    -recoil_vertical * (0.8 + randf() * 0.4)
  )

func release_trigger():
  WeaponSystem.release_trigger(self)

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
@export var base_mass: float = 3.5
@export var base_reload_time: float = 2.5
@export var base_accuracy: float = 2.0
@export var base_recoil_vertical: float = 1.0
@export var base_recoil_horizontal: float = 0.5
@export var base_recoil_tilt = 1.5
@export var base_recoil_kick = 0.04

# ─── STATE ─────────────────────────────────────────
var firemode: int = Firemode.SAFE
var semi_control: bool = false
var burst_counter: int = 0
var chambered_round: Ammo = null
var is_cycled: bool = true
var current_durability: float = 100.0
var attachments: Dictionary = {}  # point: Attachment

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

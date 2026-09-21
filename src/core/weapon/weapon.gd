# res://addons/cabra.lat_shooters/src/core/weapon/weapon.gd
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
signal weapon_malfunctioned(weapon: Weapon, kind: int)
signal malfunction_cleared(weapon: Weapon, kind: int)

# ─── ENUMS ─────────────────────────────────────────
enum AttachmentPoint {
  MUZZLE     = 1 << 0,
  LEFT_RAIL  = 1 << 1,
  RIGHT_RAIL = 1 << 2,
  TOP_RAIL   = 1 << 3,
  UNDER      = 1 << 4,
}

## Internal key for magazine-type attachments. Magazines ride the existing
## MagazinePoint / ammo_feed path instead of an attach_points rail bit.
const MAGAZINE_POINT := -1

# Genre-typical weapon faults. NONE = healthy.
enum Malfunction {
  NONE,
  FEED_FAILURE,   # round not chambered
  STOVEPIPE,      # case caught in the ejection port
  MISFIRE,        # dud cartridge, no bang
}

# ─── METADATA ──────────────────────────────────────
@export_multiline var description: String = "This Weapon is the default one."
## Pending consumer: weapon audio (fire/feed/empty/extra) — wired by the audio lane.
@export var fire_sound: AudioStream
@export var feed_sound: AudioStream
@export var empty_sound: AudioStream
@export var extra_sound: AudioStream

# ─── CONFIGURATION ─────────────────────────────────
@export var ammo_feed: AmmoFeed
@export_flags("MUZZLE", "LEFT_RAIL", "RIGHT_RAIL", "TOP_RAIL", "UNDER", "NONE")
var attach_points: int = 0
@export_flags("SAFE", "AUTO", "SEMI", "BURST", "PUMP", "BOLT")
var firemodes: int = Firemode.SEMI:
  set(value):
    firemodes = value
    _refresh_firemode()
@export var feed_type: AmmoFeed.Type = AmmoFeed.Type.INTERNAL

# ─── BASE STATS ────────────────────────────────────
@export var firerate: float = 600
@export var burst_count: int = 3
@export_custom(PROPERTY_HINT_NONE, "suffix:kg") var base_mass: float = 3.5
@export var base_reload_time: float = 2.5
@export var base_accuracy: float = 2.0

# ─── MECHANICS (malfunctions / wear / ergonomics) ───
@export_group("Mechanics")
@export var max_durability: float = 100.0
@export_custom(PROPERTY_HINT_NONE, "suffix:/shot") var durability_wear_per_shot: float = 0.01
@export_custom(PROPERTY_HINT_NONE, "suffix:/shot") var ammo_burn_wear_scale: float = 0.0002
@export_range(0.0, 1.0) var base_malfunction_chance: float = 0.0
@export_range(0.0, 1.0) var base_stovepipe_chance: float = 0.05
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var cleaning_time: float = 1.5
@export var base_ergonomics: float = 50.0
@export_custom(PROPERTY_HINT_NONE, "suffix:0-1") var repair_loss_ratio: float = 0.1
@export_custom(PROPERTY_HINT_NONE, "suffix:kg") var ergonomic_reference_mass: float = 3.5

# ─── SIGHTS (iron fallback; a mounted OPTICS attachment overrides) ──
@export_group("Sights")
@export_custom(PROPERTY_HINT_NONE, "suffix:m") var sight_height_over_bore: float = 0.04  # m, sight line above bore
@export_custom(PROPERTY_HINT_NONE, "suffix:m") var zero_distance: float = 50.0  # m, POA == POI (resolver compensates drop)
@export_custom(PROPERTY_HINT_NONE, "suffix:x") var magnification: float = 1.0  # 1.0 = irons; FOV only, never ballistics

# ─── RECOIL PHYSICS ────────────────────────────────
@export_group("Recoil Physics")
@export var base_recoil_vertical: float = 1.0
@export var base_recoil_horizontal: float = 0.5
@export var base_recoil_tilt = 1.5
@export var base_recoil_kick = 0.04

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
var active_malfunction: int = Malfunction.NONE
var _magazine_base_capacity: int = -1
var clearing_t: float = 0.0
var repair_count: int = 0
var wear_accumulated: float = 0.0

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

# ─── EFFECTIVE SIGHTS (optic override, else iron fallback) ──
func get_optic_attachment() -> Attachment:
  for att in attachments.values():
    if att is Attachment and att.type == Attachment.AttachmentType.OPTICS:
      return att
  return null

func get_effective_sight_height() -> float:
  var o := get_optic_attachment()
  return o.sight_height_over_bore if o != null else sight_height_over_bore

func get_effective_zero_distance() -> float:
  var o := get_optic_attachment()
  return o.zero_distance if o != null else zero_distance

func get_effective_magnification() -> float:
  var o := get_optic_attachment()
  return o.magnification if o != null else magnification

# ─── INIT ──────────────────────────────────────────
func _init():
  _refresh_firemode()

## Firemode is derived from the available-modes mask. Called on mask assignment
## (including .tres deserialization) because _init runs before it.
func _refresh_firemode() -> void:
  firemode = Firemode.get_initial_from_available(firemodes)
  if firemode == Firemode.BURST:
    burst_counter = burst_count

# ─── EJECTION ──────────────────────────────────────
# ─── ATTACHMENTS ───────────────────────────────────
func attach_attachment(point: int, attachment: Attachment) -> bool:
  var is_magazine := attachment.type == Attachment.AttachmentType.MAGAZINE
  var key := MAGAZINE_POINT if is_magazine else point
  if not is_magazine and not (attach_points & point):
    return false
  if attachments.has(key):
    return false
  if not attachment.attach_to_weapon(self):
    return false
  attachments[key] = attachment
  if is_magazine:
    _apply_magazine_capacity(attachment)
  attachment_added.emit(self, attachment, key)
  return true

func detach_attachment(point: int) -> bool:
  if not attachments.has(point):
    return false
  var attachment = attachments[point]
  attachment.detach_from_weapon()
  attachments.erase(point)
  if attachment.type == Attachment.AttachmentType.MAGAZINE:
    _restore_magazine_capacity()
  attachment_removed.emit(self, attachment, point)
  return true

## Magazine attachments feed the weapon by scaling the live ammo_feed capacity.
func _apply_magazine_capacity(a: Attachment) -> void:
  if ammo_feed == null:
    return
  if _magazine_base_capacity < 0:
    _magazine_base_capacity = ammo_feed.max_capacity
  ammo_feed.max_capacity = maxi(1, int(round(_magazine_base_capacity * a.capacity_multiplier)))

func _restore_magazine_capacity() -> void:
  if ammo_feed != null and _magazine_base_capacity >= 0:
    ammo_feed.max_capacity = _magazine_base_capacity
  _magazine_base_capacity = -1

func get_attachment(point: int) -> Attachment:
  return attachments.get(point)

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

func durability_recoil_multiplier() -> float:
  return 1.0 + (1.0 - durability_ratio()) * 0.5

func get_current_recoil_vertical() -> float:
  var rec = base_recoil_vertical * durability_recoil_multiplier()
  for att in attachments.values():
    rec *= att.recoil_modifier
  return rec

func get_current_recoil_horizontal() -> float:
  var rec = base_recoil_horizontal * durability_recoil_multiplier()
  for att in attachments.values():
    rec *= att.recoil_modifier
  return rec

func get_current_recoil_kick() -> float:
  var rec = base_recoil_kick * durability_recoil_multiplier()
  for att in attachments.values():
    rec *= att.recoil_modifier
  return rec

func get_current_recoil_tilt() -> float:
  var rec = base_recoil_tilt * durability_recoil_multiplier()
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

# ─── MECHANICS: DURABILITY / WEAR ──────────────────
func durability_ratio() -> float:
  return clampf(current_durability / maxf(max_durability, 1.0), 0.0, 1.0)

## Applies one shot of wear (weapon base + the round's durability_burn).
func apply_firing_wear(cartridge: Ammo = null) -> float:
  var wear := max_durability * durability_wear_per_shot
  if cartridge != null:
    wear += max_durability * cartridge.durability_burn * ammo_burn_wear_scale
  current_durability = maxf(0.0, current_durability - wear)
  wear_accumulated += wear
  return wear

## Weapon repair: restores current durability but permanently reduces MAX
## durability (genre-typical). Cannot be done in raid.
func apply_repair(kit: RepairKit = null, in_raid: bool = false) -> float:
  if in_raid or not is_repairable():
    return 0.0
  var loss_mult := kit.loss_multiplier if kit != null else 1.0
  var restore := kit.restore_ratio if kit != null else 1.0
  var before := max_durability
  max_durability = maxf(1.0, max_durability * (1.0 - repair_loss_ratio * loss_mult))
  current_durability = max_durability * restore
  repair_count += 1
  return before - max_durability

func is_repairable() -> bool:
  return current_durability > 0.0 and max_durability > 5.0

# ─── MECHANICS: MALFUNCTIONS ───────────────────────
## Probability per shot of each fault at the current wear. Ratings map to
## per-shot chances (None..Very high = 0..5).
static func rating_chance(r: int) -> float:
  return [0.0, 0.001, 0.003, 0.008, 0.02, 0.05][clampi(r, 0, 5)]

func malfunction_chance(cartridge: Ammo = null) -> Dictionary:
  var wear_factor := 1.0 + (1.0 - durability_ratio()) * 3.0
  var feed := base_malfunction_chance
  var misfire := base_malfunction_chance
  if cartridge != null:
    feed += rating_chance(cartridge.feed_failure) * wear_factor
    misfire += rating_chance(cartridge.misfire) * wear_factor
  var stove := base_stovepipe_chance * (1.0 - durability_ratio()) * wear_factor
  return {
    "feed": clampf(feed, 0.0, 0.95),
    "misfire": clampf(misfire, 0.0, 0.95),
    "stovepipe": clampf(stove, 0.0, 0.95),
    "total": clampf(feed + misfire + stove, 0.0, 0.95),
  }

## Deterministic when rolls are supplied (tests); otherwise uses randf().
func roll_malfunction(cartridge: Ammo = null, feed_roll: float = -1.0,
    fire_roll: float = -1.0, stove_roll: float = -1.0) -> int:
  var c := malfunction_chance(cartridge)
  var fr := feed_roll if feed_roll >= 0.0 else randf()
  var sr := fire_roll if fire_roll >= 0.0 else randf()
  var tr := stove_roll if stove_roll >= 0.0 else randf()
  if sr < float(c["misfire"]):
    return Malfunction.MISFIRE
  if fr < float(c["feed"]):
    return Malfunction.FEED_FAILURE
  if tr < float(c["stovepipe"]):
    return Malfunction.STOVEPIPE
  return Malfunction.NONE

## Triggers a fault (used by WeaponSystem when pull_trigger fails). While a
## fault is active the weapon cannot fire until cleared.
func trigger_malfunction(kind: int) -> void:
  if kind == Malfunction.NONE:
    return
  active_malfunction = kind
  weapon_malfunctioned.emit(self, kind)

func clearing_time_for(kind: int) -> float:
  match kind:
    Malfunction.MISFIRE: return cleaning_time * 0.7
    Malfunction.STOVEPIPE: return cleaning_time * 1.3
    _: return cleaning_time

## Troubleshooting: begins clearing. One entry point, per-kind duration; the
## kind is recorded so distinct animations/actions can be added later.
func start_clearing() -> bool:
  if active_malfunction == Malfunction.NONE:
    return false
  if clearing_t <= 0.0:
    clearing_t = float(clearing_time_for(active_malfunction))
  return true

func clear_immediately() -> void:
  _finish_clearing()

## Must be called each frame by the holding node (Weapon3D).
func advance(delta: float) -> void:
  if clearing_t > 0.0:
    clearing_t = maxf(0.0, clearing_t - delta)
    if clearing_t == 0.0:
      _finish_clearing()

func _finish_clearing() -> void:
  var kind := active_malfunction
  if kind == Malfunction.NONE:
    return
  active_malfunction = Malfunction.NONE
  clearing_t = 0.0
  malfunction_cleared.emit(self, kind)

static func malfunction_name(kind: int) -> String:
  return ["none", "feed_failure", "stovepipe", "misfire"][clampi(kind, 0, 3)]

# ─── MECHANICS: ERGONOMICS / ADS / MOVE ────────────
func get_effective_ergonomics() -> float:
  var erg := base_ergonomics
  for att in attachments.values():
    erg *= att.ergonomics_modifier
  return clampf(erg, 1.0, 100.0)

func get_ads_time_multiplier() -> float:
  var mult := clampf(base_ergonomics / maxf(get_effective_ergonomics(), 1.0), 0.5, 2.0)
  for att in attachments.values():
    mult *= att.aim_down_sights_modifier
  return mult

func get_ads_time(base_aim_time: float) -> float:
  return base_aim_time * get_ads_time_multiplier()

func get_sway_multiplier() -> float:
  var erg_sway := clampf(base_ergonomics / maxf(get_effective_ergonomics(), 1.0), 0.6, 1.8)
  return erg_sway * (1.0 + (1.0 - durability_ratio()) * 0.3)

## Movement speed scale from weight (contrast with ergonomics, which drives ADS).
func get_move_speed_multiplier() -> float:
  var overload := maxf(get_mass() - ergonomic_reference_mass, 0.0)
  return clampf(1.0 - overload * 0.03, 0.6, 1.0)

## State snapshot for HUD / verification.
func get_state() -> Dictionary:
  return {
    "durability": current_durability,
    "max_durability": max_durability,
    "durability_ratio": durability_ratio(),
    "ergonomics": get_effective_ergonomics(),
    "ads_time_multiplier": get_ads_time_multiplier(),
    "sway_multiplier": get_sway_multiplier(),
    "move_speed_multiplier": get_move_speed_multiplier(),
    "malfunction": active_malfunction,
    "malfunction_name": malfunction_name(active_malfunction),
    "clearing": clearing_t,
  }

func release_trigger():
  WeaponSystem.release_trigger(self)

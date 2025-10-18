# res://src/core/ammo/ammo.gd
class_name Ammo
extends Item

# ─── CORE METADATA ───────────────────────────────
@export var caliber: String = "Unknown Caliber":
  set(value):
    _caliber_data = Utils.parse_caliber(value)
    caliber = value
@export_multiline var description: String = "Generic ammunition"
@export var shell_model: PackedScene
@export var shell_sound: AudioStream

# ─── BALLISTIC PROPERTIES ─────────────────────────
enum Type {
  FMJ, JSP, JHP, AP, API, STEEL_CORE, GREEN_TIP, M995,
  FSP, FRAGMENTATION, SLUG, BUCKSHOT, BIRD_SHOT,
  TRACER, INCENDIARY, HOLLOW_POINT
}

@export var type: Type = Type.FMJ
@export var bullet_mass: float = 1.0     # grams
@export var cartridge_mass: float = 1.0  # grams
@export var muzzle_velocity: float = 1.0 # m/s

# ─── ADVANCED BALLISTICS ──────────────────────────
@export_group("Advanced Ballistics")
@export var ballistic_coefficient: float = 0.3
@export var bullet_length: float = 20.0         # mm
@export var bullet_diameter: float = 7.62       # mm
@export var sectional_density: float = 0.2      # kg/m²

# ─── PENETRATION MODEL ────────────────────────────
@export_group("Unified Penetration Model")
@export var reference_penetration: float = 15.0  # mm RHA at reference_distance
@export var reference_distance: float = 100.0    # meters
@export var penetration_at_500m: float = 8.0
@export var armor_performance: float = 1.0
@export var core_hardness: float = 300.0         # BHN
@export var core_density: float = 7.85           # g/cm³
@export var angle_performance: float = 1.0

# ─── TERMINAL EFFECTS ─────────────────────────────
@export var armor_modifier: float = 1.0
@export var flesh_modifier: float = 1.0
@export var ricochet_angle: float = 30.0        # degrees
@export_range(0.0, 1.0) var armor_damage: float = 0.0
@export_range(0.0, 1.0) var bleeding_chance: float = 0.0
@export_range(0.0, 1.0) var ricochet_chance: float = 0.0
@export_range(0.0, 1.0) var fragment_chance: float = 0.0
@export var accuracy: float = 1.0  # mm R50 at 300m

func get_mass() -> float:
  return cartridge_mass

# ─── INTERNAL STATE ───────────────────────────────
var _caliber_data: Dictionary = {}

# ─── COMPUTED PROPERTIES ──────────────────────────
var cross_sectional_area: float:
  get: return PI * pow(bullet_diameter / 2000.0, 2)  # m²

var kinetic_energy: float:
  get: return Utils.bullet_energy(bullet_mass, muzzle_velocity)

var momentum: float:
  get: return (bullet_mass / 1000.0) * muzzle_velocity

var bore_mm: float:
  get: return _caliber_data.get("bore_mm", bullet_diameter)

var case_mm: float:
  get: return _caliber_data.get("case_mm", 0.0)

# ─── INIT ─────────────────────────────────────────
func _init(mass: float = 1.0, speed: float = 1.0, ammo_type: Type = Type.FMJ) -> void:
  bullet_mass = mass
  muzzle_velocity = speed
  type = ammo_type
  _caliber_data = Utils.parse_caliber(caliber)

# ─── PHYSICS METHODS ──────────────────────────────
func get_energy() -> float:
  return Utils.bullet_energy(bullet_mass, muzzle_velocity)

func get_velocity_at_range(distance: float) -> float:
  var drag_factor = ballistic_coefficient * distance / 1000.0
  return muzzle_velocity * exp(-drag_factor)

func get_energy_at_range(distance: float) -> float:
  var v = get_velocity_at_range(distance)
  return Utils.bullet_energy(bullet_mass, v)

func get_ballistic_drop(distance: float, zero_range: float = 100.0, gravity: float = 9.81) -> float:
  var time = distance / muzzle_velocity
  var drop = 0.5 * gravity * pow(time, 2)
  var zero_time = zero_range / muzzle_velocity
  var zero_drop = 0.5 * gravity * pow(zero_time, 2)
  return drop - zero_drop

func should_ricochet(impact_angle: float, surface_hardness: float = 1.0) -> bool:
  var base_chance = ricochet_chance * surface_hardness
  var angle_factor = 1.0 - (impact_angle / ricochet_angle)
  return randf() < (base_chance * angle_factor)

func should_fragment(impact_energy: float, target_hardness: float = 1.0) -> int:
  var energy_threshold = get_energy() * 0.3
  if impact_energy < energy_threshold:
    return 0
  var effective_chance = fragment_chance * (impact_energy / get_energy())
  if randf() < effective_chance:
    return int(randf() * 10.0)
  return 0

func is_deforming() -> bool:
  return type in [Type.JHP, Type.HOLLOW_POINT, Type.JSP, Type.SLUG, Type.FRAGMENTATION, Type.FSP]

# ─── FACTORY METHODS ──────────────────────────────
static func create_test_ammo() -> Ammo:
  var a = Ammo.new()
  a.caliber = "9mm"
  a.type = Ammo.Type.FMJ
  a.bullet_mass = 8.0
  a.muzzle_velocity = 360.0
  a.armor_modifier = 1.0
  a.flesh_modifier = 1.0
  a.ricochet_chance = 0.1
  a.accuracy = 2.0
  return a

static func create_jhp_ammo() -> Ammo:
  var a = create_test_ammo()
  a.type = Ammo.Type.JHP
  a.flesh_modifier = 1.4
  a.armor_modifier = 0.4
  return a

static func create_ap_ammo() -> Ammo:
  var a = Ammo.new()
  a.type = Ammo.Type.AP
  a.name = "5.56x45mm Armor Piercing 3 (M995)"
  a.caliber = "5.56x45mm"
  a.description = "Tungsten carbide core for hard target penetration."
  a.bullet_mass = 3.4
  a.muzzle_velocity = 1030.0
  return a

static func create_test_shotgun_ammo() -> Ammo:
  var a = Ammo.new()
  a.name = "Test Buckshot"
  a.caliber = "12 Gauge"
  a.type = Ammo.Type.BUCKSHOT
  a.bullet_mass = 32.0
  a.muzzle_velocity = 400.0
  return a

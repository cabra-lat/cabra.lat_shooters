class_name Ammo
extends Item

# ─── CORE METADATA ───────────────────────────────
@export var caliber: String = "Unknown Caliber":
  set(value):
    _caliber_data = Utils.parse_caliber(value)
    caliber = value
@export_multiline var description: String = "Generic ammunition"
@export var shell_model: PackedScene  # 3D model for the casing
@export var shell_sound: AudioStream

# ─── BALLISTIC PROPERTIES ─────────────────────────
enum Type {
  FMJ, JSP, JHP, AP, API, STEEL_CORE, GREEN_TIP, M995,
  FSP, FRAGMENTATION, SLUG, BUCKSHOT, BIRD_SHOT,
  TRACER, INCENDIARY, HOLLOW_POINT
}

@export var type: Type = Type.FMJ
@export_custom(PROPERTY_HINT_NONE, "suffix:g") var bullet_mass: float = 8.0     # grams
@export_custom(PROPERTY_HINT_NONE, "suffix:g") var cartridge_mass: float = 12.0  # grams
@export_custom(PROPERTY_HINT_NONE, "suffix:m/s") var muzzle_velocity: float = 360.0 # m/s

# ─── RECOIL & EJECTION PHYSICS ────────────────────
@export_group("Recoil Physics")
@export_custom(PROPERTY_HINT_NONE, "suffix:g") var propellant_mass: float = 0.4  # grams
@export_custom(PROPERTY_HINT_NONE, "suffix:m/s") var gas_velocity: float = 1200.0  # m/s
@export_custom(PROPERTY_HINT_NONE, "suffix:m/s") var ejection_velocity: float = 5.0  # m/s

# ─── ADVANCED BALLISTICS ──────────────────────────
@export_group("Advanced Ballistics")
@export var ballistic_coefficient: float = 0.3
@export_custom(PROPERTY_HINT_NONE, "suffix:mm") var bullet_length: float = 20.0         # mm
@export_custom(PROPERTY_HINT_NONE, "suffix:mm") var bullet_diameter: float = 7.62       # mm
@export_custom(PROPERTY_HINT_NONE, "suffix:kg/m²") var sectional_density: float = 0.2      # kg/m²

# ─── PENETRATION MODEL ────────────────────────────
@export_group("Unified Penetration Model")
@export_custom(PROPERTY_HINT_NONE, "suffix:mmRHA") var reference_penetration: float = 15.0  # mm RHA at reference_distance
@export_custom(PROPERTY_HINT_NONE, "suffix:m") var reference_distance: float = 100.0    # meters
@export_custom(PROPERTY_HINT_NONE, "suffix:m") var penetration_at_500m: float = 8.0
@export var armor_performance: float = 1.0
@export_custom(PROPERTY_HINT_NONE, "suffix:BHN") var core_hardness: float = 300.0         # BHN
@export_custom(PROPERTY_HINT_NONE, "suffix:g/cm³") var core_density: float = 7.85           # g/cm³
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
  return cartridge_mass / 1000.0  # Convert grams to kg

# ─── INTERNAL STATE ───────────────────────────────
var _caliber_data: Dictionary = {}

# ─── COMPUTED PROPERTIES ──────────────────────────
var cross_sectional_area: float:
  get: return PI * pow(bullet_diameter / 2000.0, 2)  # m²

var kinetic_energy: float:
  get:
    return Utils.bullet_energy(bullet_mass / 1000.0, muzzle_velocity)  # Convert to kg

var momentum: float:
  get: return (bullet_mass / 1000.0) * muzzle_velocity  # Convert to kg

var bore_mm: float:
  get: return _caliber_data.get("bore_mm", bullet_diameter)

var case_mm: float:
  get: return _caliber_data.get("case_mm", 0.0)

# Computed property for automatic recoil calculation
var recoil_impulse: float:
  get:
        # Recoil impulse = bullet momentum + gas momentum
        # All masses in kg, velocities in m/s
    var bullet_momentum = (bullet_mass / 1000.0) * muzzle_velocity  # kg·m/s
    var gas_momentum = (propellant_mass / 1000.0) * gas_velocity * 1.5  # Factor for gas expansion
    return bullet_momentum + gas_momentum

# ─── INIT ─────────────────────────────────────────
func _init(mass: float = 8.0, speed: float = 360.0, ammo_type: Type = Type.FMJ) -> void:
  bullet_mass = mass
  muzzle_velocity = speed
  type = ammo_type
  _caliber_data = Utils.parse_caliber(caliber)

# ─── FACTORY METHODS ──────────────────────────────
static func create_9mm_ammo() -> Ammo:
  var a = Ammo.new()
  a.name = "9x19mm Parabellum"
  a.caliber = "9mm"
  a.type = Ammo.Type.FMJ
  a.bullet_mass = 8.0
  a.cartridge_mass = 12.0
  a.muzzle_velocity = 360.0
  a.propellant_mass = 0.4
  a.gas_velocity = 1200.0
  a.ejection_velocity = 5.0
  return a

static func create_556_ammo() -> Ammo:
  var a = Ammo.new()
  a.name = "5.56x45mm NATO"
  a.caliber = "5.56x45mm"
  a.type = Ammo.Type.FMJ
  a.bullet_mass = 4.0
  a.cartridge_mass = 12.0
  a.muzzle_velocity = 940.0
  a.propellant_mass = 1.6
  a.gas_velocity = 1400.0
  a.ejection_velocity = 6.0
  return a

static func create_762x39_ammo() -> Ammo:
  var a = Ammo.new()
  a.name = "7.62x39mm"
  a.caliber = "7.62x39mm"
  a.type = Ammo.Type.FMJ
  a.bullet_mass = 8.0
  a.cartridge_mass = 16.0
  a.muzzle_velocity = 720.0
  a.propellant_mass = 1.2
  a.gas_velocity = 1300.0
  a.ejection_velocity = 5.5
  return a

static func create_308_ammo() -> Ammo:
  var a = Ammo.new()
  a.name = "7.62x51mm NATO"
  a.caliber = "7.62x51mm"
  a.type = Ammo.Type.FMJ
  a.bullet_mass = 9.5
  a.cartridge_mass = 24.0
  a.muzzle_velocity = 860.0
  a.propellant_mass = 2.4
  a.gas_velocity = 1400.0
  a.ejection_velocity = 6.5
  return a

static func create_12g_buckshot() -> Ammo:
  var a = Ammo.new()
  a.name = "12 Gauge Buckshot"
  a.caliber = "12 Gauge"
  a.type = Ammo.Type.BUCKSHOT
  a.bullet_mass = 32.0
  a.cartridge_mass = 40.0
  a.muzzle_velocity = 400.0
  a.propellant_mass = 2.0
  a.gas_velocity = 1100.0
  a.ejection_velocity = 7.0
  return a

static func create_test_ammo() -> Ammo:
  return create_9mm_ammo()

static func create_jhp_ammo() -> Ammo:
  var a = create_9mm_ammo()
  a.type = Ammo.Type.JHP
  a.name = "9mm JHP"
  a.flesh_modifier = 1.4
  a.armor_modifier = 0.4
  return a

static func create_ap_ammo() -> Ammo:
  var a = create_556_ammo()
  a.type = Ammo.Type.AP
  a.name = "5.56x45mm Armor Piercing (M995)"
  a.description = "Tungsten carbide core for hard target penetration."
  a.armor_modifier = 2.0
  a.flesh_modifier = 0.8
  return a

static func create_test_shotgun_ammo() -> Ammo:
  return create_12g_buckshot()

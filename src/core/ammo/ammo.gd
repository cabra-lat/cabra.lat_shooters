class_name Ammo
extends Item

# ─── CORE METADATA ───────────────────────────────
@export var caliber: String = "Unknown Caliber":
  set(value):
    _caliber_data = Utils.parse_caliber(value)
    caliber = value

# ─── BALLISTIC PROPERTIES ─────────────────────────
enum Type {
  FMJ, JSP, JHP, AP, API, STEEL_CORE, GREEN_TIP, M995,
  FSP, FRAGMENTATION, SLUG, BUCKSHOT, BIRD_SHOT,
  TRACER, INCENDIARY, HOLLOW_POINT
}

@export var type: Type = Type.FMJ
@export var base_damage: float = 0.0  # genre-typical damage stat (per projectile)
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

# ─── TERMINAL EFFECTS ─────────────────────────────
@export var armor_modifier: float = 1.0
@export var flesh_modifier: float = 1.0
@export var ricochet_angle: float = 30.0        # degrees
@export_range(0.0, 1.0) var armor_damage: float = 0.0
@export_range(0.0, 1.0) var bleeding_chance: float = 0.0
@export_range(0.0, 1.0) var ricochet_chance: float = 0.0
@export_range(0.0, 1.0) var fragment_chance: float = 0.0
@export var accuracy: float = 1.0  # mm R50 at 300m

# ─── TERMINAL / MALFUNCTION DATA (from reference infoboxes) ───
# Rating scale used by the genre for feedfailure / misfire.
enum Rating { NONE, VERY_LOW, LOW, MEDIUM, HIGH, VERY_HIGH }

@export_group("Terminal Effects")
@export_range(0.0, 1.0) var light_bleed_chance: float = 0.0   # chance per projectile
@export_range(0.0, 1.0) var heavy_bleed_chance: float = 0.0

@export_group("Weapon Malfunction")
@export var feed_failure: Rating = Rating.LOW
@export var misfire: Rating = Rating.LOW
@export_custom(PROPERTY_HINT_NONE, "suffix:%") var durability_burn: float = 0.0  # per shot
@export_custom(PROPERTY_HINT_NONE, "suffix:%") var heat: float = 0.0             # per shot

@export_group("Multi-Projectile")
# projectiles fired per cartridge (buckshot/flechette). bullet_mass and
# base_damage are PER PROJECTILE when this is > 1.
@export_range(1, 64) var projectile_count: int = 1
@export_custom(PROPERTY_HINT_NONE, "suffix:J") var projectile_damage: float = 0.0  # 0 => use base_damage

func get_mass() -> float:
  return cartridge_mass / 1000.0  # Convert grams to kg

# ─── TERMINAL / MULTI-PROJECTILE / EFFECTIVENESS API ───
func get_projectile_damage() -> float:
  return projectile_damage if projectile_damage > 0.0 else base_damage

static func rating_to_string(r: Rating) -> String:
  return ["None", "Very low", "Low", "Medium", "High", "Very high"][int(r)]

static func rating_from_string(s: String) -> Rating:
  match s.strip_edges().to_lower():
    "none": return Rating.NONE
    "very low", "verylow", "very_low": return Rating.VERY_LOW
    "low": return Rating.LOW
    "medium": return Rating.MEDIUM
    "high": return Rating.HIGH
    "very high", "veryhigh", "very_high": return Rating.VERY_HIGH
    _: return Rating.LOW

## Genre-typical effectiveness scale 0..6 (0 = pointless, 20+ hits; 6 = usually
## ignores, >80% pen) derived from reference penetration vs class reference.
func effectiveness_vs_class(armor_class: int) -> int:
  var thr := Certification.class_reference_rha(armor_class)
  if thr <= 0.0:
    return 6
  return effectiveness_for_ratio(reference_penetration / thr)

static func effectiveness_for_ratio(r: float) -> int:
  if r >= 1.35: return 6
  if r >= 1.05: return 5
  if r >= 0.90: return 4
  if r >= 0.72: return 3
  if r >= 0.55: return 2
  if r >= 0.40: return 1
  return 0

## Durability-wear multiplier the round inflicts on a plate of the class.
## Wear model: hardness/pen relative; heavier AP rounds burn less, overmatch more.
func armor_wear_factor(armor_class: int) -> float:
  var thr := Certification.class_reference_rha(armor_class)
  if thr <= 0.0:
    return 1.0
  return clampf(0.4 + 0.6 * (reference_penetration / thr), 0.4, 2.0)

# ─── INTERNAL STATE ───────────────────────────────
var _caliber_data: Dictionary = {}

# ─── COMPUTED PROPERTIES ──────────────────────────
var cross_sectional_area: float:
  get: return PI * pow(bullet_diameter / 2000.0, 2)  # m²

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

# ─── RANGE / ENERGY API (used by BallisticsCalculator) ──
func get_energy() -> float:
  return Utils.bullet_energy(bullet_mass, muzzle_velocity)

func get_velocity_at_range(distance_m: float) -> float:
  # Exponential velocity decay calibrated by ballistic coefficient.
  # Cheap stand-in for G1/G7 drag tables (future work: proper drag curves).
  if distance_m <= 0.0:
    return muzzle_velocity
  var scale = max(800.0, ballistic_coefficient * 12000.0)
  return muzzle_velocity * exp(-distance_m / scale)

func get_energy_at_range(distance_m: float) -> float:
  return Utils.bullet_energy(bullet_mass, get_velocity_at_range(distance_m))

func get_ballistic_drop(distance_m: float, _zero_range: float, gravity: float) -> float:
  var v = get_velocity_at_range(distance_m)
  if v <= 0.0:
    return 0.0
  var t = distance_m / v
  return 0.5 * gravity * t * t

func should_fragment(energy_j: float, _target_hardness: float) -> int:
  if fragment_chance <= 0.0 or energy_j < 300.0:
    return 0
  return int(ceil(fragment_chance * energy_j / 500.0))

func is_deforming() -> bool:
  return type in [Type.JHP, Type.JSP, Type.HOLLOW_POINT]

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

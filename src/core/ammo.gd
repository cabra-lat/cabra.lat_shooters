@tool
class_name Ammo extends Resource

# Normalized caliber data (computed from string)
var _caliber_data: Dictionary = Utils.parse_caliber("")

# ─── CORE METADATA ───────────────────────────────
@export var name: String = "Unnamed Ammo"  # e.g., "7.62x39mm", "5.56x45mm NATO"
@export var caliber: String = "Uknown Caliber":  # e.g., "7.62x39mm", "5.56x45mm NATO"
	set(value):
		_caliber_data = Utils.parse_caliber(value)
		caliber = value
@export_multiline var description: String = "Generic ammunition"
@export var view_model: PackedScene
@export var shell_model: PackedScene
@export var shell_sound: AudioStream

# ─── BALLISTIC PROPERTIES ─────────────────────────
enum Type {
	FMJ,           # Full Metal Jacket
	JSP,           # Jacketed Soft Point
	JHP,           # Jacketed Hollow Point
	AP,            # Armor-Piercing
	API,           # Armor-Piercing Incendiary
	STEEL_CORE,    # Mild/Steel Core (e.g., 7.62x39mm PS)
	GREEN_TIP,     # SS109 / M855 (steel penetrator tip)
	M995,          # Tungsten AP (5.56mm)
	FSP,           # Fragment (military sim)
	FRAGMENTATION, # Fragment (actual)
	SLUG,          # Shotgun slug
	BUCKSHOT,      # Shotgun buckshot
	BIRD_SHOT,     # Shotgun bird shot
	TRACER,        # Tracer rounds
	INCENDIARY,    # Incendiary rounds
	HOLLOW_POINT   # Expanding hollow point
}
@export var type: Type = Type.FMJ

@export var bullet_mass: float = 1.0     # grams
@export var cartridge_mass: float = 1.0  # grams
@export var muzzle_velocity: float = 1.0 # m/s
@export var penetration_value: float = 1.0     # mm RHA - Rolled Homogeneous Armour

# ─── ENHANCED BALLISTIC PROPERTIES ────────────────
@export_group("Advanced Ballistics")
@export var ballistic_coefficient: float = 0.3  # G1 BC for drag calculation
@export var bullet_length: float = 20.0         # mm
@export var bullet_diameter: float = 7.62       # mm
@export var sectional_density: float = 0.2      # kg/m²

# Terminal ballistics
@export var armor_modifier: float = 1.0         # Multiplier against armored targets
@export var flesh_modifier: float = 1.0         # Multiplier against unarmored targets
@export var ricochet_angle: float = 30.0        # Minimum angle for ricochet (degrees)

# Special effects
@export var tracer_duration: float = 0.0        # seconds of tracer visibility
@export var incendiary_chance: float = 0.0      # chance to ignite target
@export var fragmentation_chance: float = 0.0   # chance to fragment on impact

# ─── GAMEPLAY EFFECTS ────────────────────────────
@export_range(0.0, 1.0) var armor_damage: float = 0.0    # % armor durability loss
@export_range(0.0, 1.0) var bleeding_chance: float = 0.0 # % chance to cause bleed
@export_range(0.0, 1.0) var ricochet_chance: float = 0.0 # % chance to ricochet
@export_range(0.0, 1.0) var fragment_chance: float = 0.0 # % chance to fragment
@export var accuracy: float = 1.0  # mm R50 at 300m (lower = better)

# ─── COMPUTED PROPERTIES ─────────────────────────
var cross_sectional_area: float:
	get: return PI * pow(bullet_diameter / 2000.0, 2)  # m²

var kinetic_energy: float:
	get: return get_energy()

var momentum: float:
	get: return get_momentum()

var effective_range: float:
	get: return _calculate_effective_range()

var time_to_target: float:
	get: return _calculate_time_to_target()
	
var bore_mm: float:
	get: return _caliber_data.get("bore_mm", bullet_diameter)

var case_mm: float:
	get: return _caliber_data.get("case_mm", 0.0)

func _init(mass: float = bullet_mass, speed: float = muzzle_velocity, ammo_type: Type = type) -> void:
	self.bullet_mass = mass
	self.muzzle_velocity = speed
	self.type = ammo_type

# ─── ENHANCED PHYSICS METHODS ────────────────────
func get_energy() -> float:
	return Utils.bullet_energy(bullet_mass, muzzle_velocity)

func get_momentum() -> float:
	return (bullet_mass / 1000.0) * muzzle_velocity  # kg·m/s

func get_velocity_at_range(distance: float) -> float:
	# Calculate velocity at given range using ballistic coefficient
	# Simplified drag model - real implementation would use proper ballistic tables
	var drag_factor = ballistic_coefficient * distance / 1000.0
	return muzzle_velocity * exp(-drag_factor)

func get_energy_at_range(distance: float) -> float:
	var velocity = get_velocity_at_range(distance)
	return Utils.bullet_energy(bullet_mass, velocity)

func get_ballistic_drop(distance: float, zero_range: float = 100.0, gravity: float = 9.81) -> float:
	# Calculate bullet drop at given distance with zeroing
	var time = distance / muzzle_velocity
	var drop = 0.5 * gravity * pow(time, 2)
	
	# Adjust for zero range
	var zero_time = zero_range / muzzle_velocity
	var zero_drop = 0.5 * gravity * pow(zero_time, 2)
	
	return drop - zero_drop

func get_penetration_at_range(distance: float, target_hardness: float = 1.0) -> float:
	# Calculate penetration capability at range
	var energy_ratio = get_energy_at_range(distance) / get_energy()
	var range_penalty = 1.0 - (distance / 1000.0)  # Linear reduction up to 1000m
	return penetration_value * energy_ratio * range_penalty / target_hardness

func should_ricochet(impact_angle: float, surface_hardness: float = 1.0) -> bool:
	# Calculate ricochet chance based on angle and surface
	var base_chance = ricochet_chance * surface_hardness
	var angle_factor = 1.0 - (impact_angle / ricochet_angle)  # Higher angle = more chance
	return randf() < (base_chance * angle_factor)

func should_fragment(impact_energy: float, target_hardness: float = 1.0) -> int:
	# Fragmentation requires sufficient energy and the right conditions
	var energy_threshold = get_energy() * 0.3  # Minimum energy for fragmentation
	if impact_energy < energy_threshold:
		return false
	
	var effective_chance = fragment_chance * (impact_energy / get_energy())
	var random_number = randf()
	if random_number < effective_chance: return int(random_number * 10.0)
	return 0

## Effective range where energy drops below practical threshold
func _calculate_effective_range() -> float:
	var min_effective_energy = get_energy() * 0.5  # 50% energy loss threshold
	var range_estimate = 0.0
	var velocity = muzzle_velocity
	
	while velocity > 0 and get_energy_at_range(range_estimate) > min_effective_energy:
		range_estimate += 10.0
		velocity = get_velocity_at_range(range_estimate)
	
	return min(range_estimate, 2000.0)  # Cap at 2km

func _calculate_time_to_target(distance: float = effective_range) -> float:
	# Simplified time calculation (ignoring drag for simplicity)
	return distance / muzzle_velocity

# ─── DEBUG & INFO ────────────────────────────────
func get_ballistic_info() -> Dictionary:
	return {
		"caliber": caliber,
		"type": Type.keys()[type],
		"muzzle_velocity": muzzle_velocity,
		"muzzle_energy": get_energy(),
		"effective_range": effective_range,
		"ballistic_coefficient": ballistic_coefficient,
		"penetration_at_100m": get_penetration_at_range(100.0),
		"drop_at_300m": get_ballistic_drop(300.0)
	}

func is_deforming() -> bool:
	match type:
		Type.JHP, Type.HOLLOW_POINT, \
		Type.JSP, Type.SLUG, \
		Type.FRAGMENTATION, Type.FSP:
			return true
		_:
			return false

static func create_test_ammo() -> Ammo:
	# Create ammo with low penetration that armor can stop
	var test_ammo: Ammo = Ammo.new()
	test_ammo.caliber = "9mm"
	test_ammo.type = Ammo.Type.FMJ
	test_ammo.bullet_mass = 8.0
	test_ammo.muzzle_velocity = 360.0
	test_ammo.penetration_value = 5.0  # Reduced to ensure armor stops it
	test_ammo.armor_modifier = 1.0
	test_ammo.flesh_modifier = 1.0
	test_ammo.ricochet_chance = 0.1
	test_ammo.fragment_chance = 0.0
	test_ammo.accuracy = 2.0
	return test_ammo

static func create_jhp_ammo() -> Ammo:
	var ammo: Ammo = create_test_ammo()
	ammo.type = Ammo.Type.JHP
	ammo.flesh_modifier = 1.4
	ammo.armor_modifier = 0.4
	return ammo

static func create_ap_ammo() -> Ammo:
	var ammo = Ammo.new()
	ammo.type = Ammo.Type.AP
	ammo.name = "5.56x45mm Armor Piercing 3 (M995)"
	ammo.caliber = "5.57x46mm"
	ammo.description = """
	Significantly increases the warfighter's lethality. 
	Optimized projectile design with a tungsten carbide core for penetration of hard targets.
	Penetrates 12 mm rolled homogeneous armor 300HB at 100 m 
	and light body armor at normal combat distances.
	"""
	ammo.bullet_mass = 3.4
	ammo.muzzle_velocity = 1030.0
	ammo.penetration_value = 12.0 # mm RHA (300 HB)
	return ammo

static func create_test_shotgun_ammo() -> Ammo:
	var ammo = Ammo.new()
	ammo.name = "Test Buckshot"
	ammo.caliber = "12 Gauge"
	ammo.type = Ammo.Type.BUCKSHOT
	ammo.bullet_mass = 32.0  # Total payload
	ammo.muzzle_velocity = 400.0
	return ammo

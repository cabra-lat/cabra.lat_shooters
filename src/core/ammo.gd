@tool
class_name Ammo extends Resource

# ─── CORE METADATA ───────────────────────────────
@export var caliber: String = ""  # e.g., "7.62x39mm", "5.56x45mm NATO"
@export_multiline var description: String = "Generic ammunition"
@export var view_model: PackedScene
@export var shell_model: PackedScene
@export var shell_sound: AudioStream

var name: String:
	get: return caliber
	set(value): caliber = value

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
@export var penetration_value: float = 1.0     # relative or mm RHA

# ─── ENHANCED BALLISTIC PROPERTIES ────────────────
@export_group("Advanced Ballistics")
@export var ballistic_coefficient: float = 0.3  # G1 BC for drag calculation
@export var bullet_length: float = 20.0         # mm
@export var bullet_diameter: float = 7.62       # mm
@export var sectional_density: float = 0.2      # kg/m²

# Terminal ballistics
@export var base_damage: float = 50.0           # Base damage value
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

# Normalized caliber data (computed from string)
var _caliber_data: Dictionary = {}

func _ready():
	_caliber_data = Utils.parse_caliber(caliber)
	# Auto-populate bullet_diameter from caliber if not set
	if bullet_diameter <= 0.1 and _caliber_data.has("bore_mm"):
		bullet_diameter = _caliber_data.get("bore_mm", 7.62)

func get_bore_mm() -> float:
	return _caliber_data.get("bore_mm", bullet_diameter)

func get_case_mm() -> float:
	return _caliber_data.get("case_mm", 0.0)

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

# ─── TERMINAL BALLISTICS ─────────────────────────
func calculate_impact_damage(impact_energy: float, target_material: String = "flesh", hit_location: String = "torso") -> float:
	var base_dmg = base_damage * (impact_energy / get_energy())
	var material_multiplier = _get_material_multiplier(target_material)
	var location_multiplier = _get_location_multiplier(hit_location)
	
	return base_dmg * material_multiplier * location_multiplier

func should_ricochet(impact_angle: float, surface_hardness: float = 1.0) -> bool:
	# Calculate ricochet chance based on angle and surface
	var base_chance = ricochet_chance * surface_hardness
	var angle_factor = 1.0 - (impact_angle / ricochet_angle)  # Higher angle = more chance
	return randf() < (base_chance * angle_factor)

func should_fragment(impact_energy: float, target_hardness: float = 1.0) -> bool:
	# Fragmentation requires sufficient energy and the right conditions
	var energy_threshold = get_energy() * 0.3  # Minimum energy for fragmentation
	if impact_energy < energy_threshold:
		return false
	
	var effective_chance = fragment_chance * (impact_energy / get_energy())
	return randf() < effective_chance

# ─── INTERNAL HELPERS ────────────────────────────
func _calculate_effective_range() -> float:
	# Effective range where energy drops below practical threshold
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

func _get_material_multiplier(material: String) -> float:
	var multipliers = {
		"flesh": flesh_modifier,
		"armor": armor_modifier,
		"light_armor": armor_modifier * 1.2,
		"heavy_armor": armor_modifier * 0.7,
		"concrete": 0.3,
		"wood": 0.8,
		"glass": 1.5,
		"vehicle": 0.5
	}
	return multipliers.get(material, 1.0)

func _get_location_multiplier(location: String) -> float:
	var multipliers = {
		"head": 3.0,
		"neck": 2.0,
		"upper_chest": 1.3,
		"lower_chest": 1.0,
		"stomach": 1.1,
		"arms": 0.7,
		"legs": 0.8,
		"hands": 0.5,
		"feet": 0.5
	}
	return multipliers.get(location, 1.0)

# ─── TYPE-SPECIFIC BEHAVIORS ─────────────────────
func get_type_modifiers() -> Dictionary:
	match type:
		Type.FMJ:
			return {"penetration": 1.0, "flesh_damage": 0.9, "armor_damage": 1.0}
		Type.JHP:
			return {"penetration": 0.6, "flesh_damage": 1.4, "armor_damage": 0.4}
		Type.AP:
			return {"penetration": 1.8, "flesh_damage": 0.8, "armor_damage": 1.5}
		Type.STEEL_CORE:
			return {"penetration": 1.3, "flesh_damage": 1.0, "armor_damage": 1.2}
		Type.GREEN_TIP:
			return {"penetration": 1.4, "flesh_damage": 0.9, "armor_damage": 1.3}
		Type.TRACER:
			return {"penetration": 0.9, "flesh_damage": 0.9, "armor_damage": 0.9}
		Type.INCENDIARY:
			return {"penetration": 0.8, "flesh_damage": 1.1, "armor_damage": 0.8}
		Type.BUCKSHOT:
			return {"penetration": 0.3, "flesh_damage": 1.2, "armor_damage": 0.2}
		_:
			return {"penetration": 1.0, "flesh_damage": 1.0, "armor_damage": 1.0}

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

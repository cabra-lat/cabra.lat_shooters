# ballistic_material.gd
@tool
class_name BallisticMaterial extends Resource

signal material_penetrated(material: BallisticMaterial, depth: float)
signal material_ricochet(material: BallisticMaterial, angle: float)

enum Type {
	AIR,
	WATER,
	GLASS,
	WOOD,
	METAL_THIN,     # Car doors, aluminum
	METAL_MEDIUM,   # Steel plates, engine blocks
	METAL_HEAVY,    # Armor plate, concrete reinforcement
	CONCRETE,
	BRICK,
	ROCK,
	SOIL,
	FLESH_SOFT,     # Unarmored human
	FLESH_MEDIUM,   # Muscle, organs
	FLESH_HARD,     # Bone
	ARMOR_SOFT,     # Kevlar, soft armor
	ARMOR_MEDIUM,   # Ceramic plates
	ARMOR_HARD      # Hardened steel armor
}

# Material properties
@export var name: String
@export var type: Type = Type.FLESH_SOFT
@export var density: float = 1000.0        ## kg/m³
@export var hardness: float = 300.0        ## HB
@export var toughness: float = 1.0         ## Resistance to fracture
@export var thickness: float = 1.0         ## mm
@export var effectiveness: float = 1.0     ## Weared materials degrades its performance
@export var energy_absorption: float = 0.3 ## Energy absorbed if penetrated

# Ballistic interaction properties
@export var penetration_resistance: float = 1.0
@export var ricochet_chance_modifier: float = 1.0 ## Materials can increase the ricochet

# Visual/Audio effects
@export var impact_effect: PackedScene
@export var penetration_effect: PackedScene
@export var impact_sound: AudioStream
@export var exit_sound: AudioStream


static func penetration_classic(ammo: Ammo, material: BallisticMaterial) -> float:
	var penetration_length = ammo.bullet_length * sqrt(material.density)
	return penetration_length

static func Lanz_Odermat(ammo: Ammo, material: BallisticMaterial, impact_energy: float, b: float = 0.0):
	# P = L • V n • exp (-b/v2)
	var impact_velocity = Utils.bullet_velocity(ammo.bullet_mass, impact_energy)
	var penetration_length = ammo.bullet_length * sqrt(material.density) \
						   * exp(-b / impact_velocity**2)
	return penetration_length

static func Rapacki_1995(ammo: Ammo, material: BallisticMaterial, impact_energy: float):
	var q = 1.0
	var m = 1.0
	var S = q * (material.hardness) ** m
	var b = 2 * S / material.density
	return Lanz_Odermat(ammo, material, impact_energy, b)

#func calculate_penetration(projectile: Ammo, impact_energy: float, angle: float) -> float:
	#var effective_hardness = hardness * (1.0 + abs(cos(angle)))
	#var penetration_depth = (impact_energy) * (projectile.penetration_value / effective_hardness)
	#return max(0.0, penetration_depth)

func calculate_penetration(ammo: Ammo, material: BallisticMaterial, impact_energy: float, obliquity_deg: float = 0.0) -> float:
	var impact_velocity = Utils.bullet_velocity(ammo.bullet_mass, impact_energy)
	# Reference condition: 12 mm at 950 m/s into 300 BHN RHA (normal incidence)
	var v_ref = ammo.get_velocity_at_range(100) # m/s (estimated at 100 m)
	const h_ref = 300.0 # BHN
	const p_ref = 12.0  # mm
	
	# Sensitivity coefficients from Hohler & Stilp (averaged)
	var dP_dv = 0.092        # mm per (m/s)
	var dP_dH = -0.116       # mm per BHN
	
	# Velocity effect (linear approximation around reference)
	var delta_v = impact_velocity - v_ref
	var p_from_velocity = p_ref + dP_dv * delta_v
	
	# Hardness correction
	var delta_h = hardness - h_ref
	var p_corrected = p_from_velocity + dP_dH * delta_h
	
	# Obliquity correction (simplified: effective thickness = actual / cos(theta))
	# Only valid for theta < ~60°; for higher, ricochet likely
	var theta_rad = deg_to_rad(obliquity_deg)
	if theta_rad >= PI/2.0:
		return 0.0
	var cos_theta = cos(theta_rad)
	if cos_theta <= 0.0:
		return 0.0
	# Effective penetration reduced by cos(theta) (normal component)
	var p_oblique = p_corrected * cos_theta
	
	return max(0.0, p_oblique)

func should_ricochet(projectile: Ammo, impact_angle: float) -> bool:
	var base_ricochet_chance = projectile.ricochet_chance * ricochet_chance_modifier
	var angle_factor = 1.0 - (impact_angle / 90.0)
	return randf() < (base_ricochet_chance * angle_factor)

static func create_for_armor_certification(standard: int, level: int) -> BallisticMaterial:
	"""
	Creates ballistic material based on armor certification standards.
	Uses the certified threat energy levels to determine material properties.
	"""
	# Get the maximum energy threat for this certification level
	var max_threat_energy = Certification.get_max_certified_energy(standard, level)
	var armor_type = Certification.get_armor_type_for_certification(standard, level)
	
	return create_for_energy_stopping(max_threat_energy, armor_type)

static func create_for_energy_stopping(max_energy_joules: float, 
									 armor_type: Type = Type.ARMOR_MEDIUM,
									 safety_factor: float = 1.2) -> BallisticMaterial:
	"""
	Creates a ballistic material designed to stop projectiles up to specified energy.
	
	Parameters:
	- max_energy_joules: Maximum kinetic energy this material should stop (in Joules)
	- armor_type: Type of armor material (SOFT, MEDIUM, HARD)
	- safety_factor: Multiplier for extra protection margin (1.2 = 20% safety margin)
	"""
	var material = BallisticMaterial.new()
	material.type = armor_type
	
	# Base penetration resistance scales with required stopping energy
	var base_resistance = max_energy_joules * safety_factor
	
	match armor_type:
		Type.ARMOR_SOFT:  # Kevlar, aramid fibers
			material.name = "Soft Armor (%.0f J)" % max_energy_joules
			material.density = 1400.0  # kg/m³ - typical for ballistic fibers
			material.hardness = 3.0    # Relatively soft but tough
			material.toughness = 12.0  # High toughness (fibers absorb energy)
			material.penetration_resistance = base_resistance * 0.8
			material.ricochet_chance_modifier = 0.1  # Low ricochet chance
			
		Type.ARMOR_MEDIUM:  # Ceramic composites, polyethylene
			material.name = "Medium Armor (%.0f J)" % max_energy_joules
			material.density = 2600.0  # kg/m³ - ceramic/PE composite
			material.hardness = 15.0   # Medium hardness
			material.toughness = 8.0   # Moderate toughness
			material.penetration_resistance = base_resistance * 1.2
			material.ricochet_chance_modifier = 0.3
			
		Type.ARMOR_HARD:  # Steel plates, hardened ceramics
			material.name = "Hard Armor (%.0f J)" % max_energy_joules
			material.density = 7800.0  # kg/m³ - steel
			material.hardness = 25.0   # Very hard
			material.toughness = 6.0   # Lower toughness (brittle)
			material.penetration_resistance = base_resistance * 1.5
			material.ricochet_chance_modifier = 0.6  # High ricochet chance
			
		_:
			# Default to medium armor properties
			material.type = Type.ARMOR_MEDIUM
			material.density = 2000.0
			material.hardness = 10.0
			material.toughness = 8.0
			material.penetration_resistance = base_resistance
	
	return material

static func create_for_penetration_resistance(required_resistance: float,
											desired_hardness: float = 10.0,
											material_type: Type = Type.ARMOR_MEDIUM) -> BallisticMaterial:
	"""
	Creates material with specific penetration resistance value.
	Useful for tuning specific protection levels.
	"""
	var material = BallisticMaterial.new()
	material.type = material_type
	material.penetration_resistance = required_resistance
	
	# Set other properties based on resistance and hardness
	material.hardness = desired_hardness
	material.density = 1500.0 + (required_resistance * 0.1)
	material.toughness = max(5.0, 15.0 - (desired_hardness * 0.5))
	
	material.name = "Custom Armor (R:%.0f H:%.1f)" % [required_resistance, desired_hardness]
	
	return material


static func create_default_flesh_material() -> BallisticMaterial:
	var material = BallisticMaterial.new()
	material.name = "Human Flesh"
	material.type = BallisticMaterial.Type.FLESH_SOFT
	material.density = 1060.0
	material.hardness = 0.5
	material.toughness = 2.0
	material.penetration_resistance = 0.1
	return material

static func create_default_bone_material() -> BallisticMaterial:
	var material = BallisticMaterial.new()
	material.name = "Human Bone"
	material.type = BallisticMaterial.Type.FLESH_HARD
	material.density = 1900.0
	material.hardness = 3.0
	material.toughness = 5.0
	material.penetration_resistance = 0.5
	return material

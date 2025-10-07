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
@export var density: float = 1000.0  # kg/m³
@export var hardness: float = 1.0    # Relative hardness scale
@export var toughness: float = 1.0   # Resistance to fracture

# Ballistic interaction properties
@export var penetration_resistance: float = 1.0
@export var ricochet_chance_modifier: float = 1.0
@export var damage_modifier: float = 1.0
@export var sound_absorption: float = 0.0

# Armor-specific properties
@export var armor_thickness: float = 0.0  # mm
@export var armor_effectiveness: float = 1.0  # Base protection level

# Visual/Audio effects
@export var impact_effect: PackedScene
@export var penetration_effect: PackedScene
@export var impact_sound: AudioStream
@export var exit_sound: AudioStream

func check_penetration(ammo: Ammo, impact_energy: float, armor_value: float = 1.0) -> Dictionary:
	var result = {
		"penetrated": true,
		"energy_absorbed": 0.0,
		"damage_reduction": 0.0,
		"blunt_trauma_multiplier": 0.3
	}
	
	# Non-armor materials always get penetrated
	if not _is_armor_material():
		return result
	
	# Calculate penetration based on ammo vs armor
	var penetration_power = ammo.penetration_value * ammo.armor_modifier * (impact_energy / ammo.kinetic_energy)
	var armor_resistance = armor_value * penetration_resistance * armor_effectiveness * 10.0
	
	if penetration_power > armor_resistance:
		# Penetrated
		result.penetrated = true
		result.energy_absorbed = impact_energy * 0.3
		result.damage_reduction = (result.energy_absorbed / impact_energy)
	else:
		# Stopped - blunt trauma only
		result.penetrated = false
		result.energy_absorbed = impact_energy * 0.8
		result.damage_reduction = result.blunt_trauma_multiplier * (1 - armor_value)
	
	return result

func calculate_penetration(projectile: Ammo, impact_energy: float, angle: float) -> float:
	var effective_hardness = hardness * (1.0 + abs(cos(angle)))
	var penetration_depth = (impact_energy / 1000.0) * (projectile.penetration_value / effective_hardness)
	return max(0.0, penetration_depth)

func should_ricochet(projectile: Ammo, impact_angle: float) -> bool:
	var base_ricochet_chance = projectile.ricochet_chance * ricochet_chance_modifier
	var angle_factor = 1.0 - (impact_angle / 90.0)
	return randf() < (base_ricochet_chance * angle_factor)

func get_damage_multiplier(hit_location: String = "torso") -> float:
	var location_multipliers = {
		"head": 3.0, "neck": 2.0, "torso": 1.0, "arms": 0.7, 
		"legs": 0.8, "hands": 0.5, "feet": 0.5
	}
	return damage_modifier * location_multipliers.get(hit_location, 1.0)

func _is_armor_material() -> bool:
	return type in [Type.ARMOR_SOFT, Type.ARMOR_MEDIUM, Type.ARMOR_HARD, 
				   Type.METAL_THIN, Type.METAL_MEDIUM, Type.METAL_HEAVY]

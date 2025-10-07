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
@export var sound_absorption: float = 0.0  # 0-1, 1 = complete absorption

# Visual/Audio effects
@export var impact_effect: PackedScene
@export var penetration_effect: PackedScene
@export var impact_sound: AudioStream
@export var exit_sound: AudioStream

func calculate_penetration(projectile: Ammo, impact_energy: float, angle: float) -> float:
	# Calculate penetration depth based on material and projectile properties
	var effective_hardness = hardness * (1.0 + abs(cos(angle)))  # Angle affects penetration
	var penetration_depth = (impact_energy / 1000.0) * (projectile.penetration_value / effective_hardness)
	return max(0.0, penetration_depth)

func should_ricochet(projectile: Ammo, impact_angle: float) -> bool:
	# Determine if projectile should ricochet
	var base_ricochet_chance = projectile.ricochet_chance * ricochet_chance_modifier
	var angle_factor = 1.0 - (impact_angle / 90.0)  # Higher angle = more chance to ricochet
	return randf() < (base_ricochet_chance * angle_factor)

func get_damage_multiplier(hit_location: String = "torso") -> float:
	# Location-based damage multipliers
	var location_multipliers = {
		"head": 3.0,
		"neck": 2.0,
		"torso": 1.0,
		"arms": 0.7,
		"legs": 0.8,
		"hands": 0.5,
		"feet": 0.5
	}
	return damage_modifier * location_multipliers.get(hit_location, 1.0)

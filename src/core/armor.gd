# armor.gd
@tool
class_name Armor extends Resource

## Body parts for hit detection and damage calculation.
## 
## Each part is a unique bit flag to allow combined hit zones (e.g., `HEAD | EYES`).
## Values are powers of two for bitwise operations.
enum BodyParts {
	HEAD      = 1 << 0,   ## Head (non-eye areas)
	EYES      = 1 << 1,   ## Eyes (critical hit zone)
	LEFT_ARM  = 1 << 2,   ## Left arm
	RIGHT_ARM = 1 << 3,   ## Right arm
	LEFT_LEG  = 1 << 4,   ## Left leg
	RIGHT_LEG = 1 << 5,   ## Right leg
	ABDOMEN   = 1 << 6,   ## Abdomen
	THORAX    = 1 << 7    ## Chest/torso (vital organs)
}
@export_flags(
	"HEAD", "EYES", "LEFT_ARM", "RIGHT_ARM",
	"LEFT_LEG", "RIGHT_LEG", "ABDOMEN", "THORAX"
) var protection_zones: int = 0

## Armor types for protection and equipment slots.
## 
## Determines what kind of armor piece this is and where it can be equipped.
enum ArmorType {
	GENERIC,  ## Generic armor (e.g., plates, non-specific)
	HELMET,   ## Head protection
	VEST      ## Torso protection (e.g., ballistic vest)
}
@export var type: ArmorType = ArmorType.GENERIC

# Metadata
@export var name: String = "Generic Armor"
@export_multiline var description: String = "This Armor is the default one."
@export var view_model: PackedScene
@export var equip_sound: AudioStream
@export var hit_sound: AudioStream

# Durability
@export var max_durability: int = 100
var current_durability: int = 100
@export_range(0, 50) var max_backface_deformation: float = 25.0 ## mm

# Gameplay penalties
@export_range(-1.0, 0.0) var turn_speed_penalty: float = 0.0
@export_range(-1.0, 0.0) var move_speed_penalty: float = 0.0
@export_range(0.0, 1.0) var ricochet_chance: float = 0.0
@export_range(-1.0, 0.0) var sound_reduction: float = 0.0
@export_range(-1.0, 0.0) var blind_reduction: float = 0.0

# Certification system (for reference/validation)
@export var standard: Certification.Standard = Certification.Standard.NIJ:
	set(value):
		standard = value
		material = BallisticMaterial.create_for_armor_certification(standard, level) # Armor material

@export_range(1, 14) var level: int = 1:
	set(value):
		level = value
		material = BallisticMaterial.create_for_armor_certification(standard, level) # Armor material

# Material
@export var material: BallisticMaterial = BallisticMaterial.create_for_armor_certification(standard, level) # Armor material

signal armor_damaged(armor: Armor, damage: float)
signal armor_destroyed(armor: Armor)

func take_damage(damage: float) -> void:
	current_durability = max(0, current_durability - damage)
	armor_damaged.emit(self, damage)
	
	if current_durability <= 0:
		armor_destroyed.emit(self)

func get_effective_armor_value() -> float:
	return (current_durability / max_durability) * material.effectiveness

func covers_body_part(body_part_type: BodyPart.Type) -> bool:
	var armor_body_part = _convert_to_armor_body_part(body_part_type)
	return protection_zones & armor_body_part

func _convert_to_armor_body_part(body_part_type: BodyPart.Type) -> int:
	match body_part_type:
		BodyPart.Type.HEAD: return BodyParts.HEAD
		BodyPart.Type.UPPER_CHEST, BodyPart.Type.LOWER_CHEST: return BodyParts.THORAX
		BodyPart.Type.ABDOMEN: return BodyParts.ABDOMEN
		BodyPart.Type.LEFT_UPPER_ARM, BodyPart.Type.LEFT_LOWER_ARM, BodyPart.Type.LEFT_HAND: return BodyParts.LEFT_ARM
		BodyPart.Type.RIGHT_UPPER_ARM, BodyPart.Type.RIGHT_LOWER_ARM, BodyPart.Type.RIGHT_HAND: return BodyParts.RIGHT_ARM
		BodyPart.Type.LEFT_UPPER_LEG, BodyPart.Type.LEFT_LOWER_LEG, BodyPart.Type.LEFT_FOOT: return BodyParts.LEFT_LEG
		BodyPart.Type.RIGHT_UPPER_LEG, BodyPart.Type.RIGHT_LOWER_LEG, BodyPart.Type.RIGHT_FOOT: return BodyParts.RIGHT_LEG
		_: return 0

# Certification validation (optional - for debugging/validation)
func validate_certification(ammo: Ammo) -> bool:
	# This can be used to validate if armor should stop this ammo based on certification
	# Useful for debugging or game balancing
	var certified_threats = Certification.get_certified_threats(standard, level)
	
	for threat in certified_threats:
		if _matches_threat(ammo, threat):
			return true  # Armor is certified to stop this threat
	
	return false

func check_penetration(ammo: Ammo, prev_impact: BallisticsImpact = null) -> BallisticsImpact:
	var impact: BallisticsImpact = prev_impact
	if not impact:

		impact = BallisticsImpact.new()#calculate_impact(ammo, material, 0.0, 0.0)
	
	if current_durability <= 0:
		impact.penetration_depth = impact.thickness # Penetrated!
		impact.exit_energy = impact.hit_energy # Should pass
		return impact
	
	# if certified should stop the bullet
	if validate_certification(ammo):
		impact.penetration_depth = 0.0
		impact.thickness = material.thickness
		impact.exit_energy = 0.0 # Should stop
		return impact

	# If not certified check energy,
	# if it's lower than the highest threat stopped, assume it stopped
	var certified_threats = Certification.get_certified_threats(standard, level)
	var max_certified_energy = certified_threats.map(func(threat): return threat.energy if threat.energy else 0.0).max()
	if impact.hit_energy < max_certified_energy:
		impact.penetration_depth = 0.0
		impact.thickness = material.thickness
		impact.exit_energy = 0.0 # Should stop
		return impact

	return impact

func is_penetrated_by(ammo: Ammo) -> bool:
	return check_penetration(ammo).penetrated

# In armor.gd - Improved _matches_threat function
func _matches_threat(ammo: Ammo, threat: Dictionary) -> bool:
	# Check if ammo matches the threat specification
	var energy_match = ammo.get_energy() <= threat.energy
	var type_match = ammo.type == threat.type
	var caliber_match = Utils.is_same_caliber(ammo.caliber, threat.caliber)
	# For exact certification, we need all three to match
	return caliber_match and type_match and energy_match

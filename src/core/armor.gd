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
	STOMACH   = 1 << 6,   ## Abdomen
	THORAX    = 1 << 7    ## Chest/torso (vital organs)
}
@export_flags(
	"HEAD", "EYES", "LEFT_ARM", "RIGHT_ARM",
	"LEFT_LEG", "RIGHT_LEG", "STOMACH", "THORAX"
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

# Material
@export var material: BallisticMaterial  # Armor material

# Durability
@export var max_durability: int = 100
var current_durability: int = 100
@export_range(0, 50) var max_backface_deformation: float = 25.0

# Gameplay penalties
@export_range(-1.0, 0.0) var turn_speed_penalty: float = 0.0
@export_range(-1.0, 0.0) var move_speed_penalty: float = 0.0
@export_range(0.0, 1.0) var ricochet_chance: float = 0.0
@export_range(-1.0, 0.0) var sound_reduction: float = 0.0
@export_range(-1.0, 0.0) var blind_reduction: float = 0.0

# Certification system (for reference/validation)
enum Standard { NIJ, VPAM, GOST, GA141, MILITARY }
@export var standard: Standard = Standard.NIJ
@export_range(1, 14) var level: int = 1

signal armor_damaged(armor: Armor, damage: float)
signal armor_destroyed(armor: Armor)

func check_penetration(ammo: Ammo, impact_energy: float) -> Dictionary:
	if current_durability <= 0:
		return {"penetrated": true, "damage_reduction": 1.0}
	
	# Use BallisticMaterial for penetration calculation
	var effective_armor_value = get_effective_armor_value()
	return material.check_penetration(ammo, impact_energy, effective_armor_value)

func take_damage(damage: float) -> void:
	current_durability = max(0, current_durability - damage)
	armor_damaged.emit(self, damage)
	
	if current_durability <= 0:
		armor_destroyed.emit(self)

func get_effective_armor_value() -> float:
	return (current_durability / max_durability) * material.armor_effectiveness

func covers_body_part(body_part_type: BodyPart.Type) -> bool:
	var armor_body_part = _convert_to_armor_body_part(body_part_type)
	return protection_zones & armor_body_part

func _convert_to_armor_body_part(body_part_type: BodyPart.Type) -> int:
	match body_part_type:
		BodyPart.Type.HEAD: return BodyParts.HEAD
		BodyPart.Type.UPPER_CHEST, BodyPart.Type.LOWER_CHEST: return BodyParts.THORAX
		BodyPart.Type.STOMACH: return BodyParts.STOMACH
		BodyPart.Type.LEFT_UPPER_ARM, BodyPart.Type.LEFT_LOWER_ARM, BodyPart.Type.LEFT_HAND: return BodyParts.LEFT_ARM
		BodyPart.Type.RIGHT_UPPER_ARM, BodyPart.Type.RIGHT_LOWER_ARM, BodyPart.Type.RIGHT_HAND: return BodyParts.RIGHT_ARM
		BodyPart.Type.LEFT_UPPER_LEG, BodyPart.Type.LEFT_LOWER_LEG, BodyPart.Type.LEFT_FOOT: return BodyParts.LEFT_LEG
		BodyPart.Type.RIGHT_UPPER_LEG, BodyPart.Type.RIGHT_LOWER_LEG, BodyPart.Type.RIGHT_FOOT: return BodyParts.RIGHT_LEG
		_: return 0

# Certification validation (optional - for debugging/validation)
func validate_certification(ammo: Ammo) -> bool:
	# This can be used to validate if armor should stop this ammo based on certification
	# Useful for debugging or game balancing
	var certified_threats = _get_certified_threats()
	
	for threat in certified_threats:
		if _matches_threat(ammo, threat):
			return true  # Armor is certified to stop this threat
	
	return false

# ─── PENETRATION LOGIC ──────────────────

func is_penetrated_by(ammo: Ammo) -> bool:
	if current_durability <= 0:
		return true
	
	var certified_threats = _get_certified_threats()
	var ammo_energy = ammo.get_energy()
	
	# Check if this specific ammo matches any certified threat
	for threat in certified_threats:
		if _matches_threat(ammo, threat):
			# If it matches a certified threat, armor should stop it
			return false
	
	# For non-certified threats, use energy-based fallback
	return ammo_energy > _get_fallback_threshold(certified_threats)

func _matches_threat(ammo: Ammo, threat: Dictionary) -> bool:
	# Check if ammo matches the threat specification
	var energy_match = ammo.get_energy() <= threat.energy
	var type_match = ammo.type == threat.type
	
	# For exact certification, we need both energy and type to match
	return energy_match and type_match

func _get_fallback_threshold(certified_threats: Array) -> float:
	if certified_threats.is_empty():
		return 1000.0
	
	# Use the highest certified energy as conservative estimate
	var max_energy = 0.0
	for threat in certified_threats:
		if threat.energy > max_energy:
			max_energy = threat.energy
	
	return max_energy

# ─── CORRECTED CERTIFICATION DATA ─────────────────

func _get_certified_threats() -> Array:
	match standard:
		Standard.VPAM:
			match level:
				1: return [ # .22 Long Rifle
					{"type": Ammo.Type.FMJ, "energy": E(2.6, 360), "caliber": ".22 LR"}
				]
				2: return [ # 9×19mm Parabellum
					{"type": Ammo.Type.FMJ, "energy": E(8.0, 360), "caliber": "9x19mm"}
				]
				3: return [ # 9×19mm Parabellum (higher velocity)
					{"type": Ammo.Type.FMJ, "energy": E(8.0, 415), "caliber": "9x19mm"}
				]
				4: return [ # .357 Magnum & .44 Magnum
					{"type": Ammo.Type.JSP, "energy": E(10.2, 430), "caliber": ".357 Magnum"},
					{"type": Ammo.Type.JHP, "energy": E(15.6, 440), "caliber": ".44 Magnum"}
				]
				5: return [ # .357 Magnum FMs
					{"type": Ammo.Type.FMJ, "energy": E(7.1, 580), "caliber": ".357 Magnum"}
				]
				6: return [ # 7.62×39mm PS
					{"type": Ammo.Type.STEEL_CORE, "energy": E(8.0, 720), "caliber": "7.62x39mm"}
				]
				7: return [ # 5.56×45mm SS109 & 7.62×51mm DM111
					{"type": Ammo.Type.GREEN_TIP, "energy": E(4.0, 950), "caliber": "5.56x45mm"},
					{"type": Ammo.Type.STEEL_CORE, "energy": E(9.55, 830), "caliber": "7.62x51mm"}
				]
				8: return [ # 7.62×39mm BZ API
					{"type": Ammo.Type.API, "energy": E(7.7, 740), "caliber": "7.62x39mm"}
				]
				9: return [ # 7.62×51mm P80 AP
					{"type": Ammo.Type.AP, "energy": E(9.7, 820), "caliber": "7.62x51mm"}
				]
				_: return []
		
		Standard.NIJ:
			match level:
				# NIJ 0101.06 (old standard)
				1: return [ # .22 LR & .380 ACP
					{"type": Ammo.Type.FMJ, "energy": E(2.6, 329), "caliber": ".22 LR"},
					{"type": Ammo.Type.FMJ, "energy": E(6.2, 322), "caliber": ".380 ACP"}
				]
				2: return [ # 9mm
					{"type": Ammo.Type.FMJ, "energy": E(8.0, 373), "caliber": "9x19mm"}
				]
				3: return [ # .357 Magnum
					{"type": Ammo.Type.JSP, "energy": E(10.2, 436), "caliber": ".357 Magnum"}
				]
				4: return [ # .30-06 M2 AP
					{"type": Ammo.Type.AP, "energy": E(10.8, 878), "caliber": ".30-06"}
				]
				# NIJ 0123.00 (2024 new standard)
				5: return [ # HG1 - 9mm & .357 Magnum
					{"type": Ammo.Type.FMJ, "energy": E(8.0, 398), "caliber": "9x19mm"}
				]
				6: return [ # HG2 - 9mm & .44 Magnum
					{"type": Ammo.Type.FMJ, "energy": E(8.0, 448), "caliber": "9x19mm"},
					{"type": Ammo.Type.JHP, "energy": E(15.6, 436), "caliber": ".44 Magnum"}
				]
				7: return [ # RF1 - 7.62x51mm & 7.62x39mm
					{"type": Ammo.Type.FMJ, "energy": E(9.6, 847), "caliber": "7.62x51mm"},
					{"type": Ammo.Type.STEEL_CORE, "energy": E(8.05, 732), "caliber": "7.62x39mm"}
				]
				8: return [ # RF2 - Adds M855 to RF1
					{"type": Ammo.Type.FMJ, "energy": E(9.6, 847), "caliber": "7.62x51mm"},
					{"type": Ammo.Type.STEEL_CORE, "energy": E(8.05, 732), "caliber": "7.62x39mm"},
					{"type": Ammo.Type.GREEN_TIP, "energy": E(4.0, 950), "caliber": "5.56x45mm"}
				]
				9: return [ # RF3 - .30-06 AP
					{"type": Ammo.Type.AP, "energy": E(10.8, 878), "caliber": ".30-06"}
				]
				_: return []
		
		Standard.GA141:
			match level:
				1: return [ # 7.62×17mm
					{"type": Ammo.Type.FMJ, "energy": E(4.87, 320), "caliber": "7.62x17mm"}
				]
				2: return [ # 7.62×25mm Tokarev (Pistol)
					{"type": Ammo.Type.FMJ, "energy": E(5.60, 445), "caliber": "7.62x25mm"}
				]
				3: return [ # 7.62×25mm Tokarev (SMG)
					{"type": Ammo.Type.FMJ, "energy": E(5.60, 515), "caliber": "7.62x25mm"}
				]
				4: return [ # 7.62×25mm Tokarev AP (SMG)
					{"type": Ammo.Type.AP, "energy": E(5.68, 515), "caliber": "7.62x25mm"}
				]
				5: return [ # 7.62×39mm
					{"type": Ammo.Type.STEEL_CORE, "energy": E(8.05, 725), "caliber": "7.62x39mm"}
				]
				6: return [ # 7.62×54mmR
					{"type": Ammo.Type.STEEL_CORE, "energy": E(9.60, 830), "caliber": "7.62x54mmR"}
				]
				_: return []
		
		Standard.MILITARY:
			match level:
				1: return [ # SAPI - stops M855
					{"type": Ammo.Type.FMJ, "energy": E(9.6, 840), "caliber": "7.62x51mm"},
					{"type": Ammo.Type.STEEL_CORE, "energy": E(9.5, 700), "caliber": "7.62x54mmR"}, 
					{"type": Ammo.Type.GREEN_TIP, "energy": E(4.0, 990), "caliber": "5.56x45mm"}
				]
				2: return [ # ESAPI Rev G - stops M995 AP
					{"type": Ammo.Type.FMJ, "energy": E(9.6, 840), "caliber": "7.62x51mm"},
					{"type": Ammo.Type.STEEL_CORE, "energy": E(9.5, 840), "caliber": "7.62x54mmR"},
					{"type": Ammo.Type.AP, "energy": E(10.8, 870), "caliber": ".30-06"},
					{"type": Ammo.Type.M995, "energy": E(3.6, 1020), "caliber": "5.56x45mm"}
				]
				_: return []
		Standard.GOST:
			match level:
				1: return [ # 9×18mm Makarov
					{"type": Ammo.Type.STEEL_CORE, "energy": E(5.9, 335), "caliber": "9x18mm"}
				]
				2: return [ # 9×21mm Gyurza
					{"type": Ammo.Type.FMJ, "energy": E(7.93, 390), "caliber": "9x21mm"}
				]
				3: return [ # 9×19mm 7N21
					{"type": Ammo.Type.STEEL_CORE, "energy": E(5.2, 455), "caliber": "9x19mm"}
				]
				4: return [ # 5.45×39mm & 7.62×39mm
					{"type": Ammo.Type.STEEL_CORE, "energy": E(3.4, 895), "caliber": "5.45x39mm"},
					{"type": Ammo.Type.STEEL_CORE, "energy": E(7.9, 720), "caliber": "7.62x39mm"}
				]
				5: return [ # 7.62×54mmR 7N13
					{"type": Ammo.Type.STEEL_CORE, "energy": E(9.4, 830), "caliber": "7.62x54mmR"}
				]
				6: return [ # 12.7×108mm B32 API
					{"type": Ammo.Type.API, "energy": E(48.2, 830), "caliber": "12.7x108mm"}
				]
				_: return []
		_:
			return []

# Keep your existing E(m, v) helper function
func E(m, v):
	return Utils.bullet_energy(m, v)

# res://src/core/health/wound.gd
class_name Wound
extends Resource

enum Severity {
	MINOR,      # Surface wounds, light bleeding
	MODERATE,   # Muscle damage, moderate bleeding  
	SEVERE,     # Bone/organ damage, heavy bleeding
	CRITICAL    # Limb loss, instant death scenarios
}

enum Type {
	BLEEDING,   # Blood loss - must be patched
	FRACTURE,   # Broken bone - must be immobilized
	BURN,       # Burning - must be patched
	PUNCTURE,   # Clean hole
	SHRAPNEL,   # Embedded fragments
	CAVITY,     # Internal temporary cavity
	CONCUSSION, # Brain trauma
	SCRATCHED   # Minor abrasion
}

@export var name: String = "Generic Wound"
@export var severity: Severity
@export var type: Type
@export var location: BodyPart.Type
@export var source_ammo: Ammo
@export var damage_per_second: float = 0.0
@export var duration: float = 0.0
@export var penetration_depth: float = 0.0  # cm

func _init(
	_severity: Severity,
	_type: Type,
	_location: BodyPart.Type,
	_source_ammo: Ammo = null,
	_dps: float = 0.0,
	_duration: float = 0.0,
	_penetration: float = 0.0
):
	severity = _severity
	type = _type
	location = _location
	source_ammo = _source_ammo
	damage_per_second = _dps
	duration = _duration
	penetration_depth = _penetration

static func create_ballistic_wound(bullet: Ammo, impact: BallisticsImpact, body_part: BodyPart) -> Wound:
	var severity: Severity
	var wound_type: Type
	var dps: float = 0.0
	var duration: float = 0.0

	# Step 1: Base severity by KE
	if impact.hit_energy < 500:
		severity = Severity.MINOR
	elif impact.hit_energy < 1000:
		severity = Severity.MODERATE
	elif impact.hit_energy < 2000:
		severity = Severity.SEVERE
	else:
		severity = Severity.CRITICAL

	# Step 2: Anatomical adjustment
	match body_part.type:
		BodyPart.Type.HEAD:
			if severity < Severity.SEVERE:
				severity = Severity.SEVERE
		BodyPart.Type.ABDOMEN, BodyPart.Type.UPPER_CHEST, BodyPart.Type.LOWER_CHEST:
			if impact.penetration_depth > Utils.to_mm(5.0):
				severity = max(severity, Severity.SEVERE)
		BodyPart.Type.LEFT_FOOT, BodyPart.Type.RIGHT_FOOT, \
		BodyPart.Type.LEFT_HAND, BodyPart.Type.RIGHT_HAND:
			if severity == Severity.MINOR:
				severity = Severity.MODERATE

	# Step 3: Wound type by bullet behavior
	if bullet.is_deforming():
		wound_type = Type.CAVITY
		if impact.hit_energy > 800:
			wound_type = Type.SHRAPNEL
	else:
		wound_type = Type.PUNCTURE
		if impact.penetrated and severity > Severity.MINOR:
			severity = severity - 1

	# Special ammo overrides
	if bullet.type in [Ammo.Type.BUCKSHOT, Ammo.Type.BIRD_SHOT]:
		wound_type = Type.SHRAPNEL
	elif bullet.type in [Ammo.Type.INCENDIARY, Ammo.Type.API]:
		wound_type = Type.BURN

	# Step 4: Secondary effects (bone fracture chance)
	var hit_long_bone := body_part.type in [
		BodyPart.Type.LEFT_UPPER_LEG, BodyPart.Type.RIGHT_UPPER_LEG,
		BodyPart.Type.LEFT_UPPER_ARM, BodyPart.Type.RIGHT_UPPER_ARM,
		BodyPart.Type.PELVIS
	]
	const bone_breaking_chance = 0.3
	if hit_long_bone and randf() < bone_breaking_chance and impact.hit_energy > 500:
		wound_type = Type.FRACTURE
		severity = max(severity, Severity.MODERATE)

	# Step 5: Bleeding for limb wounds
	if body_part.is_limb() and wound_type != Type.BURN and impact.hit_energy > 400:
		if wound_type in [Type.PUNCTURE, Type.CAVITY, Type.SHRAPNEL, Type.FRACTURE]:
			dps = 0.5 if severity == Severity.MODERATE else \
				  1.2 if severity == Severity.SEVERE else \
				  2.5
			duration = 30.0

	# Step 6: Joint-specific retained fragment risk
	if not impact.penetrated and wound_type == Type.SHRAPNEL and body_part.is_joint():
		severity = Severity.SEVERE

	return Wound.new(severity, wound_type, body_part.type, bullet, dps, duration, impact.penetration_depth)

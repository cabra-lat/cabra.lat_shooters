@tool
class_name Wound extends Resource

enum Severity {
	MINOR,      # Surface wounds, light bleeding
	MODERATE,   # Muscle damage, moderate bleeding  
	SEVERE,     # Bone/organ damage, heavy bleeding
	CRITICAL    # Limb loss, instant death scenarios
}

enum Type {
	BLEEDING,   ## Blood loss - must be patched with gazes
	FRACTURE,   ## Broken bone - muse be imobilized
	BURN,       ## Burning - must be patched with gazes
	PUNCTURE,   ## Hole
	SHRAPNEL,   ## Fragments
	CAVITY,     ## A internal hole
	CONCUSSION, ## 
	SCRATCHED   ## Scratches
}

@export var name: String = "Generic Wound"
@export var severity: Wound.Severity
@export var damage_per_second: float
@export var duration: float

var type: Type
var location: BodyPart.Type
var source_ammo: Ammo
var penetration_depth: float

func _init(_severity: Wound.Severity, _type: Type, _location: BodyPart.Type, 
		   _source_ammo: Ammo = null, _dps: float = 0.0, _duration: float = 0.0,
		   _penetration: float = 0.0):
	severity = _severity
	type = _type
	location = _location
	source_ammo = _source_ammo
	damage_per_second = _dps
	duration = _duration
	penetration_depth = _penetration

static func create_ballistic_wound(bullet: Ammo, impact: BallisticsImpact, body_part: BodyPart) -> Wound:
	var severity: Wound.Severity
	var wound_type: Wound.Type
	var dps: float = 0.0
	var duration: float = 0.0
	
	#region Step 1: Base severity by KE
	if impact.hit_energy < 500:
		severity = Wound.Severity.MINOR
	elif impact.hit_energy < 1000:
		severity = Wound.Severity.MODERATE
	elif impact.hit_energy < 2000:
		severity = Wound.Severity.SEVERE
	else:
		severity = Wound.Severity.CRITICAL
	#endregion
	#region Step 2: Anatomical adjustment
	match body_part.type:
		BodyPart.Type.HEAD:
			if severity < Wound.Severity.SEVERE:
				severity = Wound.Severity.SEVERE
		BodyPart.Type.ABDOMEN, BodyPart.Type.UPPER_CHEST, BodyPart.Type.LOWER_CHEST:
			if impact.penetration_cm > 5.0:
				severity = max(severity, Wound.Severity.SEVERE)
		BodyPart.Type.LEFT_FOOT, BodyPart.Type.RIGHT_FOOT, \
		BodyPart.Type.LEFT_HAND, BodyPart.Type.RIGHT_HAND:
			if severity == Wound.Severity.MINOR:
				severity = Wound.Severity.MODERATE
	#endregion
	#region Step 3: Wound type by bullet behavior
	if bullet.is_deforming():
		wound_type = Wound.Type.CAVITY
		if impact.hit_energy > 800:
			wound_type = Wound.Type.SHRAPNEL
	else:
		wound_type = Wound.Type.PUNCTURE
		if impact.penetrated and severity > Wound.Severity.MINOR:
			severity -= 1
	#endregion
	#region Special ammo overrides
	if bullet.type == Ammo.Type.BUCKSHOT or bullet.type == Ammo.Type.BIRD_SHOT:
		wound_type = Wound.Type.SHRAPNEL
	elif bullet.type == Ammo.Type.INCENDIARY or bullet.type == Ammo.Type.API:
		wound_type = Wound.Type.BURN
	#endregion
	#region Step 4: Secondary effects
	var hit_long_bone := body_part.type in [
		BodyPart.Type.LEFT_UPPER_LEG, BodyPart.Type.RIGHT_UPPER_LEG,
		BodyPart.Type.LEFT_UPPER_ARM, BodyPart.Type.RIGHT_UPPER_ARM,
		BodyPart.Type.PELVIS
	]
	#FIXME there is a chance of hitting the bone
	const bone_breaking_chance = 0.3
	if randf() < bone_breaking_chance and impact.hit_energy > 500:
		wound_type = Wound.Type.FRACTURE
		severity = max(severity, Wound.Severity.MODERATE)
	#endregion
	#region Bleeding for limb wounds (including fractures!)
	if body_part.is_limb() and wound_type != Wound.Type.BURN and impact.hit_energy > 400:
		if wound_type in [Wound.Type.PUNCTURE, Wound.Type.CAVITY, Wound.Type.SHRAPNEL, Wound.Type.FRACTURE]:
			dps = 0.5 if severity == Wound.Severity.MODERATE else \
				  1.2 if severity == Wound.Severity.SEVERE else \
				  2.5
			duration = 30.0
	#endregion
	#region Step 5: Joint-specific retained fragment risk
	if not impact.penetrated and wound_type == Wound.Type.SHRAPNEL and body_part.is_joint():
		severity = Wound.Severity.SEVERE
	#endregion
	return Wound.new(severity, wound_type, body_part.type, bullet, dps, duration, impact.penetration_cm)

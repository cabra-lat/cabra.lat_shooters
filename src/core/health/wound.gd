@tool
class_name Wound extends Resource

enum Severity {
	MINOR,      # Surface wounds, light bleeding
	MODERATE,   # Muscle damage, moderate bleeding  
	SEVERE,     # Bone/organ damage, heavy bleeding
	CRITICAL    # Limb loss, instant death scenarios
}

@export var name: String = "Generic Wound"
@export var severity: Wound.Severity
@export var damage_per_second: float
@export var duration: float

var type: String  # "bleeding", "fracture", "burn", "concussion", "puncture"
var location: BodyPart.Type
var source_ammo: Ammo
var penetration_depth: float

func _init(_severity: Wound.Severity, _type: String, _location: BodyPart.Type, 
		   _source_ammo: Ammo = null, _dps: float = 0.0, _duration: float = 0.0,
		   _penetration: float = 0.0):
	severity = _severity
	type = _type
	location = _location
	source_ammo = _source_ammo
	damage_per_second = _dps
	duration = _duration
	penetration_depth = _penetration

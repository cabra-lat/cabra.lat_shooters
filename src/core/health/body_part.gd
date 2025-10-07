@tool
class_name BodyPart extends Resource

enum Type {
	NONE,
	HEAD,
	UPPER_CHEST,
	LOWER_CHEST,
	STOMACH,
	LEFT_UPPER_ARM,
	RIGHT_UPPER_ARM,
	LEFT_LOWER_ARM,
	RIGHT_LOWER_ARM,
	LEFT_HAND,
	RIGHT_HAND,
	LEFT_UPPER_LEG,
	RIGHT_UPPER_LEG,
	LEFT_LOWER_LEG,
	RIGHT_LOWER_LEG,
	LEFT_FOOT,
	RIGHT_FOOT
}

@export var type: Type
@export var max_health: float
@export var current_health: float
@export var wounds: Array[Wound] = []
@export var functionality_multiplier: float = 1.0
@export var hitbox_size: float = 1.0  # Relative size for hit probability
@export var tissue_multiplier: float = 1.0
@export var is_destroyed: bool = false
@export var blunt_trauma_damage_multiplier: float = 1.0
@export var minimum_wound_damage: float = 1.0

#FIXME this should be Armor's data
@export var armor_value: float = 0.0
@export var armor_material: BallisticMaterial = null
@export var armor_protection_efficiency: float = 15.0

signal functionality_changed(multiplier: float)

func _init(_type: Type, _max_health: float, _hitbox_size: float = 1.0):
	type = _type
	max_health = _max_health
	current_health = _max_health
	hitbox_size = _hitbox_size

func set_tissue_multiplier(multiplier: float):
	tissue_multiplier = multiplier

func _get_tissue_multiplier() -> float:
	return tissue_multiplier

func take_ballistic_impact(ammo: Ammo, impact_data: Dictionary, distance: float) -> Dictionary:
	if is_destroyed:
		return {"damage_taken": 0.0, "penetrated": false, "wound_created": null}
	
	var result = {
		"damage_taken": 0.0,
		"penetrated": false,
		"wound_created": null,
		"armor_defeated": false,
		"energy_absorbed": 0.0
	}
	
	# Calculate effective armor protection
	var effective_armor = armor_value
	if armor_material:
		effective_armor *= armor_material.penetration_resistance
	
	# Check if armor is penetrated
	var penetration_result = _check_armor_penetration(ammo, impact_data, effective_armor)
	result.penetrated = penetration_result.penetrated
	result.energy_absorbed = penetration_result.energy_absorbed
	
	# Calculate base damage before armor reduction
	var base_damage = impact_data.damage * _get_tissue_multiplier()
	
	if result.penetrated:
		# Armor penetrated - but damage is still reduced by energy absorption
		var damage_reduction = 1.0 - (penetration_result.energy_absorbed / impact_data.energy)
		var actual_damage = base_damage * damage_reduction
		result.damage_taken = take_damage(actual_damage)
		
		# Create penetrating wound
		var wound = _create_ballistic_wound(ammo, impact_data, actual_damage, true)
		if wound:
			add_wound(wound)
			result.wound_created = wound
	else:
		# Armor stopped the round - reduced damage (blunt trauma)
		var armor_protection = effective_armor * armor_protection_efficiency
		var blunt_damage = base_damage * blunt_trauma_damage_multiplier * (1.0 - armor_protection)
		result.damage_taken = take_damage(blunt_damage)
		
		if blunt_damage > minimum_wound_damage:
			var wound = _create_ballistic_wound(ammo, impact_data, blunt_damage, false)
			if wound:
				add_wound(wound)
				result.wound_created = wound
	
	return result

func _check_armor_penetration(ammo: Ammo, impact_data: Dictionary, effective_armor: float) -> Dictionary:
	var result = {"penetrated": true, "energy_absorbed": 0.0}
	
	if effective_armor <= 0:
		return result
	
	# Calculate penetration based on ammo vs armor characteristics
	var penetration_power = ammo.penetration_value * ammo.armor_modifier * (impact_data.energy / ammo.kinetic_energy)
	var armor_resistance = effective_armor * armor_resistance_scale
	
	# Simple penetration threshold
	if penetration_power > armor_resistance:
		# Penetrated, but armor still absorbs some energy
		result.penetrated = true
		result.energy_absorbed = min(impact_data.energy * armor_energy_absorption_penetrated, armor_resistance * 2.0)
	else:
		# Not penetrated
		result.penetrated = false
		result.energy_absorbed = min(impact_data.energy * armor_energy_absorption_stopped, impact_data.energy)
	
	return result

func _create_ballistic_wound(ammo: Ammo, impact_data: Dictionary, damage: float, penetrated: bool) -> Wound:
	var severity = Wound.Severity.MINOR
	var wound_type = "puncture"
	var dps = 0.0
	var duration = 0.0
	
	# Determine severity based on damage and body part
	var damage_ratio = damage / max_health
	
	if damage_ratio > severe_wound_threshold: severity = Wound.Severity.CRITICAL
	elif damage_ratio > moderate_wound_threshold: severity = Wound.Severity.SEVERE
	elif damage_ratio > minor_wound_threshold: severity = Wound.Severity.MODERATE
	
	# Improved ammo type wound logic
	match ammo.type:
		Ammo.Type.JHP, Ammo.Type.HOLLOW_POINT:
			wound_type = "cavity"
			if penetrated: 
				dps = damage * 0.04  # High bleeding for expanding rounds
				duration = 25.0
		Ammo.Type.AP:
			wound_type = "puncture"  # AP always creates puncture wounds
			if penetrated:
				dps = damage * 0.015  # Low bleeding but deep penetration
				duration = 20.0
		Ammo.Type.INCENDIARY:
			wound_type = "burn"
			dps = damage * 0.03
			duration = 12.0
		Ammo.Type.FRAGMENTATION, Ammo.Type.FSP:
			wound_type = "fragmentation"
			dps = damage * 0.05
			duration = 8.0
		Ammo.Type.FMJ, Ammo.Type.STEEL_CORE, Ammo.Type.GREEN_TIP:
			# Standard ball ammunition - default to bleeding for penetrating wounds
			if penetrated and severity >= Wound.Severity.MODERATE:
				wound_type = "bleeding"
				dps = damage * 0.025 * (severity + 1)
				duration = 30.0 / (severity + 1)
	
	# Ensure AP ammo always creates puncture wounds, even without bleeding
	if ammo.type == Ammo.Type.AP and penetrated:
		wound_type = "puncture"
		# Ensure we have at least minimal ongoing effects for severe wounds
		if severity >= Wound.Severity.SEVERE and dps == 0.0:
			dps = damage * 0.01
			duration = 15.0
	
	# Bleeding override for most penetrating wounds, but preserve AP puncture wounds
	if penetrated and severity >= Wound.Severity.MODERATE and wound_type != "burn":
		# Don't override AP ammo puncture wounds
		if ammo.type != Ammo.Type.AP:
			# All other penetrating wounds cause some bleeding, unless it's a burn
			if wound_type != "bleeding" and wound_type != "fragmentation":
				wound_type = "bleeding"  # Override to bleeding for most wound types
			if dps == 0.0:
				dps = damage * 0.02 * (severity + 1)
				duration = 25.0 / (severity + 1)
	
	# Fractures for high damage to limbs
	if severity >= Wound.Severity.SEVERE and _is_limb():
		wound_type = "fracture"
		dps = damage * 0.008  # Ongoing pain from fracture
		duration = 75.0
	
	# Always create wounds for moderate+ severity or if there are ongoing effects
	if severity >= Wound.Severity.MODERATE or dps > 0 or duration > 0:
		return Wound.new(severity, wound_type, type, ammo, dps, duration, impact_data.get("penetration_depth", 0.0))
	
	return null
	
func _is_limb() -> bool:
	return type in [BodyPart.Type.LEFT_UPPER_ARM, BodyPart.Type.RIGHT_UPPER_ARM,
				   BodyPart.Type.LEFT_LOWER_ARM, BodyPart.Type.RIGHT_LOWER_ARM,
				   BodyPart.Type.LEFT_UPPER_LEG, BodyPart.Type.RIGHT_UPPER_LEG,
				   BodyPart.Type.LEFT_LOWER_LEG, BodyPart.Type.RIGHT_LOWER_LEG]

func take_damage(amount: float) -> float:
	if is_destroyed:
		return 0.0
		
	var old_health = current_health
	current_health = max(0, current_health - amount)
	
	if current_health == 0:
		is_destroyed = true
		_apply_destruction_effects()
	
	return old_health - current_health

func add_wound(wound: Wound):
	wounds.append(wound)
	_apply_wound_effects(wound)

func _apply_destruction_effects():
	match type:
		BodyPart.Type.HEAD, BodyPart.Type.UPPER_CHEST:
			functionality_multiplier = 0.0  # Instant death
		BodyPart.Type.LEFT_UPPER_ARM, BodyPart.Type.RIGHT_UPPER_ARM:
			functionality_multiplier = 0.2  # Severe aiming penalty
		BodyPart.Type.LEFT_LOWER_ARM, BodyPart.Type.RIGHT_LOWER_ARM:
			functionality_multiplier = 0.4  # Moderate aiming penalty
		BodyPart.Type.LEFT_HAND, BodyPart.Type.RIGHT_HAND:
			functionality_multiplier = 0.6  # Fine motor skill penalty
		BodyPart.Type.LEFT_UPPER_LEG, BodyPart.Type.RIGHT_UPPER_LEG:
			functionality_multiplier = 0.1  # Severe movement penalty
		BodyPart.Type.LEFT_LOWER_LEG, BodyPart.Type.RIGHT_LOWER_LEG:
			functionality_multiplier = 0.3  # Moderate movement penalty
		BodyPart.Type.LEFT_FOOT, BodyPart.Type.RIGHT_FOOT:
			functionality_multiplier = 0.5  # Minor movement penalty
		_:
			functionality_multiplier = 0.8
	
	functionality_changed.emit(functionality_multiplier)

func _apply_wound_effects(wound: Wound):
	match wound.type:
		"fracture":
			if wound.severity >= Wound.Severity.SEVERE:
				functionality_multiplier *= 0.3
			else:
				functionality_multiplier *= 0.7
		"bleeding":
			# Bleeding handled in update loop
			pass
		"concussion":
			functionality_multiplier *= 0.5
		"burn":
			functionality_multiplier *= 0.8
	
	functionality_changed.emit(functionality_multiplier)

func heal(amount: float):
	if is_destroyed:
		return
		
	var old_health = current_health
	current_health = min(max_health, current_health + amount)
	
	# Heal minor wounds automatically when health is high
	if current_health > max_health * 0.8:
		wounds = wounds.filter(func(wound): return wound.severity > Wound.Severity.MINOR)

func update(delta: float):
	# Process ongoing wound effects
	for wound in wounds:
		if wound.duration > 0:
			take_damage(wound.damage_per_second * delta)
			wound.duration -= delta
	
	# Remove expired wounds
	var remaining_wounds: Array[Wound] = []
	for wound in wounds:
		if wound.duration > 0:
			remaining_wounds.append(wound)
	wounds = remaining_wounds


func _to_string() -> String:
	match type:
		BodyPart.Type.HEAD: return "Head"
		BodyPart.Type.UPPER_CHEST: return "Upper Chest"
		BodyPart.Type.LOWER_CHEST: return "Lower Chest"
		BodyPart.Type.STOMACH: return "Stomach"
		BodyPart.Type.LEFT_UPPER_ARM: return "Left Upper Arm"
		BodyPart.Type.RIGHT_UPPER_ARM: return "Right Upper Arm"
		BodyPart.Type.LEFT_LOWER_ARM: return "Left Lower Arm"
		BodyPart.Type.RIGHT_LOWER_ARM: return "Right Lower Arm"
		BodyPart.Type.LEFT_HAND: return "Left Hand"
		BodyPart.Type.RIGHT_HAND: return "Right Hand"
		BodyPart.Type.LEFT_UPPER_LEG: return "Left Upper Leg"
		BodyPart.Type.RIGHT_UPPER_LEG: return "Right Upper Leg"
		BodyPart.Type.LEFT_LOWER_LEG: return "Left Lower Leg"
		BodyPart.Type.RIGHT_LOWER_LEG: return "Right Lower Leg"
		BodyPart.Type.LEFT_FOOT: return "Left Foot"
		BodyPart.Type.RIGHT_FOOT: return "Right Foot"
		_: return "Unknown"

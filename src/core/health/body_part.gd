# body_part.gd
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
@export var hitbox_size: float = 1.0
@export var tissue_multiplier: float = 1.0
@export var is_destroyed: bool = false

# Materials
@export var base_material: BallisticMaterial  # Flesh/bone material
@export var equipped_armor: Armor = null      # Optional armor

# Wound thresholds
@export var minor_wound_threshold: float = 0.3
@export var moderate_wound_threshold: float = 0.5  
@export var severe_wound_threshold: float = 0.8
@export var minimum_wound_damage: float = 5.0

signal functionality_changed(multiplier: float)

func _init(_type: Type, _max_health: float, _hitbox_size: float = 1.0):
	type = _type
	max_health = _max_health
	current_health = _max_health
	hitbox_size = _hitbox_size

func take_ballistic_impact(ammo: Ammo, impact_data: Dictionary, distance: float) -> Dictionary:

	var result = {
		"damage_taken": 0.0,
		"penetrated": false,
		"wound_created": null,
		"armor_penetrated": false
	}
	
	if is_destroyed: return result
	
	# Calculate base tissue damage
	var base_damage = impact_data.damage * tissue_multiplier
	
	# Check armor first
	if equipped_armor and equipped_armor.material:
		var armor_result = equipped_armor.check_penetration(ammo, impact_data.energy)
		result.penetrated = armor_result.penetrated
		result.armor_penetrated = armor_result.penetrated
		
		if result.penetrated:
			# Armor penetrated - reduced damage
			var actual_damage = base_damage * armor_result.damage_reduction
			result.damage_taken = take_damage(actual_damage)
			
			# Damage armor
			equipped_armor.take_damage(actual_damage)
			
			# Create penetrating wound
			var wound = _create_ballistic_wound(ammo, impact_data, actual_damage, true)
			if wound:
				wounds.append(wound)
				result.wound_created = wound
		else:
			# Armor stopped - blunt trauma
			var blunt_damage = base_damage * armor_result.damage_reduction
			result.damage_taken = take_damage(blunt_damage)
			
			# Less armor damage for stopped rounds
			equipped_armor.take_damage(blunt_damage * 0.5)
			
			if blunt_damage > minimum_wound_damage:
				var wound = _create_ballistic_wound(ammo, impact_data, blunt_damage, false)
				if wound:
					wounds.append(wound)
					result.wound_created = wound
	else:
		# No armor - full damage
		result.penetrated = true
		result.damage_taken = take_damage(base_damage)
		
		# Create wound
		var wound = _create_ballistic_wound(ammo, impact_data, base_damage, true)
		if wound:
			wounds.append(wound)
			result.wound_created = wound
	
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
				dps = damage * 0.04
				duration = 25.0
		Ammo.Type.AP:
			wound_type = "puncture"
			if penetrated:
				dps = damage * 0.015
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
			if penetrated and severity >= Wound.Severity.MODERATE:
				wound_type = "bleeding"
				dps = damage * 0.025 * (severity + 1)
				duration = 30.0 / (severity + 1)
	
	# Ensure AP ammo always creates puncture wounds
	if ammo.type == Ammo.Type.AP and penetrated:
		wound_type = "puncture"
		if severity >= Wound.Severity.SEVERE and dps == 0.0:
			dps = damage * 0.01
			duration = 15.0
	
	# Bleeding override for most penetrating wounds
	if penetrated and severity >= Wound.Severity.MODERATE and wound_type != "burn" and ammo.type != Ammo.Type.AP:
		if wound_type != "bleeding" and wound_type != "fragmentation":
			wound_type = "bleeding"
		if dps == 0.0:
			dps = damage * 0.02 * (severity + 1)
			duration = 25.0 / (severity + 1)
	
	# Fractures for high damage to limbs
	if severity >= Wound.Severity.SEVERE and _is_limb():
		wound_type = "fracture"
		dps = damage * 0.008
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
			functionality_multiplier = 0.0
		BodyPart.Type.LEFT_UPPER_ARM, BodyPart.Type.RIGHT_UPPER_ARM:
			functionality_multiplier = 0.2
		BodyPart.Type.LEFT_LOWER_ARM, BodyPart.Type.RIGHT_LOWER_ARM:
			functionality_multiplier = 0.4
		BodyPart.Type.LEFT_HAND, BodyPart.Type.RIGHT_HAND:
			functionality_multiplier = 0.6
		BodyPart.Type.LEFT_UPPER_LEG, BodyPart.Type.RIGHT_UPPER_LEG:
			functionality_multiplier = 0.1
		BodyPart.Type.LEFT_LOWER_LEG, BodyPart.Type.RIGHT_LOWER_LEG:
			functionality_multiplier = 0.3
		BodyPart.Type.LEFT_FOOT, BodyPart.Type.RIGHT_FOOT:
			functionality_multiplier = 0.5
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

func equip_armor(armor: Armor) -> void:
	equipped_armor = armor

func unequip_armor() -> void:
	equipped_armor = null

func _to_string() -> String:
	return BodyPart.Type.keys()[type] if type < BodyPart.Type.keys().size() else "Unknown"

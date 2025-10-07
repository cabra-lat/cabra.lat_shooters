# body_part.gd
@tool
class_name BodyPart extends Resource

enum Type {
	NONE,
	HEAD,
	CERVICAL_SPINE,
	THORACIC_SPINE,
	LUMBAR_SPINE,
	UPPER_CHEST,      # Clavicles, upper ribs, brachial plexus origin
	LOWER_CHEST,      # Lower ribs, diaphragm proximity
	ABDOMEN,
	PELVIS,           # Includes iliac bones, sacrum, hip girdle
	LEFT_SHOULDER,
	LEFT_UPPER_ARM,
	LEFT_ELBOW,
	LEFT_LOWER_ARM,
	LEFT_HAND,
	RIGHT_SHOULDER,
	RIGHT_UPPER_ARM,
	RIGHT_ELBOW,
	RIGHT_LOWER_ARM,
	RIGHT_HAND,
	LEFT_HIP,
	LEFT_UPPER_LEG,
	LEFT_KNEE,
	LEFT_LOWER_LEG,
	LEFT_FOOT,
	RIGHT_HIP,
	RIGHT_UPPER_LEG,
	RIGHT_KNEE,
	RIGHT_LOWER_LEG,
	RIGHT_FOOT
}

@export var type: Type
@export var max_health: float
@export var current_health: float
@export var wounds: Array[Wound] = []
@export var hitbox_size: float = 1.0
@export var tissue_multiplier: float = 1.0
@export var is_destroyed: bool = false

# Materials
@export var base_material: BallisticMaterial  # Flesh/bone material
@export var equipped_armor: Armor = null      # Optional armor

var functionality_multiplier: float = 1.0:
	get: return _get_functionality_multiplier()

signal functionality_changed(multiplier: float)

func _init(_type: Type, _max_health: float, _hitbox_size: float = 1.0):
	type = _type
	max_health = _max_health
	current_health = _max_health
	hitbox_size = _hitbox_size

func take_ballistic_impact(impact: BallisticsImpact) -> Dictionary:

	var result = {
		"damage_taken": 0.0,
		"penetrated": false,
		"wound_created": null,
		"armor_penetrated": false
	}
	
	if is_destroyed: return result
	
	# Calculate base tissue damage
	var base_damage = impact.damage * tissue_multiplier
	
	# Check armor first
	if equipped_armor and equipped_armor.material:
		pass
		#result.penetrated = impact.penetrated
		#result.armor_penetrated = impact.penetrated
		#
		#if result.penetrated:
			## Armor penetrated - reduced damage
			#var actual_damage = base_damage * (1 - impact.energy_loss)
			#result.damage_taken = take_damage(actual_damage)
			#
			## Damage armor
			#equipped_armor.take_damage(actual_damage)
			#
			## Create penetrating wound
			#var wound = _create_ballistic_wound(ammo, impact_data, actual_damage, true)
			#if wound:
				#wounds.append(wound)
				#result.wound_created = wound
		#else:
			## Armor stopped - blunt trauma
			#var blunt_damage = base_damage * (1 - impact.damage_reduction)
			#result.damage_taken = take_damage(blunt_damage)
			#
			## Less armor damage for stopped rounds
			#equipped_armor.take_damage(blunt_damage * 0.5)
			#
			#if blunt_damage > minimum_wound_damage:
				#var wound = _create_ballistic_wound(ammo, impact_data, blunt_damage, false)
				#if wound:
					#wounds.append(wound)
					#result.wound_created = wound
	#else:
		## No armor - full damage
		#result.penetrated = true
		#result.damage_taken = take_damage(base_damage)
		#
		## Create wound
		#var wound = _create_ballistic_wound(ammo, impact_data, base_damage, true)
		#if wound:
			#wounds.append(wound)
			#result.wound_created = wound
	
	return result

func is_limb() -> bool:
	return type in [
		Type.LEFT_UPPER_ARM, Type.LEFT_LOWER_ARM, Type.LEFT_HAND,
		Type.RIGHT_UPPER_ARM, Type.RIGHT_LOWER_ARM, Type.RIGHT_HAND,
		Type.LEFT_UPPER_LEG, Type.LEFT_LOWER_LEG, Type.LEFT_FOOT,
		Type.RIGHT_UPPER_LEG, Type.RIGHT_LOWER_LEG, Type.RIGHT_FOOT
	]

func is_joint() -> bool:
	return type in [
		Type.LEFT_SHOULDER, Type.RIGHT_SHOULDER,
		Type.LEFT_ELBOW, Type.RIGHT_ELBOW,
		Type.LEFT_HIP, Type.RIGHT_HIP,
		Type.LEFT_KNEE, Type.RIGHT_KNEE,
		Type.LEFT_HAND, Type.RIGHT_HAND,  # Carpometacarpal joints
		Type.LEFT_FOOT, Type.RIGHT_FOOT   # Subtalar/tibiotalar
	]

func is_spine() -> bool:
	return type in [Type.CERVICAL_SPINE, Type.THORACIC_SPINE, Type.LUMBAR_SPINE]

func is_torso() -> bool:
	return type in [Type.UPPER_CHEST, Type.LOWER_CHEST, Type.ABDOMEN, Type.PELVIS]

func take_damage(amount: float) -> float:
	if is_destroyed:
		return 0.0
		
	var old_health = current_health
	current_health = max(0, current_health - amount)
	
	if current_health == 0:
		is_destroyed = true
	
	return old_health - current_health

func add_wound(wound: Wound):
	wounds.append(wound)

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

func _get_functionality_multiplier():
	if is_destroyed:
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
				
		for wound in wounds:
			functionality_multiplier *= _get_wound_effects(wound)

static func _get_wound_effects(wound: Wound):
	match wound.type:
		Wound.Type.FRACTURE:
			if wound.severity >= Wound.Severity.SEVERE:
				return 0.3
			else:
				return 0.7
		Wound.Type.CONCUSSION:
			return 0.5
		Wound.Type.BURN:
			return 0.8
		_: return 1.0

func _to_string() -> String:
	return type_to_string(type)

static func type_to_string(type: BodyPart.Type) -> String:
	var string: String = BodyPart.Type.keys()[type] if type < BodyPart.Type.keys().size() else "Unknown"
	return string.capitalize()

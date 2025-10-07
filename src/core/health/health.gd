# health.gd
@tool
class_name Health extends Resource

signal health_changed(body_part: BodyPart, old_health: float, new_health: float)
signal body_part_destroyed(body_part: BodyPart)
signal wound_sustained(body_part: BodyPart, wound: Wound)
signal player_died(cause: String)
signal armor_penetrated(armor: Armor, location: BodyPart.Type)
signal bleeding_started(severity: float, location: BodyPart.Type)

# ─── CONFIGURATION VARIABLES ────────────────────────────────────────────────

# Bleeding Configuration
@export var bleeding_ml_per_damage_per_second: float = 10.0
@export var bleeding_health_damage_start_threshold: float = 0.1  # 10% blood loss
@export var bleeding_damage_multiplier_base: float = 1.0
@export var bleeding_damage_multiplier_max: float = 4.0

# Blood Loss Death Configuration  
@export var critical_blood_loss_threshold_ratio: float = 0.2   # 20% blood volume remaining
@export var blood_loss_low_health_threshold_ratio: float = 0.3
@export var blood_loss_low_health_ratio: float = 0.3

# Pain & Healing Configuration
@export var pain_increase_per_damage: float = 0.1
@export var pain_decrease_rate: float = 0.1
@export var healing_blood_restoration_multiplier: float = 2.0
@export var healing_bleeding_reduction_multiplier: float = 0.02

# Explosive Damage Configuration
@export var explosive_front_damage_ratio: float = 0.6
@export var explosive_back_damage_ratio: float = 0.4
@export var explosive_pain_multiplier: float = 0.15

# Body materials
@export var flesh_material: BallisticMaterial
@export var bone_material: BallisticMaterial

# Body Part Configuration
@export var body_part_config: Dictionary = {
	BodyPart.Type.HEAD: {"max_health": 40.0, "hitbox_size": 0.08, "tissue_multiplier": 3.0, "bone_material": true},
	BodyPart.Type.UPPER_CHEST: {"max_health": 70.0, "hitbox_size": 0.15, "tissue_multiplier": 1.5, "bone_material": true},
	BodyPart.Type.LOWER_CHEST: {"max_health": 60.0, "hitbox_size": 0.12, "tissue_multiplier": 1.2, "bone_material": true},
	BodyPart.Type.STOMACH: {"max_health": 50.0, "hitbox_size": 0.10, "tissue_multiplier": 1.3, "bone_material": false},
	BodyPart.Type.LEFT_UPPER_ARM: {"max_health": 35.0, "hitbox_size": 0.07, "tissue_multiplier": 0.8, "bone_material": true},
	BodyPart.Type.RIGHT_UPPER_ARM: {"max_health": 35.0, "hitbox_size": 0.07, "tissue_multiplier": 0.8, "bone_material": true},
	BodyPart.Type.LEFT_LOWER_ARM: {"max_health": 25.0, "hitbox_size": 0.05, "tissue_multiplier": 0.6, "bone_material": true},
	BodyPart.Type.RIGHT_LOWER_ARM: {"max_health": 25.0, "hitbox_size": 0.05, "tissue_multiplier": 0.6, "bone_material": true},
	BodyPart.Type.LEFT_HAND: {"max_health": 15.0, "hitbox_size": 0.03, "tissue_multiplier": 0.4, "bone_material": true},
	BodyPart.Type.RIGHT_HAND: {"max_health": 15.0, "hitbox_size": 0.03, "tissue_multiplier": 0.4, "bone_material": true},
	BodyPart.Type.LEFT_UPPER_LEG: {"max_health": 45.0, "hitbox_size": 0.09, "tissue_multiplier": 0.9, "bone_material": true},
	BodyPart.Type.RIGHT_UPPER_LEG: {"max_health": 45.0, "hitbox_size": 0.09, "tissue_multiplier": 0.9, "bone_material": true},
	BodyPart.Type.LEFT_LOWER_LEG: {"max_health": 30.0, "hitbox_size": 0.06, "tissue_multiplier": 0.7, "bone_material": true},
	BodyPart.Type.RIGHT_LOWER_LEG: {"max_health": 30.0, "hitbox_size": 0.06, "tissue_multiplier": 0.7, "bone_material": true},
	BodyPart.Type.LEFT_FOOT: {"max_health": 20.0, "hitbox_size": 0.04, "tissue_multiplier": 0.5, "bone_material": true},
	BodyPart.Type.RIGHT_FOOT: {"max_health": 20.0, "hitbox_size": 0.04, "tissue_multiplier": 0.5, "bone_material": true}
}

# Main Health class
var body_parts: Dictionary = {}
var is_alive: bool = true
var total_bleeding_rate: float = 0.0
var pain_level: float = 0.0
var blood_volume: float = 5000.0
var max_blood_volume: float = 5000.0

var total_health: float:
	get:
		var total = 0.0
		for part in body_parts.values():
			total += part.current_health
		return total

var max_total_health: float:
	get:
		var total = 0.0
		for part in body_parts.values():
			total += part.max_health
		return total

var health_percentage: float:
	get: return total_health / max_total_health

func _init():
	# Create default materials if none provided
	if flesh_material == null:
		flesh_material = _create_default_flesh_material()
	if bone_material == null:
		bone_material = _create_default_bone_material()
	
	# Initialize body parts
	for part_type in body_part_config.keys():
		var config = body_part_config[part_type]
		var body_part = BodyPart.new(part_type, config.max_health, config.hitbox_size)
		body_part.tissue_multiplier = config.tissue_multiplier
		
		# Set base material (flesh or bone)
		if config.get("bone_material", false):
			body_part.base_material = bone_material
		else:
			body_part.base_material = flesh_material
		
		body_parts[part_type] = body_part
	
	blood_volume = max_blood_volume
	
	# Connect signals
	for part in body_parts.values():
		part.functionality_changed.connect(_on_body_part_functionality_changed)

func _create_default_flesh_material() -> BallisticMaterial:
	var material = BallisticMaterial.new()
	material.name = "Human Flesh"
	material.type = BallisticMaterial.Type.FLESH_SOFT
	material.density = 1060.0
	material.hardness = 0.5
	material.toughness = 2.0
	material.penetration_resistance = 0.1
	material.damage_modifier = 1.0
	return material

func _create_default_bone_material() -> BallisticMaterial:
	var material = BallisticMaterial.new()
	material.name = "Human Bone"
	material.type = BallisticMaterial.Type.FLESH_HARD
	material.density = 1900.0
	material.hardness = 3.0
	material.toughness = 5.0
	material.penetration_resistance = 0.5
	material.damage_modifier = 0.8
	return material

# Primary method for handling ballistic impacts
func take_ballistic_damage(ammo: Ammo, impact_data: Dictionary, hit_location: BodyPart.Type, distance: float) -> Dictionary:
	if not is_alive:
		return {"damage_taken": 0.0, "fatal": false, "wounds": []}
	
	var part: BodyPart = body_parts[hit_location]
	var result = part.take_ballistic_impact(ammo, impact_data, distance)
	
	health_changed.emit(part, part.current_health + result.damage_taken, part.current_health)
	
	# Update pain level based on damage
	pain_level += result.damage_taken * pain_increase_per_damage
	
	# Handle bleeding
	if result.wound_created and result.wound_created.type == "bleeding":
		total_bleeding_rate += result.wound_created.damage_per_second
		bleeding_started.emit(result.wound_created.severity, hit_location)
	
	# Handle armor penetration event
	if result.armor_penetrated and part.equipped_armor:
		armor_penetrated.emit(part.equipped_armor, hit_location)
	
	# Check for death
	var fatal = _check_death()
	if fatal:
		player_died.emit("Ballistic trauma to " + _body_part_to_string(hit_location))
	
	result["fatal"] = fatal
	return result

# Method for environmental/explosive damage
func take_explosive_damage(damage: float, blast_center: Vector3, player_position: Vector3, explosion_radius: float) -> Dictionary:
	if not is_alive:
		return {"damage_taken": 0.0, "fatal": false, "wounds": []}
	
	var distance = player_position.distance_to(blast_center)
	var falloff = 1.0 - (distance / explosion_radius)
	falloff = clamp(falloff, 0.0, 1.0)
	
	var actual_damage = damage * falloff
	var wounds_created = []
	
	# Distribute damage to multiple body parts based on orientation to blast
	var front_parts = [BodyPart.Type.UPPER_CHEST, BodyPart.Type.LOWER_CHEST, BodyPart.Type.STOMACH, 
					  BodyPart.Type.LEFT_UPPER_ARM, BodyPart.Type.RIGHT_UPPER_ARM]
	var back_parts = [BodyPart.Type.HEAD, BodyPart.Type.LEFT_UPPER_LEG, BodyPart.Type.RIGHT_UPPER_LEG]
	
	var damage_distribution = {}
	for part in front_parts:
		damage_distribution[part] = actual_damage * explosive_front_damage_ratio / front_parts.size()
	for part in back_parts:
		damage_distribution[part] = actual_damage * explosive_back_damage_ratio / back_parts.size()
	
	var total_damage = 0.0
	for part_type in damage_distribution:
		var part = body_parts[part_type]
		var part_damage = damage_distribution[part_type]
		var old_health = part.current_health
		part.take_damage(part_damage)
		total_damage += old_health - part.current_health
		
		# Create explosion wound
		if part_damage > 10.0:
			var wound = Wound.new(Wound.Severity.MODERATE, "burn", part_type, null, part_damage * 0.01, 15.0)
			part.add_wound(wound)
			wounds_created.append(wound)
	
	pain_level += total_damage * explosive_pain_multiplier
	
	# Check for death
	var fatal = _check_death()
	if fatal:
		player_died.emit("Explosive trauma")
	
	return {
		"damage_taken": total_damage,
		"fatal": fatal,
		"wounds": wounds_created
	}

func _check_death() -> bool:
	# Instant death conditions
	if body_parts[BodyPart.Type.HEAD].is_destroyed or body_parts[BodyPart.Type.UPPER_CHEST].is_destroyed:
		is_alive = false
		return true
	
	# Check blood loss death
	if _check_blood_loss_death():
		is_alive = false
		return true
	
	# Death from complete health depletion
	if total_health <= 0:
		is_alive = false
		return true
	
	return false

func _on_body_part_functionality_changed(multiplier: float):
	# Update overall pain level based on functionality loss
	pain_level = max(pain_level, 1.0 - multiplier)

func update(delta: float):
	if not is_alive:
		return
	
	_apply_bleeding_damage(delta)
	
	# Update all body parts
	for part in body_parts.values():
		part.update(delta)
	
	# Gradually reduce pain
	pain_level = max(0.0, pain_level - delta * pain_decrease_rate)
	
	# Check for death from blood loss
	if _check_blood_loss_death():
		is_alive = false
		player_died.emit("Critical blood loss")

func _check_blood_loss_death() -> bool:
	# Instant death from extreme blood loss
	if blood_volume <= (max_blood_volume * 0.1):
		return true
	
	# Death from critical blood volume with ongoing heavy bleeding
	if blood_volume < (max_blood_volume * critical_blood_loss_threshold_ratio) and total_bleeding_rate > 3.0:
		return true
	
	# Death from combination of blood loss and moderate health loss
	if blood_volume < (max_blood_volume * blood_loss_low_health_threshold_ratio) and total_health < (max_total_health * 0.5):
		return true
	
	# Death from severe blood loss regardless of health
	if blood_volume < (max_blood_volume * 0.25):
		return true
	
	return false

func _apply_bleeding_damage(delta: float):
	if total_bleeding_rate <= 0:
		return
	
	# Calculate actual blood loss
	var blood_loss_ml = total_bleeding_rate * bleeding_ml_per_damage_per_second * delta
	blood_volume = max(0, blood_volume - blood_loss_ml)
	
	# Apply health damage based on blood loss percentage
	var blood_loss_ratio = 1.0 - (blood_volume / max_blood_volume)
	
	if blood_loss_ratio > 0:
		# Damage increases exponentially with blood loss
		var damage_multiplier = bleeding_damage_multiplier_base + (pow(blood_loss_ratio, 2) * (bleeding_damage_multiplier_max - bleeding_damage_multiplier_base))
		var health_damage = blood_loss_ratio * damage_multiplier * delta * 2.0
		
		# Distribute damage to all body parts (systemic shock)
		var parts_count = 0
		for part in body_parts.values():
			if not part.is_destroyed:
				parts_count += 1
		
		if parts_count > 0:
			var damage_per_part = health_damage / parts_count
			for part in body_parts.values():
				if not part.is_destroyed:
					part.take_damage(damage_per_part)

func apply_healing(amount: float, specific_part: BodyPart.Type = BodyPart.Type.NONE):
	if specific_part != BodyPart.Type.NONE:
		body_parts[specific_part].heal(amount)
	else:
		# Distribute healing based on damage severity
		var damaged_parts = []
		for part in body_parts.values():
			if part.current_health < part.max_health:
				damaged_parts.append(part)
		
		if not damaged_parts.is_empty():
			var heal_per_part = amount / damaged_parts.size()
			for part in damaged_parts:
				part.heal(heal_per_part)
	
	# Healing also restores blood volume and reduces bleeding
	var blood_restored = amount * healing_blood_restoration_multiplier
	blood_volume = min(max_blood_volume, blood_volume + blood_restored)
	
	# Reduce bleeding from healed wounds
	total_bleeding_rate = max(0.0, total_bleeding_rate - amount * healing_bleeding_reduction_multiplier)

func equip_armor(armor: Armor) -> void:
	for part_type in body_parts:
		var body_part = body_parts[part_type]
		if armor.covers_body_part(part_type):
			body_part.equip_armor(armor)

func unequip_armor(armor: Armor) -> void:
	for part_type in body_parts:
		var body_part = body_parts[part_type]
		if body_part.equipped_armor == armor:
			body_part.unequip_armor()

func get_functionality_multiplier(part: BodyPart.Type) -> float:
	return body_parts[part].functionality_multiplier * (1.0 - pain_level * 0.3)

func get_health_percentage(part: BodyPart.Type) -> float:
	return body_parts[part].current_health / body_parts[part].max_health

func get_hit_probability_multiplier(part: BodyPart.Type) -> float:
	return body_parts[part].hitbox_size

func _body_part_to_string(part: BodyPart.Type) -> String:
	match part:
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

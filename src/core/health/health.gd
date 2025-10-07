# player_health.gd
@tool
class_name PlayerHealth
extends Resource

signal health_changed(body_part: BodyPart, old_health: float, new_health: float)
signal body_part_destroyed(body_part: BodyPart)
signal wound_sustained(body_part: BodyPart, wound: Wound)
signal player_died(cause: String)
signal armor_penetrated(armor_type: String, location: BodyPart)
signal bleeding_started(severity: float, location: BodyPart)

# ─── CONFIGURATION VARIABLES ────────────────────────────────────────────────
# Armor & Penetration Configuration
@export var armor_resistance_scale: float = 8.0  # Was 15.0, reduced to 8.0 for better armor effectiveness
@export var armor_energy_absorption_penetrated: float = 0.3  # 30% energy absorbed when penetrated
@export var armor_energy_absorption_stopped: float = 0.8     # 80% energy absorbed when stopped
@export var blunt_trauma_damage_multiplier: float = 0.3      # Base blunt trauma damage
@export var armor_protection_efficiency: float = 0.8         # 80% protection when armor stops round

# Wound & Damage Configuration
@export var minor_wound_threshold: float = 0.3
@export var moderate_wound_threshold: float = 0.5  
@export var severe_wound_threshold: float = 0.8
@export var minimum_wound_damage: float = 5.0

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

# Body Part Configuration (moved from hardcoded values)
@export var body_part_config: Dictionary = {
	BodyPart.Type.HEAD: {"max_health": 40.0, "hitbox_size": 0.08, "tissue_multiplier": 3.0},
	BodyPart.Type.UPPER_CHEST: {"max_health": 70.0, "hitbox_size": 0.15, "tissue_multiplier": 1.5},
	BodyPart.Type.LOWER_CHEST: {"max_health": 60.0, "hitbox_size": 0.12, "tissue_multiplier": 1.2},
	BodyPart.Type.STOMACH: {"max_health": 50.0, "hitbox_size": 0.10, "tissue_multiplier": 1.3},
	BodyPart.Type.LEFT_UPPER_ARM: {"max_health": 35.0, "hitbox_size": 0.07, "tissue_multiplier": 0.8},
	BodyPart.Type.RIGHT_UPPER_ARM: {"max_health": 35.0, "hitbox_size": 0.07, "tissue_multiplier": 0.8},
	BodyPart.Type.LEFT_LOWER_ARM: {"max_health": 25.0, "hitbox_size": 0.05, "tissue_multiplier": 0.6},
	BodyPart.Type.RIGHT_LOWER_ARM: {"max_health": 25.0, "hitbox_size": 0.05, "tissue_multiplier": 0.6},
	BodyPart.Type.LEFT_HAND: {"max_health": 15.0, "hitbox_size": 0.03, "tissue_multiplier": 0.4},
	BodyPart.Type.RIGHT_HAND: {"max_health": 15.0, "hitbox_size": 0.03, "tissue_multiplier": 0.4},
	BodyPart.Type.LEFT_UPPER_LEG: {"max_health": 45.0, "hitbox_size": 0.09, "tissue_multiplier": 0.9},
	BodyPart.Type.RIGHT_UPPER_LEG: {"max_health": 45.0, "hitbox_size": 0.09, "tissue_multiplier": 0.9},
	BodyPart.Type.LEFT_LOWER_LEG: {"max_health": 30.0, "hitbox_size": 0.06, "tissue_multiplier": 0.7},
	BodyPart.Type.RIGHT_LOWER_LEG: {"max_health": 30.0, "hitbox_size": 0.06, "tissue_multiplier": 0.7},
	BodyPart.Type.LEFT_FOOT: {"max_health": 20.0, "hitbox_size": 0.04, "tissue_multiplier": 0.5},
	BodyPart.Type.RIGHT_FOOT: {"max_health": 20.0, "hitbox_size": 0.04, "tissue_multiplier": 0.5}
}


# Main PlayerHealth class
var body_parts: Dictionary = {}
var is_alive: bool = true
var total_bleeding_rate: float = 0.0
var pain_level: float = 0.0  # Affects player performance
var blood_volume: float = 5000.0  # ml of blood
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
	# Initialize body parts with realistic health distribution and hitbox sizes
	for part_type in body_part_config.keys():
		var config = body_part_config[part_type]
		body_parts[part_type] = BodyPart.new(part_type, config.max_health, config.hitbox_size)
		body_parts[part_type].set_tissue_multiplier(config.tissue_multiplier)
	
	blood_volume = max_blood_volume
	
	# Connect signals
	for part in body_parts.values():
		part.functionality_changed.connect(_on_body_part_functionality_changed)

# Primary method for handling ballistic impacts
func take_ballistic_damage(ammo: Ammo, impact_data: Dictionary, hit_location: BodyPart, distance: float) -> Dictionary:
	if not is_alive:
		return {"damage_taken": 0.0, "fatal": false, "wounds": []}
	
	var part = body_parts[hit_location]
	var result = part.take_ballistic_impact(ammo, impact_data, distance)
	
	health_changed.emit(part, part.current_health + result.damage_taken, part.current_health)
	
	# Update pain level based on damage
	pain_level += result.damage_taken * pain_increase_per_damage
	
	# Handle bleeding
	if result.wound_created and result.wound_created.type == "bleeding":
		total_bleeding_rate += result.wound_created.damage_per_second
		bleeding_started.emit(result.wound_created.severity, hit_location)
	
	# Handle armor penetration event
	if result.penetrated and part.armor_value > 0:
		armor_penetrated.emit(part.armor_material.name if part.armor_material else "Unknown", hit_location)
	
	# Check for death
	var fatal = _check_death()
	if fatal:
		player_died.emit("Ballistic trauma to " + hit_location.to_string())
	
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
	var blast_direction = (player_position - blast_center).normalized()
	
	# Simple orientation model (could be enhanced with proper hit detection)
	var front_parts = [BodyPart.Type.UPPER_CHEST, BodyPart.Type.LOWER_CHEST, BodyPart.Type.STOMACH, BodyPart.Type.LEFT_UPPER_ARM, BodyPart.Type.RIGHT_UPPER_ARM]
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
	
	# Update all body parts (for non-bleeding wounds)
	for part in body_parts.values():
		part.update(delta)
	
	# Gradually reduce pain
	pain_level = max(0.0, pain_level - delta * pain_decrease_rate)
	
	# Check for death from blood loss
	if _check_blood_loss_death():
		is_alive = false
		player_died.emit("Critical blood loss")

func _apply_bleeding_damage(delta: float):
	if total_bleeding_rate <= 0:
		return
	
	# Calculate actual blood loss
	var blood_loss_ml = total_bleeding_rate * bleeding_ml_per_damage_per_second * delta  # Convert to ml/sec
	blood_volume = max(0, blood_volume - blood_loss_ml)
	
	# Apply health damage based on blood loss percentage
	var blood_loss_ratio = 1.0 - (blood_volume / max_blood_volume)
	if blood_loss_ratio > bleeding_health_damage_start_threshold:  # Only start taking damage after 10% blood loss
		var damage_multiplier = bleeding_damage_multiplier_base + (blood_loss_ratio * (bleeding_damage_multiplier_max - bleeding_damage_multiplier_base))  # Scale up to 4x damage at 100% blood loss
		var health_damage = blood_loss_ratio * damage_multiplier * delta  # Scale damage with blood loss
		
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

func _check_blood_loss_death() -> bool:
	# Multiple blood loss death conditions
	
	# Instant death from extreme blood loss
	if blood_volume <= 0:
		return true
	
	# Death from critical blood volume (more realistic threshold)
	if blood_volume < (max_blood_volume * critical_blood_loss_threshold_ratio):  # 20% blood volume remaining
		return true
	
	# Death from combination of blood loss and low health
	if blood_volume < (max_blood_volume * blood_loss_low_health_threshold_ratio) and total_health < (max_total_health * blood_loss_low_health_ratio):
		return true
	
	return false

func apply_healing(amount: float, specific_part: BodyPart.Type = 0):
	if specific_part:
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
	var blood_restored = amount * healing_blood_restoration_multiplier  # Healing restores blood
	blood_volume = min(max_blood_volume, blood_volume + blood_restored)
	
	# Reduce bleeding from healed wounds
	total_bleeding_rate = max(0.0, total_bleeding_rate - amount * healing_bleeding_reduction_multiplier)

func equip_armor(armor_material: BallisticMaterial, armor_value: float, protected_parts: Array[BodyPart.Type]):
	for part_type in protected_parts:
		var part = body_parts[part_type]
		part.armor_material = armor_material
		part.armor_value = armor_value

func get_functionality_multiplier(part: BodyPart.Type) -> float:
	return body_parts[part].functionality_multiplier * (1.0 - pain_level * 0.3)

func get_health_percentage(part: BodyPart.Type) -> float:
	return body_parts[part].current_health / body_parts[part].max_health

func get_hit_probability_multiplier(part: BodyPart.Type) -> float:
	return body_parts[part].hitbox_size

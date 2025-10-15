# res://src/core/health/health.gd
class_name Health
extends Resource

# ─── SIGNALS ───────────────────────────────────────
signal health_changed(body_part: BodyPart, old_health: float, new_health: float)
signal body_part_destroyed(body_part: BodyPart)
signal wound_sustained(body_part: BodyPart, wound: Wound)
signal player_died(cause: String)
signal armor_penetrated(armor: Armor, location: BodyPart.Type)
signal bleeding_started(severity: float, location: BodyPart.Type)

# ─── CONFIGURATION ─────────────────────────────────
@export var bleeding_ml_per_damage_per_second: float = 10.0
@export var critical_blood_loss_threshold_ratio: float = 0.2
@export var pain_increase_per_damage: float = 0.1
@export var pain_decrease_rate: float = 0.1
@export var healing_blood_restoration_multiplier: float = 2.0
@export var healing_bleeding_reduction_multiplier: float = 0.02
@export var explosive_front_damage_ratio: float = 0.6
@export var explosive_back_damage_ratio: float = 0.4

# Body materials
@export var flesh_material: BallisticMaterial
@export var bone_material: BallisticMaterial

# Body part config
@export var body_part_config: Dictionary = {
  BodyPart.Type.HEAD: {"max_health": 40.0, "hitbox_size": 0.08, "tissue_multiplier": 3.0, "bone_material": true},
  BodyPart.Type.UPPER_CHEST: {"max_health": 70.0, "hitbox_size": 0.15, "tissue_multiplier": 1.5, "bone_material": true},
  BodyPart.Type.LOWER_CHEST: {"max_health": 60.0, "hitbox_size": 0.12, "tissue_multiplier": 1.2, "bone_material": true},
  BodyPart.Type.ABDOMEN: {"max_health": 50.0, "hitbox_size": 0.10, "tissue_multiplier": 1.3, "bone_material": false},
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

# ─── STATE ─────────────────────────────────────────
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

# ─── INIT ──────────────────────────────────────────
func _init():
  if flesh_material == null:
    flesh_material = BallisticMaterial.create_default_flesh_material()
  if bone_material == null:
    bone_material = BallisticMaterial.create_default_bone_material()
  for part_type in body_part_config.keys():
    var config = body_part_config[part_type]
    var body_part = BodyPart.new(part_type, config.max_health, config.hitbox_size)
    body_part.tissue_multiplier = config.tissue_multiplier
    body_part.base_material = bone_material if config.get("bone_material", false) else flesh_material
    body_parts[part_type] = body_part
  blood_volume = max_blood_volume
  for part in body_parts.values():
    part.functionality_changed.connect(_on_body_part_functionality_changed)
    part.destroyed.connect(_on_body_part_destroyed)

# ─── PUBLIC METHODS ────────────────────────────────
func take_ballistic_damage(impact: BallisticsImpact, hit_location: BodyPart.Type) -> Dictionary:
  if not is_alive:
    return {"damage_taken": 0.0, "fatal": false, "wound_created": null}
  var part: BodyPart = body_parts[hit_location]
  var result = _process_ballistic_impact(part, impact)
  health_changed.emit(part, part.current_health + result.damage_taken, part.current_health)
  pain_level += result.damage_taken * pain_increase_per_damage
  if result.wound_created:
    wound_sustained.emit(part, result.wound_created)
    if result.wound_created.damage_per_second > 0:
      total_bleeding_rate += result.wound_created.damage_per_second
      bleeding_started.emit(result.wound_created.severity, hit_location)
  if result.armor_penetrated and part.equipped_armor:
    armor_penetrated.emit(part.equipped_armor, hit_location)
  var fatal = _check_death()
  if fatal:
    player_died.emit("Ballistic trauma to " + BodyPart.type_to_string(hit_location))
  result["fatal"] = fatal
  return result

func apply_healing(amount: float, specific_part: BodyPart.Type = BodyPart.Type.NONE):
  if specific_part != BodyPart.Type.NONE:
    body_parts[specific_part].heal(amount)
  else:
    var damaged_parts = body_parts.values().filter(func(p): return p.current_health < p.max_health)
    if not damaged_parts.is_empty():
      var heal_per_part = amount / damaged_parts.size()
      for part in damaged_parts:
        part.heal(heal_per_part)
  blood_volume = min(max_blood_volume, blood_volume + amount * healing_blood_restoration_multiplier)
  total_bleeding_rate = max(0.0, total_bleeding_rate - amount * healing_bleeding_reduction_multiplier)

func equip_armor(armor: Armor) -> void:
  for part_type in body_parts:
    if armor.covers_body_part(part_type):
      body_parts[part_type].equip_armor(armor)

func unequip_armor(armor: Armor) -> void:
  for part_type in body_parts:
    if body_parts[part_type].equipped_armor == armor:
      body_parts[part_type].unequip_armor()

func get_functionality_multiplier(part: BodyPart.Type) -> float:
  return body_parts[part].functionality_multiplier * (1.0 - pain_level * 0.3)

func update(delta: float):
  if not is_alive:
    return
  _apply_bleeding_damage(delta)
  for part in body_parts.values():
    part.update(delta)
  pain_level = max(0.0, pain_level - delta * pain_decrease_rate)
  if _check_blood_loss_death():
    is_alive = false
    player_died.emit("Critical blood loss")

# ─── INTERNAL LOGIC ────────────────────────────────
func _process_ballistic_impact(part: BodyPart, impact: BallisticsImpact) -> Dictionary:
  var result = {
    "damage_taken": 0.0,
    "penetrated": false,
    "wound_created": null,
    "armor_penetrated": false
  }
  if part.is_destroyed:
    return result
  var base_damage = impact.hit_energy * part.tissue_multiplier
  if part.equipped_armor and part.equipped_armor.material:
    var armor_result = part.equipped_armor.check_penetration(Ammo.new(), impact)
    result.armor_penetrated = armor_result.penetrated
    if armor_result.penetrated:
      var actual_damage = base_damage * (1.0 - impact.hit_energy / (impact.hit_energy + 1000.0))
      result.damage_taken = part.take_damage(actual_damage)
      part.equipped_armor.take_damage(actual_damage)
      result.wound_created = Wound.create_ballistic_wound(Ammo.new(), impact, part)
    else:
      var blunt_damage = base_damage * 0.3
      result.damage_taken = part.take_damage(blunt_damage)
      part.equipped_armor.take_damage(blunt_damage * 0.5)
      if blunt_damage > 5.0:
        result.wound_created = Wound.create_ballistic_wound(Ammo.new(), impact, part)
  else:
    result.penetrated = true
    result.damage_taken = part.take_damage(base_damage)
    result.wound_created = Wound.create_ballistic_wound(Ammo.new(), impact, part)
  if part.is_destroyed:
    body_part_destroyed.emit(part)
  return result

func _apply_bleeding_damage(delta: float):
  if total_bleeding_rate <= 0:
    return
  var blood_loss_ml = total_bleeding_rate * bleeding_ml_per_damage_per_second * delta
  blood_volume = max(0, blood_volume - blood_loss_ml)
  var blood_loss_ratio = 1.0 - (blood_volume / max_blood_volume)
  if blood_loss_ratio > 0:
    var damage_multiplier = 1.0 + (pow(blood_loss_ratio, 2) * 3.0)
    var health_damage = blood_loss_ratio * damage_multiplier * delta * 2.0
    var parts_count = body_parts.values().filter(func(p): return not p.is_destroyed).size()
    if parts_count > 0:
      var damage_per_part = health_damage / parts_count
      for part in body_parts.values():
        if not part.is_destroyed:
          part.take_damage(damage_per_part)

func _check_death() -> bool:
  if body_parts[BodyPart.Type.HEAD].is_destroyed or body_parts[BodyPart.Type.UPPER_CHEST].is_destroyed:
    return true
  if total_health <= 0:
    return true
  return _check_blood_loss_death()

func _check_blood_loss_death() -> bool:
  if blood_volume <= max_blood_volume * 0.1:
    return true
  if blood_volume < max_blood_volume * critical_blood_loss_threshold_ratio and total_bleeding_rate > 3.0:
    return true
  if blood_volume < max_blood_volume * 0.25:
    return true
  return false

func _on_body_part_functionality_changed(multiplier: float):
  pain_level = max(pain_level, 1.0 - multiplier)

func _on_body_part_destroyed(body_part: BodyPart):
  if _check_death():
    is_alive = false
    player_died.emit("Instant trauma to " + BodyPart.type_to_string(body_part.type))

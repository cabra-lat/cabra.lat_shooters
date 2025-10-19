# src/core/health/body_part.gd
class_name BodyPart
extends Resource

signal functionality_changed(multiplier: float)
signal destroyed(body_part: BodyPart)

enum Type {
  NONE,
  HEAD,
  CERVICAL_SPINE,
  THORACIC_SPINE,
  LUMBAR_SPINE,
  UPPER_CHEST,
  LOWER_CHEST,
  ABDOMEN,
  PELVIS,
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
@export var base_material: BallisticMaterial
@export var equipped_armor: Armor = null

var functionality_multiplier: float:
  get: return _get_functionality_multiplier()

func _init(_type: Type, _max_health: float, _hitbox_size: float = 1.0):
  type = _type
  max_health = _max_health
  current_health = _max_health
  hitbox_size = _hitbox_size

func take_damage(amount: float) -> float:
  if is_destroyed:
    return 0.0
  var old_health = current_health
  current_health = max(0, current_health - amount)
  if current_health == 0 and not is_destroyed:
    is_destroyed = true
    functionality_changed.emit(_get_functionality_multiplier())
    destroyed.emit(self)  # ← ADD THIS
  return old_health - current_health

func add_wound(wound: Wound):
  wounds.append(wound)

func heal(amount: float):
  if is_destroyed:
    return
  current_health = min(max_health, current_health + amount)
  # Heal minor wounds automatically when health is high
  if current_health > max_health * 0.8:
    wounds = wounds.filter(func(w): return w.severity > Wound.Severity.MINOR)

func update(delta: float):
  for wound in wounds:
    if wound.duration > 0:
      take_damage(wound.damage_per_second * delta)
      wound.duration -= delta
  # Remove expired wounds
  wounds = wounds.filter(func(w): return w.duration > 0)

func equip_armor(armor: Armor) -> void:
  equipped_armor = armor

func unequip_armor() -> void:
  equipped_armor = null

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
    Type.LEFT_HAND, Type.RIGHT_HAND,
    Type.LEFT_FOOT, Type.RIGHT_FOOT
  ]

func is_spine() -> bool:
  return type in [Type.CERVICAL_SPINE, Type.THORACIC_SPINE, Type.LUMBAR_SPINE]

func is_torso() -> bool:
  return type in [Type.UPPER_CHEST, Type.LOWER_CHEST, Type.ABDOMEN, Type.PELVIS]

func _get_functionality_multiplier() -> float:
  if is_destroyed:
    match type:
      Type.HEAD, Type.UPPER_CHEST: return 0.0
      Type.LEFT_UPPER_ARM, Type.RIGHT_UPPER_ARM: return 0.2
      Type.LEFT_LOWER_ARM, Type.RIGHT_LOWER_ARM: return 0.4
      Type.LEFT_HAND, Type.RIGHT_HAND: return 0.6
      Type.LEFT_UPPER_LEG, Type.RIGHT_UPPER_LEG: return 0.1
      Type.LEFT_LOWER_LEG, Type.RIGHT_LOWER_LEG: return 0.3
      Type.LEFT_FOOT, Type.RIGHT_FOOT: return 0.5
      _: return 0.8
  var mult = 1.0
  for wound in wounds:
    mult *= _get_wound_effects(wound)
  return mult

static func _get_wound_effects(wound: Wound) -> float:
  match wound.type:
    Wound.Type.FRACTURE:
      return 0.3 if wound.severity >= Wound.Severity.SEVERE else 0.7
    Wound.Type.CONCUSSION: return 0.5
    Wound.Type.BURN: return 0.8
    _: return 1.0

static func type_to_string(type: Type) -> String:
  return Type.keys()[type].capitalize() if type < Type.keys().size() else "Unknown"

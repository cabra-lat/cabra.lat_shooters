# res://src/core/armor/ballistic_material.gd
class_name BallisticMaterial
extends Resource

signal material_penetrated(material: BallisticMaterial, depth: float)
signal material_ricochet(material: BallisticMaterial, angle: float)

enum Type {
  AIR,
  WATER,
  GLASS,
  WOOD,
  METAL_THIN,
  METAL_MEDIUM,
  METAL_HEAVY,
  CONCRETE,
  BRICK,
  ROCK,
  SOIL,
  FLESH_SOFT,
  FLESH_MEDIUM,
  FLESH_HARD,
  ARMOR_SOFT,
  ARMOR_MEDIUM,
  ARMOR_HARD
}

@export var name: String = "Ballistic Material"
@export var type: Type = Type.FLESH_SOFT
@export var density: float = 1000.0        # kg/m³
@export var hardness: float = 300.0        # HB
@export var toughness: float = 1.0
@export var thickness: float = 1.0         # mm
@export var effectiveness: float = 1.0
@export var energy_absorption: float = 0.3

@export var penetration_resistance: float = 1.0
@export var ricochet_chance_modifier: float = 1.0

@export var impact_effect: PackedScene
@export var penetration_effect: PackedScene
@export var impact_sound: AudioStream
@export var exit_sound: AudioStream

func calculate_penetration(ammo: Ammo, impact_energy: float, obliquity_deg: float = 0.0) -> float:
  var impact_velocity = Utils.bullet_velocity(ammo.bullet_mass, impact_energy)
  const v_ref = 950.0
  const h_ref = 300.0
  const p_ref = 12.0
  var dP_dv = 0.092
  var dP_dH = -0.116
  var delta_v = impact_velocity - v_ref
  var p_from_velocity = p_ref + dP_dv * delta_v
  var delta_h = hardness - h_ref
  var p_corrected = p_from_velocity + dP_dH * delta_h
  var theta_rad = deg_to_rad(obliquity_deg)
  if theta_rad >= PI / 2.0:
    return 0.0
  var cos_theta = cos(theta_rad)
  if cos_theta <= 0.0:
    return 0.0
  var p_oblique = p_corrected * cos_theta
  return max(0.0, p_oblique)

func should_ricochet(projectile: Ammo, impact_angle: float) -> bool:
  var base_ricochet_chance = projectile.ricochet_chance * ricochet_chance_modifier
  var angle_factor = 1.0 - (impact_angle / 90.0)
  return randf() < (base_ricochet_chance * angle_factor)

static func create_for_armor_certification(standard: Certification.Standard, level: int) -> BallisticMaterial:
  var max_threat_energy = Certification.get_max_certified_energy(standard, level)
  var armor_type = Certification.get_armor_type_for_certification(standard, level)
  return create_for_energy_stopping(max_threat_energy, armor_type)

static func create_for_energy_stopping(max_energy_joules: float, armor_type: Type = Type.ARMOR_MEDIUM, safety_factor: float = 1.2) -> BallisticMaterial:
  var material = BallisticMaterial.new()
  material.type = armor_type
  var base_resistance = max_energy_joules * safety_factor
  match armor_type:
    Type.ARMOR_SOFT:
      material.name = "Soft Armor (%.0f J)" % max_energy_joules
      material.density = 1400.0
      material.hardness = 3.0
      material.toughness = 12.0
      material.penetration_resistance = base_resistance * 0.8
      material.ricochet_chance_modifier = 0.1
    Type.ARMOR_MEDIUM:
      material.name = "Medium Armor (%.0f J)" % max_energy_joules
      material.density = 2600.0
      material.hardness = 15.0
      material.toughness = 8.0
      material.penetration_resistance = base_resistance * 1.2
      material.ricochet_chance_modifier = 0.3
    Type.ARMOR_HARD:
      material.name = "Hard Armor (%.0f J)" % max_energy_joules
      material.density = 7800.0
      material.hardness = 25.0
      material.toughness = 6.0
      material.penetration_resistance = base_resistance * 1.5
      material.ricochet_chance_modifier = 0.6
    _:
      material.type = Type.ARMOR_MEDIUM
      material.density = 2000.0
      material.hardness = 10.0
      material.toughness = 8.0
      material.penetration_resistance = base_resistance
  return material

static func create_default_flesh_material() -> BallisticMaterial:
  var m = BallisticMaterial.new()
  m.name = "Human Flesh"
  m.type = Type.FLESH_SOFT
  m.density = 1060.0
  m.hardness = 0.5
  m.toughness = 2.0
  m.penetration_resistance = 0.1
  return m

static func create_default_bone_material() -> BallisticMaterial:
  var m = BallisticMaterial.new()
  m.name = "Human Bone"
  m.type = Type.FLESH_HARD
  m.density = 1900.0
  m.hardness = 3.0
  m.toughness = 5.0
  m.penetration_resistance = 0.5
  return m

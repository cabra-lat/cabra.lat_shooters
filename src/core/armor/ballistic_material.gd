# res://addons/cabra.lat_shooters/src/core/armor/ballistic_material.gd
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

# ─── TARKOV MATERIAL / WEAR MODEL ──────────────────
# Genre-typical armour material families, each with a destructibility factor.
enum MaterialClass { ARAMID, UHMWPE, COMBINED, TITAN, ALUMINIUM, ARMOR_STEEL, CERAMIC, GLASS }

const DESTRUCTIBILITY := {
  MaterialClass.ARAMID: 0.1875,
  MaterialClass.UHMWPE: 0.3375,
  MaterialClass.COMBINED: 0.375,
  MaterialClass.TITAN: 0.4125,
  MaterialClass.ALUMINIUM: 0.45,
  MaterialClass.ARMOR_STEEL: 0.525,
  MaterialClass.CERAMIC: 0.6,
  MaterialClass.GLASS: 0.6,
}

@export var material_class: MaterialClass = MaterialClass.ARAMID
@export_custom(PROPERTY_HINT_NONE, "suffix:0-1") var destructibility: float = 0.1875

## Effective durability = durability / destructibility (genre-typical).
func effective_durability(durability: float) -> float:
  return durability / maxf(destructibility, 0.01)

func set_material_class(mc: MaterialClass) -> void:
  material_class = mc
  destructibility = destructibility_for(mc)

static func destructibility_for(mc: MaterialClass) -> float:
  return DESTRUCTIBILITY.get(mc, 0.25)

## Fraction of MAX durability permanently lost per repair. Harder/crack-prone
## materials (ceramic) lose a lot; UHMWPE survives many repairs.
func repair_loss_ratio() -> float:
  return clampf(destructibility * 0.8, 0.05, 0.6)

@export_custom(PROPERTY_HINT_NONE, "suffix:0-1") var min_repair_fraction: float = 0.15

@export var penetration_resistance: float = 1.0
@export var ricochet_chance_modifier: float = 1.0

## Pending consumer: impact VFX/SFX per material — wired by the VFX/audio lane.
@export var impact_effect: PackedScene
@export var penetration_effect: PackedScene
@export var impact_sound: AudioStream
@export var exit_sound: AudioStream

func calculate_penetration(ammo: Ammo, impact_energy: float, obliquity_deg: float = 0.0) -> float:
  # Legacy wrapper: capability at normal incidence, de-rated by obliquity.
  # Prefer penetration_capability() + LOS thickness comparison (see calculator).
  var theta_rad = deg_to_rad(clampf(obliquity_deg, 0.0, 89.0))
  return max(0.0, penetration_capability(ammo, impact_energy) * cos(theta_rad))

func is_soft_tissue() -> bool:
  return type == Type.FLESH_SOFT or type == Type.FLESH_MEDIUM or type == Type.FLESH_HARD

func penetration_capability(ammo: Ammo, impact_energy: float) -> float:
  # mm of material this projectile defeats at normal incidence.
  if impact_energy <= 0.0:
    return 0.0
  if is_soft_tissue():
    return _poncelet_depth_mm(ammo, impact_energy)
  # Hard targets: penetration scales with impact KE (De Marre energy form),
  # anchored at the ammo's quoted mm-RHA reference point.
  var e_ref = ammo.get_energy_at_range(ammo.reference_distance)
  if e_ref <= 0.0:
    return 0.0
  var p = ammo.reference_penetration * (impact_energy / e_ref)
  p *= ammo.armor_performance * ammo.armor_modifier
  p *= sqrt(RHA_HARDNESS / max(hardness, 50.0))
  return max(0.0, p)

func stopping_energy(ammo: Ammo, los_thickness_mm: float) -> float:
  # Ballistic-limit energy E_bl: minimum impact energy to perforate los_thickness.
  # Feeds the Recht-Ipson residual: E_exit = max(0, E_hit - E_bl).
  if los_thickness_mm <= 0.0:
    return 0.0
  if is_soft_tissue():
    # Invert P(E) = K·ln(1 + E/E1).
    var k = _tissue_k_meters(ammo)
    var e1 = _tissue_e1_joules(ammo)
    if k <= 0.0 or e1 <= 0.0:
      return INF
    return e1 * (exp(los_thickness_mm / 1000.0 / k) - 1.0)
  var e_ref = ammo.get_energy_at_range(ammo.reference_distance)
  var p_full = ammo.reference_penetration * ammo.armor_performance * ammo.armor_modifier
  p_full *= sqrt(RHA_HARDNESS / max(hardness, 50.0))
  if p_full <= 0.0:
    return INF
  return e_ref * los_thickness_mm / p_full

# Reference hardness of RHA (HB) that ammo reference_penetration is quoted against.
const RHA_HARDNESS := 300.0

# Poncelet / Segletes form for tissue (gelatin): F = A·(½ρv² + σ).
# Closed-form depth: P = K·ln(1 + E/E1), K = m/(A·ρ), E1 = m·σ/ρ.
func _tissue_strength_pa(ammo: Ammo) -> float:
  var sigma = toughness * 0.5e6
  return sigma / max(ammo.flesh_modifier, 0.05)

func _tissue_k_meters(ammo: Ammo) -> float:
  var denom = ammo.cross_sectional_area * density
  if denom <= 0.0:
    return 0.0
  return (ammo.bullet_mass / 1000.0) / denom

func _tissue_e1_joules(ammo: Ammo) -> float:
  if density <= 0.0:
    return 0.0
  return (ammo.bullet_mass / 1000.0) * _tissue_strength_pa(ammo) / density

func _poncelet_depth_mm(ammo: Ammo, impact_energy: float) -> float:
  var k = _tissue_k_meters(ammo)
  var e1 = _tissue_e1_joules(ammo)
  if k <= 0.0 or e1 <= 0.0:
    return 0.0
  return k * log(1.0 + impact_energy / e1) * 1000.0

func should_ricochet(projectile: Ammo, impact_angle: float, roll: float = -1.0) -> bool:
  var r = roll if roll >= 0.0 else randf()
  var base_ricochet_chance = projectile.ricochet_chance * ricochet_chance_modifier
  var angle_factor = clampf(1.0 - (impact_angle / 90.0), 0.0, 1.0)
  return r < (base_ricochet_chance * angle_factor)

static func create_for_armor_certification(standard: Certification.Standard, level: int) -> BallisticMaterial:
  var max_threat_energy = Certification.get_max_certified_energy(standard, level)
  var armor_type = Certification.get_armor_type_for_certification(standard, level)
  # A standard only defines a subset of levels (NIJ 1-9, GOST 1-6, ...). For an
  # undefined level, fall back to the class reference RHA instead of silently
  # producing a 0 J "armour that stops nothing", and say so.
  if max_threat_energy <= 0.0:
    var rha := Certification.class_reference_rha(level)
    push_warning("Armor certification standard %d defines no level %d threat list; using class-RHA fallback (%.1f mm)." % [standard, level, rha])
    return create_for_class_rha(rha, armor_type)
  return create_for_energy_stopping(max_threat_energy, armor_type)

## Hard material scaled from a class-reference RHA thickness (mm). Resistance is
## expressed in the same J-equivalent unit as the cert path (1 mm RHA ~ 100 J-eq)
## so the fallback keeps the table ordering coherent.
static func create_for_class_rha(rha_mm: float, armor_type: Type = Type.ARMOR_HARD) -> BallisticMaterial:
  var m = BallisticMaterial.new()
  m.type = armor_type
  m.name = "Class Armor (%.0f mm RHA)" % rha_mm
  m.density = 7800.0
  m.hardness = RHA_HARDNESS
  m.toughness = 6.0
  m.penetration_resistance = maxf(rha_mm, 1.0) * 100.0
  m.ricochet_chance_modifier = 0.6
  m.material_class = MaterialClass.ARMOR_STEEL
  m.destructibility = destructibility_for(MaterialClass.ARMOR_STEEL)
  return m

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

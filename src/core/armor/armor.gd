# res://addons/cabra.lat_shooters/src/core/armor/armor.gd
class_name Armor
extends Item

enum BodyParts {
  HEAD      = 1 << 0,
  EYES      = 1 << 1,
  LEFT_ARM  = 1 << 2,
  RIGHT_ARM = 1 << 3,
  LEFT_LEG  = 1 << 4,
  RIGHT_LEG = 1 << 5,
  ABDOMEN   = 1 << 6,
  THORAX    = 1 << 7
}

@export_flags("HEAD", "EYES", "LEFT_ARM", "RIGHT_ARM", "LEFT_LEG", "RIGHT_LEG", "ABDOMEN", "THORAX")
var protection_zones: int = 0

enum ArmorType {
  GENERIC,
  HELMET,
  VEST
}

enum Face {
  FRONT,
  BACK
}

@export var type: ArmorType = ArmorType.GENERIC
## Pending consumer: armour impact audio — wired by the audio lane.
@export var hit_sound: AudioStream

@export var max_durability: int = 100:
  set(v):
    max_durability = maxi(v, 1)
    if current_durability <= 0 or current_durability > max_durability:
      current_durability = max_durability
var current_durability: int = 100
var repair_count: int = 0

@export_range(0, 50) var max_backface_deformation: float = 25.0
@export_range(-1.0, 0.0) var turn_speed_penalty: float = 0.0
@export_range(-1.0, 0.0) var move_speed_penalty: float = 0.0
@export_range(0.0, 1.0) var ricochet_chance: float = 0.0
@export_range(-1.0, 0.0) var sound_reduction: float = 0.0
@export_range(-1.0, 0.0) var blind_reduction: float = 0.0

# ─── LAYERED PLATES ───────────────────────
# A hard plate worn on a face overrides the base class on that face while it
# has durability. Base armour still covers zones the plate doesn't.
@export var front_plate: BallisticPlate
@export var back_plate: BallisticPlate

# ─── HELMET RICOCHET WINDOW ────────────────────────
@export_custom(PROPERTY_HINT_NONE, "suffix:deg") var ricochet_angle_min: float = 15.0
@export_custom(PROPERTY_HINT_NONE, "suffix:deg") var ricochet_angle_max: float = 75.0

@export var standard: Certification.Standard = Certification.Standard.NIJ:
  set(value):
    standard = value
    _rebuild_material()
@export_range(1, 14) var level: int = 1:
  set(value):
    level = value
    _rebuild_material()

@export var material: BallisticMaterial = BallisticMaterial.create_for_armor_certification(Certification.Standard.NIJ, 1)

## Single authority for the protection material: standard + level.
func _rebuild_material() -> void:
  material = BallisticMaterial.create_for_armor_certification(standard, level)

signal armor_damaged(armor: Armor, damage: float)
signal armor_destroyed(armor: Armor)
signal plate_damaged(plate: BallisticPlate, damage: float)

func is_intact() -> bool:
  return current_durability > 0

func take_damage(damage: float) -> void:
  current_durability = max(0, current_durability - int(round(maxf(damage, 1.0))))
  armor_damaged.emit(self, damage)
  if current_durability <= 0:
    armor_destroyed.emit(self)

func covers_body_part(body_part_type: BodyPart.Type) -> bool:
  var armor_body_part = _convert_to_armor_body_part(body_part_type)
  return protection_zones & armor_body_part

func _convert_to_armor_body_part(body_part_type: BodyPart.Type) -> int:
  match body_part_type:
    BodyPart.Type.HEAD: return BodyParts.HEAD
    BodyPart.Type.UPPER_CHEST, BodyPart.Type.LOWER_CHEST: return BodyParts.THORAX
    BodyPart.Type.ABDOMEN: return BodyParts.ABDOMEN
    BodyPart.Type.LEFT_UPPER_ARM, BodyPart.Type.LEFT_LOWER_ARM, BodyPart.Type.LEFT_HAND: return BodyParts.LEFT_ARM
    BodyPart.Type.RIGHT_UPPER_ARM, BodyPart.Type.RIGHT_LOWER_ARM, BodyPart.Type.RIGHT_HAND: return BodyParts.RIGHT_ARM
    BodyPart.Type.LEFT_UPPER_LEG, BodyPart.Type.LEFT_LOWER_LEG, BodyPart.Type.LEFT_FOOT: return BodyParts.LEFT_LEG
    BodyPart.Type.RIGHT_UPPER_LEG, BodyPart.Type.RIGHT_LOWER_LEG, BodyPart.Type.RIGHT_FOOT: return BodyParts.RIGHT_LEG
    _: return 0

func validate_certification(ammo: Ammo) -> bool:
  return _layer_certifies(self, ammo)

func check_penetration(ammo: Ammo, prev_impact: BallisticsImpact = null) -> BallisticsImpact:
  # Legacy single-layer stop/residual (cert decides, physics falls through).
  var impact = prev_impact if prev_impact else BallisticsImpact.new()
  if current_durability <= 0:
    impact.penetration_depth = impact.thickness
    impact.exit_energy = impact.hit_energy
    return impact
  if _layer_certifies(self, ammo):
    impact.penetration_depth = 0.0
    impact.thickness = material.thickness
    impact.exit_energy = 0.0
    return impact
  var certified_threats = Certification.get_certified_threats(standard, level)
  var max_certified_energy = certified_threats.map(func(t): return t.energy if t.energy else 0.0).max()
  if impact.hit_energy < max_certified_energy:
    impact.penetration_depth = 0.0
    impact.thickness = material.thickness
    impact.exit_energy = 0.0
    return impact
  var durability_factor = clampf(float(current_durability) / float(maxi(max_durability, 1)), 0.0, 1.0)
  var eff_thickness = max(material.thickness, 0.5) * durability_factor
  impact.penetration_depth = material.penetration_capability(ammo, impact.hit_energy)
  impact.thickness = eff_thickness
  var limit_energy = material.stopping_energy(ammo, eff_thickness)
  impact.exit_energy = BallisticsCalculator.residual_energy(impact.hit_energy, limit_energy)
  return impact

func is_penetrated_by(ammo: Ammo) -> bool:
  return check_penetration(ammo).penetrated

# ─── LAYERED RESOLUTION (used by Health) ───────────
## Resolves one projectile against the layer stack on `face`: the covering plate
## (if intact) first, then the base armour. Applies durability wear per layer.
## Returns {stopped, penetrated, exit_energy, layer, durability_damage, layers}.
func resolve_projectile(ammo: Ammo, impact: BallisticsImpact, face: int = Face.FRONT) -> Dictionary:
  var out := {
    "stopped": false,
    "penetrated": false,
    "exit_energy": impact.hit_energy,
    "layer": "none",
    "durability_damage": 0.0,
    "layers": [],
  }
  var stack: Array = []
  var plate := front_plate if face == Face.FRONT else back_plate
  if plate != null and plate.is_intact():
    stack.append(plate)
  if is_intact():
    stack.append(self)
  if stack.is_empty():
    out.penetrated = true
    return out

  var remaining := impact.hit_energy
  for layer in stack:
    var lname := "plate" if layer is BallisticPlate else "base"
    if _layer_certifies(layer, ammo):
      var wear_stop := _apply_wear(layer, ammo, false)
      out.stopped = true
      out.layer = lname
      out.exit_energy = 0.0
      out.durability_damage += wear_stop
      out.layers.append({"layer": lname, "stopped": true, "wear": wear_stop})
      return out
    # Cert-decides: a hit below the layer's rated max threat energy is stopped
    # even without an exact threat match (preserves the old energy gate).
    if remaining < _layer_certified_energy(layer):
      var wear_gate := _apply_wear(layer, ammo, false)
      out.stopped = true
      out.layer = lname
      out.exit_energy = 0.0
      out.durability_damage += wear_gate
      out.layers.append({"layer": lname, "stopped": true, "wear": wear_gate})
      return out
    if remaining < _layer_ballistic_limit(layer, ammo):
      var wear_block := _apply_wear(layer, ammo, false)
      out.stopped = true
      out.layer = lname
      out.exit_energy = 0.0
      out.durability_damage += wear_block
      out.layers.append({"layer": lname, "stopped": true, "wear": wear_block})
      return out
    # Layer penetrated: lose its ballistic limit, continue into the next layer.
    remaining = maxf(0.0, remaining - _layer_ballistic_limit(layer, ammo))
    var wear_pen := _apply_wear(layer, ammo, true)
    out.durability_damage += wear_pen
    out.layers.append({"layer": lname, "stopped": false, "wear": wear_pen})

  out.penetrated = true
  out.exit_energy = remaining
  out.layer = "base"
  return out

# ─── REPAIR (out of raid) ───────────────────────────
## Repairs current durability toward max and permanently shrinks max durability
## by the material's repair-loss curve. Returns the applied durability damage.
func apply_repair(kit: RepairKit = null) -> float:
  if material == null:
    return 0.0
  var loss_mult := kit.loss_multiplier if kit != null else 1.0
  var restore := kit.restore_ratio if kit != null else 1.0
  var before := max_durability
  var loss_frac := material.repair_loss_ratio() * loss_mult
  var new_max := int(round(float(max_durability) * (1.0 - loss_frac)))
  var floor := int(round(float(before) * material.min_repair_fraction))
  max_durability = maxi(new_max, maxi(floor, 1))
  current_durability = int(round(float(max_durability) * restore))
  repair_count += 1
  return float(before - max_durability)

func is_repairable() -> bool:
  if material == null:
    return false
  var floor := int(round(float(max_durability) * material.min_repair_fraction))
  return max_durability > floor and current_durability > 0

# ─── HELMET RICOCHET WINDOW ─────────────────────────
func should_ricochet(impact_angle_deg: float, roll: float = -1.0) -> bool:
  var r := roll if roll >= 0.0 else randf()
  if ricochet_chance <= 0.0:
    return false
  var a := absf(impact_angle_deg)
  if a < ricochet_angle_min or a > ricochet_angle_max:
    return false
  # Shallower angles within the window are more likely to bounce.
  var t := 1.0 - inverse_lerp(ricochet_angle_min, ricochet_angle_max, a)
  return r < ricochet_chance * clampf(t, 0.0, 1.0)

# ─── INTERNAL ───────────────────────────────────────
func _layer_certifies(layer, ammo: Ammo) -> bool:
  var std: Certification.Standard
  var lvl: int
  if layer is BallisticPlate:
    std = layer.standard
    lvl = layer.level
  else:
    std = standard
    lvl = level
  for threat in Certification.get_certified_threats(std, lvl):
    if _matches_threat(ammo, threat):
      return true
  return false

func _matches_threat(ammo: Ammo, threat: Dictionary) -> bool:
  var energy_match = ammo.get_energy() <= threat.energy
  var type_match = ammo.type == threat.type
  var caliber_match = Utils.is_same_caliber(ammo.caliber, threat.caliber)
  return caliber_match and type_match and energy_match

func _layer_ballistic_limit(layer, ammo: Ammo) -> float:
  var mat: BallisticMaterial = layer.material
  if mat == null:
    return INF
  var thickness := maxf(mat.thickness, 0.5)
  return mat.stopping_energy(ammo, thickness)

func _layer_certified_energy(layer) -> float:
  var std: Certification.Standard
  var lvl: int
  if layer is BallisticPlate:
    std = layer.standard
    lvl = layer.level
  else:
    std = standard
    lvl = level
  var threats := Certification.get_certified_threats(std, lvl)
  if threats.is_empty():
    return 0.0
  return threats.map(func(t): return t.energy if t.energy else 0.0).max()

func _layer_max_durability(layer) -> float:
  return float(layer.max_durability)

func _layer_level(layer) -> int:
  return layer.level

func _apply_wear(layer, ammo: Ammo, penetrated: bool) -> float:
  var mat: BallisticMaterial = layer.material
  var destr := mat.destructibility if mat != null else 0.25
  var lvl := _layer_level(layer)
  # Wear model: durability damage scales with max durability, the ammo's armor
  # damage %, the round-vs-class factor and the material destructibility.
  # Penetrating hits do ~12.5% LESS durability damage than stopped ones.
  var dmg := durability_damage(_layer_max_durability(layer), ammo, lvl, destr, penetrated)
  if layer is BallisticPlate:
    layer.take_wear(dmg)
    plate_damaged.emit(layer, dmg)
  else:
    take_damage(dmg)
  return dmg

## Pure durability-damage function (genre-typical form), exposed for tests.
static func durability_damage(max_durability: float, ammo: Ammo, level: int,
    destructibility: float, penetrated: bool) -> float:
  var dmg := max_durability * (ammo.armor_damage * 0.5) * ammo.armor_wear_factor(level) * destructibility
  if penetrated:
    dmg *= 0.875
  return maxf(dmg, 1.0)

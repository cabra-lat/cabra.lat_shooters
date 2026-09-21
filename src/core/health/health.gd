# res://addons/cabra.lat_shooters/src/core/health/health.gd
class_name Health
extends Resource

# ─── SIGNALS ───────────────────────────────────────
signal health_changed(body_part: BodyPart, old_health: float, new_health: float)
signal body_part_destroyed(body_part: BodyPart)
signal wound_sustained(body_part: BodyPart, wound: Wound)
signal player_died(cause: String)
signal armor_penetrated(armor: Armor, location: BodyPart.Type)
signal bleeding_started(severity: float, location: BodyPart.Type)
signal heavy_bleeding_changed(active: bool)
signal fracture_changed(active: bool)
signal blacked_part_restored(location: BodyPart.Type)
signal pain_relief_changed(seconds_left: float)

# ─── CONFIGURATION ─────────────────────────────────
@export var bleeding_ml_per_damage_per_second: float = 10.0
@export var critical_blood_loss_threshold_ratio: float = 0.2
@export var severe_blood_loss_ratio: float = 0.25
@export var fatal_blood_loss_ratio: float = 0.1
@export_range(0.0, 1.0) var blunt_damage_ratio: float = 0.3
@export_custom(PROPERTY_HINT_NONE, "suffix:J") var penetration_energy_scale: float = 1000.0
@export var pain_increase_per_damage: float = 0.1
@export var pain_decrease_rate: float = 0.1
@export var healing_blood_restoration_multiplier: float = 2.0
@export var healing_bleeding_reduction_multiplier: float = 0.02
# Overkill: hitting an already-black limb this hard in one shot can kill.
@export var overkill_death_threshold: float = 60.0
@export var fresh_wound_dps: float = 0.6
@export var fresh_wound_duration: float = 15.0

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
var pain_relief_timer: float = 0.0

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
func take_ballistic_damage(impact: BallisticsImpact, hit_location: BodyPart.Type, ammo: Ammo = null, face: int = 0) -> Dictionary:
  if not is_alive:
    return {"damage_taken": 0.0, "fatal": false, "wound_created": null, "projectiles": 0}
  var part: BodyPart = body_parts[hit_location]
  var old_health: float = part.current_health
  var projectiles: int = maxi(impact.projectile_count, 1)
  var total_damage := 0.0
  var first_wound: Wound = null
  var armor_pen := false
  var bleed_wounds: Array = []
  # Multi-projectile (buckshot/flechette): each projectile applies its own
  # damage, its own armour durability hit (min 1) and its own bleed roll.
  for _i in projectiles:
    if part.is_destroyed:
      break
    var r = _process_ballistic_impact(part, impact, ammo, face)
    total_damage += r.damage_taken
    if r.wound_created and first_wound == null:
      first_wound = r.wound_created
    armor_pen = armor_pen or r.armor_penetrated
    var b = _roll_ammo_bleed(part, ammo, hit_location)
    if b != null:
      bleed_wounds.append(b)
  health_changed.emit(part, old_health, part.current_health)
  pain_level += total_damage * pain_increase_per_damage
  _recompute_bleeding()
  if first_wound:
    wound_sustained.emit(part, first_wound)
  for b in bleed_wounds:
    bleeding_started.emit(b.severity, hit_location)
  if armor_pen and part.equipped_armor:
    armor_penetrated.emit(part.equipped_armor, hit_location)
  var fatal = _check_death()
  if fatal and is_alive:
    is_alive = false
    player_died.emit("Ballistic trauma to " + BodyPart.type_to_string(hit_location))
  return {
    "damage_taken": total_damage,
    "fatal": fatal,
    "wound_created": first_wound,
    "projectiles": projectiles,
    "armor_penetrated": armor_pen,
  }

## Rolls the round's light/heavy bleed chance and, on success, adds a BLEEDING
## wound to the part and flags the global bleeding rate. Returns the wound or null.
func _roll_ammo_bleed(part: BodyPart, ammo: Ammo, hit_location: BodyPart.Type) -> Wound:
  if ammo == null:
    return null
  var b: Dictionary = Wound.bleed_from_ammo(ammo)
  if not b.get("bleeding", false):
    return null
  var w := Wound.new(b["severity"], Wound.Type.BLEEDING, hit_location, ammo,
    b["dps"], b["duration"])
  w.name = "Heavy bleed" if b.get("heavy", false) else "Light bleed"
  part.add_wound(w)
  return w

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

func apply_environmental_damage(amount: float, _reason: String = "") -> float:
  if not is_alive or amount <= 0.0:
    return 0.0
  var living: Array = []
  for t in body_parts:
    if not body_parts[t].is_destroyed:
      living.append(t)
  if living.is_empty():
    return 0.0
  var per_part := amount / float(living.size())
  var dealt := 0.0
  for t in living:
    dealt += body_parts[t].take_damage(per_part)
  pain_level += dealt * pain_increase_per_damage
  if _check_death():
    is_alive = false
    player_died.emit("Environmental attrition" if _reason == "" else _reason)
  return dealt

# ─── CONDITIONS (bleeding / fracture / pain / blacked limbs) ────────────────
# These back the medical items (see medical_item.gd) and the movement/aim
# penalties. Everything is derived from the wound list so state cannot drift.

## A bleed is "heavy" when it is severe or bleeds faster than 1 HP/s.
static func is_heavy_bleed(w: Wound) -> bool:
  return w.type != Wound.Type.FRACTURE and w.damage_per_second > 0.0 \
    and (w.severity >= Wound.Severity.SEVERE or w.damage_per_second >= 1.0)

func has_light_bleeding() -> bool:
  for part in body_parts.values():
    for w in part.wounds:
      if w.damage_per_second > 0.0 and not is_heavy_bleed(w):
        return true
  return false

func has_heavy_bleeding() -> bool:
  for part in body_parts.values():
    for w in part.wounds:
      if is_heavy_bleed(w):
        return true
  return false

## Clears a bleed by zeroing its dps (army bandage). Returns true if it
## actually stopped something (so a limited-use item is not wasted).
func stop_light_bleeding() -> bool:
  var stopped := false
  for part in body_parts.values():
    for w in part.wounds:
      if w.damage_per_second > 0.0 and not is_heavy_bleed(w):
        _zero_wound_bleed(w)
        stopped = true
  if stopped:
    _recompute_bleeding()
  return stopped

func stop_heavy_bleeding() -> bool:
  var stopped := false
  for part in body_parts.values():
    for w in part.wounds:
      if is_heavy_bleed(w):
        _zero_wound_bleed(w)
        stopped = true
  if stopped:
    heavy_bleeding_changed.emit(false)
    _recompute_bleeding()
  return stopped

func _zero_wound_bleed(w: Wound) -> void:
  w.damage_per_second = 0.0
  w.duration = 0.0

## Tourniquets leave a fresh (light) wound behind.
func add_fresh_wound(part: BodyPart.Type = BodyPart.Type.NONE) -> void:
  var target := part
  if target == BodyPart.Type.NONE:
    for t in body_parts:
      if body_parts[t].is_limb():
        target = t
        break
  if target == BodyPart.Type.NONE or not body_parts.has(target):
    return
  var w := Wound.new(Wound.Severity.MINOR, Wound.Type.BLEEDING, target, null,
    fresh_wound_dps, fresh_wound_duration)
  w.name = "Fresh wound"
  body_parts[target].add_wound(w)
  _recompute_bleeding()

func has_fracture(part: BodyPart.Type = BodyPart.Type.NONE) -> bool:
  for t in body_parts:
    if part != BodyPart.Type.NONE and t != part:
      continue
    for w in body_parts[t].wounds:
      if w.type == Wound.Type.FRACTURE:
        return true
  return false

func splint_fracture(part: BodyPart.Type = BodyPart.Type.NONE) -> bool:
  for t in body_parts:
    if part != BodyPart.Type.NONE and t != part:
      continue
    var bp: BodyPart = body_parts[t]
    var before := bp.wounds.size()
    bp.wounds = bp.wounds.filter(func(w): return w.type != Wound.Type.FRACTURE)
    if bp.wounds.size() != before:
      fracture_changed.emit(false)
      return true
  return false

func get_blacked_parts() -> Array:
  var out: Array = []
  for t in body_parts:
    if body_parts[t].is_destroyed:
      out.append(t)
  return out

func apply_surgery(part: BodyPart.Type = BodyPart.Type.NONE, hp_penalty_ratio: float = 0.35) -> bool:
  var target := part
  if target == BodyPart.Type.NONE:
    for t in body_parts:
      if body_parts[t].is_destroyed:
        target = t
        break
  if target == BodyPart.Type.NONE or not body_parts.has(target):
    return false
  var bp: BodyPart = body_parts[target]
  if not bp.is_destroyed:
    return false
  bp.is_destroyed = false
  bp.current_health = maxf(bp.max_health * clampf(1.0 - hp_penalty_ratio, 0.05, 1.0), 1.0)
  bp.wounds = []
  blood_volume = maxf(blood_volume - bp.max_health * 2.0, max_blood_volume * 0.1)
  blacked_part_restored.emit(target)
  return true

func relieve_pain(seconds: float) -> void:
  pain_relief_timer = maxf(pain_relief_timer, seconds)
  pain_level = 0.0
  pain_relief_changed.emit(pain_relief_timer)

## Pain that actually reaches the hands: analgesia zeroes it, wounds add it.
func effective_pain() -> float:
  if pain_relief_timer > 0.0:
    return 0.0
  return clampf(pain_level, 0.0, 1.0)

func heal_hp(amount: float) -> float:
  var before := total_health
  apply_healing(amount)
  return maxf(total_health - before, 0.0)

## Movement scale from fractures and blacked legs.
func movement_penalty() -> float:
  var mult := 1.0
  if has_fracture():
    mult *= 0.55
  for t in [BodyPart.Type.LEFT_UPPER_LEG, BodyPart.Type.RIGHT_UPPER_LEG,
      BodyPart.Type.LEFT_LOWER_LEG, BodyPart.Type.RIGHT_LOWER_LEG]:
    if body_parts.has(t) and body_parts[t].is_destroyed:
      mult *= 0.8
  return clampf(mult, 0.2, 1.0)

## Aim scale from blacked arms (and wound functionality).
func aim_stability() -> float:
  var mult := 1.0
  for t in [BodyPart.Type.LEFT_UPPER_ARM, BodyPart.Type.RIGHT_UPPER_ARM,
      BodyPart.Type.LEFT_LOWER_ARM, BodyPart.Type.RIGHT_LOWER_ARM]:
    if body_parts.has(t):
      mult *= body_parts[t].functionality_multiplier
  return clampf(mult, 0.15, 1.0)

func _recompute_bleeding() -> void:
  total_bleeding_rate = 0.0
  for part in body_parts.values():
    for w in part.wounds:
      if w.damage_per_second > 0.0:
        total_bleeding_rate += w.damage_per_second

func update(delta: float):
  if not is_alive:
    return
  _apply_bleeding_damage(delta)
  for part in body_parts.values():
    part.update(delta)
  # Recompute the bleed bookkeeping: medical items zero wound dps directly
  # and wounds expire, so the cached rate must not be the only source.
  _recompute_bleeding()
  pain_level = max(0.0, pain_level - delta * pain_decrease_rate)
  if pain_relief_timer > 0.0:
    pain_relief_timer = maxf(pain_relief_timer - delta, 0.0)
    if pain_relief_timer == 0.0:
      pain_relief_changed.emit(0.0)
  # Starvation / dehydration bites once the pools are empty (survival.gd
  # reports them through the player; here they cost blood and health).
  if _check_blood_loss_death():
    is_alive = false
    player_died.emit("Critical blood loss")

# ─── INTERNAL LOGIC ────────────────────────────────
func _process_ballistic_impact(part: BodyPart, impact: BallisticsImpact, ammo: Ammo = null, face: int = 0) -> Dictionary:
  var result = {
    "damage_taken": 0.0,
    "penetrated": false,
    "wound_created": null,
    "armor_penetrated": false,
    "overkill": false
  }
  if part.is_destroyed:
    # Overkill: hammering a blacked limb can still kill (genre-typical bleed-out
    # on a destroyed part). Threshold on the single-shot energy.
    if impact.hit_energy >= overkill_death_threshold and not part.is_torso() \
        and part.type != BodyPart.Type.HEAD:
      is_alive = false
      result["overkill"] = true
      player_died.emit("Overkill on a destroyed limb")
    elif impact.hit_energy >= overkill_death_threshold * 2.0:
      is_alive = false
      result["overkill"] = true
      player_died.emit("Overkill trauma")
    return result
  var base_damage = impact.hit_energy * part.tissue_multiplier
  var bullet = ammo if ammo != null else Ammo.new()
  if part.equipped_armor and part.equipped_armor.material:
    # Layered stop (plates over base) + material destructibility wear.
    var ar := part.equipped_armor.resolve_projectile(bullet, impact, face)
    result.armor_penetrated = ar.get("penetrated", false)
    if ar.get("penetrated", false):
      var actual_damage = base_damage * (1.0 - impact.hit_energy / (impact.hit_energy + penetration_energy_scale))
      result.damage_taken = part.take_damage(actual_damage)
      result.wound_created = Wound.create_ballistic_wound(bullet, impact, part)
    else:
      var blunt_damage = base_damage * blunt_damage_ratio
      result.damage_taken = part.take_damage(blunt_damage)
      if blunt_damage > 5.0:
        result.wound_created = Wound.create_ballistic_wound(bullet, impact, part)
  else:
    result.penetrated = true
    result.damage_taken = part.take_damage(base_damage)
    result.wound_created = Wound.create_ballistic_wound(bullet, impact, part)
  if result.wound_created != null:
    part.add_wound(result.wound_created)
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
  if blood_volume <= max_blood_volume * fatal_blood_loss_ratio:
    return true
  # Heavy bleed past the critical ratio kills; the severe band only kills while
  # bleeding is still active, so it is not subsumed by the critical gate.
  if blood_volume < max_blood_volume * critical_blood_loss_threshold_ratio and total_bleeding_rate > 3.0:
    return true
  if blood_volume < max_blood_volume * severe_blood_loss_ratio and total_bleeding_rate > 0.0:
    return true
  return false

func _on_body_part_functionality_changed(multiplier: float):
  pain_level = max(pain_level, 1.0 - multiplier)

func _on_body_part_destroyed(body_part: BodyPart):
  if is_alive and _check_death():
    is_alive = false
    player_died.emit("Instant trauma to " + BodyPart.type_to_string(body_part.type))

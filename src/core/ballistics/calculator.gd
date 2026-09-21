# res://addons/cabra.lat_shooters/src/core/ballistics/ballistics_calculator.gd
class_name BallisticsCalculator
extends Resource

@export var gravity: float = 9.81       # m/s²
@export var wind_velocity: Vector3 = Vector3.ZERO

static func los_thickness(thickness: float, impact_angle_deg: float) -> float:
  # Line-of-sight thickness through a plate struck at obliquity (Recht-Ipson
  # oblique treatment: Heff = H / cos). Clamped to avoid the 90° singularity.
  var c = cos(deg_to_rad(clampf(impact_angle_deg, 0.0, 89.0)))
  return thickness / max(c, 0.05)

static func residual_energy(hit_energy: float, limit_energy: float) -> float:
  # Recht-Ipson with exponent p=2 (constant target energy absorption):
  # Vr² = Vi² - Vbl²  ⟺  Er = Eh - Ebl. Zero below the ballistic limit.
  return max(0.0, hit_energy - limit_energy)

# ─── SIGHT / ZERO MODEL ─────────────────────────────
# Convention: bore at y=0, sight line horizontal at y=sight_height_m.
# The barrel pitches up by launch angle θ so the trajectory crosses the
# sight line exactly at zero_m (POA == POI). The resolver compensates drop
# via sight_launch_angle; zero_distance is NOT mere metadata.
static func sight_launch_angle(ammo: Ammo, sight_height_m: float, zero_m: float, gravity: float = 9.81) -> float:
  # tanθ = (h + drop(Z)) / Z, reusing Ammo's gravity-drop model.
  var z := max(zero_m, 0.5)
  return atan((sight_height_m + ammo.get_ballistic_drop(z, 0.0, gravity)) / z)

static func poi_height_vs_poa(ammo: Ammo, sight_height_m: float, zero_m: float, distance_m: float, gravity: float = 9.81) -> float:
  # Signed vertical impact offset vs point of aim, meters. + = hits high.
  # Below the zero the round strikes low, just past it high, then drop wins.
  var d := max(distance_m, 0.0)
  var theta := sight_launch_angle(ammo, sight_height_m, zero_m, gravity)
  return d * tan(theta) - ammo.get_ballistic_drop(d, 0.0, gravity) - sight_height_m

static func sight_compensation_table(ammo: Ammo, sight_height_m: float, zero_m: float, distances: Array, gravity: float = 9.81) -> Array:
  # Per-distance POI offset + dial correction. correction_moa > 0 = dial up.
  var rows: Array = []
  for d in distances:
    var dd := float(d)
    var off: float = poi_height_vs_poa(ammo, sight_height_m, zero_m, dd, gravity)
    var corr_moa := 0.0
    if dd > 0.01:
      corr_moa = -rad_to_deg(atan(off / dd)) * 60.0
    rows.append({"distance_m": dd, "offset_m": off, "offset_cm": off * 100.0, "correction_moa": corr_moa})
  return rows

static func calculate_impact(
  ammo: Ammo,
  target: BallisticMaterial,
  thickness: float = 0.0,
  distance: float = 0.0,
  impact_angle: float = 0.0,
  prev_impact: BallisticsImpact = null
) -> BallisticsImpact:
  var impact = BallisticsImpact.new()
  impact.mass = ammo.bullet_mass
  impact.hit_energy = ammo.get_energy_at_range(distance)
  impact.angle = impact_angle
  impact.thickness = los_thickness(thickness, impact_angle)
  impact.projectile_count = maxi(ammo.projectile_count, 1)
  impact.projectile_damage = ammo.get_projectile_damage()

  if prev_impact:
    impact.hit_energy = prev_impact.exit_energy

  # Check for ricochet
  impact.ricochet = target.should_ricochet(ammo, impact_angle)
  if impact.ricochet:
    impact.penetration_depth = 0.0
    impact.exit_energy = impact.hit_energy * 0.25
    return impact

  # Penetration capability vs LOS thickness; residual via Recht-Ipson.
  impact.penetration_depth = target.penetration_capability(ammo, impact.hit_energy)
  var limit_energy = target.stopping_energy(ammo, impact.thickness)
  impact.exit_energy = residual_energy(impact.hit_energy, limit_energy)

  # Fragmentation
  impact.fragments = ammo.should_fragment(impact.exit_energy, target.hardness)

  return impact

static func calculate_multi_layer_penetration(
  ammo: Ammo,
  layers: Array,
  distance: float,
  impact_angle: float
) -> Array[BallisticsImpact]:
  var results: Array[BallisticsImpact] = []
  var current_impact: BallisticsImpact = null
  for layer in layers:
    current_impact = calculate_impact(
      ammo,
      layer.material,
      layer.thickness,
      distance,
      impact_angle,
      current_impact
    )
    results.append(current_impact)
  return results

func calculate_trajectory(ammo: Ammo, distance: float, zero_range: float = 100.0) -> Dictionary:
  var v_downrange = max(ammo.get_velocity_at_range(distance), 1.0)
  return {
    "drop": ammo.get_ballistic_drop(distance, zero_range, gravity),
    "windage": wind_velocity.x * (distance / v_downrange),
    "time_of_flight": distance / v_downrange,
    "velocity": ammo.get_velocity_at_range(distance),
    "energy": ammo.get_energy_at_range(distance)
  }

func calculate_hit_probability(
  ammo: Ammo,
  distance: float,
  shooter_skill: float = 1.0,
  target_size: float = 1.0,
  stability: float = 1.0
) -> float:
  var base_accuracy = ammo.accuracy
  var distance_factor = 1.0 + (distance / 100.0) * 0.1
  var effective_accuracy = base_accuracy * distance_factor / (shooter_skill * stability)
  var hit_probability = 1.0 / (1.0 + effective_accuracy * 0.1) * target_size
  return clamp(hit_probability, 0.0, 1.0)

func calculate_shotgun_spread(ammo: Ammo, distance: float, choke: float = 1.0) -> Dictionary:
  if ammo.type != Ammo.Type.BUCKSHOT and ammo.type != Ammo.Type.BIRD_SHOT:
    return {"spread_radius": 0.0, "pellet_count": 1, "effective_range": 0.0}

  var pellet_count = 9 if ammo.type == Ammo.Type.BUCKSHOT else 24
  var spread_radius = (1.0 * (distance / 0.9144) / choke) * 0.0254  # meters

  return {
    "spread_radius": spread_radius,
    "pellet_count": pellet_count,
    "effective_range": 40.0 if ammo.type == Ammo.Type.BUCKSHOT else 25.0
  }

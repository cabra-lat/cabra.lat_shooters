# res://src/core/ballistics/ballistics_calculator.gd
class_name BallisticsCalculator
extends Resource

@export var air_density: float = 1.225  # kg/m³ at sea level
@export var gravity: float = 9.81       # m/s²
@export var wind_velocity: Vector3 = Vector3.ZERO
@export var temperature: float = 15.0   # Celsius

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
	impact.thickness = thickness

	if prev_impact:
		impact.hit_energy = prev_impact.exit_energy

	# Check for ricochet
	impact.ricochet = target.should_ricochet(ammo, impact_angle)
	if impact.ricochet:
		return impact

	# Calculate penetration
	impact.penetration_depth = target.calculate_penetration(ammo, impact.hit_energy, impact.angle)

	# Energy loss through layer
	impact.exit_energy = impact.hit_energy * (1.0 - target.energy_absorption)

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
	return {
		"drop": ammo.get_ballistic_drop(distance, zero_range, gravity),
		"windage": wind_velocity.x * (distance / ammo.muzzle_velocity),
		"time_of_flight": distance / ammo.muzzle_velocity,
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

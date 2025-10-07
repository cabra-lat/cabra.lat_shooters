# ballistics_calculator.gd
@tool
class_name BallisticsCalculator extends Resource

# Environmental factors
@export var air_density: float = 1.225  # kg/m³ at sea level
@export var gravity: float = 9.81       # m/s²
@export var wind_velocity: Vector3 = Vector3.ZERO  # m/s
@export var temperature: float = 15.0   # Celsius

## Method for calculating penetration through target
static func calculate_impact(ammo: Ammo, target: BallisticMaterial, 
							 thickness: float = 0.0, distance: float = 0.0, 
							 impact_angle: float = 0.0, prev_impact: BallisticsImpact = null) -> BallisticsImpact:
	var impact = BallisticsImpact.new()
	impact.mass       = ammo.bullet_mass
	impact.hit_energy = ammo.get_energy_at_range(distance)
	impact.angle      = impact_angle
	impact.ricochet   = target.should_ricochet(ammo, impact_angle)

	if 	prev_impact:
		impact.hit_energy = prev_impact.exit_energy

	# Check for ricochet
	if impact.ricochet: return impact
	
	impact.fragments = ammo.should_fragment(impact.hit_energy, target.hardness)
	# Calculate penetration using ammo's method
	impact.penetration_depth = target.calculate_penetration(ammo, impact.hit_energy, impact.angle)
	impact.thickness = thickness
	
	# Energy loss through layer (simplified)
	impact.exit_energy = impact.hit_energy * (1.0 - target.energy_absorption)
	
	# Check for fragmentation using ammo's method
	if not impact.fragmented:
		impact.fragments = ammo.should_fragment(impact.exit_energy, target.hardness)
	return impact

## Method for calculating penetration through multiple layers
static func calculate_multi_layer_penetration(ammo: Ammo, layers: Array, distance: float, 
									  impact_angle: float) -> Array[BallisticsImpact]:
	# Calculate penetration through multiple material layers
	var results: Array[BallisticsImpact] = []
	var impact: BallisticsImpact = null
	for layer in layers:
		# Calculate penetration in this layer
		impact = calculate_impact(
			ammo, 
			layer.material, 
			layer.thickness, 
			distance, impact_angle, impact)
		results.append(impact)
	return results

func calculate_trajectory(ammo: Ammo, distance: float, zero_range: float = 100.0) -> Dictionary:
	# Calculate bullet trajectory with environmental factors
	var results = {
		"drop": 0.0,
		"windage": 0.0,
		"time_of_flight": 0.0,
		"velocity": 0.0,
		"energy": 0.0
	}
	
	# Use ammo's built-in trajectory calculations
	results.drop = ammo.get_ballistic_drop(distance, zero_range, gravity)
	results.velocity = ammo.get_velocity_at_range(distance)
	results.energy = ammo.get_energy_at_range(distance)
	
	# Time of flight (simplified)
	results.time_of_flight = distance / ammo.muzzle_velocity
	
	# Wind effect
	results.windage = wind_velocity.x * results.time_of_flight
	
	return results

## Method for calculating hit probability
func calculate_hit_probability(ammo: Ammo, distance: float, shooter_skill: float = 1.0, 
							  target_size: float = 1.0, stability: float = 1.0) -> float:
	# Calculate hit probability based on multiple factors
	var base_accuracy = ammo.accuracy  # Lower is better
	
	# Distance factor (accuracy degrades with distance)
	var distance_factor = 1.0 + (distance / 100.0) * 0.1
	
	# Shooter skill factor
	var skill_factor = 1.0 / shooter_skill
	
	# Stability factor (weapon stability, breathing, etc.)
	var stability_factor = 1.0 / stability
	
	# Combined accuracy value
	var effective_accuracy = base_accuracy * distance_factor * skill_factor * stability_factor
	
	# Convert accuracy to hit probability (simplified)
	# Lower effective_accuracy = higher hit probability
	var hit_probability = 1.0 / (1.0 + effective_accuracy * 0.1)
	
	# Adjust for target size
	hit_probability *= target_size
	
	# Cap between 0 and 1
	return clamp(hit_probability, 0.0, 1.0)

## Method for calculating multiple projectile spread (shotguns)
func calculate_shotgun_spread(ammo: Ammo, distance: float, choke: float = 1.0) -> Dictionary:
	# Calculate shotgun pellet spread
	var results = {
		"spread_radius": 0.0,
		"pellet_count": 1,
		"effective_range": 0.0
	}
	
	# Only applies to shotgun ammo types
	if ammo.type != Ammo.Type.BUCKSHOT and ammo.type != Ammo.Type.BIRD_SHOT:
		return results
	
	# Determine pellet count based on ammo type
	match ammo.type:
		Ammo.Type.BUCKSHOT:
			results.pellet_count = 9  # Typical 00 buckshot
			results.effective_range = 40.0
		Ammo.Type.BIRD_SHOT:
			results.pellet_count = 24  # Typical birdshot
			results.effective_range = 25.0
	
	# Calculate spread radius (inches at distance)
	var base_spread = 1.0  # inches at 1 yard
	var spread_at_distance = base_spread * (distance / 0.9144)  # Convert meters to yards
	
	# Apply choke modifier (lower choke = tighter spread)
	spread_at_distance /= choke
	
	results.spread_radius = spread_at_distance * 0.0254  # Convert to meters
	
	return results

## Utility method for zeroing calculations
func calculate_zero_range(ammo: Ammo, target_distance: float, sight_height: float = 0.05) -> float:
	# Calculate optimal zero range for given target distance
	# This is a simplified calculation - real zeroing is more complex
	
	# Basic zero range calculation
	var time_to_target = target_distance / ammo.muzzle_velocity
	var drop = 0.5 * gravity * pow(time_to_target, 2)
	
	# Account for sight height
	var angle_correction = atan2(drop - sight_height, target_distance)
	
	# Convert to zero range (where bullet crosses line of sight)
	var zero_range = target_distance * 0.8  # Simplified approximation
	
	return zero_range

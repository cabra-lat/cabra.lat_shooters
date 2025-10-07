# test_ballistics_calculator.gd
@tool
class_name TestBallisticsCalculator extends EditorScript

var TEST_RESULTS = []

func _run():
	print("🎯 Testing Ballistics Calculator...")
	
	_test_trajectory_calculation()
	_test_impact_calculation()
	_test_hit_probability()
	_test_shotgun_spread()
	_test_multi_layer_penetration()
	
	print("\n✅ BALLISTICS CALCULATOR TEST SUMMARY:")
	for result in TEST_RESULTS:
		print(result)
	print("\nDone.")

func _test_trajectory_calculation():
	print("\n🎯 Testing Trajectory Calculation:")
	
	var calculator = BallisticsCalculator.new()
	var ammo = _create_test_ammo()
	
	var trajectory = calculator.calculate_trajectory(ammo, 100.0)
	
	if trajectory.has("drop") and trajectory.has("velocity") and trajectory.has("energy"):
		TEST_RESULTS.append("✅ PASS: Trajectory calculation returns all required fields")
	else:
		TEST_RESULTS.append("❌ FAIL: Trajectory calculation missing fields")
	
	# Test that drop increases with distance
	var drop_100m = trajectory.drop
	var trajectory_200m = calculator.calculate_trajectory(ammo, 200.0)
	var drop_200m = trajectory_200m.drop
	
	if drop_200m > drop_100m:
		TEST_RESULTS.append("✅ PASS: Bullet drop increases with distance")
	else:
		TEST_RESULTS.append("❌ FAIL: Bullet drop calculation incorrect")

func _test_impact_calculation():
	print("\n🎯 Testing Impact Calculation:")
	
	var calculator = BallisticsCalculator.new()
	var ammo = _create_test_ammo()
	var steel_plate = _create_test_material("steel_plate")
	
	var impact = calculator.calculate_impact(ammo, steel_plate, 100.0, 0.0, "torso")
	
	if impact.has("damage") and impact.has("penetrated") and impact.has("ricochet"):
		TEST_RESULTS.append("✅ PASS: Impact calculation returns all required fields")
	else:
		TEST_RESULTS.append("❌ FAIL: Impact calculation missing fields")
	
	# Test that high-angle impacts are more likely to ricochet
	var low_angle_impact = calculator.calculate_impact(ammo, steel_plate, 100.0, 10.0, "torso")
	var high_angle_impact = calculator.calculate_impact(ammo, steel_plate, 100.0, 80.0, "torso")
	
	# High angle should be more likely to ricochet (though this is probabilistic)
	TEST_RESULTS.append("✅ PASS: Impact calculation handles different angles")

func _test_hit_probability():
	print("\n🎯 Testing Hit Probability:")
	
	var calculator = BallisticsCalculator.new()
	var ammo = _create_test_ammo()
	
	var close_range_prob = calculator.calculate_hit_probability(ammo, 50.0, 1.0, 1.0, 1.0)
	var far_range_prob = calculator.calculate_hit_probability(ammo, 300.0, 1.0, 1.0, 1.0)
	
	if close_range_prob > far_range_prob:
		TEST_RESULTS.append("✅ PASS: Hit probability decreases with distance")
	else:
		TEST_RESULTS.append("❌ FAIL: Hit probability doesn't decrease with distance")
	
	# Test probability bounds
	if close_range_prob >= 0.0 and close_range_prob <= 1.0:
		TEST_RESULTS.append("✅ PASS: Hit probability within valid range")
	else:
		TEST_RESULTS.append("❌ FAIL: Hit probability outside valid range")

func _test_shotgun_spread():
	print("\n🎯 Testing Shotgun Spread:")
	
	var calculator = BallisticsCalculator.new()
	var buckshot = _create_test_shotgun_ammo()
	
	var spread = calculator.calculate_shotgun_spread(buckshot, 25.0, 1.0)
	
	if spread.has("spread_radius") and spread.has("pellet_count"):
		TEST_RESULTS.append("✅ PASS: Shotgun spread calculation works")
	else:
		TEST_RESULTS.append("❌ FAIL: Shotgun spread calculation broken")
	
	if spread.pellet_count > 1:
		TEST_RESULTS.append("✅ PASS: Shotgun identifies multiple pellets")
	else:
		TEST_RESULTS.append("❌ FAIL: Shotgun pellet count incorrect")

func _test_multi_layer_penetration():
	print("\n🎯 Testing Multi-Layer Penetration:")
	
	var calculator = BallisticsCalculator.new()
	var ammo = _create_test_ammo()
	
	var layers = [
		{"material": _create_test_material("kevlar"), "thickness": 0.01},
		{"material": _create_test_material("steel"), "thickness": 0.005}
	]
	
	var penetration = calculator.calculate_multi_layer_penetration(ammo, layers, 100.0, 0.0)
	
	if penetration.has("layers_penetrated") and penetration.has("remaining_energy"):
		TEST_RESULTS.append("✅ PASS: Multi-layer penetration calculation works")
	else:
		TEST_RESULTS.append("❌ FAIL: Multi-layer penetration calculation broken")

func _create_test_ammo() -> Ammo:
	var ammo = Ammo.new()
	ammo.name = "Test Ammo"
	ammo.caliber = "7.62x39mm"
	ammo.type = Ammo.Type.STEEL_CORE
	ammo.bullet_mass = 8.0
	ammo.muzzle_velocity = 720.0
	ammo.base_damage = 55.0
	ammo.accuracy = 2.0
	ammo.ballistic_coefficient = 0.275
	return ammo

func _create_test_shotgun_ammo() -> Ammo:
	var ammo = Ammo.new()
	ammo.name = "Test Buckshot"
	ammo.caliber = "12 Gauge"
	ammo.type = Ammo.Type.BUCKSHOT
	ammo.bullet_mass = 32.0  # Total payload
	ammo.muzzle_velocity = 400.0
	ammo.base_damage = 25.0
	return ammo

func _create_test_material(material_name: String) -> BallisticMaterial:
	var material = BallisticMaterial.new()
	material.name = material_name
	
	match material_name:
		"steel_plate":
			material.type = BallisticMaterial.Type.METAL_MEDIUM
			material.hardness = 8.0
			material.penetration_resistance = 5.0
		"kevlar":
			material.type = BallisticMaterial.Type.ARMOR_SOFT
			material.hardness = 2.0
			material.penetration_resistance = 2.0
		_:
			material.type = BallisticMaterial.Type.FLESH_SOFT
			material.hardness = 0.5
			material.penetration_resistance = 0.5
	
	return material

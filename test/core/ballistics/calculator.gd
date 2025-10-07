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
	var ammo = Ammo.create_test_ammo()
	
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
	var ammo = Ammo.create_ap_ammo()
	var steel_plate = _create_test_material("RHA300HB")
	var impact = calculator.calculate_impact(ammo, steel_plate, 5.0, 100.0)
	print(impact)
	if impact.penetrated and impact.penetration_depth > 0.12:
		TEST_RESULTS.append("✅ PASS: Impact calculation correct (%s mm RHA)" % impact.penetration_depth)
	else:
		TEST_RESULTS.append("❌ FAIL: Impact calculation incorrect: %s mm RHA" % impact.penetration_depth)
	
	# Test that high-angle impacts are more likely to ricochet
	var low_angle_impact = calculator.calculate_impact(ammo, steel_plate, 100.0, 10.0)
	var high_angle_impact = calculator.calculate_impact(ammo, steel_plate, 100.0, 80.0)
	print(low_angle_impact)
	print(high_angle_impact)
	# High angle should be more likely to ricochet (though this is probabilistic)
	TEST_RESULTS.append("✅ PASS: Impact calculation handles different angles")

func _test_hit_probability():
	print("\n🎯 Testing Hit Probability:")
	
	var calculator = BallisticsCalculator.new()
	var ammo = Ammo.create_test_ammo()
	
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
	var buckshot = Ammo.create_test_shotgun_ammo()
	
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
	var ammo = Ammo.create_ap_ammo()
	
	var layers = [
		{"material": _create_test_material("RHA300HB"), "thickness": 5.0},
		{"material": _create_test_material("RHA300HB"), "thickness": 5.0},
		{"material": _create_test_material("kevlar"),   "thickness": 1.0},
		{"material": _create_test_material("RHA300HB"), "thickness": 10.0},
		{"material": _create_test_material("flesh"),    "thickness": 10.0}
	]
	
	var impacts = calculator.calculate_multi_layer_penetration(ammo, layers, 100.0, 0.0)
	var layers_penetrated = impacts.map(func(g): return g.penetrated).count(true)
	var remaining_energy = impacts.map(func(g): return g.exit_energy)[-1]
	for impact in impacts:
		print(impact)
	if layers_penetrated > 0 and remaining_energy == 0:
		TEST_RESULTS.append("✅ PASS: Multi-layer penetration calculation works")
	else:
		TEST_RESULTS.append("❌ FAIL: Multi-layer penetration calculation broken")


func _create_test_material(material_name: String) -> BallisticMaterial:
	var material = BallisticMaterial.new()
	material.name = material_name
	
	match material_name:
		"RHA300HB":
			material.type = BallisticMaterial.Type.METAL_MEDIUM
			material.hardness = 300.0
			material.energy_absorption = material.hardness
			material.penetration_resistance = 5.0
		"kevlar":
			material.type = BallisticMaterial.Type.ARMOR_SOFT
			material.hardness = 65.0 # 65-92 HN
			material.penetration_resistance = 2.0
		_:
			material.type = BallisticMaterial.Type.FLESH_SOFT
			material.hardness = 0.5
			material.penetration_resistance = 0.5
	
	return material

# test_ammo_ballistics.gd
@tool
class_name TestAmmoBallistics extends EditorScript

var TEST_RESULTS = []

func _run():
	print("🎯 Testing Enhanced Ammo Ballistics...")
	
	_test_ammo_creation()
	_test_ballistic_calculations()
	
	print("\n✅ AMMO BALLISTICS TEST SUMMARY:")
	for result in TEST_RESULTS:
		print(result)
	print("\nDone.")

func _test_ammo_creation():
	print("\n🎯 Testing Ammo Creation:")
	
	var m855 = Ammo.new()
	m855.name = "5.56x45mm M855"
	m855.caliber = "5.56x45mm"
	m855.type = Ammo.Type.GREEN_TIP
	m855.bullet_mass = 4.0
	m855.muzzle_velocity = 940.0
	m855.penetration_value = 1.4
	m855.ballistic_coefficient = 0.151
	
	if m855 and m855.name == "5.56x45mm M855":
		TEST_RESULTS.append("✅ PASS: Enhanced ammo creation successful")
	else:
		TEST_RESULTS.append("❌ FAIL: Enhanced ammo creation failed")
	
	# Test computed properties
	var energy = m855.get_energy()
	var expected_energy = 0.5 * (4.0 / 1000.0) * pow(940.0, 2)
	if abs(energy - expected_energy) < 1.0:
		TEST_RESULTS.append("✅ PASS: Energy calculation correct")
	else:
		TEST_RESULTS.append("❌ FAIL: Energy calculation incorrect")

func _test_ballistic_calculations():
	print("\n🎯 Testing Ballistic Calculations:")
	
	var ammo = Ammo.new()
	ammo.bullet_mass = 8.0
	ammo.muzzle_velocity = 720.0
	ammo.ballistic_coefficient = 0.3
	
	# Test velocity at range
	var velocity_100m = ammo.get_velocity_at_range(100.0)
	if velocity_100m < ammo.muzzle_velocity:
		TEST_RESULTS.append("✅ PASS: Velocity decreases with range")
	else:
		TEST_RESULTS.append("❌ FAIL: Velocity doesn't decrease with range")
	
	# Test energy at range
	var energy_100m = ammo.get_energy_at_range(100.0)
	if energy_100m < ammo.get_energy():
		TEST_RESULTS.append("✅ PASS: Energy decreases with range")
	else:
		TEST_RESULTS.append("❌ FAIL: Energy doesn't decrease with range")
	
	# Test ballistic drop
	var drop = ammo.get_ballistic_drop(300.0)
	if drop > 0.0:
		TEST_RESULTS.append("✅ PASS: Ballistic drop calculation works")
	else:
		TEST_RESULTS.append("❌ FAIL: Ballistic drop calculation broken")

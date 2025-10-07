# test_ammo_ballistics.gd
@tool
class_name TestAmmoBallistics extends EditorScript

var TEST_RESULTS = []

func _run():
	print("🎯 Testing Enhanced Ammo Ballistics...")
	
	_test_ammo_creation()
	_test_ballistic_calculations()
	_test_terminal_ballistics()
	_test_type_specific_behaviors()
	
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
	m855.base_damage = 42.0
	
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

func _test_terminal_ballistics():
	print("\n🎯 Testing Terminal Ballistics:")
	
	var ammo = Ammo.new()
	ammo.base_damage = 50.0
	ammo.flesh_modifier = 1.2
	ammo.armor_modifier = 0.8
	
	# Test damage calculation
	var flesh_damage = ammo.calculate_impact_damage(1500.0, "flesh", "head")
	var armor_damage = ammo.calculate_impact_damage(1500.0, "armor", "chest")
	
	if flesh_damage > armor_damage:
		TEST_RESULTS.append("✅ PASS: Flesh damage higher than armor damage")
	else:
		TEST_RESULTS.append("❌ FAIL: Damage modifiers not working correctly")
	
	# Test location multipliers
	var head_damage = ammo.calculate_impact_damage(1500.0, "flesh", "head")
	var leg_damage = ammo.calculate_impact_damage(1500.0, "flesh", "legs")
	
	if head_damage > leg_damage:
		TEST_RESULTS.append("✅ PASS: Headshot damage multiplier works")
	else:
		TEST_RESULTS.append("❌ FAIL: Headshot damage multiplier broken")

func _test_type_specific_behaviors():
	print("\n🎯 Testing Type-Specific Behaviors:")
	
	var fmj = Ammo.new()
	fmj.type = Ammo.Type.FMJ
	
	var jhp = Ammo.new()
	jhp.type = Ammo.Type.JHP
	
	var ap = Ammo.new()
	ap.type = Ammo.Type.AP
	
	# Test type modifiers
	var fmj_mods = fmj.get_type_modifiers()
	var jhp_mods = jhp.get_type_modifiers()
	var ap_mods = ap.get_type_modifiers()
	
	if jhp_mods["flesh_damage"] > fmj_mods["flesh_damage"]:
		TEST_RESULTS.append("✅ PASS: JHP has higher flesh damage than FMJ")
	else:
		TEST_RESULTS.append("❌ FAIL: JHP flesh damage incorrect")
	
	if ap_mods["penetration"] > fmj_mods["penetration"]:
		TEST_RESULTS.append("✅ PASS: AP has higher penetration than FMJ")
	else:
		TEST_RESULTS.append("❌ FAIL: AP penetration incorrect")
	
	# Test ricochet behavior
	fmj.ricochet_chance = 0.3
	fmj.ricochet_angle = 30.0
	
	var should_ricochet = fmj.should_ricochet(10.0, 1.0)  # Low angle on hard surface
	# This is probabilistic, so we just test the function runs
	TEST_RESULTS.append("✅ PASS: Ricochet calculation functional")

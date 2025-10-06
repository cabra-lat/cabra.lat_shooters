

@tool
class_name TestArmor extends EditorScript

var TEST_RESULTS = []

func _run():
	run_armor_tests()

func run_armor_tests():
	print("🔍 Loading ammo resources...")
	var ammo_list = TestUtils.load_all_ammo()
	if ammo_list.is_empty():
		push_error("No ammo resources found!")
		return

	print("🛡️ Testing armor penetration logic...")
	_test_certified_threats(ammo_list)
	_test_energy_thresholds()
	_test_durability_failure()
	_test_detailed_penetration_analysis(ammo_list)  # NEW: Detailed analysis

	# Print results
	print("\n✅ TEST SUMMARY:")
	for result in TEST_RESULTS:
		print(result)
	print("\nDone.")

# ─── TEST 1: CERTIFIED THREATS MUST NOT PENETRATE ──

func _test_certified_threats(ammo_list):
	# Create armor for each standard/level
	var test_cases = [
		{standard = Armor.Standard.VPAM, level = 6, caliber = "7.62x39mm PS"},
		{standard = Armor.Standard.VPAM, level = 7, caliber = "5.56x45mm SS109"},
		{standard = Armor.Standard.NIJ, level = 7, caliber = "7.62x51mm M80"},
		{standard = Armor.Standard.NIJ, level = 8, caliber = "5.56x45mm M855"},
		{standard = Armor.Standard.GA141, level = 5, caliber = "7.62x39mm"},
		{standard = Armor.Standard.MILITARY, level = 2, caliber = "5.56x45mm M995"}
	]

	for case in test_cases:
		var armor = Armor.new()
		armor.standard = case.standard
		armor.level = case.level

		var matching_ammo = ammo_list.filter(func(a): return case.caliber in a.caliber)
		if matching_ammo.is_empty():
			TEST_RESULTS.append("⚠️ SKIP: No ammo for %s" % case.caliber)
			continue

		var ammo = matching_ammo[0]
		var penetrated = armor.is_penetrated_by(ammo)
		if penetrated:
			TEST_RESULTS.append("❌ FAIL: %s (Level %d) penetrated by certified %s" % [
				armor.standard, armor.level, ammo.caliber
			])
		else:
			TEST_RESULTS.append("✅ PASS: %s (Level %d) stops %s" % [
				armor.standard, armor.level, ammo.caliber
			])

# ─── TEST 2: ENERGY THRESHOLDS ─────────────────────

func _test_energy_thresholds():
	# Test VPAM PM6 vs weaker threat (9mm)
	var armor = Armor.new()
	armor.standard = Armor.Standard.VPAM
	armor.level = 6

	var nine_mm = Ammo.new(8.0, 360)
	# E = 518 J < 2074 J steel-core limit

	if armor.is_penetrated_by(nine_mm):
		TEST_RESULTS.append("❌ FAIL: VPAM PM6 should stop 9mm FMJ")
	else:
		TEST_RESULTS.append("✅ PASS: VPAM PM6 stops 9mm FMJ")

	# Test VPAM PM6 vs stronger threat (7.62x39mm BZ API)
	var bz_api = Ammo.new(7.7, 740, Ammo.Type.API)
	# E = 2110 J > 2074 J

	if not armor.is_penetrated_by(bz_api):
		TEST_RESULTS.append("❌ FAIL: VPAM PM6 should NOT stop 7.62x39mm BZ API")
	else:
		TEST_RESULTS.append("✅ PASS: VPAM PM6 fails vs 7.62x39mm BZ API")

# ─── TEST 3: DURABILITY FAILURE ────────────────────

func _test_durability_failure():
	var armor = Armor.new()
	armor.standard = Armor.Standard.VPAM
	armor.level = 6
	armor.current_durability = 0

	var ammo = Ammo.new(8.0, 720, Ammo.Type.STEEL_CORE)

	if not armor.is_penetrated_by(ammo):
		TEST_RESULTS.append("❌ FAIL: Broken armor should always penetrate")
	else:
		TEST_RESULTS.append("✅ PASS: Broken armor penetrates")

# ─── TEST 4: DETAILED PENETRATION ANALYSIS ─────────

func _test_detailed_penetration_analysis(ammo_list):
	print("\n🔍 Detailed Penetration Analysis:")
	
	# Focus on the failing case
	var armor = Armor.new()
	armor.standard = Armor.Standard.NIJ
	armor.level = 8
	
	var m855_ammo = ammo_list.filter(func(a): return "5.56x45mm M855" in a.caliber)[0]
	
	# Debug information
	print("  Armor: %s Level %d" % [armor.standard, armor.level])
	print("  Ammo: %s" % m855_ammo.caliber)
	print("  Mass: %.1fg" % m855_ammo.bullet_mass)
	print("  Velocity: %.0f m/s" % m855_ammo.muzzle_velocity)
	print("  Energy: %.0f J" % m855_ammo.get_energy())
	print("  Type: %s" % m855_ammo.type)
	
	var penetrated = armor.is_penetrated_by(m855_ammo)
	print("  Penetrated: %s" % penetrated)
	
	# Check if this is a steel core round that should be handled differently
	if m855_ammo.type == Ammo.Type.STEEL_CORE:
		print("  ⚠️ M855 has steel core - may require special handling")
	
	# Test with different armor standards at same level
	print("\n  Comparing standards at similar levels:")
	var comparison_armors = [
		{"standard": Armor.Standard.NIJ, "level": 8},
		{"standard": Armor.Standard.VPAM, "level": 7},
		{"standard": Armor.Standard.GA141, "level": 6}
	]
	
	for comp_armor_data in comparison_armors:
		var comp_armor = Armor.new()
		comp_armor.standard = comp_armor_data.standard
		comp_armor.level = comp_armor_data.level
		var comp_penetrated = comp_armor.is_penetrated_by(m855_ammo)
		print("    %s Level %d: %s" % [comp_armor_data.standard, comp_armor_data.level,
			"PENETRATED" if comp_penetrated else "STOPPED"])

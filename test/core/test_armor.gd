@tool
class_name TestArmor extends EditorScript

var TEST_RESULTS = []

func _run():
	run_armor_tests()

func run_armor_tests():
	print("🔍 Loading ammo resources...")
	var ammo_list: Array[Ammo] = TestUtils.load_all_ammo()
	if ammo_list.is_empty():
		push_error("No ammo resources found!")
		return

	print("🛡️ Loading armor resources...")
	var armor_list: Array[Armor] = TestUtils.load_all_armors()
	if armor_list.is_empty():
		push_error("No armor resources found!")
		return

	print("🎯 Testing armor penetration logic...")
	_test_specific_failures(ammo_list, armor_list)
	_test_certified_threats(ammo_list, armor_list)
	#_test_energy_thresholds(armor_list)
	#_test_durability_failure(armor_list)
	#_test_detailed_penetration_analysis(ammo_list, armor_list)

	# Print results
	print("\n✅ TEST SUMMARY:")
	for result in TEST_RESULTS:
		print(result)
	print("\nDone.")

func _test_specific_failures(ammo_list, armor_list):
	print("\n🔧 DIAGNOSTIC TEST FOR FAILING CASES:")
	
	# Case 1: NIJ RF2 vs M855
	var nij_rf2 = armor_list.filter(func(a): return "NIJ_RF2" in a.name.replace(" ", "_"))[0]
	print(ammo_list.map(func(a): return a.name))
	var m855 = ammo_list.filter(func(a): return "M855" in a.name)[0]
	
	print("Case 1: NIJ RF2 vs M855")
	print("  Armor: %s (Level %d)" % [nij_rf2.name, nij_rf2.level])
	print("  Ammo: %s" % m855.name)
	print("  Ammo Energy: %.0fJ" % m855.get_energy())
	print("  Certified: %s" % nij_rf2.validate_certification(m855))
	print("  Penetrated: %s" % nij_rf2.is_penetrated_by(m855))
	
	# Case 2: GOST BR5 vs BZ API  
	var gost_br5 = armor_list.filter(func(a): return "GOST_BR5" in a.name.replace(" ", "_"))[0]
	var bz_api = ammo_list.filter(func(a): return "BZ_API" in a.name)[0]
	
	print("Case 2: GOST BR5 vs BZ API")
	print("  Armor: %s (Level %d)" % [gost_br5.name, gost_br5.level])
	print("  Ammo: %s" % bz_api.name)
	print("  Ammo Energy: %.0fJ" % bz_api.get_energy())
	print("  Certified: %s" % gost_br5.validate_certification(bz_api))
	print("  Penetrated: %s" % gost_br5.is_penetrated_by(bz_api))
	
	# Case 3: VPAM PM6 vs 9mm
	var vpam_pm6 = armor_list.filter(func(a): return "VPAM_PM6" in a.name.replace(" ", "_"))[0]
	var nine_mm = ammo_list.filter(func(a): return "9mm" in a.name and "VPAM_PM2" in a.name)[0]
	
	print("Case 3: VPAM PM6 vs 9mm")
	print("  Armor: %s (Level %d)" % [vpam_pm6.name, vpam_pm6.level])
	print("  Ammo: %s" % nine_mm.name)
	print("  Ammo Energy: %.0fJ" % nine_mm.get_energy())
	print("  Certified: %s" % vpam_pm6.validate_certification(nine_mm))
	print("  Penetrated: %s" % vpam_pm6.is_penetrated_by(nine_mm))

# ─── TEST 1: CERTIFIED THREATS MUST NOT PENETRATE ──

func _test_certified_threats(ammo_list, armor_list):
	# Test specific armor/ammo combinations
	for armor in armor_list:
		# Find matching ammo by standard reference
		var matching_ammo = ammo_list.filter(func(a): return armor.validate_certification(a))
		if matching_ammo.is_empty():
			TEST_RESULTS.append("⚠️ SKIP: No ammo for standard %s" % armor.name)
			continue

		var ammo = matching_ammo[0]
		
		# DEBUG: Print certification details
		print("Testing: %s vs %s" % [armor.name, ammo.caliber])
		var certified_threats = armor._get_certified_threats()
		for threat in certified_threats:
			print("  Certified threat: %s (Type: %d, Energy: %.0fJ)" % [threat.caliber, threat.type, threat.energy])
			print("  Ammo: %s (Type: %d, Energy: %.0fJ)" % [ammo.caliber, ammo.type, ammo.get_energy()])
			print("  Match: %s" % armor._matches_threat(ammo, threat))
		
		var penetrated = armor.is_penetrated_by(ammo)
		
		if penetrated:
			TEST_RESULTS.append("❌ FAIL: %s penetrated by certified %s" % [
				armor.description, ammo.caliber
			])
		else:
			TEST_RESULTS.append("✅ PASS: %s stops %s" % [
				armor.description, ammo.caliber
			])

# ─── TEST 2: ENERGY THRESHOLDS ─────────────────────

func _test_energy_thresholds(armor_list):
	# Test VPAM PM6 vs weaker threat (9mm)
	var armor = armor_list.filter(func(a): return "VPAM_PM6" in a.name.replace(" ", "_"))[0]
	
	if not armor:
		TEST_RESULTS.append("⚠️ SKIP: VPAM_PM6 armor not found")
		return

	# Create 9mm FMJ ammo (should be stopped)
	var nine_mm = Ammo.new(8.0, 360, Ammo.Type.FMJ)
	nine_mm.caliber = "9x19mm"
	
	if armor.is_penetrated_by(nine_mm):
		TEST_RESULTS.append("❌ FAIL: VPAM PM6 should stop 9mm FMJ")
	else:
		TEST_RESULTS.append("✅ PASS: VPAM PM6 stops 9mm FMJ")

	# Test VPAM PM6 vs stronger threat (7.62x39mm BZ API)
	var bz_api = Ammo.new(7.7, 740, Ammo.Type.API)
	bz_api.caliber = "7.62x39mm"
	
	if not armor.is_penetrated_by(bz_api):
		TEST_RESULTS.append("❌ FAIL: VPAM PM6 should NOT stop 7.62x39mm BZ API")
	else:
		TEST_RESULTS.append("✅ PASS: VPAM PM6 fails vs 7.62x39mm BZ API")

# ─── TEST 3: DURABILITY FAILURE ────────────────────

func _test_durability_failure(armor_list):
	var armor = armor_list.filter(func(a): return "VPAM_PM6" in a.name.replace(" ", "_"))[0]
	
	if not armor:
		TEST_RESULTS.append("⚠️ SKIP: VPAM_PM6 armor not found")
		return

	armor.current_durability = 0

	var ammo = Ammo.new(8.0, 720, Ammo.Type.STEEL_CORE)
	ammo.caliber = "7.62x39mm"

	if not armor.is_penetrated_by(ammo):
		TEST_RESULTS.append("❌ FAIL: Broken armor should always penetrate")
	else:
		TEST_RESULTS.append("✅ PASS: Broken armor penetrates")

# ─── TEST 4: DETAILED PENETRATION ANALYSIS ─────────

func _test_detailed_penetration_analysis(ammo_list, armor_list):
	print("\n🔍 Detailed Penetration Analysis:")
	
	# Test NIJ RF2 vs M855
	var armor = armor_list.filter(func(a): return "NIJ_RF2" in a.name.replace(" ", "_"))[0]
	var m855_ammo = ammo_list.filter(func(a): return "5.56x45mm M855" in a.caliber and "NIJ RF2" in a.standard_ref)[0]
	
	if not armor or not m855_ammo:
		print("⚠️ Required resources not found for detailed analysis")
		return
	
	# Debug information
	print("  Armor: %s (Level %d)" % [armor.name, armor.level])
	print("  Ammo: %s (%s)" % [m855_ammo.caliber, m855_ammo.standard_ref])
	print("  Mass: %.1fg" % m855_ammo.bullet_mass)
	print("  Velocity: %.0f m/s" % m855_ammo.muzzle_velocity)
	print("  Energy: %.0f J" % m855_ammo.get_energy())
	print("  Type: %s" % m855_ammo.type)
	
	var penetrated = armor.is_penetrated_by(m855_ammo)
	print("  Penetrated: %s" % penetrated)
	
	# Check certification
	var certified = armor.validate_certification(m855_ammo)
	print("  Certified to stop: %s" % certified)
	
	# Test with different armor standards
	print("\n  Comparing different armors vs M855:")
	var comparison_armors = [
		"NIJ_RF2",
		"VPAM_PM7", 
		"GOST_BR4",
		"ESAPI"
	]
	
	for armor_name in comparison_armors:
		var comp_armor = armor_list.filter(func(a): return armor_name in a.name.replace(" ", "_"))[0]
		if comp_armor:
			var comp_penetrated = comp_armor.is_penetrated_by(m855_ammo)
			var comp_certified = comp_armor.validate_certification(m855_ammo)
			print("    %s: %s (Certified: %s)" % [
				comp_armor.name,
				"PENETRATED" if comp_penetrated else "STOPPED",
				"YES" if comp_certified else "NO"
			])

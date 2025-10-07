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
	_test_certified_threats(ammo_list, armor_list)
	#_test_uncertified_threats(ammo_list, armor_list)
	_test_durability_failure(armor_list)
	_test_detailed_penetration_analysis(ammo_list, armor_list)

	# Print results
	print("\n✅ TEST SUMMARY:")
	for result in TEST_RESULTS:
		print(result)
	print("\nDone.")

# ─── TEST 1: CERTIFIED THREATS MUST NOT PENETRATE ──
func _test_certified_threats(ammo_list: Array[Ammo], armor_list: Array[Armor]):
	# Test specific armor/ammo combinations
	for armor in armor_list:
		# Find matching ammo by standard reference
		var matching_ammo = ammo_list.filter(func(a): return armor.validate_certification(a))
		if matching_ammo.is_empty():
			TEST_RESULTS.append("⚠️ SKIP: No ammo for standard %s" % armor.name)
			continue

		for ammo in matching_ammo:
			var penetrated = armor.is_penetrated_by(ammo)
			
			if penetrated:
				TEST_RESULTS.append("❌ FAIL: %s penetrated by certified %s" % [
					armor.name, ammo.caliber
				])
			else:
				TEST_RESULTS.append("✅ PASS: %s stops %s" % [
					armor.name, ammo.caliber
				])

# ─── TEST 2: ENERGY THRESHOLDS ─────────────────────
func _test_uncertified_threats(ammo_list, armor_list):
	# Test specific armor/ammo combinations
	ammo_list.sort_custom(func(a,b): return a.get_energy() < b.get_energy())
	for armor in armor_list:
		print("Armor %s" % armor.name)
		for ammo in ammo_list:
			var penetrated = armor.is_penetrated_by(ammo)
			if penetrated:
				print("    ❌ (%.2f J) %s penetrates" % [ammo.get_energy(), ammo.name])
			else:
				print("    ✅ (%.2f J) %s stopped" % [ammo.get_energy(), ammo.name])

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
	var armor: Armor = armor_list.filter(func(a): return "NIJ_RF2" in a.name.replace(" ", "_"))[0]
	var m855_ammo: Ammo = ammo_list.filter(func(a): return "5.56x45mm M855" in a.caliber)[0]
	
	if not armor or not m855_ammo:
		print("⚠️ Required resources not found for detailed analysis")
		return
	
	# Debug information
	print("  Armor: %s (Level %d)" % [armor.name, armor.level])
	print("  Ammo: %s (%s)" % [m855_ammo.caliber, m855_ammo.description])
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

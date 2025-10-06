@tool
extends EditorScript

const AMMO_PATH = "res://addons/cabra.lat_shooters/src/resources/ammo/"
var TEST_RESULTS = []

func _run():
	run_armor_tests()

func run_armor_tests():
	print("s🔍 Loading ammo resources...")
	var ammo_files = _get_ammo_files()
	var ammo_list = []
	for file in ammo_files:
		var path = AMMO_PATH + file
		if ResourceLoader.exists(path):
			var ammo: Ammo = ResourceLoader.load(path)
			ammo_list.append(ammo)
		else:
			push_warning("Missing file: %s" % path)

	print("🛡️ Testing armor penetration logic...")
	_test_certified_threats(ammo_list)
	_test_energy_thresholds()
	_test_durability_failure()

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

# ─── HELPER: GET AMMO FILES ────────────────────────

func _get_ammo_files():
	var files = []
	if DirAccess.dir_exists_absolute(AMMO_PATH):
		var dir = DirAccess.open(AMMO_PATH)
		dir.list_dir_begin()
		var file = dir.get_next()
		while file != "":
			if file.ends_with(".tres"):
				files.append(file)
			file = dir.get_next()
	return files

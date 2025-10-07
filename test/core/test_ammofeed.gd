# test_ammofeed.gd
@tool
class_name TestAmmoFeed extends EditorScript

var TEST_RESULTS = []

func _run():
	run_ammofeed_tests()

func run_ammofeed_tests():
	print("🔍 Loading ammo resources...")
	var ammo_list = TestUtils.load_all_ammo()
	if ammo_list.is_empty():
		push_error("No ammo resources found!")
		return

	print("🧪 Testing AmmoFeed compatibility...")
	_test_ak47_magazine(ammo_list)
	_test_m4_magazine(ammo_list)
	_test_mosin_internal(ammo_list)
	_test_ga141_compatibility(ammo_list)
	_test_physical_tolerance(ammo_list)
	_test_rimmed_incompatibility(ammo_list)
	_test_strict_mode(ammo_list)

	# Print results
	print("\n✅ AMMOFEED COMPATIBILITY TEST SUMMARY:")
	for result in TEST_RESULTS:
		print(result)
	print("\nDone.")

# ─── TEST 1: AK-47 MAGAZINE (7.62x39mm ONLY) ──────
# From KB: GA5 = 8.05g @ 725 m/s | VPAM PM6 = 8.0g @ 720 m/s → compatible
# But 7.62x51mm = 9.6g @ 847 m/s → case too long (51mm vs 39mm)

func _test_ak47_magazine(ammo_list):
	var mag = AmmoFeed.new()
	mag.type = AmmoFeed.Type.EXTERNAL
	mag.compatible_calibers = ["7.62x39mm"]

	var ga5 = _find_ammo(ammo_list, "7.62x39mm")          # GA141
	var ps = _find_ammo(ammo_list, "7.62x39mm PS")       # VPAM PM6
	var m80 = _find_ammo(ammo_list, "7.62x51mm M80")     # NIJ RF1
	
	if ga5 and mag.insert(ga5):
		TEST_RESULTS.append("✅ PASS: AK-47 mag accepts GA141 7.62x39mm")
	else:
		TEST_RESULTS.append("❌ FAIL: AK-47 mag rejects GA141 7.62x39mm")

	if ps and mag.insert(ps):
		TEST_RESULTS.append("✅ PASS: AK-47 mag accepts VPAM 7.62x39mm PS")
	else:
		TEST_RESULTS.append("❌ FAIL: AK-47 mag rejects VPAM 7.62x39mm PS")

	if m80 and not mag.insert(m80):
		TEST_RESULTS.append("✅ PASS: AK-47 mag rejects 7.62x51mm M80 (case too long)")
	else:
		TEST_RESULTS.append("❌ FAIL: AK-47 mag accepts 7.62x51mm M80")

# ─── TEST 2: M4 MAGAZINE (5.56x45mm NATO) ──────────
# From KB: RF2 = M193 (56gr @ 3250 ft/s) + M855 (62gr @ 3115 ft/s) → same base caliber

func _test_m4_magazine(ammo_list):
	var mag = AmmoFeed.new()
	mag.type = AmmoFeed.Type.EXTERNAL
	mag.compatible_calibers = ["5.56x45mm"]

	var m193 = _find_ammo(ammo_list, "5.56x45mm M193")   # NIJ RF1
	var m855 = _find_ammo(ammo_list, "5.56x45mm M855")   # NIJ RF2
	var ss109 = _find_ammo(ammo_list, "5.56x45mm SS109") # VPAM PM7

	if m193 and mag.insert(m193):
		TEST_RESULTS.append("✅ PASS: M4 mag accepts M193")
	else:
		TEST_RESULTS.append("❌ FAIL: M4 mag rejects M193")

	if m855 and mag.insert(m855):
		TEST_RESULTS.append("✅ PASS: M4 mag accepts M855")
	else:
		TEST_RESULTS.append("❌ FAIL: M4 mag rejects M855")

	if ss109 and mag.insert(ss109):
		TEST_RESULTS.append("✅ PASS: M4 mag accepts SS109")
	else:
		TEST_RESULTS.append("❌ FAIL: M4 mag rejects SS109")

# ─── TEST 3: MOSIN INTERNAL (7.62x54mmR ONLY) ──────
# From KB: GOST BR6 = 7.62x54mmR B32 API → must match exactly

func _test_mosin_internal(ammo_list):
	var feed = AmmoFeed.new()
	feed.type = AmmoFeed.Type.INTERNAL
	feed.compatible_calibers = ["7.62x54mmR"]

	var b32_api = _find_ammo(ammo_list, "7.62x54mmR B32 API") # GOST BR6
	var m80 = _find_ammo(ammo_list, "7.62x51mm M80")         # NIJ RF1

	if b32_api and feed.insert(b32_api):
		TEST_RESULTS.append("✅ PASS: Mosin accepts 7.62x54mmR B32 API")
	else:
		TEST_RESULTS.append("❌ FAIL: Mosin rejects 7.62x54mmR B32 API")

	if m80 and not feed.insert(m80):
		TEST_RESULTS.append("✅ PASS: Mosin rejects 7.62x51mm M80 (different caliber)")
	else:
		TEST_RESULTS.append("❌ FAIL: Mosin accepts 7.62x51mm M80")

# ─── TEST 4: GA141 FEED COMPATIBILITY ──────────────
# GA5 (7.62x39mm Type 56) should accept VPAM PM6 (7.62x39mm PS)

func _test_ga141_compatibility(ammo_list):
	var ga5_feed = AmmoFeed.new()
	ga5_feed.type = AmmoFeed.Type.EXTERNAL
	ga5_feed.compatible_calibers = ["7.62x39mm"]

	var type56 = _find_ammo(ammo_list, "7.62x39mm")      # GA141
	var ps = _find_ammo(ammo_list, "7.62x39mm PS")       # VPAM PM6

	if type56 and ga5_feed.insert(type56):
		TEST_RESULTS.append("✅ PASS: GA5 feed accepts GA141 7.62x39mm")
	else:
		TEST_RESULTS.append("❌ FAIL: GA5 feed rejects GA141 7.62x39mm")

	if ps and ga5_feed.insert(ps):
		TEST_RESULTS.append("✅ PASS: GA5 feed accepts VPAM 7.62x39mm PS")
	else:
		TEST_RESULTS.append("❌ FAIL: GA5 feed rejects VPAM 7.62x39mm PS")

# ─── TEST 5: PHYSICAL TOLERANCE (M193 in M855 mag) ─
# Same base caliber → should work

func _test_physical_tolerance(ammo_list):
	var mag = AmmoFeed.new()
	mag.type = AmmoFeed.Type.EXTERNAL
	mag.compatible_calibers = ["5.56x45mm M855"]

	var m193 = _find_ammo(ammo_list, "5.56x45mm M193")

	if m193 and mag.insert(m193):
		TEST_RESULTS.append("✅ PASS: M855 mag accepts M193 (physical compatibility)")
	else:
		TEST_RESULTS.append("❌ FAIL: M855 mag rejects M193")

# ─── TEST 6: RIMMED VS RIMLESS ─────────────────────
# 7.62x54mmR (rimmed) ≠ 7.62x51mm (rimless) → never compatible

func _test_rimmed_incompatibility(ammo_list):
	var mag = AmmoFeed.new()
	mag.type = AmmoFeed.Type.EXTERNAL
	mag.compatible_calibers = ["7.62x51mm"]

	var b32_api = _find_ammo(ammo_list, "7.62x54mmR B32 API") # Rimmed

	if not mag.insert(b32_api):
		TEST_RESULTS.append("✅ PASS: Rejects rimmed 7.62x54mmR in rimless 7.62x51mm mag")
	else:
		TEST_RESULTS.append("❌ FAIL: Accepts rimmed in rimless mag")

# ─── TEST 7: STRICT MODE ───────────────────────────

func _test_strict_mode(ammo_list):
	var mag = AmmoFeed.new()
	mag.type = AmmoFeed.Type.EXTERNAL
	mag.compatible_calibers = ["5.56x45mm M855"]
	mag.strict_mode = true

	var m193 = _find_ammo(ammo_list, "5.56x45mm M193")

	if not mag.insert(m193):
		TEST_RESULTS.append("✅ PASS: Strict mode rejects M193 in M855-only mag")
	else:
		TEST_RESULTS.append("❌ FAIL: Strict mode accepts M193")

# ─── HELPER: FIND AMMO BY NAME ─────────────────────

func _find_ammo(ammo_list: Array, name_part: String) -> Ammo:
	for ammo in ammo_list:
		if name_part in ammo.caliber:
			return ammo
	return null

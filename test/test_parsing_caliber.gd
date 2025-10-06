# test_caliber_parsing.gd
@tool
class_name TestUtilsParsingCaliber extends EditorScript

func _run():
	print("🧪 Testing Caliber Parsing Utility...")
	
	_test_x_format_calibers()
	_test_30_06_format()
	_test_pistol_calibers()
	_test_edge_cases()
	_test_rimmed_detection()
	_test_invalid_inputs()
	
	print("\n✅ CALIBER PARSING TEST COMPLETE")

# ─── TEST SUITES ───────────────────────────────────

func _test_x_format_calibers():
	print("\n📐 Testing x-format calibers:")
	
	# Standard rifle calibers
	_assert_caliber("7.62x51mm", 7.62, 51.0, false, "7.62x51mm standard")
	_assert_caliber("5.56x45mm", 5.56, 45.0, false, "5.56x45mm NATO")
	_assert_caliber("9x19mm", 9.0, 19.0, false, "9x19mm Parabellum")
	_assert_caliber("12.7x99mm", 12.7, 99.0, false, "12.7x99mm BMG")
	
	# Rimmed variants
	_assert_caliber("7.62x54mmR", 7.62, 54.0, true, "7.62x54mmR rimmed")
	_assert_caliber("5.45x39mm", 5.45, 39.0, false, "5.45x39mm Soviet")
	
	# With additional text
	_assert_caliber("7.62x51mm M80", 7.62, 51.0, false, "7.62x51mm with designation")
	_assert_caliber("5.56x45mm M855 AP", 5.56, 45.0, false, "5.56x45mm with full designation")

func _test_30_06_format():
	print("\n🎯 Testing .30-06 format:")
	
	# .30-06 Springfield has a case length of 63mm
	_assert_caliber(".30-06", 7.62, 63.0, false, ".30-06 basic")
	_assert_caliber(".30-06 M2 AP", 7.62, 63.0, false, ".30-06 with designation")
	_assert_caliber("30-06", 7.62, 63.0, false, "30-06 without dot")

func _test_pistol_calibers():
	print("\n🔫 Testing pistol calibers:")
	
	# These should match the exact strings in your common_calibers dictionary
	_assert_caliber(".45 ACP", 11.43, 22.8, false, ".45 ACP")
	_assert_caliber(".40 S&W", 10.16, 21.6, false, ".40 S&W")
	_assert_caliber(".22 LR", 5.56, 15.6, true, ".22 LR rimmed")
	_assert_caliber(".44 Magnum", 10.9, 32.6, true, ".44 Magnum rimmed")
	_assert_caliber(".357 Magnum", 9.07, 33.0, true, ".357 Magnum")
	_assert_caliber(".380 ACP", 9.65, 17.3, false, ".380 ACP")
	_assert_caliber("9mm", 9.0, 19.0, false, "9mm shorthand")

func _test_edge_cases():
	print("\n⚠️ Testing edge cases:")
	
	# FSP/gr designations (should return zeros)
	_assert_caliber("64gr FSP", 0.0, 0.0, false, "FSP designation")
	_assert_caliber("4gr FSP", 0.0, 0.0, false, "small FSP")
	_assert_caliber("16gr FSP", 0.0, 0.0, false, "medium FSP")
	_assert_caliber("2gr FSP", 0.0, 0.0, false, "tiny FSP")
	
	# Mixed case and punctuation
	_assert_caliber("7.62X51MM", 7.62, 51.0, false, "uppercase X")
	_assert_caliber("9x19mm 7N21", 9.0, 19.0, false, "with Russian designation")
	_assert_caliber("9x18mm Makarov", 9.0, 18.0, false, "Makarov caliber")
	_assert_caliber("9x21mm Gyurza", 9.0, 21.0, false, "Gyurza caliber")

func _test_rimmed_detection():
	print("\n🎯 Testing rimmed detection:")
	
	# Explicit rimmed
	_assert_caliber("7.62x54mmR", 7.62, 54.0, true, "explicit R suffix")
	_assert_caliber("7.62x54mmr", 7.62, 54.0, true, "lowercase r suffix")
	
	# Implicit rimmed from common calibers
	_assert_caliber(".22 LR", 5.56, 15.6, true, ".22 LR implicit rimmed")
	_assert_caliber(".44 Magnum", 10.9, 32.6, true, ".44 Magnum implicit rimmed")
	
	# Rimless
	_assert_caliber("7.62x51mm", 7.62, 51.0, false, "rimless rifle")
	_assert_caliber("9x19mm", 9.0, 19.0, false, "rimless pistol")

func _test_invalid_inputs():
	print("\n❌ Testing invalid inputs:")
	
	_assert_caliber("", 0.0, 0.0, false, "empty string")
	_assert_caliber("invalid", 0.0, 0.0, false, "gibberish")
	_assert_caliber("123", 0.0, 0.0, false, "just numbers")
	_assert_caliber("x", 0.0, 0.0, false, "just x")
	_assert_caliber("mm", 0.0, 0.0, false, "just mm")

# ─── ASSERTION HELPER ──────────────────────────────

func _assert_caliber(input: String, expected_bore: float, expected_case: float, expected_rimmed: bool, test_name: String):
	var result = Utils.parse_caliber(input)
	
	var bore_ok = abs(result.bore_mm - expected_bore) < 0.01
	var case_ok = abs(result.case_mm - expected_case) < 0.01
	var rimmed_ok = result.rimmed == expected_rimmed
	
	if bore_ok and case_ok and rimmed_ok:
		print("  ✅ PASS: %s → %.2fx%.1fmm %s" % [test_name, result.bore_mm, result.case_mm, "(rimmed)" if result.rimmed else ""])
	else:
		print("  ❌ FAIL: %s" % test_name)
		print("     Input: '%s'" % input)
		print("     Expected: bore=%.2f case=%.1f rimmed=%s" % [expected_bore, expected_case, expected_rimmed])
		print("     Got: bore=%.2f case=%.1f rimmed=%s" % [result.bore_mm, result.case_mm, result.rimmed])

# res://test/core/ballistics/ballistics_impact.gd
@tool
class_name TestBallisticsImpact extends EditorScript

func _run():
	print("🧪 Testing BallisticsImpact...")

	var impact = BallisticsImpact.new()
	impact.penetration_depth = 15.0
	impact.thickness = 10.0
	check(impact.penetrated, "Should be penetrated")

	impact.fragments = 3
	check(impact.fragmented, "Should be fragmented")

	print("✅ BallisticsImpact tests passed!")

func check(condition: bool, message: String):
	if not condition:
		push_error("❌ FAIL: " + message)
	else:
		print("  ✅ PASS: " + message)

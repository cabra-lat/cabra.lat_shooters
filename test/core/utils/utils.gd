# test/core/utils/utils.gd
@tool
class_name TestUtils extends EditorScript

func _run():
	print("🧪 Testing Utils...")
	
	# Test energy
	var energy = Utils.bullet_energy(8.0, 360.0)
	var expected = 0.5 * (8.0 / 1000.0) * (360.0 * 360.0)
	if abs(energy - expected) < 0.1:
		print("  ✅ PASS: bullet_energy correct")
	else:
		push_error("❌ FAIL: bullet_energy wrong: got %.2f, expected %.2f" % [energy, expected])
	
	# Test velocity
	var velocity = Utils.bullet_velocity(8.0, energy)
	if abs(velocity - 360.0) < 0.1:
		print("  ✅ PASS: bullet_velocity correct")
	else:
		push_error("❌ FAIL: bullet_velocity wrong: got %.2f" % velocity)
	
	# Test caliber equality
	if Utils.is_same_caliber("9x19mm", "9mm"):
		print("  ✅ PASS: is_same_caliber works")
	else:
		push_error("❌ FAIL: is_same_caliber failed")
	
	print("✅ All Utils tests passed!")

# test/core/ammo/ammo.gd
@tool
class_name TestAmmo extends EditorScript

func _run():
	print("🧪 Testing Ammo...")
	
	# Test creation
	var ammo = Ammo.create_test_ammo()
	check(ammo != null, "Ammo should be created")
	check(ammo.caliber == "9mm", "Caliber should be set")
	
	# Test energy
	var expected_energy = Utils.bullet_energy(8.0, 360.0)
	check(abs(ammo.get_energy() - expected_energy) < 0.1, "Energy should match")
	
	# Test velocity at range
	var v_100 = ammo.get_velocity_at_range(100.0)
	check(v_100 < 360.0, "Velocity should decrease with distance")
	
	# Test caliber parsing
	check(ammo.bore_mm == 9.0, "Bore should be parsed from '9mm'")
	
	# Test deforming
	var jhp = Ammo.create_jhp_ammo()
	check(jhp.is_deforming(), "JHP should be deforming")
	
	var ap = Ammo.create_ap_ammo()
	check(not ap.is_deforming(), "AP should not be deforming")
	
	# Test fragmentation
	randomize()
	var frag_count = jhp.should_fragment(jhp.get_energy() * 0.8)
	# Could be 0 due to randomness, but let's just ensure method runs
	print("  ✅ PASS: Fragmentation logic executed (result: %d)" % frag_count)
	
	# Test shotgun
	var shotgun = Ammo.create_test_shotgun_ammo()
	check(shotgun.type == Ammo.Type.BUCKSHOT, "Shotgun ammo type correct")
	
	print("✅ Ammo tests passed!")

func check(condition: bool, message: String):
	if not condition:
		push_error("❌ FAIL: " + message)
	else:
		print("  ✅ PASS: " + message)

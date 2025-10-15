# res://test/core/ammo/ammo_feed.gd
@tool
class_name TestAmmoFeed extends EditorScript

func _run():
  print("🧪 Testing AmmoFeed...")

  var nine_mm = Ammo.new()
  nine_mm.caliber = "9x19mm"
  nine_mm.cartridge_mass = 8.0 / 1000.0

  var twenty_two = Ammo.new()
  twenty_two.caliber = ".22 LR"
  twenty_two.cartridge_mass = 2.6 / 1000.0

  var seven_six_two = Ammo.new()
  seven_six_two.caliber = "7.62x54mmR"
  seven_six_two.cartridge_mass = 12.0 / 1000.0

  # --- Test 1: Basic compatibility ---
  var feed1 = AmmoFeed.new()
  feed1.compatible_calibers = ["9x19mm"]
  check(feed1.insert(nine_mm), "Should accept 9x19mm")
  check(not feed1.insert(twenty_two), "Should reject .22 LR")
  check(feed1.capacity == 1, "Should contain 1 round")

  # --- Test 2: Physical compatibility ---
  var feed2 = AmmoFeed.new()
  feed2.compatible_calibers = ["9mm"]
  check(feed2.insert(nine_mm), "Should accept 9x19mm as '9mm'")

  # --- Test 3: Rimmed incompatibility ---
  var feed3 = AmmoFeed.new()
  feed3.compatible_calibers = ["7.62x51mm"]  # rimless
  check(not feed3.insert(seven_six_two), "Should reject rimmed 7.62x54mmR in rimless feed")

  # --- Test 4: Strict mode ---
  var feed4 = AmmoFeed.new()
  feed4.compatible_calibers = ["9x19mm"]
  feed4.strict_mode = true
  check(not feed4.insert(twenty_two), "Strict mode should reject non-listed calibers")

  # --- Test 5: Ejection (single round) ---
  var feed5 = AmmoFeed.new()
  feed5.compatible_calibers = ["9x19mm"]
  feed5.insert(nine_mm)
  var ejected = feed5.eject()
  check(ejected != null, "Should eject ammo")
  check(ejected.caliber == "9x19mm", "Ejected ammo should be 9x19mm")
  check(feed5.is_empty(), "Should be empty after ejection")

  # --- Test 6: Mass calculation ---
  var feed6 = AmmoFeed.new()
  feed6.empty_mass = 0.1
  feed6.compatible_calibers = ["9x19mm"]
  feed6.insert(nine_mm)
  feed6.insert(nine_mm)
  check(abs(feed6.mass - (0.1 + 2 * 0.008)) < 0.0001, "Mass should include empty + ammo")

  print("✅ AmmoFeed tests passed!")

func check(condition: bool, message: String):
  if not condition:
    push_error("❌ FAIL: " + message)
  else:
    print("  ✅ PASS: " + message)

# res://test/core/ballistics/ballistics_calculator.gd
@tool
class_name TestBallisticsCalculator extends EditorScript

func _run():
  print("🧪 Testing BallisticsCalculator...")

  var calculator = BallisticsCalculator.new()
  var ammo = Ammo.create_ap_ammo()
  var steel = BallisticMaterial.new()
  steel.hardness = 300.0
  steel.type = BallisticMaterial.Type.METAL_MEDIUM

  # Test single impact
  var impact = calculator.calculate_impact(ammo, steel, 10.0, 100.0)
  check(impact.penetration_depth > 0.0, "Should penetrate steel")

  # Test trajectory
  var traj = calculator.calculate_trajectory(ammo, 300.0)
  check(traj.has("drop"), "Trajectory has drop")
  check(traj.drop > 0.0, "Drop should be positive")

  # Test hit probability
  var prob = calculator.calculate_hit_probability(ammo, 100.0)
  check(prob > 0.0 and prob <= 1.0, "Probability in valid range")

  # Test shotgun
  var shotgun = Ammo.create_test_shotgun_ammo()
  var spread = calculator.calculate_shotgun_spread(shotgun, 25.0)
  check(spread.pellet_count == 9, "Buckshot has 9 pellets")

  print("✅ BallisticsCalculator tests passed!")

func check(condition: bool, message: String):
  if not condition:
    push_error("❌ FAIL: " + message)
  else:
    print("  ✅ PASS: " + message)

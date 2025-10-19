# test/core/health/body_part.gd
@tool
class_name TestBodyPart extends EditorScript

func _run():
  print("🧪 Testing BodyPart...")

  var part = BodyPart.new(BodyPart.Type.LEFT_UPPER_ARM, 35.0, 0.07)
  check(part.max_health == 35.0, "Max health set")
  check(part.current_health == 35.0, "Starts at full health")

  # Test damage
  var damage = part.take_damage(10.0)
  check(damage == 10.0, "Took 10 damage")
  check(part.current_health == 25.0, "Health reduced")

  # Test destruction
  part.take_damage(25.0)
  check(part.is_destroyed, "Destroyed when health = 0")

  # Test limb/joint detection
  check(part.is_limb(), "Upper arm is limb")
  check(not part.is_joint(), "Upper arm is not joint")

  # Test functionality multiplier
  check(part.functionality_multiplier < 1.0, "Destroyed limb reduces function")

  print("✅ BodyPart tests passed!")

func check(condition: bool, message: String):
  if not condition:
    push_error("❌ FAIL: " + message)
  else:
    print("  ✅ PASS: " + message)

# res://test/core/armor/armor.gd
@tool
class_name TestArmor extends EditorScript

func _run():
  print("🧪 Testing Armor...")

  # Create armor
  var vest = Armor.new()
  vest.name = "NIJ RF2 Vest"
  vest.standard = Certification.Standard.NIJ
  vest.level = 8  # RF2
  vest.protection_zones = Armor.BodyParts.THORAX | Armor.BodyParts.ABDOMEN

  # Test body part coverage
  check(vest.covers_body_part(BodyPart.Type.UPPER_CHEST), "Covers upper chest")
  check(not vest.covers_body_part(BodyPart.Type.HEAD), "Does not cover head")

  # Test certification
  var m855 = Ammo.create_test_ammo()
  m855.caliber = "5.56x45mm"
  m855.type = Ammo.Type.GREEN_TIP
  m855.bullet_mass = 4.0
  m855.muzzle_velocity = 950.0
  check(vest.validate_certification(m855), "RF2 certifies M855")

  # Test penetration
  var penetrated = vest.is_penetrated_by(m855)
  check(not penetrated, "Should stop M855")

  # Test broken armor
  vest.current_durability = 0
  penetrated = vest.is_penetrated_by(m855)
  check(penetrated, "Broken armor should be penetrated")

  print("✅ Armor tests passed!")

func check(condition: bool, message: String):
  if not condition:
    push_error("❌ FAIL: " + message)
  else:
    print("  ✅ PASS: " + message)

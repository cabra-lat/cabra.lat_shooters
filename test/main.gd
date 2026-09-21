@tool
class_name Test extends EditorScript

func _run():
  print('\n'.repeat(100))
  print("🧪 BEGIN TEST: %s" % Time.get_datetime_string_from_system())
  for test in [
    TestUtilsCaliberParser,
    TestAmmoFeed,
    TestAmmo,
    TestWeapon,
    TestAttachment,
    TestArmor,
    TestBallisticMaterial,
    TestBodyPart,
    TestWound,
    TestHealth,
    TestBallisticsCalculator,
    TestBallisticsImpact,
    TestBallisticsResidual,
    TestWeaponSystem,
    TestInventoryContainer,
    TestInventoryGrid,
    TestInventoryItem,
    TestPlayerBody,
    TestInventorySystem
  ]:
    test.new()._run()
  print("🧪 TEST ENDED: %s" % Time.get_datetime_string_from_system())

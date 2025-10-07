@tool
class_name Test extends EditorScript

func _run():
	print('\n'.repeat(100))
	print("🧪 BEGIN TEST: %s" % Time.get_datetime_string_from_system())
	TestUtilsParsingCaliber.new()._run()
	TestAmmoBallistics.new()._run()
	TestAmmoFeed.new()._run()
	TestArmor.new()._run()
	TestWeapons.new()._run()
	TestWeaponAttachments.new()._run()
	TestBallisticsCalculator.new()._run()
	TestHealth.new()._run()
	print("🧪 TEST ENDED: %s" % Time.get_datetime_string_from_system())

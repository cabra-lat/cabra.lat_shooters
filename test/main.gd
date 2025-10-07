@tool
class_name Test extends EditorScript

func _run():
	TestUtilsParsingCaliber.new()._run()
	TestAmmoFeed.new()._run()
	TestArmor.new()._run()
	TestWeapons.new()._run()
	TestWeaponAttachments.new()._run()
	TestAmmoBallistics.new()._run()
	TestBallisticsCalculator.new()._run()

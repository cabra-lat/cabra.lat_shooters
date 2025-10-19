# test/core/armor/ballistic_material.gd
@tool
class_name TestBallisticMaterial extends EditorScript

func _run():
  print("🧪 Testing BallisticMaterial...")

  # Test default flesh
  var flesh = BallisticMaterial.create_default_flesh_material()
  check(flesh.type == BallisticMaterial.Type.FLESH_SOFT, "Flesh type correct")
  check(flesh.hardness == 0.5, "Flesh hardness correct")

  # Test armor from certification
  var nijs = BallisticMaterial.create_for_armor_certification(Certification.Standard.NIJ, 3)
  check(nijs.name.begins_with("Hard Armor"), "NIJ Level 3 is hard armor")

  # Test penetration calculation
  var steel = BallisticMaterial.new()
  steel.hardness = 300.0
  steel.type = BallisticMaterial.Type.METAL_MEDIUM
  var ammo = Ammo.create_ap_ammo()
  var pen = steel.calculate_penetration(ammo, ammo.get_energy(), 0.0)
  check(pen > 0.0, "AP ammo should penetrate steel")

  print("✅ BallisticMaterial tests passed!")

func check(condition: bool, message: String):
  if not condition:
    push_error("❌ FAIL: " + message)
  else:
    print("  ✅ PASS: " + message)

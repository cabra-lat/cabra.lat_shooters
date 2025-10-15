# res://test/core/health/wound.gd
@tool
class_name TestWound extends EditorScript

func _run():
  print("🧪 Testing Wound...")

  var ammo = Ammo.create_jhp_ammo()
  var impact = BallisticsImpact.new()
  impact.hit_energy = 900.0
  impact.penetration_depth = Utils.to_mm(10.0) # mm
  impact.thickness = 50.0

  var part = BodyPart.new(BodyPart.Type.ABDOMEN, 50.0)

  var wound = Wound.create_ballistic_wound(ammo, impact, part)
  check(wound != null, "Wound created")

  check(wound.type == Wound.Type.SHRAPNEL, "High-energy JHP creates shrapnel wound")
  check(wound.severity == Wound.Severity.SEVERE, "High energy → severe")

  print("✅ Wound tests passed!")

func check(condition: bool, message: String):
  if not condition:
    push_error("❌ FAIL: " + message)
  else:
    print("  ✅ PASS: " + message)

# res://test/core/ballistics/residual.gd
@tool
class_name TestBallisticsResidual extends EditorScript

func _run():
  print("🧪 Testing Recht-Ipson residual + penetration capability...")

  # AP rifle round vs 10mm steel plate: overmatch -> perforation with residual.
  var ammo = Ammo.create_ap_ammo()
  var steel = BallisticMaterial.new()
  steel.hardness = 300.0
  steel.type = BallisticMaterial.Type.METAL_MEDIUM
  var e_hit = ammo.get_energy()
  var e_bl = steel.stopping_energy(ammo, 10.0)
  check(e_bl > 0.0 and e_bl < e_hit, "AP overmatches 10mm steel (Ebl < Ehit)")
  var e_exit = BallisticsCalculator.residual_energy(e_hit, e_bl)
  check(e_exit > 0.0 and e_exit < e_hit, "Residual energy between 0 and hit energy")
  check(BallisticsCalculator.residual_energy(e_bl * 0.5, e_bl) == 0.0, "No residual below ballistic limit")

  # Full calculator path: perforation flag + sane residual.
  var impact = BallisticsCalculator.calculate_impact(ammo, steel, 10.0, 100.0)
  check(impact.penetrated, "Calculator reports perforation")
  check(impact.exit_energy > 0.0 and impact.exit_energy < impact.hit_energy, "Calculator residual sane")

  # Obliquity hardens the target (LOS thickness).
  var los = BallisticsCalculator.los_thickness(10.0, 60.0)
  check(abs(los - 20.0) < 0.01, "60° obliquity doubles LOS thickness")

  # Tissue sanity: 9mm FMJ should stop inside ~0.2-1.5m of gelatin.
  # (Heavy slow ball out-penetrates light stable AP here — matches real gel tests.)
  var fmj = Ammo.create_9mm_ammo()
  var flesh = BallisticMaterial.create_default_flesh_material()
  var p = flesh.penetration_capability(fmj, fmj.get_energy())
  check(p > 200.0 and p < 1500.0, "9mm gelatin penetration plausible, got %.0fmm" % p)
  var ap_gel = flesh.penetration_capability(ammo, ammo.get_energy())
  check(ap_gel > 200.0 and ap_gel < 1500.0, "M995 gelatin penetration plausible, got %.0fmm" % ap_gel)

  # Armor fall-through: rifle AP overmatches a pistol-rated vest (with live impact).
  var vest = Armor.new()
  vest.standard = Certification.Standard.NIJ
  vest.level = 2
  var hot = BallisticsImpact.new()
  hot.hit_energy = ammo.get_energy()
  var res = vest.check_penetration(ammo, hot)
  check(res.penetrated, "Rifle AP perforates NIJ-2 vest when overmatching")

  # Deterministic ricochet rolls for tests.
  var plate = BallisticMaterial.new()
  check(not plate.should_ricochet(ammo, 0.0, 0.99), "High roll never ricochets")
  ammo.ricochet_chance = 1.0
  plate.ricochet_chance_modifier = 1.0
  check(plate.should_ricochet(ammo, 0.0, 0.0), "Zero roll always ricochets")

  print("✅ BallisticsResidual tests passed!")

func check(condition: bool, message: String):
  if not condition:
    push_error("❌ FAIL: " + message)
  else:
    print("  ✅ PASS: " + message)

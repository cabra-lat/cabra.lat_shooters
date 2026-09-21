# res://addons/cabra.lat_shooters/test/validate_ballistics.gd
#
# FORMAL headless math harness for the Fase 1 munitions/armour model.
# Proves the numeric behaviours, not just asset loading. CI gate.
#
# Run:
#   godot --headless --path . --script res://addons/cabra.lat_shooters/test/validate_ballistics.gd
#
# Exit code: 0 = all checks pass, 1 = at least one failure.
extends SceneTree

var _pass := 0
var _fail := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
		print("  PASS  " + msg)
	else:
		_fail += 1
		print("  FAIL  " + msg)

func _approx(a: float, b: float, eps: float = 0.001) -> bool:
	return absf(a - b) <= eps

func _mat(mc: int, destr: float, hardness: float = 300.0, thickness: float = 1.0,
		t: int = BallisticMaterial.Type.ARMOR_HARD) -> BallisticMaterial:
	var m := BallisticMaterial.new()
	m.set_material_class(mc)
	m.destructibility = destr
	m.hardness = hardness
	m.thickness = thickness
	m.type = t
	return m

func _impact(energy: float, count: int = 1) -> BallisticsImpact:
	var i := BallisticsImpact.new()
	i.hit_energy = energy
	i.projectile_count = count
	i.thickness = 1000.0
	return i

func _armor(std: int, lvl: int, dur: int = 1000) -> Armor:
	var a := Armor.new()
	a.standard = std
	a.level = lvl
	a.protection_zones = Armor.BodyParts.THORAX
	a.max_durability = dur
	a.current_durability = dur
	return a

func _initialize() -> void:
	print("=== validate_ballistics ===")
	var m855 := load("res://resources/ammo/5_56_45mm_M855_NIJ_RF2.tres") as Ammo
	_check(m855 != null, "M855 file loads")

	_test_multi_projectile(m855)
	_test_durability_min_and_pen_vs_stop(m855)
	_test_layered_plate(m855)
	_test_cert_gate()
	_test_cert_extremes()
	_test_repair_curve()
	_test_bleed()
	_test_effectiveness(m855)
	_test_shotgun_data()

	print("")
	print("checks: %d pass, %d fail" % [_pass, _fail])
	print("RESULT: " + ("PASS" if _fail == 0 else "FAIL"))
	quit(1 if _fail > 0 else 0)

# 1. N pellets => N damage applications and N durability hits (min 1 each).
func _test_multi_projectile(m855: Ammo) -> void:
	print("-- multi-projectile")
	var h1 := Health.new()
	var d1: float = h1.take_ballistic_damage(_impact(2.0, 1), BodyPart.Type.UPPER_CHEST, null)["damage_taken"]
	var h8 := Health.new()
	var res8: Dictionary = h8.take_ballistic_damage(_impact(2.0, 8), BodyPart.Type.UPPER_CHEST, null)
	_check(res8["projectiles"] == 8, "impact reports 8 projectiles")
	_check(_approx(res8["damage_taken"], d1 * 8.0, 0.01),
		"8 pellets apply 8x damage (1=%.2f, 8=%.2f)" % [d1, res8["damage_taken"]])

	# Durability: RF2 certifies M855, so each pellet is stopped and wears >=1.
	var armor := _armor(Certification.Standard.NIJ, 8, 1000)
	var h := Health.new()
	h.equip_armor(armor)
	_check(h.body_parts[BodyPart.Type.UPPER_CHEST].equipped_armor == armor, "armor equipped on chest")
	var before := armor.current_durability
	h.take_ballistic_damage(_impact(1.0, 8), BodyPart.Type.UPPER_CHEST, m855)
	var wear := before - armor.current_durability
	_check(wear >= 8, "8 pellets => >= 8 durability damage (got %.2f)" % wear)
	# Per-pellet, not aggregated: 8 pellets wear exactly 8x a single pellet.
	var armor1 := _armor(Certification.Standard.NIJ, 8, 1000)
	var h1b := Health.new()
	h1b.equip_armor(armor1)
	h1b.take_ballistic_damage(_impact(1.0, 1), BodyPart.Type.UPPER_CHEST, m855)
	var wear1 := 1000 - armor1.current_durability
	_check(_approx(float(wear), float(wear1) * 8.0, 0.01), "wear per-pellet not aggregated (1=%.1f, 8=%.1f)" % [wear1, wear])

# 2. Penetrating hit causes less durability damage than a stopped hit.
func _test_durability_min_and_pen_vs_stop(m855: Ammo) -> void:
	print("-- durability min / pen-vs-stop")
	var stopped: float = Armor.durability_damage(100.0, m855, 4, 0.6, false)
	var penetrated: float = Armor.durability_damage(100.0, m855, 4, 0.6, true)
	_check(stopped > penetrated, "stopped wear (%.2f) > penetrating wear (%.2f)" % [stopped, penetrated])
	_check(_approx(penetrated / stopped, 0.875, 0.001), "penetrating wear is 12.5%% less (ratio %.3f)" % (penetrated / stopped))
	var tiny: float = Armor.durability_damage(1.0, m855, 1, 0.05, true)
	_check(_approx(tiny, 1.0), "durability damage floor is 1 per hit (got %.3f)" % tiny)

# 3. Class-4 plate over class-2 base stops what the base alone cannot.
func _test_layered_plate(m855: Ammo) -> void:
	print("-- layered plates")
	var imp := _impact(m855.get_energy())
	var base := _armor(Certification.Standard.NIJ, 2, 200)
	var r_base: Dictionary = base.resolve_projectile(m855, imp)
	_check(r_base["penetrated"], "NIJ-2 base cannot stop M855 (layer=%s)" % r_base["layer"])

	var base2 := _armor(Certification.Standard.NIJ, 2, 200)
	var plate := BallisticPlate.new()
	plate.standard = Certification.Standard.MILITARY
	plate.level = 1
	plate.max_durability = 60
	plate.current_durability = 60
	plate.material = _mat(BallisticMaterial.MaterialClass.CERAMIC, 0.6)
	base2.front_plate = plate
	var r_plate: Dictionary = base2.resolve_projectile(m855, imp)
	_check(r_plate["stopped"], "class-4 plate over class-2 base stops M855 (layer=%s)" % r_plate["layer"])
	_check(r_plate["layer"] == "plate", "outer plate absorbs the hit")
	_check(plate.current_durability < 60, "plate takes wear (%.0f/60)" % plate.current_durability)

# 3b. Cert-decides is preserved through the Health-facing resolver path.
func _test_cert_gate() -> void:
	print("-- cert energy gate (cert decides)")
	var m193 := load("res://resources/ammo/5_56_45mm_M193_NIJ_RF1.tres") as Ammo
	_check(m193 != null, "M193 file loads")
	if m193 == null:
		return
	var rf1 := _armor(Certification.Standard.NIJ, 7, 200)
	var r: Dictionary = rf1.resolve_projectile(m193, _impact(m193.get_energy()))
	_check(r["stopped"], "NIJ RF1 stops M193 through resolve_projectile (layer=%s)" % r["layer"])

# 3c. Every standard/level extreme yields a COHERENT material (never 0 J).
func _test_cert_extremes() -> void:
	print("-- cert level extremes")
	var max_level := {
		Certification.Standard.NIJ: 9,
		Certification.Standard.GOST: 6,
		Certification.Standard.VPAM: 14,
		Certification.Standard.GA141: 6,
		Certification.Standard.MILITARY: 2,
	}
	var all_positive := true
	for std in max_level.keys():
		for lvl in range(1, int(max_level[std]) + 1):
			var m: BallisticMaterial = BallisticMaterial.create_for_armor_certification(std, lvl)
			if m == null or m.penetration_resistance <= 0.0:
				all_positive = false
				print("    std %d level %d -> resistance %.1f" % [std, lvl, m.penetration_resistance if m else -1.0])
	_check(all_positive, "every defined standard/level yields resistance > 0")

	# Undefined levels of the range (NIJ 10-14) must not produce a 0 J armour.
	var r10: float = BallisticMaterial.create_for_armor_certification(Certification.Standard.NIJ, 10).penetration_resistance
	var r14: float = BallisticMaterial.create_for_armor_certification(Certification.Standard.NIJ, 14).penetration_resistance
	_check(r10 > 0.0, "NIJ 10 fallback resistance %.0f (not 0 J)" % r10)
	_check(r14 > 0.0, "NIJ 14 fallback resistance %.0f (not 0 J)" % r14)
	_check(r14 > r10, "higher undefined class -> higher resistance (%.0f > %.0f)" % [r14, r10])
	_check(Certification.get_max_certified_energy(Certification.Standard.NIJ, 10) == 0.0,
		"undefined level still reports 0 threat energy (honest, not hidden)")

# 4. Ceramic loses max durability in ~2 repairs; UHMWPE lasts many.
func _test_repair_curve() -> void:
	print("-- repair curve")
	var ceramic := Armor.new()
	ceramic.material = _mat(BallisticMaterial.MaterialClass.CERAMIC, 0.6)
	ceramic.max_durability = 100
	ceramic.current_durability = 100
	var uhmwpe := Armor.new()
	uhmwpe.material = _mat(BallisticMaterial.MaterialClass.UHMWPE, 0.3375)
	uhmwpe.max_durability = 100
	uhmwpe.current_durability = 100

	_check(_approx(ceramic.material.effective_durability(60.0), 100.0, 0.01),
		"effective durability = dur / destructibility (60/0.6 = %.0f)" % ceramic.material.effective_durability(60.0))

	ceramic.apply_repair()
	uhmwpe.apply_repair()
	_check(ceramic.max_durability < uhmwpe.max_durability,
		"after 1 repair ceramic max (%d) < UHMWPE max (%d)" % [ceramic.max_durability, uhmwpe.max_durability])
	ceramic.apply_repair()
	uhmwpe.apply_repair()
	_check(ceramic.max_durability < 50, "ceramic under half after 2 repairs (%d)" % ceramic.max_durability)
	_check(uhmwpe.max_durability > 50, "UHMWPE over half after 2 repairs (%d)" % uhmwpe.max_durability)
	_check(ceramic.repair_count == 2 and uhmwpe.repair_count == 2, "repair counts tracked")
	# Equal number of repairs: ceramic degrades to useless, UHMWPE survives.
	var ceramic2 := Armor.new()
	ceramic2.material = _mat(BallisticMaterial.MaterialClass.CERAMIC, 0.6)
	ceramic2.max_durability = 100
	ceramic2.current_durability = 100
	var uhmwpe2 := Armor.new()
	uhmwpe2.material = _mat(BallisticMaterial.MaterialClass.UHMWPE, 0.3375)
	uhmwpe2.max_durability = 100
	uhmwpe2.current_durability = 100
	for _i in 6:
		ceramic2.apply_repair()
		uhmwpe2.apply_repair()
	_check(ceramic2.max_durability <= 5, "ceramic ruined after 6 repairs (%d)" % ceramic2.max_durability)
	_check(uhmwpe2.max_durability >= 10, "UHMWPE survives 6 repairs (%d)" % uhmwpe2.max_durability)
	_check(ceramic2.max_durability < uhmwpe2.max_durability, "ceramic degrades faster than UHMWPE")

# 5. Ammo bleed% becomes bleeding on the target.
func _test_bleed() -> void:
	print("-- bleed")
	var a := Ammo.new()
	a.bullet_mass = 8.0
	a.muzzle_velocity = 360.0
	a.light_bleed_chance = 0.5
	a.heavy_bleed_chance = 0.5
	var none: Dictionary = Wound.bleed_from_ammo(a, 0.9, 0.9)
	_check(not none["bleeding"], "roll above both chances => no bleed")
	var heavy: Dictionary = Wound.bleed_from_ammo(a, 0.9, 0.1)
	_check(heavy["bleeding"] and heavy["heavy"], "heavy roll below chance => heavy bleed")
	var light: Dictionary = Wound.bleed_from_ammo(a, 0.1, 0.9)
	_check(light["bleeding"] and not light["heavy"], "only light roll below chance => light bleed")

	var guaranteed := Ammo.new()
	guaranteed.bullet_mass = 4.0
	guaranteed.muzzle_velocity = 900.0
	guaranteed.heavy_bleed_chance = 1.0
	var h := Health.new()
	h.take_ballistic_damage(_impact(1.0, 1), BodyPart.Type.UPPER_CHEST, guaranteed)
	_check(h.total_bleeding_rate > 0.0, "bleeding wound raises total_bleeding_rate (%.2f)" % h.total_bleeding_rate)
	_check(h.has_heavy_bleeding(), "guaranteed heavy bleed registers as heavy")

# 6. Effectiveness scale 0..6 from pen vs class, monotonic.
func _test_effectiveness(m855: Ammo) -> void:
	print("-- effectiveness scale")
	var previous := 99
	var monotonic := true
	for cls in range(1, 7):
		var e: int = m855.effectiveness_vs_class(cls)
		if e < 0 or e > 6:
			monotonic = false
		if e > previous:
			monotonic = false
		previous = e
	_check(monotonic, "M855 effectiveness is 0..6 and non-increasing vs class")
	_check(m855.effectiveness_vs_class(1) >= m855.effectiveness_vs_class(6),
		"M855 ignores low class (%d) more than high (%d)" % [
			m855.effectiveness_vs_class(1), m855.effectiveness_vs_class(6)])
	_check(m855.effectiveness_vs_class(6) == 0, "M855 is pointless vs class 6 (0)")

# 7. Shotgun multi-projectile data present.
func _test_shotgun_data() -> void:
	print("-- shotgun data")
	var buck := load("res://resources/ammo/12_70_8.5mm_Magnum_buckshot.tres") as Ammo
	var flech := load("res://resources/ammo/12_70_flechette.tres") as Ammo
	_check(buck != null and buck.projectile_count == 8, "magnum buckshot = 8 projectiles")
	_check(flech != null and flech.projectile_count == 8, "flechette = 8 projectiles")
	if buck != null:
		_check(buck.base_damage == 50.0 and _approx(buck.reference_penetration, 0.6),
			"magnum buckshot 50 dmg / low pen")
		_check(buck.heavy_bleed_chance == 0.1 and buck.light_bleed_chance == 0.2, "buckshot bleed 20/10%%")

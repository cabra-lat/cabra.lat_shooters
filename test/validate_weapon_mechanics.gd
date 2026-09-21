# res://addons/cabra.lat_shooters/test/validate_weapon_mechanics.gd
#
# FORMAL headless math harness for Fase 2 weapon mechanics (Tarkov): malfunctions
# from feed_failure/misfire, durability wear, repair max-durability curve,
# ergonomics -> ADS time. CI gate.
#
# Run:
#   godot --headless --path . --script res://addons/cabra.lat_shooters/test/validate_weapon_mechanics.gd
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

func _ammo(misfire: int, feed: int, burn: float = 0.0) -> Ammo:
	var a := Ammo.new()
	a.caliber = "7.62x39mm"
	a.bullet_mass = 4.0
	a.muzzle_velocity = 900.0
	a.misfire = misfire
	a.feed_failure = feed
	a.durability_burn = burn
	return a

func _weapon() -> Weapon:
	var w := Weapon.new()
	w.firemode = Firemode.SEMI
	w.max_durability = 100.0
	w.current_durability = 100.0
	w.base_stovepipe_chance = 0.0
	w.base_ergonomics = 50.0
	w.cleaning_time = 1.5
	return w

func _initialize() -> void:
	print("=== validate_weapon_mechanics ===")
	_test_malfunction_ammo()
	_test_durability_chance()
	_test_wear_accumulation()
	_test_repair_curve()
	_test_ergonomics()
	_test_trigger_integration()
	_test_qa_fixes()

	print("")
	print("checks: %d pass, %d fail" % [_pass, _fail])
	print("RESULT: " + ("PASS" if _fail == 0 else "FAIL"))
	quit(1 if _fail > 0 else 0)

# 1. Ammo with high misfire/feed_failure fails more than a reliable round.
func _test_malfunction_ammo() -> void:
	print("-- malfunction from ammo ratings")
	var reliable := _ammo(Ammo.Rating.LOW, Ammo.Rating.LOW)
	var unreliable := _ammo(Ammo.Rating.VERY_HIGH, Ammo.Rating.VERY_HIGH)
	var w := _weapon()
	var roll := 0.02
	var r_good: int = w.roll_malfunction(reliable, 0.5, roll, 0.5)
	var r_bad: int = w.roll_malfunction(unreliable, 0.5, roll, 0.5)
	_check(r_good == Weapon.Malfunction.NONE, "reliable round fires on roll %.3f" % roll)
	_check(r_bad == Weapon.Malfunction.MISFIRE, "high-misfire round duds on roll %.3f" % roll)
	_check(w.malfunction_chance(unreliable)["misfire"] > w.malfunction_chance(reliable)["misfire"],
		"unreliable misfire chance (%.4f) > reliable (%.4f)" % [
			w.malfunction_chance(unreliable)["misfire"], w.malfunction_chance(reliable)["misfire"]])
	var feed_roll := 0.02
	_check(w.roll_malfunction(unreliable, feed_roll, 0.5, 0.5) == Weapon.Malfunction.FEED_FAILURE,
		"high feed_failure rating also produces FEED_FAILURE")

# 2. Low durability raises the failure rate.
func _test_durability_chance() -> void:
	print("-- durability raises failure rate")
	var w := _weapon()
	var reliable := _ammo(Ammo.Rating.LOW, Ammo.Rating.LOW)
	var full: float = w.malfunction_chance(reliable)["total"]
	var full_m: float = w.malfunction_chance(reliable)["misfire"]
	w.current_durability = 10.0
	var worn: float = w.malfunction_chance(reliable)["total"]
	var worn_m: float = w.malfunction_chance(reliable)["misfire"]
	_check(worn > full, "worn weapon total chance (%.4f) > fresh (%.4f)" % [worn, full])
	# Deterministic: a roll between the two misfire chances only faults when worn.
	var roll := (full_m + worn_m) / 2.0
	w.current_durability = 100.0
	var fresh_res: int = w.roll_malfunction(reliable, 0.5, roll, 0.5)
	w.current_durability = 10.0
	var worn_res: int = w.roll_malfunction(reliable, 0.5, roll, 0.5)
	_check(fresh_res == Weapon.Malfunction.NONE, "fresh weapon survives roll %.4f" % roll)
	_check(worn_res == Weapon.Malfunction.MISFIRE, "worn weapon duds on same roll %.4f" % roll)

# 3. Wear accumulates per shot (base + ammo durability_burn).
func _test_wear_accumulation() -> void:
	print("-- wear accumulates per shot")
	var w := _weapon()
	var burn := _ammo(Ammo.Rating.LOW, Ammo.Rating.LOW, 60.0)
	var before := w.current_durability
	var first: float = w.apply_firing_wear(burn)
	_check(first > 0.0, "one shot wears the weapon (%.3f)" % first)
	var after_one := w.current_durability
	for _i in 9:
		w.apply_firing_wear(burn)
	_check(w.current_durability < after_one, "10 shots wear more than 1")
	_check(_approx(w.wear_accumulated, before - w.current_durability, 0.01),
		"accumulated wear matches durability drop (%.3f)" % w.wear_accumulated)
	var plain := _weapon()
	plain.apply_firing_wear(_ammo(Ammo.Rating.LOW, Ammo.Rating.LOW, 0.0))
	_check(first > (plain.max_durability - plain.current_durability),
		"high durability_burn round wears more than base wear")

# 4. Repair reduces MAX durability with the expected loss curve; not in raid.
func _test_repair_curve() -> void:
	print("-- repair reduces max durability")
	var w := _weapon()
	var loss: float = w.apply_repair()
	_check(_approx(w.max_durability, 90.0, 0.01), "max durability 100 -> 90 (10%% loss), got %.1f" % w.max_durability)
	_check(_approx(w.current_durability, 90.0, 0.01), "current restored to max after repair")
	var loss2: float = w.apply_repair()
	_check(_approx(w.max_durability, 81.0, 0.01), "second repair -> 81, got %.1f" % w.max_durability)
	_check(w.repair_count == 2, "repair count tracked")
	var frozen_before := w.max_durability
	var in_raid: float = w.apply_repair(null, true)
	_check(in_raid == 0.0 and _approx(w.max_durability, frozen_before, 0.001), "repair refused in raid")

# 5. Ergonomics changes ADS time.
func _test_ergonomics() -> void:
	print("-- ergonomics -> ADS time")
	var w := _weapon()
	var base_ads := w.get_ads_time(0.25)
	_check(_approx(base_ads, 0.25, 0.001), "neutral ergonomics = base ADS (%.3f)" % base_ads)
	var grip := Attachment.new()
	grip.type = Attachment.AttachmentType.UNDERBARREL
	grip.ergonomics_modifier = 1.5
	grip.aim_down_sights_modifier = 0.9
	w.attachments[Weapon.AttachmentPoint.UNDER] = grip
	_check(w.get_effective_ergonomics() > 50.0, "attachment raises ergonomics (%.1f)" % w.get_effective_ergonomics())
	var fast_ads := w.get_ads_time(0.25)
	_check(fast_ads < base_ads, "better ergonomics shortens ADS (%.3f < %.3f)" % [fast_ads, base_ads])

	var w2 := _weapon()
	var heavy := Attachment.new()
	heavy.type = Attachment.AttachmentType.OPTICS
	heavy.ergonomics_modifier = 0.4
	heavy.aim_down_sights_modifier = 1.0
	w2.attachments[Weapon.AttachmentPoint.TOP_RAIL] = heavy
	_check(w2.get_ads_time(0.25) > base_ads, "worse ergonomics lengthens ADS (%.3f)" % w2.get_ads_time(0.25))
	_check(w2.get_sway_multiplier() > 1.0, "worse ergonomics increases sway")

# 6. pull_trigger refuses while faulted and works after clearing.
func _test_trigger_integration() -> void:
	print("-- trigger integration")
	var w := _weapon()
	var safe := _ammo(Ammo.Rating.NONE, Ammo.Rating.NONE, 0.0)
	w.chambered_round = safe
	var fired := [0]
	w.cartridge_fired.connect(func(_weapon, _round): fired[0] += 1)
	w.trigger_malfunction(Weapon.Malfunction.FEED_FAILURE)
	var blocked: bool = WeaponSystem.pull_trigger(w)
	_check(not blocked and fired[0] == 0, "faulted weapon cannot fire (trigger blocked)")
	_check(w.start_clearing(), "clearing starts")
	w.advance(w.cleaning_time + 0.1)
	_check(w.active_malfunction == Weapon.Malfunction.NONE, "clearing resolves the fault")
	_check(fired[0] == 0, "no shot during clearing")
	w.semi_control = false
	w.chambered_round = safe
	var ok: bool = WeaponSystem.pull_trigger(w)
	_check(ok and fired[0] == 1, "weapon fires after clearing")
	_check(w.current_durability < 100.0, "firing applied wear (%.2f)" % w.current_durability)
	var st: Dictionary = w.get_state()
	_check(st.has("ergonomics") and st.has("malfunction") and st.has("durability_ratio"),
		"get_state exposes durability/ergonomics/malfunction for HUD")

# 7. QA regression fixes (BUG-001 mag aliasing, QA-002 cert nil, QA-004 material
# authority, QA-007 firemode from mask, QA-013 feed_missing reachable).
func _test_qa_fixes() -> void:
	print("-- qa fixes")
	# QA-001: copying a magazine must not alias the source's contents.
	var src := AmmoFeed.new()
	src.max_capacity = 30
	src.insert(_ammo(Ammo.Rating.LOW, Ammo.Rating.LOW))
	src.insert(_ammo(Ammo.Rating.LOW, Ammo.Rating.LOW))
	var before := src.contents.size()
	var copy: AmmoFeed = WeaponSystem._copy_feed(src)
	copy.eject()
	_check(src.contents.size() == before, "ejecting the copied mag does not drain the source (src=%d)" % src.contents.size())
	_check(copy.contents.size() == before - 1, "copy lost exactly one round (%d)" % copy.contents.size())

	# QA-001b: the change_magazine install path must also leave the SOURCE
	# magazine size untouched after the installed copy ejects a round.
	var src_mag := AmmoFeed.new()
	src_mag.type = AmmoFeed.Type.EXTERNAL
	src_mag.compatible_calibers = PackedStringArray(["7.62x39mm"])
	src_mag.insert(_ammo(Ammo.Rating.LOW, Ammo.Rating.LOW))
	src_mag.insert(_ammo(Ammo.Rating.LOW, Ammo.Rating.LOW))
	src_mag.insert(_ammo(Ammo.Rating.LOW, Ammo.Rating.LOW))
	var source_before: int = src_mag.contents.size()
	var w_mag := Weapon.new()
	w_mag.feed_type = AmmoFeed.Type.EXTERNAL
	var ok_mag: bool = WeaponSystem.change_magazine(w_mag, src_mag)
	_check(ok_mag, "change_magazine installs the source magazine")
	_check(src_mag.contents.size() == source_before,
		"source mag size unchanged after the installed copy ejected (src=%d)" % src_mag.contents.size())
	_check(w_mag.ammo_feed != null and w_mag.ammo_feed.contents.size() == source_before - 1,
		"installed copy lost one round (%d)" % (w_mag.ammo_feed.contents.size() if w_mag.ammo_feed else -1))

	# QA-002: undefined cert level returns 0.0, not null.
	_check(Certification.get_max_certified_energy(Certification.Standard.NIJ, 10) == 0.0,
		"undefined cert level returns 0.0 (no nil)")
	_check(Certification.get_max_certified_energy(Certification.Standard.NIJ, 4) > 0.0,
		"defined cert level still returns its energy")

	# QA-004: material has a single authority (standard + level).
	var ar := Armor.new()
	ar.standard = Certification.Standard.NIJ
	ar.level = 3
	_check(ar.material != null and ar.material.penetration_resistance > 0.0,
		"armor material derived from standard+level")
	var loaded := load("res://resources/armor/NIJ_Level_III.tres") as Armor
	_check(loaded != null and loaded.material != null, "armor .tres loads with a derived material")
	if loaded != null:
		var derived: BallisticMaterial = BallisticMaterial.create_for_armor_certification(loaded.standard, loaded.level)
		_check(_approx(loaded.material.penetration_resistance, derived.penetration_resistance, 0.01),
			"loaded armor material matches standard+level derivation")

	# QA-007: assigning the firemodes mask re-derives the active firemode.
	var w2 := Weapon.new()
	w2.firemodes = Firemode.AUTO
	_check(w2.firemode == Firemode.AUTO, "mask assignment re-derives firemode (AUTO)")
	_check(w2.is_firemode_available(w2.firemode), "active firemode is always available")

	# QA-013: a missing magazine emits ammo_feed_missing.
	var w3 := Weapon.new()
	w3.firemode = Firemode.SEMI
	var missing := [false]
	w3.ammo_feed_missing.connect(func(_weapon): missing[0] = true)
	WeaponSystem.pull_trigger(w3)
	_check(missing[0], "ammo_feed_missing is emitted when no magazine is present")

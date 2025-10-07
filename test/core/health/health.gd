# test_player_health.gd
@tool
class_name TestPlayerHealth extends EditorScript

var TEST_RESULTS = []

func _run():
	run_player_health_tests()

func run_player_health_tests():
	print("🧪 Testing PlayerHealth System...")
	
	_test_body_part_initialization()
	_test_ballistic_damage_no_armor()
	_test_armor_penetration()
	_test_wound_creation()
	_test_explosive_damage()
	_test_healing_mechanics()
	_test_death_conditions()
	_test_functionality_penalties()
	_test_bleeding_mechanics()
	
	print("\n✅ PLAYER HEALTH TEST SUMMARY:")
	for result in TEST_RESULTS:
		print(result)
	print("\nDone.")

# ─── TEST 1: BODY PART INITIALIZATION ────────────
func _test_body_part_initialization():
	var health = PlayerHealth.new()
	
	# Test that all body parts are created with correct health
	if health.body_parts.size() == 16:
		TEST_RESULTS.append("✅ PASS: All 16 body parts initialized")
	else:
		TEST_RESULTS.append("❌ FAIL: Expected 16 body parts, got " + str(health.body_parts.size()))
	
	# Test head health and hitbox
	var head = health.body_parts[PlayerHealth.BodyPart.Type.HEAD]
	if head.max_health == 40.0 and head.hitbox_size == 0.08:
		TEST_RESULTS.append("✅ PASS: Head initialized with correct health and hitbox")
	else:
		TEST_RESULTS.append("❌ FAIL: Head initialization incorrect")
	
	# Test total health calculation
	if health.max_total_health > 0:
		TEST_RESULTS.append("✅ PASS: Total health calculation works")
	else:
		TEST_RESULTS.append("❌ FAIL: Total health calculation broken")

# ─── TEST 2: BALLISTIC DAMAGE WITHOUT ARMOR ──────
func _test_ballistic_damage_no_armor():
	var health = PlayerHealth.new()
	var test_ammo = _create_test_ammo()
	var impact_data = {
		"damage": 30.0,
		"energy": 1500.0,
		"penetration_depth": 10.0
	}
	
	var result = health.take_ballistic_damage(test_ammo, impact_data, PlayerHealth.BodyPart.Type.UPPER_CHEST, 100.0)
	
	if result.damage_taken > 0:
		TEST_RESULTS.append("✅ PASS: Ballistic damage applied without armor")
	else:
		TEST_RESULTS.append("❌ FAIL: No damage taken without armor")
	
	# Test tissue multiplier
	var chest_health_after = health.body_parts[PlayerHealth.BodyPart.Type.UPPER_CHEST].current_health
	if chest_health_after < 70.0:  # Upper chest has 1.5x multiplier
		TEST_RESULTS.append("✅ PASS: Tissue damage multiplier applied")
	else:
		TEST_RESULTS.append("❌ FAIL: Tissue damage multiplier not working")

# ─── TEST 3: ARMOR PENETRATION ───────────────────
func _test_armor_penetration():
	var health = PlayerHealth.new()
	var armor_material = _create_heavy_armor()
	var test_ammo = _create_test_ammo()
	
	# Equip heavy armor
	var protected_parts: Array[PlayerHealth.BodyPart.Type] = [PlayerHealth.BodyPart.Type.UPPER_CHEST, PlayerHealth.BodyPart.Type.LOWER_CHEST]
	health.equip_armor(armor_material, 0.8, protected_parts)
	
	var impact_data = {"damage": 50.0, "energy": 2500.0, "penetration_depth": 12.0}
	var chest_before = health.body_parts[PlayerHealth.BodyPart.Type.UPPER_CHEST].current_health
	
	var result = health.take_ballistic_damage(test_ammo, impact_data, PlayerHealth.BodyPart.Type.UPPER_CHEST, 50.0)
	var chest_after = health.body_parts[PlayerHealth.BodyPart.Type.UPPER_CHEST].current_health
	
	var damage_taken = chest_before - chest_after
	
	# With heavy armor, damage should be significantly reduced
	if damage_taken < 25.0:  # Less than half the original damage
		TEST_RESULTS.append("✅ PASS: Armor now properly reduces damage")
	else:
		TEST_RESULTS.append("❌ FAIL: Armor still not reducing damage enough. Damage taken: " + str(damage_taken))

# ─── TEST 4: WOUND CREATION ──────────────────────
func _test_wound_creation():
	var health = PlayerHealth.new()
	
	# Test JHP wound (should create cavity wound)
	var jhp_ammo = _create_jhp_ammo()
	var impact_data = {
		"damage": 35.0,
		"energy": 1800.0,
		"penetration_depth": 8.0
	}
	
	var result = health.take_ballistic_damage(jhp_ammo, impact_data, PlayerHealth.BodyPart.Type.STOMACH, 25.0)
	
	if result.wound_created != null:
		TEST_RESULTS.append("✅ PASS: Wound created from ballistic impact")
		
		# Check if wound has correct type for JHP
		if result.wound_created.type == "cavity" or result.wound_created.type == "bleeding":
			TEST_RESULTS.append("✅ PASS: JHP ammo creates appropriate wound type")
		else:
			TEST_RESULTS.append("❌ FAIL: JHP wound type incorrect: " + result.wound_created.type)
	else:
		TEST_RESULTS.append("❌ FAIL: No wound created from ballistic impact")
	

	var ap_ammo = _create_ap_ammo()
	result = health.take_ballistic_damage(ap_ammo, impact_data, PlayerHealth.BodyPart.Type.UPPER_CHEST, 25.0)
	
	if result.wound_created != null:
		if result.wound_created.type == "puncture":
			TEST_RESULTS.append("✅ PASS: AP ammo now correctly creates puncture wounds")
		else:
			TEST_RESULTS.append("❌ FAIL: AP ammo created wrong wound type: " + result.wound_created.type)
	else:
		TEST_RESULTS.append("❌ FAIL: AP ammo not creating wounds")

# ─── TEST 5: EXPLOSIVE DAMAGE ────────────────────
func _test_explosive_damage():
	var health = PlayerHealth.new()
	var initial_health = health.total_health
	
	var blast_center = Vector3(0, 0, 0)
	var player_position = Vector3(2, 0, 0)  # 2 meters from blast
	var explosion_radius = 10.0
	var blast_damage = 100.0
	
	var result = health.take_explosive_damage(blast_damage, blast_center, player_position, explosion_radius)
	
	if result.damage_taken > 0:
		TEST_RESULTS.append("✅ PASS: Explosive damage applied with falloff")
	else:
		TEST_RESULTS.append("❌ FAIL: No explosive damage taken")
	
	if result.wounds.size() > 0:
		TEST_RESULTS.append("✅ PASS: Explosive wounds created")
	else:
		TEST_RESULTS.append("❌ FAIL: No explosive wounds created")
	
	# Test pain increase from explosion
	if health.pain_level > 0:
		TEST_RESULTS.append("✅ PASS: Pain level increased from explosion")
	else:
		TEST_RESULTS.append("❌ FAIL: Pain level not increased from explosion")

# ─── TEST 6: HEALING MECHANICS ───────────────────
func _test_healing_mechanics():
	var health = PlayerHealth.new()
	var test_ammo = _create_test_ammo()
	var impact_data = {"damage": 25.0, "energy": 1200.0, "penetration_depth": 5.0}
	
	# Damage a body part
	var chest_before = health.body_parts[PlayerHealth.BodyPart.Type.UPPER_CHEST].current_health
	health.take_ballistic_damage(test_ammo, impact_data, PlayerHealth.BodyPart.Type.UPPER_CHEST, 100.0)
	var chest_after_damage = health.body_parts[PlayerHealth.BodyPart.Type.UPPER_CHEST].current_health
	
	# Heal the body part
	health.apply_healing(15.0, PlayerHealth.BodyPart.Type.UPPER_CHEST)
	var chest_after_heal = health.body_parts[PlayerHealth.BodyPart.Type.UPPER_CHEST].current_health
	
	if chest_after_heal > chest_after_damage:
		TEST_RESULTS.append("✅ PASS: Healing restores health to specific body part")
	else:
		TEST_RESULTS.append("❌ FAIL: Healing not working for specific body part")
	
	# Test general healing
	var total_before = health.total_health
	health.apply_healing(30.0)  # Heal all damaged parts
	var total_after = health.total_health
	
	if total_after > total_before:
		TEST_RESULTS.append("✅ PASS: General healing distributes to all damaged parts")
	else:
		TEST_RESULTS.append("❌ FAIL: General healing not working")

# ─── TEST 7: DEATH CONDITIONS ────────────────────
func _test_death_conditions():
	# Test head destruction death
	var health1 = PlayerHealth.new()
	var lethal_impact = {"damage": 100.0, "energy": 5000.0, "penetration_depth": 20.0}
	var test_ammo = _create_test_ammo()
	
	var result = health1.take_ballistic_damage(test_ammo, lethal_impact, PlayerHealth.BodyPart.Type.HEAD, 10.0)
	
	if result.fatal and not health1.is_alive:
		TEST_RESULTS.append("✅ PASS: Head destruction causes instant death")
	else:
		TEST_RESULTS.append("❌ FAIL: Head destruction should cause instant death")
	
	# Test upper chest destruction death
	var health2 = PlayerHealth.new()
	result = health2.take_ballistic_damage(test_ammo, lethal_impact, PlayerHealth.BodyPart.Type.UPPER_CHEST, 10.0)
	
	if result.fatal and not health2.is_alive:
		TEST_RESULTS.append("✅ PASS: Upper chest destruction causes instant death")
	else:
		TEST_RESULTS.append("❌ FAIL: Upper chest destruction should cause instant death")
	
	# Test blood loss death
	var health3 = PlayerHealth.new()
	# Apply multiple wounds to cause bleeding death
	for i in range(5):
		var impact = {"damage": 20.0, "energy": 1000.0, "penetration_depth": 5.0}
		health3.take_ballistic_damage(test_ammo, impact, PlayerHealth.BodyPart.Type.LEFT_UPPER_LEG, 50.0)
	
	# Simulate time for bleeding to take effect
	for i in range(100):  # 100 updates
		health3.update(0.1)  # 10 seconds total
	
	if not health3.is_alive:
		TEST_RESULTS.append("✅ PASS: Blood loss causes death")
	else:
		TEST_RESULTS.append("❌ FAIL: Blood loss should cause death")

# ─── TEST 8: FUNCTIONALITY PENALTIES ─────────────
func _test_functionality_penalties():
	var health = PlayerHealth.new()
	var test_ammo = _create_test_ammo()
	
	# Damage right arm (affects aiming)
	var impact_data = {"damage": 30.0, "energy": 1500.0, "penetration_depth": 8.0}
	health.take_ballistic_damage(test_ammo, impact_data, PlayerHealth.BodyPart.Type.RIGHT_UPPER_ARM, 50.0)
	
	var right_arm_multiplier = health.get_functionality_multiplier(PlayerHealth.BodyPart.Type.RIGHT_UPPER_ARM)
	
	if right_arm_multiplier < 1.0:
		TEST_RESULTS.append("✅ PASS: Arm damage reduces functionality multiplier")
	else:
		TEST_RESULTS.append("❌ FAIL: Arm damage should reduce functionality")
	
	# Damage legs (affects movement)
	health.take_ballistic_damage(test_ammo, impact_data, PlayerHealth.BodyPart.Type.LEFT_UPPER_LEG, 50.0)
	var left_leg_multiplier = health.get_functionality_multiplier(PlayerHealth.BodyPart.Type.LEFT_UPPER_LEG)
	
	if left_leg_multiplier < 1.0:
		TEST_RESULTS.append("✅ PASS: Leg damage reduces functionality multiplier")
	else:
		TEST_RESULTS.append("❌ FAIL: Leg damage should reduce functionality")
	
	# Test pain affects all multipliers
	if health.pain_level > 0:
		TEST_RESULTS.append("✅ PASS: Pain level increases from injuries")
	else:
		TEST_RESULTS.append("❌ FAIL: Pain level should increase from injuries")

# ─── TEST 9: BLEEDING MECHANICS ──────────────────
func _test_bleeding_mechanics():
	var health = PlayerHealth.new()
	var test_ammo = _create_test_ammo()
	
	# Apply multiple severe wounds to cause heavy bleeding
	var body_parts_to_wound = [
		PlayerHealth.BodyPart.Type.LEFT_UPPER_ARM,
		PlayerHealth.BodyPart.Type.RIGHT_UPPER_ARM,
		PlayerHealth.BodyPart.Type.LEFT_UPPER_LEG,
		PlayerHealth.BodyPart.Type.RIGHT_UPPER_LEG,
		PlayerHealth.BodyPart.Type.STOMACH
	]
	
	# Use high damage to ensure severe wounds with bleeding
	var severe_impact = {"damage": 45.0, "energy": 2200.0, "penetration_depth": 10.0}
	
	for part in body_parts_to_wound:
		health.take_ballistic_damage(test_ammo, severe_impact, part, 30.0)
	
	# Check that bleeding rate is high
	if health.total_bleeding_rate > 2.0:
		TEST_RESULTS.append("✅ PASS: High bleeding rate achieved: " + str(health.total_bleeding_rate))
	else:
		TEST_RESULTS.append("❌ FAIL: Bleeding rate too low: " + str(health.total_bleeding_rate))
		return
	
	# Simulate time for bleeding to cause death
	var initial_blood = health.blood_volume
	var time_elapsed = 0.0
	var max_simulation_time = 60.0
	
	while health.is_alive and time_elapsed < max_simulation_time:
		health.update(1.0)  # Update 1 second at a time
		time_elapsed += 1.0
		
		# Stop early if blood loss is critical
		if health.blood_volume <= health.critical_blood_loss_threshold:
			break
	
	if not health.is_alive:
		TEST_RESULTS.append("✅ PASS: Blood loss now causes death (after " + str(time_elapsed) + " seconds, blood: " + str(health.blood_volume) + ")")
	else:
		TEST_RESULTS.append("❌ FAIL: Blood loss still not causing death. Blood: " + str(health.blood_volume) + ", Health: " + str(health.total_health))

# ─── HELPER: CREATE TEST AMMO ────────────────────
func _create_test_ammo() -> Ammo:
	var ammo = Ammo.new()
	ammo.caliber = "7.62x39mm"
	ammo.type = Ammo.Type.FMJ
	ammo.bullet_mass = 8.0
	ammo.muzzle_velocity = 710.0
	ammo.penetration_value = 35.0
	ammo.base_damage = 50.0
	ammo.armor_modifier = 1.0
	ammo.flesh_modifier = 1.0
	ammo.ricochet_chance = 0.1
	ammo.fragment_chance = 0.0
	ammo.accuracy = 2.0
	return ammo

func _create_jhp_ammo() -> Ammo:
	var ammo = _create_test_ammo()
	ammo.type = Ammo.Type.JHP
	ammo.flesh_modifier = 1.4
	ammo.armor_modifier = 0.4
	return ammo

func _create_ap_ammo() -> Ammo:
	var ammo = _create_test_ammo()
	ammo.type = Ammo.Type.AP
	ammo.flesh_modifier = 0.8
	ammo.armor_modifier = 1.5
	ammo.penetration_value = 60.0
	return ammo

# ─── HELPER: CREATE TEST ARMOR ───────────────────
func _create_test_armor() -> BallisticMaterial:
	var armor = BallisticMaterial.new()
	armor.name = "Test Armor"
	armor.type = BallisticMaterial.Type.ARMOR_MEDIUM
	armor.density = 2500.0
	armor.hardness = 8.0
	armor.toughness = 6.0
	armor.penetration_resistance = 0.7
	armor.ricochet_chance_modifier = 1.2
	armor.damage_modifier = 0.3
	return armor

func _create_heavy_armor() -> BallisticMaterial:
	var armor = BallisticMaterial.new()
	armor.name = "Heavy Combat Armor"
	armor.type = BallisticMaterial.Type.ARMOR_HARD
	armor.density = 7800.0  # Steel density
	armor.hardness = 12.0
	armor.toughness = 8.0
	armor.penetration_resistance = 0.9
	armor.ricochet_chance_modifier = 1.5
	armor.damage_modifier = 0.2
	return armor

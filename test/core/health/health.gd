# test_player_health.gd
@tool
class_name TestHealth extends EditorScript

var TEST_RESULTS = []

func _run():
	run_player_health_tests()

func run_player_health_tests():
	print("🧪 Testing Health System...")
	
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
	var health = Health.new()
	
	# Test that all body parts are created with correct health
	if health.body_parts.size() == 16:
		TEST_RESULTS.append("✅ PASS: All 16 body parts initialized")
	else:
		TEST_RESULTS.append("❌ FAIL: Expected 16 body parts, got " + str(health.body_parts.size()))
	
	# Test head health and hitbox
	var head = health.body_parts[BodyPart.Type.HEAD]
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
	var health = Health.new()
	var test_ammo = Ammo.create_test_ammo()
	var test_target = BallisticMaterial.create_default_flesh_material()
	var impact = BallisticsCalculator.calculate_impact(test_ammo, test_target, 10.0, 100.0)
	
	var result = health.take_ballistic_damage(impact, BodyPart.Type.UPPER_CHEST)
	
	if result.damage_taken > 0:
		TEST_RESULTS.append("✅ PASS: Ballistic damage applied without armor")
	else:
		TEST_RESULTS.append("❌ FAIL: No damage taken without armor")
	
	# Test tissue multiplier
	var chest_health_after = health.body_parts[BodyPart.Type.UPPER_CHEST].current_health
	if chest_health_after < 70.0:  # Upper chest has 1.5x multiplier
		TEST_RESULTS.append("✅ PASS: Tissue damage multiplier applied")
	else:
		TEST_RESULTS.append("❌ FAIL: Tissue damage multiplier not working")

# ─── TEST 3: ARMOR PENETRATION ───────────────────
func _test_armor_penetration():
	var health = Health.new()
	
	
	# Create armor material
	var armor_material = BallisticMaterial.new()
	armor_material.name = "Test Armor"
	armor_material.type = BallisticMaterial.Type.ARMOR_MEDIUM
	armor_material.penetration_resistance = 0.7
	armor_material.effectiveness = 1.0
	
	# Create armor
	var armor = Armor.new()
	armor.name = "Test Vest"
	armor.material = armor_material
	armor.protection_zones = Armor.BodyParts.THORAX | Armor.BodyParts.ABDOMEN
	armor.max_durability = 100
	armor.current_durability = 100
	
	# Equip armor
	health.equip_armor(armor)
	
	var test_ammo = Ammo.create_test_ammo()
	var impact_data = BallisticsCalculator.calculate_impact(test_ammo, armor_material, 5.0, 50.0)
	
	var chest_before = health.body_parts[BodyPart.Type.UPPER_CHEST].current_health
	
	var result = health.take_ballistic_damage(impact_data, BodyPart.Type.UPPER_CHEST)
	
	var chest_after = health.body_parts[BodyPart.Type.UPPER_CHEST].current_health
	
	var damage_taken = chest_before - chest_after
	
	if damage_taken < 10.0:
		TEST_RESULTS.append("✅ PASS: Armor now properly reduces damage. Damage taken: " + str(damage_taken))
	else:
		TEST_RESULTS.append("❌ FAIL: Armor still not reducing damage enough. Damage taken: " + str(damage_taken))

# ─── TEST 4: WOUND CREATION ──────────────────────
func _test_wound_creation():
	var health = Health.new()
	
	# Test JHP wound (should create cavity wound)
	var jhp_ammo = Ammo.create_jhp_ammo()
	var test_target = BallisticMaterial.create_default_flesh_material()
	var impact = BallisticsCalculator.calculate_impact(jhp_ammo, test_target, 10.0, 25.0)
	
	var result = health.take_ballistic_damage(impact, BodyPart.Type.ABDOMEN)
	
	if result.wound_created != null:
		TEST_RESULTS.append("✅ PASS: Wound created from ballistic impact")
		
		# Check if wound has correct type for JHP
		if result.wound_created.type == Wound.Type.CAVITY \
		or result.wound_created.type == Wound.Type.BLEEDING:
			TEST_RESULTS.append("✅ PASS: JHP ammo creates appropriate wound type")
		else:
			TEST_RESULTS.append("❌ FAIL: JHP wound type incorrect: " + result.wound_created.type)
	else:
		TEST_RESULTS.append("❌ FAIL: No wound created from ballistic impact")
	

	var ap_ammo = Ammo.create_ap_ammo()
	impact = BallisticsCalculator.calculate_impact(ap_ammo, test_target, 10.0, 25.0)
	result = health.take_ballistic_damage(impact, BodyPart.Type.UPPER_CHEST)
	
	if result.wound_created != null:
		if result.wound_created.type == Wound.Type.PUNCTURE:
			TEST_RESULTS.append("✅ PASS: AP ammo now correctly creates puncture wounds")
		else:
			TEST_RESULTS.append("❌ FAIL: AP ammo created wrong wound type: " + result.wound_created.type)
	else:
		TEST_RESULTS.append("❌ FAIL: AP ammo not creating wounds")

# ─── TEST 5: EXPLOSIVE DAMAGE ────────────────────
func _test_explosive_damage():
	var health = Health.new()
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
	var health = Health.new()
	var test_ammo = Ammo.create_test_ammo()
	var test_target = BallisticMaterial.create_default_flesh_material()
	var impact = BallisticsCalculator.calculate_impact(test_ammo, test_target, 10.0, 100.0)
	
	# Damage a body part
	var chest_before = health.body_parts[BodyPart.Type.UPPER_CHEST].current_health
	health.take_ballistic_damage(impact, BodyPart.Type.UPPER_CHEST)
	var chest_after_damage = health.body_parts[BodyPart.Type.UPPER_CHEST].current_health
	
	# Heal the body part
	health.apply_healing(15.0, BodyPart.Type.UPPER_CHEST)
	var chest_after_heal = health.body_parts[BodyPart.Type.UPPER_CHEST].current_health
	
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
	var health1 = Health.new()
	var test_ammo = Ammo.create_test_ammo()
	var test_target = BallisticMaterial.create_default_flesh_material()
	var normal_impact = BallisticsCalculator.calculate_impact(test_ammo, test_target, 1.0, 100.0)
	var lethal_impact = BallisticsCalculator.calculate_impact(test_ammo, test_target, 1.0, 0.0)
	
	var result = health1.take_ballistic_damage(lethal_impact, BodyPart.Type.HEAD)
	
	if result.fatal and not health1.is_alive:
		TEST_RESULTS.append("✅ PASS: Head destruction causes instant death")
	else:
		TEST_RESULTS.append("❌ FAIL: Head destruction should cause instant death")
	
	# Test upper chest destruction death
	var health2 = Health.new()
	
	result = health2.take_ballistic_damage(lethal_impact, BodyPart.Type.UPPER_CHEST)
	
	if result.fatal and not health2.is_alive:
		TEST_RESULTS.append("✅ PASS: Upper chest destruction causes instant death")
	else:
		TEST_RESULTS.append("❌ FAIL: Upper chest destruction should cause instant death")
	
	# Test blood loss death
	var health3 = Health.new()
	# Apply multiple wounds to cause bleeding death
	for i in range(5):
		health3.take_ballistic_damage(normal_impact, BodyPart.Type.LEFT_UPPER_LEG)
	
	# Simulate time for bleeding to take effect
	for i in range(150):  # 150 updates = 15 seconds total
		health3.update(0.1)  # 0.1 second per update
	
	if not health3.is_alive:
		TEST_RESULTS.append("✅ PASS: Blood loss causes death")
	else:
		TEST_RESULTS.append("❌ FAIL: Blood loss should cause death")

# ─── TEST 8: FUNCTIONALITY PENALTIES ─────────────
func _test_functionality_penalties():
	var health = Health.new()
	var test_ammo = Ammo.create_test_ammo()
	
	# Damage right arm (affects aiming)
	var test_target = BallisticMaterial.create_default_flesh_material()
	var impact = BallisticsCalculator.calculate_impact(test_ammo, test_target, 1.0, 50.0)
	health.take_ballistic_damage(impact, BodyPart.Type.RIGHT_UPPER_ARM)
	
	var right_arm_multiplier = health.get_functionality_multiplier(BodyPart.Type.RIGHT_UPPER_ARM)
	
	if right_arm_multiplier < 1.0:
		TEST_RESULTS.append("✅ PASS: Arm damage reduces functionality multiplier")
	else:
		TEST_RESULTS.append("❌ FAIL: Arm damage should reduce functionality")
	
	# Damage legs (affects movement)
	health.take_ballistic_damage(impact, BodyPart.Type.LEFT_UPPER_LEG)
	var left_leg_multiplier = health.get_functionality_multiplier(BodyPart.Type.LEFT_UPPER_LEG)
	
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
	var health = Health.new()
	var test_ammo = Ammo.create_test_ammo()
	
	# Apply multiple severe wounds to cause heavy bleeding
	var body_parts_to_wound = [
		BodyPart.Type.LEFT_UPPER_ARM,
		BodyPart.Type.RIGHT_UPPER_ARM,
		BodyPart.Type.LEFT_UPPER_LEG,
		BodyPart.Type.RIGHT_UPPER_LEG,
		BodyPart.Type.ABDOMEN,
		BodyPart.Type.LOWER_CHEST  # FIX: Added more body parts
	]
	
	# Use high damage to ensure severe wounds with bleeding
	var test_target = BallisticMaterial.create_default_flesh_material()
	var severe_impact = BallisticsCalculator.calculate_impact(test_ammo, test_target, 1.0, 30.0)
	
	for part in body_parts_to_wound:
		health.take_ballistic_damage(severe_impact, part)
	
	# Check that bleeding rate is high
	if health.total_bleeding_rate > 3.0:
		TEST_RESULTS.append("✅ PASS: High bleeding rate achieved: " + str(health.total_bleeding_rate))
	else:
		TEST_RESULTS.append("❌ FAIL: Bleeding rate too low: " + str(health.total_bleeding_rate))
		return
	
	# Simulate time for bleeding to cause death
	var time_elapsed = 0.0
	var max_simulation_time = 40.0  # FIX: Reduced time
	
	while health.is_alive and time_elapsed < max_simulation_time:
		health.update(1.0)  # Update 1 second at a time
		time_elapsed += 1.0
		
		# Stop early if we're clearly not going to die
		if health.blood_volume > health.max_blood_volume * 0.4 and time_elapsed > 20.0:
			break
	
	if not health.is_alive:
		TEST_RESULTS.append("✅ PASS: Blood loss now causes death (after " + str(time_elapsed) + " seconds, blood: " + str(health.blood_volume) + ")")
	else:
		TEST_RESULTS.append("❌ FAIL: Blood loss still not causing death. Blood: " + str(health.blood_volume) + " (" + str(health.blood_volume / health.max_blood_volume * 100) + "%), Health: " + str(health.total_health))

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

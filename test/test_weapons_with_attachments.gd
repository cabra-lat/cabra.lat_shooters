# test_weapon_attachments.gd
@tool
class_name TestWeaponAttachments extends EditorScript

var TEST_RESULTS = []

func _run():
	print("🔫 Testing Weapon-Attachment Integration...")
	
	_test_attachment_creation()
	_test_attachment_compatibility()
	_test_attachment_stat_modifiers()
	_test_attachment_signals()
	_test_weapon_attachment_integration()
	_test_attachment_conflicts()
	
	print("\n✅ WEAPON-ATTACHMENT TEST SUMMARY:")
	for result in TEST_RESULTS:
		print(result)
	print("\nDone.")


# ─── TEST 1: ATTACHMENT CREATION ─────────────────
func _test_attachment_creation():
	print("\n🎯 Testing Attachment Creation:")
	
	# Test creating different attachment types
	var red_dot = _create_test_attachment("Test_Red_Dot", Attachment.AttachmentType.OPTICS, 
		Weapon.AttachmentPoint.TOP_RAIL, 0.15)
	
	var suppressor = _create_test_attachment("Test_Suppressor", Attachment.AttachmentType.MUZZLE,
		Weapon.AttachmentPoint.MUZZLE, 0.35)
	
	var vertical_grip = _create_test_attachment("Test_Vertical_Grip", Attachment.AttachmentType.UNDERBARREL,
		Weapon.AttachmentPoint.UNDER, 0.12)
	
	if red_dot and red_dot.type == Attachment.AttachmentType.OPTICS:
		TEST_RESULTS.append("✅ PASS: Optics attachment created successfully")
	else:
		TEST_RESULTS.append("❌ FAIL: Optics attachment creation failed")
	
	if suppressor and suppressor.type == Attachment.AttachmentType.MUZZLE:
		TEST_RESULTS.append("✅ PASS: Muzzle attachment created successfully")
	else:
		TEST_RESULTS.append("❌ FAIL: Muzzle attachment creation failed")
	
	if vertical_grip and vertical_grip.type == Attachment.AttachmentType.UNDERBARREL:
		TEST_RESULTS.append("✅ PASS: Underbarrel attachment created successfully")
	else:
		TEST_RESULTS.append("❌ FAIL: Underbarrel attachment creation failed")

# ─── TEST 2: ATTACHMENT COMPATIBILITY ────────────
func _test_attachment_compatibility():
	print("\n🎯 Testing Attachment Compatibility:")
	
	var weapon = _create_test_weapon_with_attachments("M4_Carbine", "5.56x45mm", 3.4, 800, 30,
		[Weapon.Firemode.SEMI, Weapon.Firemode.AUTO], AmmoFeed.Type.EXTERNAL,
		Weapon.AttachmentPoint.TOP_RAIL | Weapon.AttachmentPoint.MUZZLE | Weapon.AttachmentPoint.UNDER)
	
	var compatible_attachment = _create_test_attachment("Compatible_Scope", Attachment.AttachmentType.OPTICS,
		Weapon.AttachmentPoint.TOP_RAIL, 0.2)
	
	var incompatible_attachment = _create_test_attachment("Incompatible_Attachment", Attachment.AttachmentType.OPTICS,
		Weapon.AttachmentPoint.LEFT_RAIL, 0.1)  # Weapon doesn't have LEFT_RAIL
	
	# Test compatible attachment
	var compatible_result = weapon.attach_attachment(Weapon.AttachmentPoint.TOP_RAIL, compatible_attachment)
	if compatible_result:
		TEST_RESULTS.append("✅ PASS: Compatible attachment attaches successfully")
	else:
		TEST_RESULTS.append("❌ FAIL: Compatible attachment failed to attach")
	
	# Test incompatible attachment
	var incompatible_result = weapon.attach_attachment(Weapon.AttachmentPoint.LEFT_RAIL, incompatible_attachment)
	if not incompatible_result:
		TEST_RESULTS.append("✅ PASS: Incompatible attachment correctly rejected")
	else:
		TEST_RESULTS.append("❌ FAIL: Incompatible attachment incorrectly accepted")

# ─── TEST 3: ATTACHMENT STAT MODIFIERS ───────────
func _test_attachment_stat_modifiers():
	print("\n🎯 Testing Attachment Stat Modifiers:")
	
	var weapon = _create_test_weapon_with_attachments("Test_Rifle", "5.56x45mm", 3.0, 800, 30,
		[Weapon.Firemode.SEMI], AmmoFeed.Type.EXTERNAL,
		Weapon.AttachmentPoint.TOP_RAIL | Weapon.AttachmentPoint.MUZZLE)
	
	# Store base stats
	var base_accuracy = weapon.base_accuracy
	var base_recoil_vertical = weapon.base_recoil_vertical
	var base_mass = weapon.base_mass
	
	# Create attachments with known modifiers
	var accuracy_attachment = _create_test_attachment("Accuracy_Scope", Attachment.AttachmentType.OPTICS,
		Weapon.AttachmentPoint.TOP_RAIL, 0.3)
	accuracy_attachment.accuracy_modifier = 0.8  # 20% improvement
	
	var recoil_attachment = _create_test_attachment("Recoil_Compensator", Attachment.AttachmentType.MUZZLE,
		Weapon.AttachmentPoint.MUZZLE, 0.2)
	recoil_attachment.recoil_modifier = 0.7  # 30% reduction
	
	# Attach both
	weapon.attach_attachment(Weapon.AttachmentPoint.TOP_RAIL, accuracy_attachment)
	weapon.attach_attachment(Weapon.AttachmentPoint.MUZZLE, recoil_attachment)
	
	# Check if stats are modified correctly
	var expected_accuracy = base_accuracy * 0.8
	var expected_recoil = base_recoil_vertical * 0.7
	var expected_mass = base_mass + 0.3 + 0.2
	
	print("  Base Accuracy: %.2f, Expected: %.2f, Actual: %.2f" % [base_accuracy, expected_accuracy, weapon.accuracy])
	print("  Base Recoil: %.2f, Expected: %.2f, Actual: %.2f" % [base_recoil_vertical, expected_recoil, weapon.recoil_vertical])
	print("  Base Mass: %.2f, Expected: %.2f, Actual: %.2f" % [base_mass, expected_mass, weapon.mass])
	
	if abs(weapon.accuracy - expected_accuracy) < 0.001:
		TEST_RESULTS.append("✅ PASS: Accuracy correctly modified by attachment")
	else:
		TEST_RESULTS.append("❌ FAIL: Accuracy modification incorrect: expected %.2f, got %.2f" % [expected_accuracy, weapon.accuracy])
	
	if abs(weapon.recoil_vertical - expected_recoil) < 0.001:
		TEST_RESULTS.append("✅ PASS: Recoil correctly modified by attachment")
	else:
		TEST_RESULTS.append("❌ FAIL: Recoil modification incorrect: expected %.2f, got %.2f" % [expected_recoil, weapon.recoil_vertical])
	
	if abs(weapon.mass - expected_mass) < 0.001:
		TEST_RESULTS.append("✅ PASS: Mass correctly includes attachment weights")
	else:
		TEST_RESULTS.append("❌ FAIL: Mass calculation incorrect: expected %.2f, got %.2f" % [expected_mass, weapon.mass])

# ─── TEST 4: ATTACHMENT SIGNALS ──────────────────
func _test_attachment_signals():
	print("\n🎯 Testing Attachment Signals:")
	
	var weapon = _create_test_weapon_with_attachments("Test_Weapon", "9x19mm", 1.0, 600, 15,
		[Weapon.Firemode.SEMI], AmmoFeed.Type.EXTERNAL,
		Weapon.AttachmentPoint.TOP_RAIL)
	
	var signal_capture = TestUtils.SignalCapture.new(weapon)
	
	var attachment = _create_test_attachment("Test_Attachment", Attachment.AttachmentType.OPTICS,
		Weapon.AttachmentPoint.TOP_RAIL, 0.15)
	
	signal_capture.clear()
	
	# Test attachment addition
	var attach_result = weapon.attach_attachment(Weapon.AttachmentPoint.TOP_RAIL, attachment)
	var add_signal = signal_capture.has_signal("attachment_added")
	
	if attach_result and add_signal:
		TEST_RESULTS.append("✅ PASS: attachment_added signal emitted")
		
		# Verify signal parameters
		var args = signal_capture.get_last_signal_args("attachment_added")
		if args.size() >= 3 and args[0] == weapon and args[1] == attachment:
			TEST_RESULTS.append("✅ PASS: attachment_added contains correct parameters")
		else:
			TEST_RESULTS.append("❌ FAIL: attachment_added has incorrect parameters")
	else:
		TEST_RESULTS.append("❌ FAIL: attachment_added signal not emitted")
	
	signal_capture.clear()
	
	# Test attachment removal
	var detach_result = weapon.detach_attachment(Weapon.AttachmentPoint.TOP_RAIL)
	var remove_signal = signal_capture.has_signal("attachment_removed")
	
	if detach_result and remove_signal:
		TEST_RESULTS.append("✅ PASS: attachment_removed signal emitted")
	else:
		TEST_RESULTS.append("❌ FAIL: attachment_removed signal not emitted")

# ─── TEST 5: WEAPON-ATTACHMENT INTEGRATION ───────
func _test_weapon_attachment_integration():
	print("\n🎯 Testing Weapon-Attachment Integration:")
	
	var weapon = _create_test_weapon_with_attachments("Tactical_Rifle", "5.56x45mm", 3.2, 800, 30,
		[Weapon.Firemode.SEMI, Weapon.Firemode.AUTO], AmmoFeed.Type.EXTERNAL,
		Weapon.AttachmentPoint.TOP_RAIL | Weapon.AttachmentPoint.MUZZLE | Weapon.AttachmentPoint.UNDER)
	
	# Create realistic attachments
	var scope = _create_test_attachment("ACOG_Scope", Attachment.AttachmentType.OPTICS,
		Weapon.AttachmentPoint.TOP_RAIL, 0.45)
	scope.accuracy_modifier = 0.7
	scope.magnification = 4.0
	
	var suppressor = _create_test_attachment("Tactical_Suppressor", Attachment.AttachmentType.MUZZLE,
		Weapon.AttachmentPoint.MUZZLE, 0.35)
	suppressor.recoil_modifier = 0.8
	suppressor.sound_suppression = 0.8
	
	var grip = _create_test_attachment("Vertical_Foregrip", Attachment.AttachmentType.UNDERBARREL,
		Weapon.AttachmentPoint.UNDER, 0.12)
	grip.recoil_modifier = 0.9
	grip.ergonomics_modifier = 1.1
	
	# Attach all three
	var scope_attached = weapon.attach_attachment(Weapon.AttachmentPoint.TOP_RAIL, scope)
	var suppressor_attached = weapon.attach_attachment(Weapon.AttachmentPoint.MUZZLE, suppressor)
	var grip_attached = weapon.attach_attachment(Weapon.AttachmentPoint.UNDER, grip)
	
	if scope_attached and suppressor_attached and grip_attached:
		TEST_RESULTS.append("✅ PASS: Multiple attachments can be attached simultaneously")
		
		# Verify all attachments are tracked
		var top_attachment = weapon.get_attachment(Weapon.AttachmentPoint.TOP_RAIL)
		var muzzle_attachment = weapon.get_attachment(Weapon.AttachmentPoint.MUZZLE)
		var under_attachment = weapon.get_attachment(Weapon.AttachmentPoint.UNDER)
		
		if top_attachment == scope and muzzle_attachment == suppressor and under_attachment == grip:
			TEST_RESULTS.append("✅ PASS: All attachments correctly tracked by weapon")
		else:
			TEST_RESULTS.append("❌ FAIL: Attachment tracking incorrect")
		
		# Verify stat stacking - both suppressor and grip affect recoil
		var expected_recoil = weapon.base_recoil_vertical * 0.8 * 0.9
		print("  Base Recoil: %.2f, Expected: %.2f, Actual: %.2f" % [weapon.base_recoil_vertical, expected_recoil, weapon.recoil_vertical])
		
		if abs(weapon.recoil_vertical - expected_recoil) < 0.001:
			TEST_RESULTS.append("✅ PASS: Attachment modifiers stack correctly")
		else:
			TEST_RESULTS.append("❌ FAIL: Attachment modifiers don't stack correctly: expected %.2f, got %.2f" % [expected_recoil, weapon.recoil_vertical])
	else:
		TEST_RESULTS.append("❌ FAIL: Failed to attach multiple attachments")

# ─── TEST 6: ATTACHMENT CONFLICTS ────────────────
func _test_attachment_conflicts():
	print("\n🎯 Testing Attachment Conflicts:")
	
	var weapon = _create_test_weapon_with_attachments("Conflict_Test", "9x19mm", 1.0, 600, 15,
		[Weapon.Firemode.SEMI], AmmoFeed.Type.EXTERNAL,
		Weapon.AttachmentPoint.TOP_RAIL)
	
	var attachment1 = _create_test_attachment("First_Scope", Attachment.AttachmentType.OPTICS,
		Weapon.AttachmentPoint.TOP_RAIL, 0.2)
	
	var attachment2 = _create_test_attachment("Second_Scope", Attachment.AttachmentType.OPTICS,
		Weapon.AttachmentPoint.TOP_RAIL, 0.25)
	
	# Attach first attachment
	var first_attach = weapon.attach_attachment(Weapon.AttachmentPoint.TOP_RAIL, attachment1)
	
	# Try to attach second to same point (should fail)
	var second_attach = weapon.attach_attachment(Weapon.AttachmentPoint.TOP_RAIL, attachment2)
	
	if first_attach and not second_attach:
		TEST_RESULTS.append("✅ PASS: Attachment point conflict correctly handled")
	else:
		TEST_RESULTS.append("❌ FAIL: Attachment point conflict not handled")
	
	# Test detaching and reattaching
	var detach_result = weapon.detach_attachment(Weapon.AttachmentPoint.TOP_RAIL)
	var reattach_result = weapon.attach_attachment(Weapon.AttachmentPoint.TOP_RAIL, attachment2)
	
	if detach_result and reattach_result:
		TEST_RESULTS.append("✅ PASS: Detach and reattach works correctly")
	else:
		TEST_RESULTS.append("❌ FAIL: Detach and reattach failed")

# ─── HELPER FUNCTIONS ────────────────────────────

func _create_test_attachment(name: String, type: int, attachment_point: int, mass: float) -> Attachment:
	var attachment = Attachment.new()
	attachment.name = name
	attachment.type = type
	attachment.attachment_point = attachment_point
	attachment.mass = mass
	return attachment

func _create_test_weapon_with_attachments(name: String, caliber: String, mass: float, firerate: int,
										capacity: int, firemodes: Array, feed_type: int,
										attachment_points: int) -> Weapon:
	var weapon = Weapon.new()
	weapon.name = name
	weapon.base_mass = mass
	weapon.firerate = firerate
	weapon.feed_type = feed_type
	weapon.base_reload_time = 2.0
	weapon.base_accuracy = 2.0
	weapon.recoil_vertical = 1.0
	weapon.recoil_horizontal = 0.5
	
	# Set attachment points
	weapon.attach_points = attachment_points
	
	# Set firemodes
	weapon.firemodes = 0
	for firemode in firemodes:
		weapon.firemodes |= firemode
	
	# Set default firemode
	if firemodes.has(Weapon.Firemode.SEMI):
		weapon.firemode = Weapon.Firemode.SEMI
	elif firemodes.has(Weapon.Firemode.BURST):
		weapon.firemode = Weapon.Firemode.BURST
		weapon.burst_counter = weapon.burst_count
	elif not firemodes.is_empty():
		weapon.firemode = firemodes[0]
	
	# Create ammo feed
	weapon.ammofeed = AmmoFeed.new()
	weapon.ammofeed.compatible_calibers = [caliber]
	weapon.ammofeed.capacity = capacity
	
	return weapon

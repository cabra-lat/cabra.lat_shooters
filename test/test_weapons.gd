# test_weapons.gd
@tool
class_name TestWeapons extends EditorScript

var TEST_RESULTS = []

func _run():
	print("🔫 Testing Advanced Weapon Features...")
	
	_test_firemode_cycling()
	_test_magazine_changing()
	_test_firing_sequence()
	_test_burst_fire()
	
	print("🔫 Testing Weapon System...")

	_test_weapon_creation()
	_test_firemode_system()
	_test_ammo_compatibility()
	_test_firing_mechanics()
	_test_reloading_system()
	_test_weapon_physics()
	_test_integration_with_ammo()
	
	# Print results
	print("\n✅ WEAPON TEST SUMMARY:")
	for result in TEST_RESULTS:
		print(result)
	print("\nDone.")

# ─── SIGNAL CAPTURE SYSTEM ──────────────────────

class SignalCapture:
	var captured_signals: Array = []
	var weapon: Weapon
	
	func _init(weapon_instance: Weapon):
		weapon = weapon_instance
		_connect_weapon_signals()
	
	func _connect_weapon_signals():
		# Connect each signal with the correct signature
		weapon.trigger_locked.connect(_on_trigger_locked)
		weapon.trigger_pressed.connect(_on_trigger_pressed)
		weapon.trigger_released.connect(_on_trigger_released)
		weapon.firemode_changed.connect(_on_firemode_changed)
		weapon.shell_ejected.connect(_on_shell_ejected)
		weapon.weapon_racked.connect(_on_weapon_racked)
		
		weapon.cartridge_fired.connect(_on_cartridge_fired)
		weapon.cartridge_ejected.connect(_on_cartridge_ejected)
		weapon.cartridge_inserted.connect(_on_cartridge_inserted)
		
		weapon.ammofeed_empty.connect(_on_ammofeed_empty)
		weapon.ammofeed_changed.connect(_on_ammofeed_changed)
		weapon.ammofeed_missing.connect(_on_ammofeed_missing)
		weapon.ammofeed_incompatible.connect(_on_ammofeed_incompatible)
	
	# Single parameter signals
	func _on_trigger_locked(weapon_param: Weapon):
		_capture_signal("trigger_locked", [weapon_param])
	
	func _on_trigger_pressed(weapon_param: Weapon):
		_capture_signal("trigger_pressed", [weapon_param])
	
	func _on_trigger_released(weapon_param: Weapon):
		_capture_signal("trigger_released", [weapon_param])
	
	func _on_firemode_changed(weapon_param: Weapon, mode: String):
		_capture_signal("firemode_changed", [weapon_param, mode])
	
	func _on_shell_ejected(weapon_param: Weapon):
		_capture_signal("shell_ejected", [weapon_param])
	
	func _on_weapon_racked(weapon_param: Weapon):
		_capture_signal("weapon_racked", [weapon_param])
	
	func _on_ammofeed_missing(weapon_param: Weapon):
		_capture_signal("ammofeed_missing", [weapon_param])
	
	# Two parameter signals
	func _on_cartridge_fired(weapon_param: Weapon, cartridge: Ammo):
		_capture_signal("cartridge_fired", [weapon_param, cartridge])
	
	func _on_cartridge_ejected(weapon_param: Weapon, cartridge: Ammo):
		_capture_signal("cartridge_ejected", [weapon_param, cartridge])
	
	func _on_cartridge_inserted(weapon_param: Weapon, cartridge: Ammo):
		_capture_signal("cartridge_inserted", [weapon_param, cartridge])
	
	func _on_ammofeed_incompatible(weapon_param: Weapon, ammofeed_param: AmmoFeed):
		_capture_signal("ammofeed_incompatible", [weapon_param, ammofeed_param])
	
	# Three parameter signals
	func _on_ammofeed_empty(weapon_param: Weapon, ammofeed_param: AmmoFeed):
		_capture_signal("ammofeed_empty", [weapon_param, ammofeed_param])
	
	func _on_ammofeed_changed(weapon_param: Weapon, old_feed: AmmoFeed, new_feed: AmmoFeed):
		_capture_signal("ammofeed_changed", [weapon_param, old_feed, new_feed])
	
	func _capture_signal(signal_name: String, args: Array):
		var signal_data = {
			"signal": signal_name,
			"timestamp": Time.get_ticks_msec(),
			"args": args
		}
		
		captured_signals.append(signal_data)
		print("📡 [%s] %s - Args: %s" % [weapon.name, signal_name, _format_args(args)])
	
	func _format_args(args: Array) -> String:
		var formatted = []
		for arg in args:
			if arg is Weapon:
				formatted.append("Weapon(%s)" % arg.name)
			elif arg is Ammo:
				formatted.append("Ammo(%s)" % arg.caliber)
			elif arg is AmmoFeed:
				formatted.append("AmmoFeed(%s)" % arg.compatible_calibers[0] if not arg.compatible_calibers.is_empty() else "AmmoFeed(empty)")
			elif arg == null:
				formatted.append("null")
			else:
				formatted.append(str(arg))
		return ", ".join(formatted)
	
	func clear():
		captured_signals.clear()
	
	func get_signal_count(signal_name: String) -> int:
		var count = 0
		for signal_data in captured_signals:
			if signal_data.signal == signal_name:
				count += 1
		return count
	
	func has_signal(signal_name: StringName) -> bool:
		return get_signal_count(signal_name) > 0
	
	func get_last_signal(signal_name: String = ""):
		if captured_signals.is_empty():
			return null
		
		if signal_name.is_empty():
			return captured_signals[-1]
		
		for i in range(captured_signals.size() - 1, -1, -1):
			if captured_signals[i].signal == signal_name:
				return captured_signals[i]
		
		return null
	
	func get_last_signal_args(signal_name: String) -> Array:
		var last_signal = get_last_signal(signal_name)
		return last_signal.args if last_signal else []

# ─── TEST 1: WEAPON CREATION & BASIC PROPERTIES ──
func _test_weapon_creation():
	print("\n🎯 Testing Weapon Creation:")
	
	var glock = _create_test_weapon("Glock_17", "9x19mm", 0.62, 1200, 17, 
		[Weapon.Firemode.SEMI], AmmoFeed.Type.EXTERNAL)
	
	if glock and glock.name == "Glock_17":
		TEST_RESULTS.append("✅ PASS: Weapon creation successful")
	else:
		TEST_RESULTS.append("❌ FAIL: Weapon creation failed")

# ─── TEST 2: FIREMODE SYSTEM ────────────────────
func _test_firemode_system():
	print("\n🎯 Testing Firemode System:")
	
	var assault_rifle = _create_test_weapon("Test_Rifle", "5.56x45mm", 3.0, 800, 30,
		[Weapon.Firemode.SEMI, Weapon.Firemode.AUTO], AmmoFeed.Type.EXTERNAL)
	
	if assault_rifle.is_firemode_available(Weapon.Firemode.SEMI):
		TEST_RESULTS.append("✅ PASS: SEMI firemode available")
	else:
		TEST_RESULTS.append("❌ FAIL: SEMI firemode not available")
	
	if assault_rifle.is_firemode_available(Weapon.Firemode.AUTO):
		TEST_RESULTS.append("✅ PASS: AUTO firemode available")
	else:
		TEST_RESULTS.append("❌ FAIL: AUTO firemode not available")
	
	if not assault_rifle.is_firemode_available(Weapon.Firemode.BURST):
		TEST_RESULTS.append("✅ PASS: BURST firemode correctly unavailable")
	else:
		TEST_RESULTS.append("❌ FAIL: BURST firemode incorrectly available")

# ─── TEST 3: AMMO COMPATIBILITY ─────────────────
func _test_ammo_compatibility():
	print("\n🎯 Testing Ammo Compatibility:")
	
	var ak47 = _create_test_weapon("AK-47", "7.62x39mm", 4.3, 600, 30,
		[Weapon.Firemode.SEMI, Weapon.Firemode.AUTO], AmmoFeed.Type.EXTERNAL)
	
	var compatible_feed = AmmoFeed.new()
	compatible_feed.type = AmmoFeed.Type.EXTERNAL
	compatible_feed.capacity = 30
	compatible_feed.compatible_calibers = ["7.62x39mm"]
	
	var ammo = Ammo.new()
	ammo.caliber = "7.62x39mm"
	ammo.cartridge_mass = 0.008
	ammo.muzzle_velocity = 720.0
	compatible_feed.insert(ammo)
	
	ak47.ammofeed = compatible_feed
	
	if ak47.ammofeed and not ak47.ammofeed.is_empty():
		TEST_RESULTS.append("✅ PASS: Direct ammo feed assignment works")
	else:
		TEST_RESULTS.append("❌ FAIL: Direct ammo feed assignment failed")

# ─── TEST 4: FIRING MECHANICS ───────────────────
func _test_firing_mechanics():
	print("\n🎯 Testing Firing Mechanics:")
	
	var weapon = _create_test_weapon("Test_Weapon", "9x19mm", 1.0, 600, 10,
		[Weapon.Firemode.SEMI], AmmoFeed.Type.EXTERNAL)
	
	var feed = AmmoFeed.new()
	feed.type = AmmoFeed.Type.EXTERNAL
	feed.capacity = 10
	feed.compatible_calibers = ["9x19mm"]
	
	var ammo = Ammo.new()
	ammo.caliber = "9x19mm"
	ammo.cartridge_mass = 0.008
	ammo.muzzle_velocity = 360.0
	feed.insert(ammo)
	
	weapon.ammofeed = feed
	
	if weapon.ammofeed and not weapon.ammofeed.is_empty():
		TEST_RESULTS.append("✅ PASS: Weapon recognizes available ammo")
	else:
		TEST_RESULTS.append("❌ FAIL: Weapon doesn't recognize available ammo")
	
	if weapon.can_fire:
		TEST_RESULTS.append("✅ PASS: Weapon can fire with ammo available")
	else:
		TEST_RESULTS.append("❌ FAIL: Weapon cannot fire despite having ammo")

# ─── TEST 5: RELOADING SYSTEM ───────────────────
func _test_reloading_system():
	print("\n🎯 Testing Reloading System:")
	
	var weapon = _create_test_weapon("Test_Weapon", "9x19mm", 1.0, 600, 15,
		[Weapon.Firemode.SEMI], AmmoFeed.Type.EXTERNAL)
	
	weapon.base_reload_time = 2.0
	
	var empty_feed = AmmoFeed.new()
	empty_feed.type = AmmoFeed.Type.EXTERNAL
	empty_feed.capacity = 15
	weapon.ammofeed = empty_feed
	
	if weapon.reload_time == 2.0:
		TEST_RESULTS.append("✅ PASS: Empty reload time correct")
	else:
		TEST_RESULTS.append("❌ FAIL: Empty reload time incorrect")

# ─── TEST 6: WEAPON PHYSICS ─────────────────────
func _test_weapon_physics():
	print("\n🎯 Testing Weapon Physics:")
	
	var weapon = _create_test_weapon("Test_Weapon", "9x19mm", 1.0, 600, 15,
		[Weapon.Firemode.SEMI], AmmoFeed.Type.EXTERNAL)
	
	weapon.base_accuracy = 2.0
	weapon.recoil_vertical = 1.0
	weapon.recoil_horizontal = 0.5
	
	var accuracy = weapon.get_current_accuracy()
	if accuracy >= 2.0:
		TEST_RESULTS.append("✅ PASS: Accuracy calculation works")
	else:
		TEST_RESULTS.append("❌ FAIL: Accuracy calculation broken")

# ─── TEST 7: INTEGRATION WITH AMMO ──────────────
func _test_integration_with_ammo():
	print("\n🎯 Testing Integration with Ammo:")
	
	# Skip if no ammo resources
	TEST_RESULTS.append("⚠️ SKIP: Integration test requires ammo resources")

# ─── TEST 8: FIREMODE CYCLING ───────────────────
func _test_firemode_cycling():
	print("\n🎯 Testing Firemode Cycling:")
	
	var weapon = _create_advanced_weapon("Advanced_Rifle", "5.56x45mm", 3.0, 800, 30,
		[Weapon.Firemode.SEMI, Weapon.Firemode.AUTO, Weapon.Firemode.BURST], 
		AmmoFeed.Type.EXTERNAL)
	
	# Setup signal capture
	var signal_capture = SignalCapture.new(weapon)
	
	if weapon.firemode == Weapon.Firemode.SEMI:
		TEST_RESULTS.append("✅ PASS: Defaults to SEMI with multiple options")
	else:
		TEST_RESULTS.append("❌ FAIL: Default firemode incorrect")
	
	signal_capture.clear()
	weapon.cycle_firemode()
	
	if weapon.firemode == Weapon.Firemode.AUTO:
		TEST_RESULTS.append("✅ PASS: Cycles from SEMI to AUTO")
	else:
		TEST_RESULTS.append("❌ FAIL: Failed to cycle to AUTO")
	
	# Check if firemode_changed signal was emitted
	if signal_capture.has_signal("firemode_changed"):
		TEST_RESULTS.append("✅ PASS: firemode_changed signal emitted")
		
		# Verify the signal contains the correct weapon
		var args = signal_capture.get_last_signal_args("firemode_changed")
		if args.size() >= 1 and args[0] == weapon:
			TEST_RESULTS.append("✅ PASS: firemode_changed contains correct weapon reference")
		else:
			TEST_RESULTS.append("❌ FAIL: firemode_changed has incorrect weapon reference")
	else:
		TEST_RESULTS.append("❌ FAIL: firemode_changed signal not emitted")
	
	signal_capture.clear()
	weapon.cycle_firemode()
	
	if weapon.firemode == Weapon.Firemode.BURST:
		TEST_RESULTS.append("✅ PASS: Cycles from AUTO to BURST")
	else:
		TEST_RESULTS.append("❌ FAIL: Failed to cycle to BURST")
	
	signal_capture.clear()
	weapon.cycle_firemode()
	
	if weapon.firemode == Weapon.Firemode.SEMI:
		TEST_RESULTS.append("✅ PASS: Cycles back to SEMI (wrap-around)")
	else:
		TEST_RESULTS.append("❌ FAIL: Failed to wrap-around to SEMI")

# ─── TEST 9: MAGAZINE CHANGING ──────────────────
func _test_magazine_changing():
	print("\n🎯 Testing Magazine Changing:")
	
	var weapon = _create_advanced_weapon("Test_Rifle", "5.56x45mm", 3.0, 800, 30,
		[Weapon.Firemode.SEMI], AmmoFeed.Type.EXTERNAL)
	
	# Setup signal capture
	var signal_capture = SignalCapture.new(weapon)
	
	var compatible_mag = AmmoFeed.new()
	compatible_mag.type = AmmoFeed.Type.EXTERNAL
	compatible_mag.capacity = 30
	compatible_mag.compatible_calibers = ["5.56x45mm"]
	
	var ammo = Ammo.new()
	ammo.caliber = "5.56x45mm"
	ammo.cartridge_mass = 0.012
	ammo.muzzle_velocity = 950.0
	compatible_mag.insert(ammo.duplicate())
	compatible_mag.insert(ammo.duplicate())
	
	# Set current feed for compatibility check
	weapon.ammofeed = AmmoFeed.new()
	weapon.ammofeed.compatible_calibers = ["5.56x45mm"]
	
	signal_capture.clear()
	var success = weapon.change_magazine(compatible_mag)
	
	if success and weapon.ammofeed and not weapon.ammofeed.is_empty():
		TEST_RESULTS.append("✅ PASS: Compatible magazine accepted and ammo available")
	else:
		TEST_RESULTS.append("❌ FAIL: Compatible magazine rejected or no ammo")
	
	# Check if ammofeed_changed signal was emitted
	if signal_capture.has_signal("ammofeed_changed"):
		TEST_RESULTS.append("✅ PASS: ammofeed_changed signal emitted")
		
		# Verify the signal contains correct parameters
		var args = signal_capture.get_last_signal_args("ammofeed_changed")
		if args.size() >= 3 and args[0] == weapon:
			TEST_RESULTS.append("✅ PASS: ammofeed_changed contains correct parameters")
		else:
			TEST_RESULTS.append("❌ FAIL: ammofeed_changed has incorrect parameters")
	else:
		TEST_RESULTS.append("❌ FAIL: ammofeed_changed signal not emitted")

# ─── TEST 10: FIRING SEQUENCE ───────────────────
func _test_firing_sequence():
	print("\n🎯 Testing Firing Sequence:")
	
	var weapon = _create_advanced_weapon("Test_Pistol", "9x19mm", 1.0, 600, 10,
		[Weapon.Firemode.SEMI], AmmoFeed.Type.EXTERNAL)
	
	# Setup signal capture
	var signal_capture = SignalCapture.new(weapon)
	
	# Load magazine
	var feed = AmmoFeed.new()
	feed.type = AmmoFeed.Type.EXTERNAL
	feed.capacity = 10
	feed.compatible_calibers = ["9x19mm"]
	
	var ammo = Ammo.new()
	ammo.caliber = "9x19mm"
	ammo.cartridge_mass = 0.008
	ammo.muzzle_velocity = 360.0
	
	for i in range(3):
		feed.insert(ammo.duplicate())
	
	weapon.ammofeed = feed
	
	# Chamber first round
	weapon.chambered_round = weapon.ammofeed.eject()
	
	signal_capture.clear()
	
	# First shot
	var first_result = weapon.pull_trigger()
	var first_fired = signal_capture.has_signal("cartridge_fired")
	var first_pressed = signal_capture.has_signal("trigger_pressed")
	
	if first_result and first_fired and first_pressed:
		TEST_RESULTS.append("✅ PASS: First shot fires correctly")
		
		# Verify cartridge_fired has correct parameters
		var fired_args = signal_capture.get_last_signal_args("cartridge_fired")
		if fired_args.size() >= 2 and fired_args[0] == weapon and fired_args[1] is Ammo:
			TEST_RESULTS.append("✅ PASS: cartridge_fired contains correct ammo reference")
	else:
		TEST_RESULTS.append("❌ FAIL: First shot failed")
	
	signal_capture.clear()
	
	# Second shot (should fail - semi control)
	var second_result = weapon.pull_trigger()
	var second_fired = signal_capture.has_signal("cartridge_fired")
	
	if not second_result and not second_fired:
		TEST_RESULTS.append("✅ PASS: Second shot blocked by semi-control")
	else:
		TEST_RESULTS.append("❌ FAIL: Second shot incorrectly fired")
	
	# Release trigger
	weapon.release_trigger()
	signal_capture.clear()
	
	# Third shot (should fire - chamber new round)
	if weapon.ammofeed and not weapon.ammofeed.is_empty():
		weapon.chambered_round = weapon.ammofeed.eject()
	
	var third_result = weapon.pull_trigger()
	var third_fired = signal_capture.has_signal("cartridge_fired")
	
	if third_result and third_fired:
		TEST_RESULTS.append("✅ PASS: Third shot fires after release")
	else:
		TEST_RESULTS.append("❌ FAIL: Third shot failed")
	
	if first_result and not second_result and third_result:
		TEST_RESULTS.append("✅ PASS: Semi-auto firing sequence works correctly")
	else:
		TEST_RESULTS.append("❌ FAIL: Semi-auto firing sequence broken")

# ─── TEST 11: BURST FIRE ────────────────────────
func _test_burst_fire():
	print("\n🎯 Testing Burst Fire:")
	
	var weapon = _create_advanced_weapon("Burst_Rifle", "5.56x45mm", 3.0, 800, 30,
		[Weapon.Firemode.BURST], AmmoFeed.Type.EXTERNAL)
	
	weapon.burst_count = 3
	weapon.firemode = Weapon.Firemode.BURST
	weapon.burst_counter = weapon.burst_count
	
	# Setup signal capture
	var signal_capture = SignalCapture.new(weapon)
	
	# Load magazine
	var feed = AmmoFeed.new()
	feed.type = AmmoFeed.Type.EXTERNAL
	feed.capacity = 30
	feed.compatible_calibers = ["5.56x45mm"]
	
	var ammo = Ammo.new()
	ammo.caliber = "5.56x45mm"
	ammo.cartridge_mass = 0.004
	ammo.muzzle_velocity = 950.0
	
	for i in range(10):
		feed.insert(ammo.duplicate())
	
	weapon.ammofeed = feed
	
	# Chamber first round
	weapon.chambered_round = weapon.ammofeed.eject()
	
	signal_capture.clear()
	
	# Fire burst (3 shots)
	var shots_fired = 0
	for i in range(4):  # Try 4 times
		if weapon.pull_trigger():
			shots_fired += 1
			# Auto-chamber next round
			if weapon.ammofeed and not weapon.ammofeed.is_empty() and shots_fired < 3:
				weapon.chambered_round = weapon.ammofeed.eject()
	
	var fire_count = signal_capture.get_signal_count("cartridge_fired")
	
	if shots_fired == 3 and fire_count == 3:
		TEST_RESULTS.append("✅ PASS: Burst fire limits to 3 shots")
	else:
		TEST_RESULTS.append("❌ FAIL: Burst fire count incorrect: %d shots" % shots_fired)
	
	# Reset burst
	weapon.release_trigger()
	signal_capture.clear()
	
	# Fire second burst
	if weapon.ammofeed and not weapon.ammofeed.is_empty():
		weapon.chambered_round = weapon.ammofeed.eject()
	
	shots_fired = 0
	for i in range(4):
		if weapon.pull_trigger():
			shots_fired += 1
			if weapon.ammofeed and not weapon.ammofeed.is_empty() and shots_fired < 3:
				weapon.chambered_round = weapon.ammofeed.eject()
	
	fire_count = signal_capture.get_signal_count("cartridge_fired")
	
	if shots_fired == 3 and fire_count == 3:
		TEST_RESULTS.append("✅ PASS: Burst fire resets on trigger release")
	else:
		TEST_RESULTS.append("❌ FAIL: Burst fire reset broken: %d shots" % shots_fired)

# ─── HELPER FUNCTIONS ────────────────────────────

func _create_test_weapon(name: String, caliber: String, mass: float, firerate: int,
						capacity: int, firemodes: Array, feed_type: int) -> Weapon:
	var weapon = Weapon.new()
	weapon.name = name
	weapon.mass = mass
	weapon.firerate = firerate
	weapon.feed_type = feed_type
	
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
	var ammo_feed = AmmoFeed.new()
	ammo_feed.type = feed_type
	ammo_feed.capacity = capacity
	ammo_feed.compatible_calibers = [caliber]
	weapon.ammofeed = ammo_feed
	
	return weapon

func _create_advanced_weapon(name: String, caliber: String, mass: float, firerate: int,
							capacity: int, firemodes: Array, feed_type: int) -> Weapon:
	var weapon = Weapon.new()
	weapon.name = name
	weapon.mass = mass
	weapon.firerate = firerate
	weapon.feed_type = feed_type
	weapon.base_reload_time = 2.0
	weapon.burst_count = 3
	
	weapon.firemodes = 0
	for firemode in firemodes:
		weapon.firemodes |= firemode
	
	if firemodes.has(Weapon.Firemode.SEMI):
		weapon.firemode = Weapon.Firemode.SEMI
	elif firemodes.has(Weapon.Firemode.BURST):
		weapon.firemode = Weapon.Firemode.BURST
		weapon.burst_counter = weapon.burst_count
	elif not firemodes.is_empty():
		weapon.firemode = firemodes[0]
	
	weapon.ammofeed = AmmoFeed.new()
	weapon.ammofeed.compatible_calibers = [caliber]
	weapon.ammofeed.capacity = capacity
	
	return weapon

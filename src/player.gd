class_name Player extends CharacterBody3D

signal player_proned
signal player_leaned
signal player_crouch
signal player_uncrouch
signal player_jumped
signal player_landed

@export var config: PlayerConfig  # No default instance — created in _ready if needed
@export var weapon: Resource

# DEV/DEBUG
@onready var ak47_magazine = preload("resources/magazine_ak47.tres")
@onready var ammo_762x39mm = preload("resources/ammo_7.62x39mm.tres")
# END DEV/DEBUG

@onready var moving_logic = $StateMachine/MovingLogic
@onready var firing_logic = $StateMachine/FiringLogic
@onready var crouch_logic = $StateMachine/CrouchLogic
@onready var head = $Head
@onready var shoulder = $Shoulder
@onready var hand = $Shoulder/Hand
@onready var focus_timer = $FocusTimer
@onready var reload_timer = $ReloadTimer
@onready var firemode_timer = $FiremodeTimer
@onready var weapon_cycle = $FirerateTimer
@onready var debug_label = $HUD/CurrentState

var push = 10
var damping = 1
var gravity = 9.82
var direction = Vector3.ZERO
var max_velocity = 0
var mouse_sensitivity = 1

func _on_trigger_locked():
	print("[can't pull the trigger]")

func _on_cartridge_fired(ejected):
	for chambered in ejected:
		print("Pow! ", chambered.caliber)

func _on_trigger_released():
	pass

func _on_firemode_changed(new):
	$HUD.show_firemode(new)
	print("changed firemode: %s" % new)

func _on_ammofeed_empty():
	print("Click!")

func _on_ammofeed_missing():
	print('Click!')
	
func _on_ammofeed_changed(old, new):
	print("changed mag %d/%d to %d/%d"
		 % [old.remaining  if old else 0,
			old.max_capacity if old else 0,
			new.remaining,
			new.max_capacity])

func _on_ammofeed_incompatible():
	print("- This doesn't fit here")

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Initialize player if not assigned in inspector
	if config == null:
		config = PlayerConfig.new()
	
	# Fill debug magazine
	for i in range(ak47_magazine.max_capacity):
		ak47_magazine.insert(ammo_762x39mm)
	
	# Connect weapon signals
	weapon.connect("trigger_locked", Callable(self, "_on_trigger_locked"))
	weapon.connect("trigger_pressed", Callable(self, "_on_trigger_pressed"))
	weapon.connect("trigger_released", Callable(self, "_on_trigger_released"))
	weapon.connect("firemode_changed", Callable(self, "_on_firemode_changed"))
	weapon.connect("cartridge_fired", Callable(self, "_on_cartridge_fired"))
	weapon.connect("ammofeed_empty", Callable(self, "_on_ammofeed_empty"))
	weapon.connect("ammofeed_changed", Callable(self, "_on_ammofeed_changed"))
	weapon.connect("ammofeed_missing", Callable(self, "_on_ammofeed_missing"))
	weapon.connect("ammofeed_incompatible", Callable(self, "_on_ammofeed_incompatible"))
	
	# Configure movement parameters once
	set_up_direction(Vector3.UP)
	set_floor_stop_on_slope_enabled(false)
	set_max_slides(4)
	set_floor_max_angle(PI / 4)

func _input(event):
	if event is InputEventMouseMotion:
		rotation_degrees.y -= event.relative.x * mouse_sensitivity / 10
		head.rotation_degrees.x = clamp(head.rotation_degrees.x - event.relative.y * mouse_sensitivity / 10, -90, 90)

func _on_focus_timeout():
	Input.action_release("focus")

func _on_reload_timeout():
	Input.action_release("reload")

func _on_firemode_timeout():
	Input.action_release("firemode")

func handle_conditions():
	moving_logic.set_condition("on_ground", is_on_floor())
	moving_logic.set_condition("on_air", not is_on_floor())
	moving_logic.set_condition("+move", abs(direction.length()) > 0)
	moving_logic.set_condition("-move", abs(direction.length()) == 0)
	moving_logic.set_condition("+jump", Input.is_action_just_pressed("jump"))
	moving_logic.set_condition("+sprint", Input.is_action_pressed("sprint"))
	moving_logic.set_condition("-sprint", Input.is_action_just_released("sprint"))
	
	crouch_logic.set_condition("+lean", Input.is_action_just_pressed("lean_left") or Input.is_action_just_pressed("lean_right"))
	crouch_logic.set_condition("-lean", not (Input.is_action_pressed("lean_left") or Input.is_action_pressed("lean_right")))
	crouch_logic.set_condition("+crouch", Input.is_action_just_pressed("crouch") or Input.is_action_just_pressed("crouch_toggle"))
	crouch_logic.set_condition("-crouch", Input.is_action_just_released("crouch") or Input.is_action_just_pressed("crouch_toggle"))
	crouch_logic.set_condition("+prone", Input.is_action_just_pressed("prone") or Input.is_action_just_pressed("prone_toggle"))
	crouch_logic.set_condition("-prone", Input.is_action_just_released("prone") or Input.is_action_just_pressed("prone_toggle"))
	
	firing_logic.set_condition("+focus", Input.is_action_just_pressed("focus"))
	firing_logic.set_condition("-focus", Input.is_action_just_released("aim") or Input.is_action_just_released("focus"))
	firing_logic.set_condition("+aim", Input.is_action_just_pressed("aim"))
	firing_logic.set_condition("-aim", Input.is_action_just_released("aim"))
	firing_logic.set_condition("+aim_pressed", Input.is_action_pressed("aim"))
	firing_logic.set_condition("+fire", Input.is_action_just_pressed("fire"))
	firing_logic.set_condition("-fire", Input.is_action_just_released("fire"))
	firing_logic.set_condition("+fire_pressed", Input.is_action_pressed("fire"))
	firing_logic.set_condition("+reload", Input.is_action_just_pressed("reload"))
	firing_logic.set_condition("-reload", Input.is_action_just_released("reload"))
	firing_logic.set_condition("+firemode", Input.is_action_just_pressed("firemode"))
	firing_logic.set_condition("-firemode", Input.is_action_just_released("firemode"))

func handle_moving_logic(delta, debug_text):
	var current_state = moving_logic.get_current_state()
	debug_text += "[Moving machine]\nstate: %s\n" % current_state
	match current_state:
		"Idle":
			config.idle()
		"Walk":
			config.walk()
		"Sprint":
			config.sprint()
		"Jump":
			velocity.y += config.jump_impulse  # Apply impulse once, not scaled by delta
			emit_signal("player_jumped")
		"Fall":
			crouch_logic.set_condition("+lean", false)
			crouch_logic.set_condition("-lean", true)
			max_velocity = max(max_velocity, velocity.length())
			if moving_logic.get_condition("on_ground"):
				var a = abs(max_velocity - velocity.length()) / delta
				var g = a / gravity
				var letality_ratio = g / config.letal_acceleration
				if letality_ratio > 1:
					print("Letal fall damage (%.2f g)" % g)
				elif letality_ratio > .5:
					print("Minor fall damage (%.2f g)" % g)
				else:
					print("Safely landed     (%.2f g)" % g)
				max_velocity = 0
				emit_signal("player_landed")
	return debug_text

func handle_crouch_logic(delta, debug_text):
	var current_state = crouch_logic.get_current_state()
	debug_text += "[Crouch machine]\nstate: %s\n" % current_state
	match current_state:
		"Idle":
			if crouch_logic.get_condition("+prone"):
				emit_signal("player_proned")
			if crouch_logic.get_condition("+crouch"):
				emit_signal("player_crouch")
		"Crouch":
			config.crouch()
			if crouch_logic.get_condition("-crouch"):
				emit_signal("player_uncrouch")
			if crouch_logic.get_condition("+prone"):
				emit_signal("player_proned")
		"Prone":
			config.prone()
			if crouch_logic.get_condition("+crouch"):
				emit_signal("player_crouch")
			if crouch_logic.get_condition("-prone"):
				emit_signal("player_uncrouch")
		"Lean":
			config.lean()
			if Input.is_action_pressed("lean_left"):
				emit_signal("player_leaned", +1)
			elif Input.is_action_pressed("lean_right"):
				emit_signal("player_leaned", -1)
			else:
				emit_signal("player_leaned", 0)
	return debug_text

func handle_firing_logic(delta, debug_text):
	var current_state = firing_logic.get_current_state()
	debug_text += "[Firing machine]\nstate: %s\n" % current_state
	
	match current_state:
		"Idle":
			pass
		"Aim":
			pass
		"Fire":
			weapon_cycle.wait_time = 60.0 / float(weapon.firerate)
			if weapon_cycle.is_stopped():
				weapon.pull_trigger()
				weapon_cycle.start()
			if firing_logic.get_condition("-aim"):
				print("Stopped aiming")
			if firing_logic.get_condition("+aim"):
				print("Aiming again")
			if firing_logic.get_condition("-fire"):
				weapon.release_trigger()
				weapon_cycle.stop()
		"Reload":
			reload_timer.wait_time = weapon.reload_time
			if reload_timer.is_stopped():
				reload_timer.start()
			if firing_logic.get_condition("-reload"):
				var remaining_time = reload_timer.wait_time - reload_timer.time_left
				if remaining_time > 0:
					if weapon.ammofeed:
						$HUD.show_ammo_left(weapon.ammofeed.remaining, weapon.ammofeed.max_capacity)
					else:
						$HUD.show_popup("no feed")
				else:
					weapon.change_magazine(ak47_magazine)
				reload_timer.stop()
		"Focus":
			config.focus()
			if focus_timer.is_stopped():
				focus_timer.start()
			if firing_logic.get_condition("-focus"):
				focus_timer.stop()
		"FireModes":
			if firemode_timer.is_stopped():
				firemode_timer.start()
			if firing_logic.get_condition("-firemode"):
				var remaining_time = firemode_timer.wait_time - firemode_timer.time_left
				if remaining_time == 0:
					weapon.safe_firemode()
				elif remaining_time > 0.05:
					weapon.cycle_firemode()
				firemode_timer.stop()
	
	# Disable sprint/jump during firing actions
	if current_state in ["Aim", "Fire", "Reload", "Focus"]:
		moving_logic.set_condition("+sprint", false)
		moving_logic.set_condition("-sprint", true)
	
	return debug_text
	
func _physics_process(delta):
	var debug_text = "FPS: %d\n" % Engine.get_frames_per_second()

	# 1. GET INPUT → DIRECTION
	direction = Vector3.ZERO
	if Input.is_action_pressed("forward"): direction += Vector3.FORWARD
	if Input.is_action_pressed("back"):    direction += Vector3.BACK
	if Input.is_action_pressed("left"):    direction += Vector3.LEFT
	if Input.is_action_pressed("right"):   direction += Vector3.RIGHT
	if direction.length() > 0.01:
		direction = direction.normalized().rotated(Vector3.UP, rotation.y)

	# 2. UPDATE STATE MACHINE CONDITIONS
	handle_conditions()

	# 3. APPLY GRAVITY
	if is_on_floor():
		velocity.y = 0
	else:
		velocity.y -= gravity * delta

	# 4. UPDATE PLAYER STATE (which sets config.speed)
	debug_text = handle_moving_logic(delta, debug_text)
	debug_text = handle_crouch_logic(delta, debug_text)
	debug_text = handle_firing_logic(delta, debug_text)
	$HUD/CurrentState.text = debug_text

	# 5. APPLY MOVEMENT USING UPDATED SPEED
	velocity.x = direction.x * config.speed
	velocity.z = direction.z * config.speed

	move_and_slide()

	# Apply damping
	velocity.x *= 1 - exp(-damping * delta)
	velocity.z *= 1 - exp(-damping * delta)

	# Apply push force to collided bodies
	for index in get_slide_collision_count():
		var collision = get_slide_collision(index)
		var collider = collision.get_collider()
		if collider and collider.is_in_group("bodies"):
			collider.apply_central_impulse(-collision.normal * push)

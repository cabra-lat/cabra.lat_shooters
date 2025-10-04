class_name Player extends CharacterBody3D

const VIEWMODEL_NAME = "WeaponViewModel"

signal player_proned
signal player_leaned
signal player_crouch
signal player_uncrouch
signal player_jumped
signal player_landed
signal player_aiming_start
signal player_aiming_stop
signal player_reload
signal player_equipped
signal player_unnequip
signal player_ammofeed_insert
signal player_ammofeed_check
signal player_debug

@export var config: PlayerConfig  # No default instance — created in _ready if needed
@export var weapon: Weapon
@export var inventory: Inventory

@onready var moving_logic = $StateMachine/MovingLogic
@onready var firing_logic = $StateMachine/FiringLogic
@onready var crouch_logic = $StateMachine/CrouchLogic
@onready var head = $Head
@onready var collision = $CollisionShape3D
@onready var camera = $Head/Camera3D
@onready var shoulder = $Head/Shoulder
@onready var hand = $Head/Shoulder/Hand
@onready var focus_timer = $FocusTimer
@onready var reload_timer = $ReloadTimer
@onready var firemode_timer = $FiremodeTimer
@onready var weapon_cycle = $FirerateTimer

var push = 10
var damping = 1
var gravity = 9.82
var direction = Vector3.ZERO
var max_velocity = 0
var mouse_sensitivity = 1

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Initialize player if not assigned in inspector
	if config == null:
		config = PlayerConfig.new()
	if inventory == null:
		inventory = Inventory.new()

	# Connect state machine entry signals
	for logic in [moving_logic, crouch_logic, firing_logic]:
		logic.connect("state_entered", Callable(self, "_on_state_entered"))
		logic.connect("state_changed", Callable(self, "_on_state_changed"))
		logic.connect("state_exited", Callable(self, "_on_state_exited"))
	
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

func _on_weapon_cycle_timeout():
	if weapon and firing_logic.get_current_state() == "Fire":
		weapon.pull_trigger()
		# Auto-restart for auto-fire
		if weapon.is_automatic():
			weapon_cycle.start()

func handle_conditions():
	moving_logic.set_condition("on_ground", is_on_floor())
	moving_logic.set_condition("on_air", not is_on_floor())
	moving_logic.set_condition("+move", abs(direction.length()) > 0)
	moving_logic.set_condition("-move", abs(direction.length()) == 0)
	moving_logic.set_condition("+jump", Input.is_action_just_pressed("jump"))
	moving_logic.set_condition("+sprint", Input.is_action_pressed("sprint"))
	moving_logic.set_condition("-sprint", Input.is_action_just_released("sprint"))
	
	crouch_logic.set_condition("lean_right", Input.is_action_just_pressed("lean_right"))
	crouch_logic.set_condition("lean_left", Input.is_action_just_pressed("lean_left"))
	crouch_logic.set_condition("+lean", crouch_logic.get_condition("lean_left")
									 or crouch_logic.get_condition("lean_right"))
	crouch_logic.set_condition("-lean", Input.is_action_just_released("lean_right")
									or Input.is_action_just_released("lean_left"))
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
	firing_logic.set_condition("+equip", Input.is_action_just_pressed("weapon_slot1") \
									  or Input.is_action_just_pressed("weapon_slot2") \
									  or Input.is_action_just_pressed("weapon_slot3") )
	firing_logic.set_condition("-equip", Input.is_action_just_pressed("weapon_drop"))

func _on_state_exited(state: String):
	match state:
		"Fire":
			weapon.release_trigger()
			weapon_cycle.stop()  # ← Critical!
		"Equip": pass
		"Focus":
			focus_timer.stop()
		"LeanRight","LeanLeft":
			lean(0)
			emit_signal("player_leaned", 0)
		"FireModes":
			if firemode_timer.time_left == 0:
				weapon.safe_firemode()
			else:
				weapon.cycle_firemode()
			firemode_timer.stop()
		"Reload":
			if reload_timer.time_left == 0:
				emit_signal("player_ammofeed_insert")
			else:
				emit_signal("player_ammofeed_check", \
				 weapon.ammofeed.remaining, \
				 weapon.ammofeed.max_capacity)
			reload_timer.stop()
	
func _on_state_entered(state: String):
	match state:
		"Fall": pass # Fall has no entry anim — handled on landing
		"Equip":
			weapon = inventory.contents[0].content as Weapon
			equip()
			emit_signal("player_equipped")
		"Bare":
			unequip()
			emit_signal("player_unnequip")
		"Fire":
			weapon_cycle.wait_time = 60.0 / float(weapon.firerate)
			weapon.pull_trigger()  # First shot immediately
			if weapon.is_automatic():
				weapon_cycle.start()
		"FireModes":
			if firemode_timer.is_stopped():
				firemode_timer.start()
		"Focus":
			if focus_timer.is_stopped():
				focus_timer.start()
		"Reload":
			reload_timer.wait_time = weapon.reload_time
			if reload_timer.is_stopped():
				reload_timer.start()
			emit_signal("player_reload")
		"Aim":
			aim()
			emit_signal("player_aiming_start")
		"Crouch":
			crouch()
			emit_signal("player_crouch")
		"Prone":
			prone()
			emit_signal("player_proned")
		"Jump":
			velocity.y += config.jump_impulse  # Apply impulse once, not scaled by delta
			jumped()
			emit_signal("player_jumped")
		"LeanRight":
			lean(-1)
			emit_signal("player_leaned", -1)
		"LeanLeft":
			lean(+1)
			emit_signal("player_leaned", +1)
			
func _on_state_changed(new_state: String, old_state: String):
	match new_state:
		"Idle":
			if old_state in ["Crouch", "Prone"]:
				uncrouch()
				emit_signal("player_uncrouch")
	
	if old_state == "Aim":
		rest()
		emit_signal("player_aiming_stop")

func handle_process(delta, debug_text):
	var state = moving_logic.get_current_state()
	debug_text += "[Moving] %s\n" % state
	
	match state:
		"Idle": config.idle()
		"Walk":
			config.walk()
			move(delta)  # Continuous
		"Sprint": 
			config.sprint()
			move(delta)  # Continuous

	state = crouch_logic.get_current_state()
	debug_text += "[Crouch machine]\nstate: %s\n" % state
	
	match state:
		"Prone": config.prone()
		"Lean":  config.lean()
		
	state = firing_logic.get_current_state()
	debug_text += "[Firing machine]\nstate: %s\n" % state
	
	match state:
		"Focus": config.focus()
	
	# Disable sprint/jump during firing actions
	if state in ["Aim", "Fire", "Reload", "Focus"]:
		moving_logic.set_condition("+sprint", false)
		moving_logic.set_condition("-sprint", true)
	
	return debug_text

func aim():
	var aim_tween = create_tween()
	aim_tween.tween_property(camera, "fov", config.aim_fov, config.aim_time) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	aim_tween.tween_property(camera, "position:x", config.aim_down_amount, config.aim_time) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)

func rest():
	var aim_tween = create_tween()
	
	aim_tween.tween_property(camera, "fov", config.default_fov, config.aim_time) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	aim_tween.tween_property(hand, "position:x",  0, config.aim_time) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)


func move(delta: float):
	# Changes in FOV
	camera.fov = lerp(camera.fov, config.camera_fov, 5 * delta)
	head.position.y = lerp(head.position.y, config.camera_height, 10 * delta)

	# Head Bobbing
	if config.speed > 0:
		var speed_ratio = config.speed / config.walk_speed
		var amplitude = 0.5 * speed_ratio
		config.head_bobbing = -config.head_bobbing
		var animation_speed = 0.25 / clamp(speed_ratio, 1, 1.6)
		var new_vector = Vector3(-amplitude, 0, config.head_bobbing)
		var move_tween = create_tween()
		move_tween \
			.tween_property(camera, "rotation_degrees", new_vector, animation_speed) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)
		move_tween.tween_property(camera, "rotation_degrees", Vector3.ZERO, animation_speed) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)

func lean(direction):
	var animation_speed = 0.1
	var angle = config.lean_angle * direction
	# Convert degrees to radians for sin()
	var displ = head.position.y * sin(deg_to_rad(angle))

	var crouch_tween = create_tween()
	crouch_tween.tween_property(head, "rotation_degrees:z", angle, animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	crouch_tween.tween_property(head, "position:x", displ, animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	crouch_tween.tween_property(collision, "rotation_degrees:z", angle, animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	crouch_tween.tween_property(collision, "position:x", displ, animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func prone(reverse = false):
	var animation_speed = 0.1
	var crouch_tween = create_tween()
	if not reverse:
		crouch_tween.tween_property(head, "position:y",  0, animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		crouch_tween.tween_property(collision, "shape:height", 0, animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		crouch_tween.tween_property(head, "position:y", 0.9, animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		crouch_tween.tween_property(collision, "shape:height", 0.9, animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func crouch():
	var crouch_tween = create_tween()
	var animation_speed = 0.4
	crouch_tween.tween_property(head, "position:y", 0.9 / 1.5, animation_speed) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	crouch_tween.tween_property(collision, "shape:height", 1.0 / 1.5, animation_speed) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	crouch_tween.tween_property(camera, "rotation_degrees:z", -1, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.35)
	crouch_tween.tween_property(camera, "rotation_degrees:z",  0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.5)
	crouch_tween.tween_property(camera, "rotation_degrees:x", -1, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.35)
	crouch_tween.tween_property(camera, "rotation_degrees:x",  0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.5)


func uncrouch():
	var crouch_tween = create_tween()
	
	crouch_tween.tween_property(head, "position:y", 0.9, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	crouch_tween.tween_property(collision, "shape:height", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	crouch_tween.tween_property(camera, "rotation_degrees:z", 1, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	crouch_tween.tween_property(camera, "rotation_degrees:z",-1, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.15)
	crouch_tween.tween_property(camera, "rotation_degrees:z", 0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.3)
	crouch_tween.tween_property(camera, "rotation_degrees:x", -1, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	crouch_tween.tween_property(camera, "rotation_degrees:x",  0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.3)


func jumped():
	var jump_tween = create_tween()
	
	jump_tween.tween_property(camera, "rotation_degrees:x", -5, 0.2) \
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	jump_tween.tween_property(camera, "rotation_degrees:x", 0, 0.4)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_delay(0.2)
	jump_tween.tween_property(camera, "rotation_degrees:z", -1, 0.3) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT) \
		.set_delay(0.2)
	jump_tween.tween_property(camera, "rotation_degrees:z",  0, 0.3) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT) \
		.set_delay(0.5)
	jump_tween.tween_property(camera, "position:y", -0.5, 0.2) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	jump_tween.tween_property(camera, "position:y",    0, 0.4) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT) \
		.set_delay(0.2)

func landed():
	
	var jump_tween = create_tween()
	jump_tween.tween_property(camera, "position:y", -0.5, 0.15) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	jump_tween.tween_property(camera, "position:y",    0, 0.35) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT) \
		.set_delay(0.15)
	jump_tween.tween_property(camera, "rotation_degrees:x", -5, 0.3) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	jump_tween.tween_property(camera, "rotation_degrees:x",  0, 0.3) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT) \
		.set_delay(0.3)
	jump_tween.tween_property(camera, "rotation_degrees:z", -1, 0.4) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	jump_tween.tween_property(camera, "rotation_degrees:z",  0, 0.3) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT) \
		.set_delay(0.4)

func unequip():
	var old_vm = hand.get_node_or_null(VIEWMODEL_NAME)
	if old_vm:
		old_vm.queue_free()
	weapon = null

func equip():
	if not weapon: return
	var new_vm = weapon.viewmodel.instantiate()
	new_vm.name = VIEWMODEL_NAME
	hand.add_child(new_vm)

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
	debug_text = handle_process(delta, debug_text)
	emit_signal("player_debug", debug_text)
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

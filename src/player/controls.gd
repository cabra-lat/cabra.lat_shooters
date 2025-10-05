class_name Player extends CharacterBody3D

signal moved(player: Player, delta: float)
signal leaned(player: Player, direction: int)
signal proned(player: Player, reverse: bool)
signal crouched(player: Player, reverse: bool)
signal aiming(player: Player, reverse: bool)
signal jumped(player: Player)
signal landed(player: Player, max_velocity: float, delta: float)
signal reloaded(player: Player)
signal equipped(player: Player)
signal unequiped(player: Player)
signal insert_ammofeed(player: Player)
signal check_ammofeed(player: Player, ammofeed: AmmoFeed)
signal debug(player: Player, text: String)

@export var config: PlayerConfig  # No default instance — created in _ready if needed
@export var weapon: Weapon
@export var inventory: Inventory

@onready var moving_logic = $StateMachine/MovingLogic
@onready var firing_logic = $StateMachine/FiringLogic
@onready var crouch_logic = $StateMachine/CrouchLogic
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var head:      Node3D           = $Head
@onready var camera:    Camera3D         = $Head/Camera3D
@onready var shoulder:  Node3D           = $Head/Shoulder
@onready var hand:      Node3D           = $Head/Shoulder/Hand
@onready var focus_timer:    Timer = $FocusTimer
@onready var reload_timer:   Timer = $ReloadTimer
@onready var firemode_timer: Timer = $FiremodeTimer
@onready var weapon_cycle:   Timer = $FirerateTimer

var push = 10
var damping = 1
var gravity = 9.82
var direction = Vector3.ZERO
var max_velocity = 0
var mouse_sensitivity = 1

# Tracks base posture for reload/firemode return
var _base_posture: String = "Idle"

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

	# Connect weapon cycle
	weapon_cycle.connect("timeout", _on_weapon_cycle_timeout)

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
	var state = firing_logic.get_current_state()
	if weapon \
	and state in ["FiringIdle", "FiringAim", "FiringFocus"] \
	or weapon.burst_control > 0:
		weapon.pull_trigger()
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
	crouch_logic.set_condition("+lean", crouch_logic.get_condition("lean_left") or crouch_logic.get_condition("lean_right"))
	crouch_logic.set_condition("-lean", Input.is_action_just_released("lean_right") or Input.is_action_just_released("lean_left"))
	crouch_logic.set_condition("+crouch", Input.is_action_just_pressed("crouch") or Input.is_action_just_pressed("crouch_toggle"))
	crouch_logic.set_condition("-crouch", Input.is_action_just_released("crouch") or Input.is_action_just_pressed("crouch_toggle"))
	crouch_logic.set_condition("+prone", Input.is_action_just_pressed("prone") or Input.is_action_just_pressed("prone_toggle"))
	crouch_logic.set_condition("-prone", Input.is_action_just_released("prone") or Input.is_action_just_pressed("prone_toggle"))
	
	firing_logic.set_condition("+focus", Input.is_action_just_pressed("focus"))
	firing_logic.set_condition("-focus", Input.is_action_just_released("focus"))
	firing_logic.set_condition("+aim", Input.is_action_just_pressed("aim"))
	firing_logic.set_condition("-aim", Input.is_action_just_released("aim"))
	firing_logic.set_condition("+fire", Input.is_action_just_pressed("fire"))
	firing_logic.set_condition("-fire", Input.is_action_just_released("fire"))
	firing_logic.set_condition("+reload", Input.is_action_just_pressed("reload"))
	firing_logic.set_condition("-reload", Input.is_action_just_released("reload"))
	firing_logic.set_condition("+firemode", Input.is_action_just_pressed("firemode"))
	firing_logic.set_condition("-firemode", Input.is_action_just_released("firemode"))
	firing_logic.set_condition("+equip", Input.is_action_just_pressed("weapon_slot1") \
									  or Input.is_action_just_pressed("weapon_slot2") \
									  or Input.is_action_just_pressed("weapon_slot3"))
	firing_logic.set_condition("-equip", Input.is_action_just_pressed("weapon_drop"))


func _on_state_exited(state: String):
	match state:
		"Aiming": aiming.emit(self, true)
		"Crouch": crouched.emit(self, true)
		"Prone":  proned.emit(self, true)
		"FiringIdle", "FiringAim", "FiringFocus":
			if weapon:
				weapon.release_trigger()
				weapon_cycle.stop()
				
		"Focus", "HoldingBreath":
			focus_timer.stop()
			
		"ChangingMode":
			if weapon:
				if firemode_timer.time_left == 0:
					weapon.safe_firemode()
				else:
					weapon.cycle_firemode()
			firemode_timer.stop()
		"Fall":
			landed.emit(self, max_velocity, get_process_delta_time())
			max_velocity = 0
		"Reload":
			if weapon:
				if reload_timer.time_left == 0:
					insert_ammofeed.emit(self)
				else:
					check_ammofeed.emit(self, weapon.ammofeed)
				firing_logic.get("parameters/playback").travel(_base_posture)
			reload_timer.stop()
			
		"LeanRight", "LeanLeft":
			leaned.emit(self, 0)

func _on_state_entered(state: String):
	match state:
		# Track base postures
		"Idle", "Aiming", "HoldingBreath":
			_base_posture = state
			
		"BareHands":
			unequiped.emit(self)
			
		# Firing states
		"FiringIdle", "FiringAim", "FiringFocus":
			if weapon:
				weapon_cycle.wait_time = 60.0 / float(weapon.firerate)
				weapon.pull_trigger()  # First shot
				if weapon.is_automatic():
					weapon_cycle.start()
					
		# Other actions
		"ChangingMode":
			if firemode_timer.is_stopped():
				firemode_timer.start()
		"Focus", "HoldingBreath":
			if focus_timer.is_stopped():
				focus_timer.start()
		"Reload":
			if weapon:
				reload_timer.wait_time = weapon.reload_time
				if reload_timer.is_stopped():
					reload_timer.start()
				reloaded.emit(self)
		"Aiming": aiming.emit(self)
		"Crouch": crouched.emit(self)
		"Prone": proned.emit(self)
		"Jump":
			velocity.y += config.jump_impulse
			jumped.emit(self)
		"LeanRight": leaned.emit(self, -1)
		"LeanLeft": leaned.emit(self, +1)

func _on_state_changed(new_state: String, old_state: String):
	# Uncrouch on Idle
	if new_state == "Idle" and old_state in ["Crouch", "Prone"]:
		crouched.emit(self, true)
	if old_state == "BareHands":
		weapon = inventory.contents[0].content as Weapon
		equipped.emit(self)
	# Stop aiming when leaving aim postures (and not entering firing)
	if old_state in ["Aiming", "HoldingBreath"] and new_state not in ["FiringAim", "FiringFocus"]:
		aiming.emit(self, true)


func handle_process(delta, debug_text):
	var state = moving_logic.get_current_state()
	debug_text += "[Moving] %s\n" % state
	
	match state:
		"Idle": config.idle()
		"Walk":
			config.walk()
			moved.emit(self, delta)
		"Sprint": 
			config.sprint()
			moved.emit(self, delta)
		"Fall":
			max_velocity = max(max_velocity, velocity.length())

	state = crouch_logic.get_current_state()
	debug_text += "[Crouch machine]\nstate: %s\n" % state
	match state:
		"Prone": config.prone()
		"Lean":  config.lean()
		
	state = firing_logic.get_current_state()
	debug_text += "[Firing machine]\nstate: %s\n" % state
	match state:
		"Focus", "HoldingBreath":
			config.focus()
	
	# Disable sprint during weapon actions
	if state in ["Aiming", "HoldingBreath", "FiringIdle", "FiringAim", "FiringFocus", "Reload", "FireModes"]:
		moving_logic.set_condition("+sprint", false)
		moving_logic.set_condition("-sprint", true)
	
	return debug_text


# --- Main Loop ---
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

	# 4. UPDATE PLAYER STATE
	debug_text = handle_process(delta, debug_text)
	debug.emit(self, debug_text)

	# 5. APPLY MOVEMENT
	velocity.x = direction.x * config.speed
	velocity.z = direction.z * config.speed
	move_and_slide()

	# Apply damping
	velocity.x *= 1 - exp(-damping * delta)
	velocity.z *= 1 - exp(-damping * delta)

	# Apply push force
	for index in get_slide_collision_count():
		var collision = get_slide_collision(index)
		var collider = collision.get_collider()
		if collider and collider.is_in_group("bodies"):
			collider.apply_central_impulse(-collision.normal * push)

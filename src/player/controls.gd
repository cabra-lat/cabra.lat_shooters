class_name Player extends CharacterBody3D

const IDLE           = "Idle"
const JUMPING        = "Jump"
const PRONING        = "Prone"
const CROUCHING      = "Crouch"
const BARE_HANDED    = "BareHands"
const FIRING_IDLE    = "Firing"
const FIRING_AIM     = "AimingFiring"
const FIRING_FOCUS   = "HoldingBreathFiring"
const AIMING         = "Aiming"
const FOCUSING       = "HoldingBreath"
const CHANGING_MODE  = "ChangingMode"
const FALLING        = "Fall"
const LEANING        = "Lean"
const LEANING_RIGHT  = "LeanRight"
const LEANING_LEFT   = "LeanLeft"
const RELOADING      = "Reload"
const SPRINTING      = "Sprint"
const WALKING        = "Walk"
const FIRING_STATES = [ FIRING_IDLE, FIRING_AIM, FIRING_FOCUS]
const AIM_STATES    = [ AIMING, FOCUSING ]
const CONFIG_STATES = [ RELOADING, CHANGING_MODE ]
const MOVING_STATES = [ WALKING, SPRINTING, JUMPING, FALLING]


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
@export var inventory: Inventory

@onready var moving_logic = $StateMachine/MovingLogic
@onready var firing_logic = $StateMachine/FiringLogic
@onready var crouch_logic = $StateMachine/CrouchLogic
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var head:      Node3D           = $Head
@onready var camera:    Camera3D         = $Head/Camera3D
@onready var shoulder:  Node3D           = $Head/Shoulder
@onready var hand:      Node3D           = $Head/Shoulder/Hand
@onready var weapon:    WeaponNode       = $Head/Shoulder/Hand/WeaponNode
@onready var focus_timer:    Timer = $FocusTimer
@onready var reload_timer:   Timer = $ReloadTimer
@onready var firemode_timer: Timer = $FiremodeTimer

var push = 10
var damping = 1
var gravity: float = 9.82
var direction: Vector3 = Vector3.ZERO
var max_velocity: float = 0.0
var mouse_sensitivity: float = 1
# Animation targets (set by state logic)
var speed: float = 0.0
var camera_height: float = 0.0
var camera_fov: float = 0.0
var shoulder_x: float = 0.0
var head_bobbing: float = 0.0
var lean_angle: float = 0.0

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
		AIMING: aiming.emit(self, true)
		CROUCHING: crouched.emit(self, true)
		PRONING:  proned.emit(self, true)
		FOCUSING: focus_timer.stop()
		CHANGING_MODE:
			if weapon:
				if firemode_timer.time_left == 0:
					weapon.data.safe_firemode()
				else:
					weapon.data.cycle_firemode()
			firemode_timer.stop()
		FALLING:
			landed.emit(self, max_velocity, get_process_delta_time())
			max_velocity = 0
		RELOADING:
			if weapon:
				if reload_timer.time_left == 0:
					insert_ammofeed.emit(self)
				else:
					check_ammofeed.emit(self, weapon.data.ammofeed)
				firing_logic.get("parameters/playback").travel(_base_posture)
			reload_timer.stop()
			
		LEANING_LEFT, LEANING_RIGHT:
			leaned.emit(self, 0)
	
	if weapon and state in FIRING_STATES:
		weapon.release_trigger()

func _on_state_entered(state: String):
	match state:
		# Track base postures
		IDLE, AIMING, FOCUSING:
			_base_posture = state
		AIMING:        aiming   .emit(self, false)
		CROUCHING:     crouched .emit(self)
		PRONING:       proned   .emit(self)
		LEANING_RIGHT: leaned   .emit(self, -1)
		LEANING_LEFT:  leaned   .emit(self, +1)
		BARE_HANDED:   unequiped.emit(self)
		CHANGING_MODE:
			if firemode_timer.is_stopped():
				firemode_timer.start()
		FOCUSING:
			if focus_timer.is_stopped():
				focus_timer.start()
		RELOADING:
			if weapon:
				reload_timer.wait_time = weapon.data.reload_time
				if reload_timer.is_stopped():
					reload_timer.start()
				reloaded.emit(self)
		JUMPING:
			velocity.y += config.default_jump_impulse
			jumped.emit(self)

		# Firing states
	if weapon and state in FIRING_STATES:
		weapon.pull_trigger()  # First shot

func _on_state_changed(new_state: String, old_state: String):
	# Uncrouch on Idle
	match [old_state, new_state]:
		[ CROUCHING, IDLE ]: crouched.emit(self, true)
		[ BARE_HANDED, _ ]:
			if len(inventory.contents) == 0: return
			weapon.data = inventory.contents[0].content as Weapon
			equipped.emit(self)

func handle_process(delta):
	var debug_text = "FPS: %d\n" % Engine.get_frames_per_second()
	var state = moving_logic.get_current_state()
	debug_text += "[Moving] %s\n" % state
	
	match state:
		IDLE:
			speed        = config.default_speed
			head_bobbing = config.default_bobing
			lean_angle   = config.lean_angle_idle
		WALKING:
			speed        = config.walk_speed
			head_bobbing = config.walk_bobbing
			lean_angle   = config.lean_angle_walk
			moved.emit(self, delta)
		SPRINTING: 
			speed        = config.sprint_speed
			head_bobbing = config.sprint_bobbing
			moved.emit(self, delta)
		FALLING:
			max_velocity = max(max_velocity, velocity.length())

	state = crouch_logic.get_current_state()
	debug_text += "[Crouch machine]\nstate: %s\n" % state
	match state:
		PRONING:
			speed         = config.prone_speed
			head_bobbing  = config.prone_bobbing
			camera_height = config.prone_height
		LEANING: 
			speed        = config.lean_speed
			head_bobbing = config.NO_BOBBING
		
	state = firing_logic.get_current_state()
	debug_text += "[Firing machine]\nstate: %s\n" % state
	match state:
		FOCUSING:
			speed        = config.prone_speed
			head_bobbing = config.NO_BOBBING
			camera_fov   = config.aim_focused_fov
		AIMING:
			speed        = config.crouch_speed
			head_bobbing = config.NO_BOBBING
			camera_fov   = config.aim_fov
	
	# Disable sprint during weapon actions
	if state in CONFIG_STATES + FIRING_STATES + AIM_STATES:
		moving_logic.set_condition("+sprint", false)
		moving_logic.set_condition("-sprint", true)
	
	debug.emit(self, debug_text)

# --- Main Loop ---
func _physics_process(delta):

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
	handle_process(delta)

	# 5. APPLY MOVEMENT
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
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

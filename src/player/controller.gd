# res://src/gameplay/player_controller.gd
class_name PlayerController extends CharacterBody3D

# ─── STATES (unchanged) ────────────────────────────
const IDLE = "Idle"
const JUMPING = "Jump"
const PRONING = "Prone"
const CROUCHING = "Crouch"
const BARE_HANDED = "BareHands"
const FIRING_IDLE = "Firing"
const FIRING_AIM = "AimingFiring"
const FIRING_FOCUS = "HoldingBreathFiring"
const AIMING = "Aiming"
const FOCUSING = "HoldingBreath"
const CHANGING_MODE = "ChangingMode"
const FALLING = "Fall"
const LEANING = "Lean"
const LEANING_RIGHT = "LeanRight"
const LEANING_LEFT = "LeanLeft"
const RELOADING = "Reload"
const SPRINTING = "Sprint"
const WALKING = "Walk"
const FIRING_STATES = [FIRING_IDLE, FIRING_AIM, FIRING_FOCUS]
const AIM_STATES = [AIMING, FOCUSING]
const CONFIG_STATES = [RELOADING, CHANGING_MODE]
const MOVING_STATES = [WALKING, SPRINTING, JUMPING, FALLING]

# ─── SIGNALS (unchanged) ───────────────────────────
signal moved(player: PlayerController, delta: float)
signal leaned(player: PlayerController, direction: int)
signal proned(player: PlayerController, reverse: bool)
signal crouched(player: PlayerController, reverse: bool)
signal aiming(player: PlayerController, reverse: bool)
signal jumped(player: PlayerController)
signal landed(player: PlayerController, max_velocity: float, delta: float)
signal reloaded(player: PlayerController)
signal equipped(player: PlayerController)
signal unequiped(player: PlayerController)
signal insert_ammofeed(player: PlayerController)
signal check_ammofeed(player: PlayerController, ammofeed: AmmoFeed)
signal debug(player: PlayerController, text: String)

# ─── REFERENCES ────────────────────────────────────
@export var config: PlayerConfig
@export var health: Health  # Player health system
@export var player_body: PlayerBody  # Equipment slots

@onready var moving_logic = %MovingLogic
@onready var firing_logic = %FiringLogic
@onready var crouch_logic = %CrouchLogic
@onready var collision: CollisionShape3D = %CollisionShape3D
@onready var head: Node3D = %Head
@onready var camera: Camera3D = %Camera3D
@onready var shoulder: Node3D = %Shoulder
@onready var hand: Node3D = %Hand
@onready var weapon_node: WeaponNode = %WeaponNode
@onready var focus_timer: Timer = %FocusTimer
@onready var reload_timer: Timer = %ReloadTimer
@onready var firemode_timer: Timer = %FiremodeTimer
@onready var inventory_ui: InventoryUI = %InventoryUi

# ─── STATE TRACKING ────────────────────────────────
var _base_posture: String = "Idle"

var max_velocity: float = 0.0
var current_weapon: Weapon = null
var current_direction: Vector3 = Vector3.ZERO
# Animation targets (set by state logic)
var current_speed: float = 0.0
var current_camera_height: float = 0.0
var current_camera_fov: float = 0.0
var current_shoulder_x: float = 0.0
var current_head_bobbing: float = 0.0
var current_lean_angle: float = 0.0
var current_damping: float = 0.0

# ─── INIT ──────────────────────────────────────────
func _ready():
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    
    # Initialize systems if not assigned
    if config == null:
        config = PlayerConfig.new()
    if health == null:
        health = Health.new()
    if player_body == null:
        player_body = PlayerBody.new()

    # Connect state machine signals
    for logic in [moving_logic, crouch_logic, firing_logic]:
        logic.connect("state_entered", _on_state_entered)
        logic.connect("state_changed", _on_state_changed)
        logic.connect("state_exited", _on_state_exited)

    set_up_direction(Vector3.UP)
    set_floor_stop_on_slope_enabled(false)
    set_max_slides(4)
    set_floor_max_angle(PI / 4)

# ─── INPUT ─────────────────────────────────────────
func _input(event):
    if not inventory_ui.visible and event is InputEventMouseMotion:
        rotation_degrees.y -= event.relative.x * config.mouse_sensitivity / 10
        head.rotation_degrees.x = clamp(head.rotation_degrees.x - event.relative.y * config.mouse_sensitivity / 10, -90, 90)
    if not inventory_ui.visible:
        if  Input.is_action_just_pressed("open_inventory"):
            inventory_ui.open_inventory(self)
            Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
    elif Input.is_action_pressed("open_inventory"):
        inventory_ui.hide()
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# ─── STATE HANDLERS ────────────────────────────────
func _on_state_entered(state: String):
    match state:
        IDLE, AIMING, FOCUSING:
            _base_posture = state
        AIMING:
            aiming.emit(self, false)
        CROUCHING:
            crouched.emit(self)
        PRONING:
            proned.emit(self)
        LEANING_RIGHT:
            leaned.emit(self, -1)
        LEANING_LEFT:
            leaned.emit(self, +1)
        BARE_HANDED:
            unequiped.emit(self)
        CHANGING_MODE:
            if firemode_timer.is_stopped() and current_weapon:
                firemode_timer.start()
        FOCUSING:
            if focus_timer.is_stopped():
                focus_timer.start()
        RELOADING:
            if current_weapon:
                reload_timer.wait_time = current_weapon.reload_time
                if reload_timer.is_stopped():
                    reload_timer.start()
                reloaded.emit(self)
        JUMPING:
            velocity.y += config.default_jump_impulse
            jumped.emit(self)

    # Firing states
    if state in FIRING_STATES and current_weapon:
        WeaponSystem.pull_trigger(current_weapon)

func _on_state_exited(state: String):
    match state:
        AIMING:
            aiming.emit(self, true)
        CROUCHING:
            crouched.emit(self, true)
        PRONING:
            proned.emit(self, true)
        FOCUSING:
            focus_timer.stop()
        CHANGING_MODE:
            if current_weapon:
                if firemode_timer.time_left == 0:
                    current_weapon.safe_firemode()
                else:
                    WeaponSystem.cycle_firemode(current_weapon)
            firemode_timer.stop()
        FALLING:
            landed.emit(self, max_velocity, get_process_delta_time())
            max_velocity = 0
        RELOADING:
            if current_weapon:
                if reload_timer.time_left == 0:
                    insert_ammofeed.emit(self)
                else:
                    check_ammofeed.emit(self, current_weapon.ammofeed)
                firing_logic.get("parameters/playback").travel(_base_posture)
            reload_timer.stop()
        LEANING_LEFT, LEANING_RIGHT:
            leaned.emit(self, 0)

    if state in FIRING_STATES and current_weapon:
        WeaponSystem.release_trigger(current_weapon)

func _on_state_changed(new_state: String, old_state: String):
    match [old_state, new_state]:
        [CROUCHING, IDLE]:
            crouched.emit(self, true)
        [BARE_HANDED, _]:
            # Equip first weapon from primary slot
            var primary = player_body.get_equipped("primary")
            if not primary.is_empty():
                current_weapon = primary[0].content as Weapon
                weapon_node.data = current_weapon
                equipped.emit(self)

# ─── MAIN LOOP ─────────────────────────────────────
func _physics_process(delta):
    # Get input
    current_direction = Vector3.ZERO
    if Input.is_action_pressed("forward"): current_direction += Vector3.FORWARD
    if Input.is_action_pressed("back"): current_direction += Vector3.BACK
    if Input.is_action_pressed("left"): current_direction += Vector3.LEFT
    if Input.is_action_pressed("right"): current_direction += Vector3.RIGHT
    if current_direction.length() > 0.01:
        current_direction = current_direction.normalized().rotated(Vector3.UP, rotation.y)

    # Update state conditions
    handle_conditions()

    # Apply gravity
    if is_on_floor():
        velocity.y = 0
    else:
        velocity.y -= config.gravity * delta

    # Update state
    handle_process(delta)

    # Apply movement
    velocity.x = current_direction.x * current_speed
    velocity.z = current_direction.z * current_speed
    move_and_slide()

    # Apply damping
    velocity.x *= 1 - exp(-current_damping * delta)
    velocity.z *= 1 - exp(-current_damping * delta)

    # Apply push force
    for index in get_slide_collision_count():
        var collision = get_slide_collision(index)
        var collider = collision.get_collider()
        if collider and collider.is_in_group("bodies"):
            collider.apply_central_impulse(-collision.normal * config.gentle_push)

# ─── HELPERS ───────────────────────────────────────
func handle_conditions():
    # Moving logic
    moving_logic.set_condition("on_ground", is_on_floor())
    moving_logic.set_condition("on_air", not is_on_floor())
    moving_logic.set_condition("+move", abs(current_direction.length()) > 0)
    moving_logic.set_condition("-move", abs(current_direction.length()) == 0)
    moving_logic.set_condition("+jump", Input.is_action_just_pressed("jump"))
    moving_logic.set_condition("+sprint", Input.is_action_pressed("sprint"))
    moving_logic.set_condition("-sprint", Input.is_action_just_released("sprint"))

    # Crouch logic
    crouch_logic.set_condition("lean_right", Input.is_action_just_pressed("lean_right"))
    crouch_logic.set_condition("lean_left", Input.is_action_just_pressed("lean_left"))
    crouch_logic.set_condition("+lean", crouch_logic.get_condition("lean_left") or crouch_logic.get_condition("lean_right"))
    crouch_logic.set_condition("-lean", Input.is_action_just_released("lean_right") or Input.is_action_just_released("lean_left"))
    crouch_logic.set_condition("+crouch", Input.is_action_just_pressed("crouch") or Input.is_action_just_pressed("crouch_toggle"))
    crouch_logic.set_condition("-crouch", Input.is_action_just_released("crouch") or Input.is_action_just_pressed("crouch_toggle"))
    crouch_logic.set_condition("+prone", Input.is_action_just_pressed("prone") or Input.is_action_just_pressed("prone_toggle"))
    crouch_logic.set_condition("-prone", Input.is_action_just_released("prone") or Input.is_action_just_pressed("prone_toggle"))

    # Firing logic
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
    firing_logic.set_condition("+equip", Input.is_action_just_pressed("weapon_slot1") or Input.is_action_just_pressed("weapon_slot2") or Input.is_action_just_pressed("weapon_slot3"))
    firing_logic.set_condition("-equip", Input.is_action_just_pressed("weapon_drop"))
var cooldown = 0.0
func handle_process(delta):
    var debug_text = "FPS: %d\n" % Engine.get_frames_per_second()
    var state = moving_logic.get_current_state()
    debug_text += "[Moving] %s\n" % state
    
    match state:
        IDLE:
            current_speed = config.default_speed
            current_head_bobbing = config.default_bobing
            current_lean_angle   = config.lean_angle_idle
        WALKING:
            current_speed        = config.walk_speed
            current_head_bobbing = config.walk_bobbing
            current_lean_angle   = config.lean_angle_walk
            #moved.emit(self, delta)
        SPRINTING: 
            current_speed        = config.sprint_speed
            current_head_bobbing = config.sprint_bobbing
            #moved.emit(self, delta)
        FALLING:
            max_velocity = max(max_velocity, velocity.length())

    state = crouch_logic.get_current_state()
    debug_text += "[Crouch machine]\nstate: %s\n" % state
    match state:
        PRONING:
            current_speed         = config.prone_speed
            current_head_bobbing  = config.prone_bobbing
            current_camera_height = config.prone_height
        LEANING: 
            current_speed        = config.lean_speed
            current_head_bobbing = config.NO_BOBBING
        
    state = firing_logic.get_current_state()
    debug_text += "[Firing machine]\nstate: %s\n" % state
    match state:
        FOCUSING:
            current_speed        = config.prone_speed
            current_head_bobbing = config.NO_BOBBING
            current_camera_fov   = config.aim_focused_fov
        AIMING:
            current_speed        = config.crouch_speed
            current_head_bobbing = config.NO_BOBBING
            current_camera_fov   = config.aim_fov
    
    # Disable sprint during weapon actions
    if state in CONFIG_STATES + FIRING_STATES + AIM_STATES:
        moving_logic.set_condition("+sprint", false)
        moving_logic.set_condition("-sprint", true)
    cooldown += delta
    if (cooldown > 1.0):
        debug.emit(self, debug_text)
        cooldown = 0.0

class_name PlayerController
extends CharacterBody3D

# ─── STATES ────────────────────────────────────────────────────────────────────
const IDLE = "Idle"
const STOPPED = "Stopped"
const JUMPING = "Jumping"
const PRONING = "Proning"
const CROUCHING = "Crouching"
const BARE_HANDED = "BareHanded"
const TRIGGER_PULLED = "TriggerPulled"
const TRIGGER_RELEASED = "TriggerReleased"
const AIMING = "Aiming"
const FOCUSING = "HoldingBreath"
const CHANGING_MODE = "ChangingMode"
const FALLING = "Falling"
const NOT_LEANING = "NotLeaning"
const LEANING_RIGHT = "LeaningRight"
const LEANING_LEFT = "LeaningLeft"
const RELOADING = "Reloading"
const SPRINTING = "Sprinting"
const WALKING = "Walking"

var debug_text: String = ""

# ─── SIGNALS ───────────────────────────────────────────────────────────────────
signal moved(player: PlayerController, delta: float)
signal leaned(player: PlayerController, direction: int)
signal proned(player: PlayerController, reverse: bool)
signal crouched(player: PlayerController, reverse: bool)
signal aimed(player: PlayerController, reverse: bool)
signal focused(player: PlayerController, reverse: bool)
signal jumped(player: PlayerController)
signal landed(player: PlayerController, max_velocity: float, delta: float)
signal reloaded(player: PlayerController)
signal equipped(player: PlayerController, what: Item)
signal unequiped(player: PlayerController, what: Item)
signal insert_ammo_feed(player: PlayerController)
signal check_ammo_feed(player: PlayerController, ammo_feed: AmmoFeed)
signal debug(player: PlayerController, text: String)

# ─── REFERENCES ────────────────────────────────────────────────────────────────
@export var input: PlayerInput
@export var config: PlayerConfig
@export var health: Health
@export var equipment: Equipment
@export var inventory_ui: InventoryUI

@onready var moving: StateMachine = %Moving
@onready var crouching: StateMachine = %Crouching
@onready var leaning: StateMachine = %Leaning
@onready var aiming: StateMachine = %Aiming
@onready var firing: StateMachine = %Firing
@onready var collision: CollisionShape3D = %CollisionShape3D
@onready var head: Node3D = %Head
@onready var camera: Camera3D = %Camera3D
@onready var shoulder: Node3D = %Shoulder
@onready var hand: Node3D = %Hand
@onready var weapon_node: WeaponNode = %WeaponNode
@onready var focus_timer: Timer = %FocusTimer
@onready var reload_timer: Timer = %ReloadTimer
@onready var firemode_timer: Timer = %FiremodeTimer

# ─── MOVEMENT VARIABLES ────────────────────────────────────────────────────────
var max_velocity: float = 0.0
var current_weapon: Weapon = null
var current_direction: Vector3 = Vector3.ZERO

# Animation targets
var current_speed: float = 0.0
var current_camera_height: float = 0.0
var current_camera_fov: float = 0.0
var current_shoulder_x: float = 0.0
var current_head_bobbing: float = 0.0
var current_lean_angle: float = 0.0
var current_damping: float = 0.0

# Debug and performance
var _last_debug_time: float = 0.0
var _debug_interval: float = 0.1  # Update debug only 10 times per second
var _condition_cache: Dictionary = {}

# ─── INITIALIZATION ────────────────────────────────────────────────────────────
func _ready():
  # Initialize input if not assigned
  if input == null:
    input = PlayerInput.new()
    add_child(input)

  # Initialize systems if not assigned
  if config == null:
    config = PlayerConfig.new()
  if health == null:
    health = Health.new()
  if equipment == null:
    equipment = Equipment.new()
  if inventory_ui == null:
    inventory_ui = InventoryUI.new()

  # Connect equipment changes to update weapon node
  if equipment.has_signal("equipped"):
    equipment.equipped.connect(_on_equipment_changed)
  if equipment.has_signal("unequiped"):
    equipment.unequiped.connect(_on_equipment_changed)

  # Connect timers
  if firemode_timer and not firemode_timer.timeout.is_connected(_on_firemode_timeout):
    firemode_timer.timeout.connect(_on_firemode_timeout)
  if reload_timer and not reload_timer.timeout.is_connected(_on_reload_timeout):
    reload_timer.timeout.connect(_on_reload_timeout)
  if focus_timer and not focus_timer.timeout.is_connected(_on_focus_timeout):
    focus_timer.timeout.connect(_on_focus_timeout)

  # Initial weapon setup
  call_deferred("_update_weapon_node")

  # Connect state machine signals
  call_deferred("_connect_state_machine_signals")

  # Setup physics
  set_up_direction(Vector3.UP)
  set_floor_stop_on_slope_enabled(false)
  set_max_slides(4)
  set_floor_max_angle(PI / 4)

  # Capture mouse
  Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

  print("PlayerController initialized")

func _connect_state_machine_signals():
  var state_machines = [moving, crouching, aiming, leaning, firing]
  for state_machine in state_machines:
    if state_machine and state_machine.has_signal("state_entered"):
      if not state_machine.state_entered.is_connected(_on_state_entered):
        state_machine.state_entered.connect(_on_state_entered.bind(state_machine.name))
    if state_machine and state_machine.has_signal("state_exited"):
      if not state_machine.state_exited.is_connected(_on_state_exited):
        state_machine.state_exited.connect(_on_state_exited.bind(state_machine.name))
    if state_machine and state_machine.has_signal("state_changed"):
      if not state_machine.state_changed.is_connected(_on_state_changed):
        state_machine.state_changed.connect(_on_state_changed.bind(state_machine.name))

# ─── EQUIPMENT HANDLING ────────────────────────────────────────────────────────
func _on_equipment_changed(item: Item, slot_name: String):
  _update_weapon_node()

func _update_weapon_node():
  if not equipment:
    return

  var primary = equipment.get_equipped("primary")
  if not primary.is_empty():
    var weapon_item = primary[0]
    if weapon_item and weapon_item.extra is Weapon:
      current_weapon = weapon_item.extra as Weapon
      if weapon_node:
        weapon_node.data = current_weapon
      print("Weapon equipped: ", current_weapon.name)
  else:
    current_weapon = null
    if weapon_node:
      weapon_node.data = null

# ─── INPUT HANDLING ────────────────────────────────────────────────────────────
func _input(event):
  if not inventory_ui or inventory_ui.visible:
    return

  if event.is_action_pressed("open_inventory"):
    inventory_ui.open_inventory(self)
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
  elif event.is_action_pressed("open_inventory"):
    inventory_ui.hide()
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# ─── MAIN PHYSICS PROCESS ──────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
  # Clear previous frame's debug data
  Debug.clear_category("player")
  Debug.clear_category("timing")

  # Time entire frame
  var frame_timer = Debug.timer("frame_total")

  # Time each section
  var camera_timer = Debug.timer("camera_rotation")
  _handle_camera_rotation()
  camera_timer.call()

  var movement_timer = Debug.timer("movement_direction")
  _calculate_movement_direction()
  movement_timer.call()

  var states_timer = Debug.timer("state_logic")
  _read_states_and_apply(delta)
  states_timer.call()

  var physics_timer = Debug.timer("physics")
  _apply_movement_and_physics(delta)
  physics_timer.call()

  frame_timer.call()

  # Add state data
  Debug.add("moving_state", moving.state, "player")
  Debug.add("crouching_state", crouching.state, "player")
  Debug.add("leaning_state", leaning.state, "player")
  Debug.add("aiming_state", aiming.state, "player")
  Debug.add("firing_state", firing.state, "player")

  # Add movement data
  Debug.add("speed", current_speed, "movement")
  Debug.add("direction", current_direction, "movement")
  Debug.add("velocity", velocity, "movement")
  Debug.add("on_ground", is_on_floor(), "movement")

  # Add input data
  Debug.add("raw_motion", input.motion, "input")
  Debug.add("is_aiming", input.aim_held, "input")
  Debug.add("is_firing", input.fire_held, "input")
  Debug.add("is_sprinting", input.sprint_held, "input")


func _handle_camera_rotation():
  if not input:
    return

  var mouse_delta = input.consume_mouse_delta()
  if mouse_delta.length_squared() > 0:
    rotation_degrees.y -= mouse_delta.x * config.mouse_sensitivity / 10
    head.rotation_degrees.x = clamp(head.rotation_degrees.x - mouse_delta.y * config.mouse_sensitivity / 10, -90, 90)

func _calculate_movement_direction():
  if not input or not camera:
    return

  current_direction = Vector3.ZERO
  if input.motion.length_squared() > 0:
    var camera_basis = camera.global_transform.basis
    current_direction = -camera_basis.z * input.motion.y + camera_basis.x * input.motion.x
    current_direction.y = 0
    current_direction = current_direction.normalized()

func _read_states_and_apply(delta):
  # Apply gravity based on moving state
  if moving and moving.state == FALLING:
    velocity.y -= config.gravity * delta
    max_velocity = max(max_velocity, velocity.length())

  # Set movement parameters based on state combinations
  _update_movement_parameters()

  # Handle state-specific logic
  _handle_state_logic()

func _update_movement_parameters():
  if not config:
    return

  # Reset to defaults
  current_speed = config.default_speed
  current_head_bobbing = config.default_bobing
  current_lean_angle = config.lean_angle_idle
  current_camera_height = config.stand_height
  current_camera_fov = config.default_fov
  current_damping = config.default_damping

  if not moving:
    return

  # Moving state determines base movement
  match moving.state:
    STOPPED:
      current_speed = config.default_speed
      current_head_bobbing = config.default_bobing
      current_lean_angle = config.lean_angle_idle
    WALKING:
      current_speed = config.walk_speed
      current_head_bobbing = config.walk_bobbing
      current_lean_angle = config.lean_angle_walk
    SPRINTING:
      current_speed = config.sprint_speed
      current_head_bobbing = config.sprint_bobbing
      current_lean_angle = 0
    FALLING:
      max_velocity = max(max_velocity, velocity.length())

  if crouching:
    # Crouching state overrides height and speed
    match crouching.state:
      CROUCHING:
        current_speed = config.crouch_speed
        current_head_bobbing = config.crouch_bobbing
        current_camera_height = config.crouch_height
      PRONING:
        current_speed = config.prone_speed
        current_head_bobbing = config.prone_bobbing
        current_camera_height = config.prone_height

  if leaning:
    # Leaning state affects speed
    match leaning.state:
      LEANING_LEFT, LEANING_RIGHT:
        current_speed = config.lean_speed

  if aiming:
    # Aiming state affects FOV and bobbing
    match aiming.state:
      AIMING:
        current_speed = config.crouch_speed
        current_head_bobbing = config.NO_BOBBING
        current_camera_fov = config.aim_fov
      FOCUSING:
        current_speed = config.prone_speed
        current_head_bobbing = config.NO_BOBBING
        current_camera_fov = config.aim_focused_fov

  # Apply camera effects
  if camera:
    camera.fov = lerp(camera.fov, current_camera_fov, 0.1)
  if head:
    head.position.y = lerp(head.position.y, current_camera_height, 0.1)

func _handle_state_logic():
  # Handle weapon visibility based on aiming state
  if aiming and weapon_node:
    if aiming.state == BARE_HANDED and current_weapon:
      weapon_node.hide()
    elif aiming.state != BARE_HANDED and current_weapon:
      weapon_node.show()

  # Handle sprint blocking when firing
  if moving and firing:
    if firing.state == TRIGGER_PULLED:
      Input.action_release("sprint")

func _apply_movement_and_physics(delta):
  # Apply movement
  velocity.x = current_direction.x * current_speed
  velocity.z = current_direction.z * current_speed

  move_and_slide()

  # Apply damping
  velocity.x *= 1 - exp(-current_damping * delta)
  velocity.z *= 1 - exp(-current_damping * delta)

  # Handle landing
  if moving and moving.state == FALLING and is_on_floor():
    landed.emit(self, max_velocity, delta)
    velocity.y = 0
    max_velocity = 0.0

# ─── STATE HANDLERS ────────────────────────────────────────────────────────────
func _on_state_entered(state: String, state_machine_name: String):
  print("State entered: ", state_machine_name, " -> ", state)

  match state_machine_name:
    "Crouching":
      match state:
        CROUCHING:
          crouched.emit(self, false)
        PRONING:
          proned.emit(self, false)

    "Aiming":
      match state:
        AIMING:
          aimed.emit(self, false)
        BARE_HANDED:
          if not current_weapon:
            return
          # Spawn world item and unequip
          var item = WorldItem.spawn(self, current_weapon)
          if equipment:
            equipment.unequip(item.inventory_item, "primary")
          unequiped.emit(self, current_weapon)
          if weapon_node:
            weapon_node.hide()
          current_weapon = null
        FOCUSING:
          if focus_timer and focus_timer.is_stopped():
            focused.emit(self, false)
            focus_timer.start()

    "Firing":
      if not current_weapon:
        return
      if moving:
        moving.set_condition("can_sprint", false)

      match state:
        TRIGGER_PULLED:
          if weapon_node:
            weapon_node.pull_trigger()
        TRIGGER_RELEASED:
          if weapon_node:
            weapon_node.release_trigger()
        CHANGING_MODE:
          if firemode_timer and firemode_timer.is_stopped():
            firemode_timer.start()
        RELOADING:
          if reload_timer:
            reload_timer.wait_time = current_weapon.reload_time
            if reload_timer.is_stopped():
              reload_timer.start()
          reloaded.emit(self)

    "Moving":
      match state:
        JUMPING:
          velocity.y += config.default_jump_impulse
          jumped.emit(self)

    "Leaning":
      match state:
        LEANING_RIGHT:
          leaned.emit(self, -1)
        LEANING_LEFT:
          leaned.emit(self, 1)
        NOT_LEANING:
          leaned.emit(self, 0)
    _: print(state_machine_name)
func _on_state_exited(state: String, state_machine_name: String):
  print("State exited: ", state_machine_name, " -> ", state)

  match state_machine_name:
    "Crouching":
      match state:
        CROUCHING:
          crouched.emit(self, true)
        PRONING:
          proned.emit(self, true)

    "Aiming":
      match state:
        BARE_HANDED:
          if not equipment:
            return
          var primary = equipment.get_equipped("primary")
          if not primary.is_empty():
            current_weapon = primary[0].extra as Weapon
            if weapon_node:
              weapon_node.data = current_weapon
              weapon_node.show()
            equipped.emit(self, current_weapon)
        FOCUSING:
          focused.emit(self, true)
          if focus_timer:
            focus_timer.stop()

    "Firing":
      match state:
        CHANGING_MODE:
          if current_weapon:
            if firemode_timer and firemode_timer.time_left == 0:
              current_weapon.safe_firemode()
            else:
              WeaponSystem.cycle_firemode(current_weapon)
          if firemode_timer:
            firemode_timer.stop()
        RELOADING:
          if current_weapon:
            if reload_timer and reload_timer.time_left == 0:
              insert_ammo_feed.emit(self)
            else:
              check_ammo_feed.emit(self, current_weapon.ammo_feed)
          if reload_timer:
            reload_timer.stop()

    "Moving":
      match state:
        FALLING:
          landed.emit(self, max_velocity, get_process_delta_time())
          velocity.y = 0
          max_velocity = 0

func _on_state_changed(new_state: String, old_state: String, state_machine_name: String):
  if state_machine_name == "Aiming":
    match [old_state, new_state]:
      [AIMING, IDLE]:
        aimed.emit(self, true)

# ─── TIMER HANDLERS ────────────────────────────────────────────────────────────
func _on_firemode_timeout():
  Input.action_release("firemode")
  WeaponSystem.cycle_firemode(current_weapon)

func _on_reload_timeout():
  Input.action_release("reload")
  if current_weapon:
    insert_ammo_feed.emit(self)

func _on_focus_timeout():
  Input.action_release("focus")

# ─── PUBLIC METHODS ────────────────────────────────────────────────────────────
func get_camera_basis() -> Basis:
  if camera:
    return camera.global_transform.basis
  return Basis()

func get_head_position() -> Vector3:
  if head:
    return head.global_position
  return global_position

func get_look_direction() -> Vector3:
  if camera:
    return -camera.global_transform.basis.z
  return -global_transform.basis.z

# Cleanup
func _exit_tree():
  if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

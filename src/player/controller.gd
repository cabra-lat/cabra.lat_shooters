# res://src/gameplay/player_controller.gd
class_name PlayerController extends CharacterBody3D

# ─── STATES (unchanged) ────────────────────────────
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

# ─── SIGNALS (unchanged) ───────────────────────────
signal moved(player: PlayerController,     delta: float)
signal leaned(player: PlayerController,  direction: int)
signal proned(player: PlayerController,   reverse: bool)
signal crouched(player: PlayerController, reverse: bool)
signal aimed(player: PlayerController,    reverse: bool)
signal focused(player: PlayerController,  reverse: bool)
signal jumped(player: PlayerController)
signal landed(player: PlayerController, max_velocity: float, delta: float)
signal reloaded(player: PlayerController)
signal equipped(player: PlayerController, what: Item)
signal unequiped(player: PlayerController, what: Item)
signal insert_ammofeed(player: PlayerController)
signal check_ammofeed(player: PlayerController, ammofeed: AmmoFeed)
signal debug(player: PlayerController, text: String)

# ─── REFERENCES ────────────────────────────────────
@export var config: PlayerConfig
@export var health: Health  # Player health system
@export var equipment: Equipment  # Equipment slots
@export var inventory_ui: InventoryUI

@onready var moving:    StateMachine = %Moving
@onready var crouching: StateMachine = %Crouching
@onready var leaning:   StateMachine = %Leaning
@onready var aiming:    StateMachine = %Aiming
@onready var firing:    StateMachine = %Firing
@onready var collision: CollisionShape3D = %CollisionShape3D
@onready var head: Node3D = %Head
@onready var camera: Camera3D = %Camera3D
@onready var shoulder: Node3D = %Shoulder
@onready var hand: Node3D = %Hand
@onready var weapon_node: WeaponNode = %WeaponNode
@onready var focus_timer: Timer = %FocusTimer
@onready var reload_timer: Timer = %ReloadTimer
@onready var firemode_timer: Timer = %FiremodeTimer

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
  if equipment == null:
    equipment = Equipment.new()

  # Connect equipment changes to update weapon node
  equipment.equipped.connect(_on_equipment_changed)
  equipment.unequiped.connect(_on_equipment_changed)

  # Initial weapon setup
  _update_weapon_node()

  # Connect state machine signals
  for logic in [moving, crouching, aiming, leaning, firing]:
    logic.connect("state_entered", Callable(self, "_on_state_entered_" + logic.name.to_lower()))
    logic.connect("state_changed", Callable(self, "_on_state_changed_" + logic.name.to_lower()))
    logic.connect("state_exited",  Callable(self, "_on_state_exited_" + logic.name.to_lower()))

  set_up_direction(Vector3.UP)
  set_floor_stop_on_slope_enabled(false)
  set_max_slides(4)
  set_floor_max_angle(PI / 4)


func _on_equipment_changed(item: Item, slot_name: String):
  _update_weapon_node()

func _update_weapon_node():
  var primary = equipment.get_equipped("primary")
  if not primary.is_empty():
    var weapon_item = primary[0]
    if weapon_item.extra is Weapon:
      current_weapon = weapon_item.extra as Weapon
      weapon_node.data = current_weapon
      print("DEBUG: WeaponNode data set to: ", current_weapon.name)
  else:
    current_weapon = null
    weapon_node.data = null
# ─── INPUT ─────────────────────────────────────────
func _input(event):
  if not inventory_ui.visible and event is InputEventMouseMotion:
    rotation_degrees.y -= event.relative.x * config.mouse_sensitivity / 10
    head.rotation_degrees.x = clamp(head.rotation_degrees.x - event.relative.y * config.mouse_sensitivity / 10, -90, 90)
  if not inventory_ui.visible and Input.is_action_just_pressed("open_inventory"):
    inventory_ui.open_inventory(self)
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
  elif Input.is_action_just_pressed("open_inventory"):
    inventory_ui.hide()
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

  if inventory_ui.visible: return

  current_direction = Vector3.ZERO
  if Input.is_action_pressed("forward"): current_direction += Vector3.FORWARD
  if Input.is_action_pressed("back"): current_direction += Vector3.BACK
  if Input.is_action_pressed("left"): current_direction += Vector3.LEFT
  if Input.is_action_pressed("right"): current_direction += Vector3.RIGHT
  current_direction = current_direction.normalized().rotated(Vector3.UP, rotation.y)
  handle_conditions()
  debug.emit(self, debug_text)

# ─── STATE HANDLERS ────────────────────────────────
func _on_state_entered_crouching(state: String):
  match state:
    CROUCHING:
      crouched.emit(self)
    PRONING:
      proned.emit(self)

func _on_state_exited_crouching(state: String):
  match state:
    CROUCHING:
      crouched.emit(self, true) # Reverse movement
    PRONING:
      proned.emit(self, true) # Reverse movement

func _on_state_entered_aiming(state: String):
  match state:
    AIMING:
      aimed.emit(self)
    BARE_HANDED:
      if not current_weapon: return
      var item = WorldItem.spawn(self, current_weapon)
      equipment.unequip(item.inventory_item, "primary")
      unequiped.emit(self, current_weapon)
      weapon_node.hide()
      current_weapon = null
    FOCUSING:
      if focus_timer.is_stopped():
        focused.emit(self)
        focus_timer.timeout.connect(func(): Input.action_release("focus"))
        focus_timer.start()

func _on_state_exited_aiming(state: String):
  match state:
    BARE_HANDED:
      var primary = equipment.get_equipped("primary")
      if not primary.is_empty():
        current_weapon = primary[0].extra as Weapon
        weapon_node.data = current_weapon
        weapon_node.show()
        equipped.emit(self, current_weapon)
    FOCUSING:
      focused.emit(self, true)
      focus_timer.stop()

func _on_state_changed_aiming(new_state: String, old_state: String):
  match [ old_state, new_state ]:
    [ AIMING, IDLE ]:
      aimed.emit(self, true)

func _on_state_entered_firing(state: String):
  if not current_weapon: return
  moving.set_condition("+sprint", false)
  moving.set_condition("-sprint", true)
  match state:
    TRIGGER_PULLED:
      weapon_node.pull_trigger()
    TRIGGER_RELEASED:
      weapon_node.release_trigger()
    CHANGING_MODE:
      if firemode_timer.is_stopped():
        firemode_timer.timeout.connect(func(): Input.action_release("firemode"))
        firemode_timer.start()
    RELOADING:
      reload_timer.wait_time = current_weapon.reload_time
      if reload_timer.is_stopped():
        reload_timer.timeout.connect(func(): Input.action_release("reload"))
        reload_timer.start()
      reloaded.emit(self)

func _on_state_exited_firing(state: String):
  match state:
    CHANGING_MODE:
      if current_weapon:
        if firemode_timer.time_left == 0:
          current_weapon.safe_firemode()
        else:
          WeaponSystem.cycle_firemode(current_weapon)
      firemode_timer.stop()
    RELOADING:
      if current_weapon:
        if reload_timer.time_left == 0:
          insert_ammofeed.emit(self)
        else:
          check_ammofeed.emit(self, current_weapon.ammofeed)
      reload_timer.stop()


func _on_state_entered_moving(state: String):
  match state:
    JUMPING:
      velocity.y += config.default_jump_impulse
      jumped.emit(self)

func _on_state_exited_moving(state: String):
  match state:
    FALLING:
      landed.emit(self, max_velocity, get_process_delta_time())
      velocity.y = 0
      max_velocity = 0

func _on_state_entered_leaning(state: String):
  match state:
    LEANING_RIGHT:
      leaned.emit(self, -1)
    LEANING_LEFT:
      leaned.emit(self, +1)
    NOT_LEANING:
      leaned.emit(self, 0)

func _physics_process(delta):
    # Moving logic
  moving.set_condition("on_ground", is_on_floor())
  moving.set_condition("on_air", not is_on_floor())

  debug_text = "FPS: %d\n" % Engine.get_frames_per_second()
  debug_text += "[Firing state: %s]\n" % firing.get_current_state()
  debug_text += "[Aiming state: %s]\n" % aiming.get_current_state()
  debug_text += "[Leaninig state: %s]\n" % leaning.get_current_state()
  debug_text += "[Crouching state: %s]\n" % crouching.get_current_state()
  debug_text += "[Moving state: %s]\n" % moving.get_current_state()

  # Apply gravity
  match moving.state:
    FALLING:
      velocity.y -= config.gravity * delta
      max_velocity = max(max_velocity, velocity.length())
    STOPPED:
      current_speed        = config.default_speed
      current_head_bobbing = config.default_bobing
      current_lean_angle   = config.lean_angle_idle
    WALKING:
      current_speed        = config.walk_speed
      current_head_bobbing = config.walk_bobbing
      current_lean_angle   = config.lean_angle_walk
    SPRINTING:
      current_speed        = config.sprint_speed
      current_head_bobbing = config.sprint_bobbing
      current_lean_angle   = 0

  match crouching.state:
    CROUCHING:
      current_speed         = config.crouch_speed
      current_head_bobbing  = config.crouch_bobbing
      current_camera_height = config.crouch_height
    PRONING:
      current_speed         = config.prone_speed
      current_head_bobbing  = config.prone_bobbing
      current_camera_height = config.prone_height
      moving.set_condition("+jump", false)
  match leaning.state:
    LEANING_LEFT, LEANING_RIGHT:
      current_speed = config.lean_speed
  match aiming.state:
    AIMING:
      current_speed        = config.crouch_speed
      current_head_bobbing = config.NO_BOBBING
      current_camera_fov   = config.aim_fov
    FOCUSING:
      current_speed        = config.prone_speed
      current_head_bobbing = config.NO_BOBBING
      current_camera_fov   = config.aim_focused_fov

  # Apply movement
  velocity.x = current_direction.x * current_speed
  velocity.z = current_direction.z * current_speed
  move_and_slide()

  # Apply damping
  velocity.x *= 1 - exp(-current_damping * delta)
  velocity.z *= 1 - exp(-current_damping * delta)

  ## Apply push force
  #for index in get_slide_collision_count():
    #var collision = get_slide_collision(index)
    #var collider = collision.get_collider()
    #if collider and collider.is_in_group("bodies"):
      #collider.apply_central_impulse(-collision.normal * config.gentle_push)

# ─── HELPERS ───────────────────────────────────────
func handle_conditions():
  moving.set_condition("+move", abs(current_direction.length()) > 0)
  moving.set_condition("-move", abs(current_direction.length()) == 0)
  moving.set_condition("+jump", Input.is_action_just_pressed("jump"))
  moving.set_condition("+sprint", Input.is_action_pressed("sprint"))
  moving.set_condition("-sprint", not Input.is_action_pressed("sprint"))

  # Lean logic
  leaning.set_condition("lean_right", Input.is_action_just_pressed("lean_right"))
  leaning.set_condition("lean_left", Input.is_action_just_pressed("lean_left"))
  leaning.set_condition("-lean", Input.is_action_just_released("lean_right") or Input.is_action_just_released("lean_left"))

  # Crouch logic
  crouching.set_condition("+crouch", Input.is_action_just_pressed("crouch") or Input.is_action_just_pressed("crouch_toggle"))
  crouching.set_condition("-crouch", Input.is_action_just_released("crouch") or Input.is_action_just_pressed("crouch_toggle"))
  crouching.set_condition("+prone", Input.is_action_just_pressed("prone") or Input.is_action_just_pressed("prone_toggle"))
  crouching.set_condition("-prone", Input.is_action_just_released("prone") or Input.is_action_just_pressed("prone_toggle"))

  # Aiming logic
  aiming.set_condition("+focus", Input.is_action_just_pressed("focus"))
  aiming.set_condition("-focus", not  Input.is_action_pressed("focus"))
  aiming.set_condition("+aim", Input.is_action_pressed("aim"))
  aiming.set_condition("-aim", not Input.is_action_pressed("aim"))
  aiming.set_condition("+equip", Input.is_action_just_pressed("weapon_slot1") and equipment.is_equipped("primary"))
  aiming.set_condition("-equip", Input.is_action_just_pressed("weapon_drop"))

  # Firing logic
  firing.set_condition("+fire", Input.is_action_pressed("fire"))
  firing.set_condition("-fire", not Input.is_action_pressed("fire"))
  firing.set_condition("+reload", Input.is_action_just_pressed("reload"))
  firing.set_condition("-reload", Input.is_action_just_released("reload"))
  firing.set_condition("+firemode", Input.is_action_just_pressed("firemode"))
  firing.set_condition("-firemode", Input.is_action_just_released("firemode"))

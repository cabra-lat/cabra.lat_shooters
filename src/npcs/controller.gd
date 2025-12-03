class_name ControllerNPC
extends CharacterBody3D

# ─── STATES ────────────────────────────────────────────────────────────────────
const IDLE = "Idle"
const PATROLLING = "Patrolling"
const CHASING = "Chasing"
const ATTACKING = "Attacking"
const TAKING_COVER = "TakingCover"
const RETREATING = "Retreating"
const FLEEING = "Fleeing"
const DEAD = "Dead"

# ─── SIGNALS ───────────────────────────────────────────────────────────────────
signal alerted(enemy: ControllerNPC, actor: Node)
signal attacked(enemy: ControllerNPC, attacker: Node)
signal killed(enemy: ControllerNPC)
signal changed_state(old_state: String, new_state: String)

# ─── REFERENCES ────────────────────────────────────────────────────────────────
@export var input: InputNPC
@export var config: ConfigNPC
@export var health: Health
@export var equipment: Equipment
@export var inventory_ui: InventoryUI

@onready var moving: StateMachine = %Moving
@onready var crouching: StateMachine = %Crouching
@onready var aiming: StateMachine = %Aiming
@onready var firing: StateMachine = %Firing
@onready var collision: CollisionShape3D = %CollisionShape3D
@onready var head: Node3D = %Head
@onready var skeleton: Node3D = %Skeleton3D
@onready var camera: Camera3D = %Camera3D
@onready var shoulder: Node3D = %Shoulder
@onready var hand: Node3D = %RightHand
@onready var other_hand: Node3D = %LeftHand
@onready var focus_timer: Timer = %FocusTimer
@onready var reload_timer: Timer = %ReloadTimer
@onready var firemode_timer: Timer = %Firemode_timer

var current_weapon: Weapon = null
var current_target: Node = null
var last_seen_position: Vector3 = Vector3.ZERO
var patrol_timer: Timer = null
var awareness_timer: Timer = null
var state_machine: StateMachine = null

# ─── INITIALIZATION ────────────────────────────────────────────────────────────
func _ready():
  # Initialize components
  if input == null:
    input = InputNPC.new()
    add_child(input)

  if config == null:
    config = ConfigNPC.new()

  if health == null:
    health = Health.new()
  if equipment == null:
    equipment = Equipment.new()
  if inventory_ui == null:
    inventory_ui = InventoryUI.new()

  # Connect signals
  #health.died.connect(_on_health_died)
  _setup_state_machines()

  # Setup timers
  patrol_timer = Timer.new()
  patrol_timer.wait_time = config.idle_time
  patrol_timer.one_shot = true
  add_child(patrol_timer)

  awareness_timer = Timer.new()
  awareness_timer.wait_time = config.reaction_time
  awareness_timer.one_shot = true
  add_child(awareness_timer)

  # Set initial state
  _set_state(IDLE)
  print("EnemyController initialized")

func _setup_state_machines():
  # Link state machines to their respective systems
  moving.state_entered.connect(_on_moving_state_entered)
  moving.state_exited.connect(_on_moving_state_exited)
  aiming.state_entered.connect(_on_aiming_state_entered)
  aiming.state_exited.connect(_on_aiming_state_exited)
  firing.state_entered.connect(_on_firing_state_entered)
  firing.state_exited.connect(_on_firing_state_exited)

func _update_perception(delta):
  var players = get_tree().get_nodes_in_group("Player")
  for player in players:
    if player.is_instance_of(PlayerController):
      var distance = global_position.distance_to(player.global_position)

      # Vision detection
      if distance <= config.detection_radius:
        if _can_see_player(player):
          current_target = player
          return

      # Sound detection (if player fired weapon)
      if distance <= config.sound_detection_range:
        if player.has_fired_recently():
          current_target = player
          return

func _can_see_player(player: Node) -> bool:
  var direction = (player.global_position - global_position).normalized()
  var result = PhysicsServer3D.cast_motion(
    global_position,
    direction * config.detection_radius,
    CollisionShape3D.get_shape(0),
    0,
    [self]
  )
  return result.is_colliding() == false

func _find_nearest_cover() -> Vector3:
  var cover_positions = []

  # Raycast from multiple angles to find cover
  for angle in [0, 90, 180, 270]:
    var dir = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(angle))
    var end_pos = global_position + dir * 5.0
    var result = PhysicsServer3D.cast_motion(
      global_position,
      dir * 5.0,
      CollisionShape3D.get_shape(0),
      0,
      [self]
    )

    if result.is_colliding():
      var hit_pos = result.get_collision_point()
      if _is_cover_valid(hit_pos):
        cover_positions.append(hit_pos)

  # Return closest valid cover
  if cover_positions.size() > 0:
    return cover_positions[0]
  return Vector3.ZERO

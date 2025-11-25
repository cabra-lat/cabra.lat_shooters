extends Skeleton3D

@export_category("Foot IK Nodes")
@export var left_foot_target: Node3D
@export var right_foot_target: Node3D
@export var left_foot_ik: SkeletonIK3D
@export var right_foot_ik: SkeletonIK3D

@export_category("Movement")
@export var stride_length: float = 0.8
@export var step_height: float = 0.25
@export var step_duration: float = 0.3
@export var foot_spacing: float = 0.2
@export var max_foot_distance: float = 1.0

@export_category("Ground Detection")
@export var raycast_length: float = 2.0
@export var hip_height: float = 1.0
@export var ground_smoothing: float = 10.0

var _player: PlayerController
var _walk_phase: float = 0.0
var _last_step_foot: String = "right"
var _movement_since_last_step: float = 0.0
var _ik_nodes: Array = []

func _ready() -> void:
  # ✅ Get player with error checking
  _player = get_parent() as PlayerController
  if not _player:
    push_error("Skeleton3D parent must be PlayerController!")
    return

  # ✅ Start IK nodes
  if left_foot_ik: left_foot_ik.start()
  if right_foot_ik: right_foot_ik.start()

  # ✅ Cache IK nodes for performance
  for child in get_children():
    if child is SkeletonIK3D:
      _ik_nodes.append(child)

  # ✅ Initialize feet below hip
  var base = global_position
  if left_foot_target:
    left_foot_target.global_position = base + Vector3(foot_spacing, -hip_height, 0)
  if right_foot_target:
    right_foot_target.global_position = base + Vector3(-foot_spacing, -hip_height, 0)

func _physics_process(delta: float) -> void:
  # ✅ Keep IK running
  for ik in _ik_nodes:
    ik.start()

  if not _player:
    return

  var speed = _player.velocity.length()
  var is_moving = speed > 0.1

  if is_moving:
    # ✅ Track actual distance traveled
    _movement_since_last_step += speed * delta

    # ✅ Advance walk phase proportionally to distance
    _walk_phase += (speed / stride_length) * delta * PI

    # ✅ Step when we've moved half a stride length
    if _movement_since_last_step >= stride_length * 0.5:
      _step_foot(delta)
      _movement_since_last_step = 0.0
  else:
    # ✅ Reset when idle
    _walk_phase = 0.0
    _movement_since_last_step = 0.0

func _step_foot(delta: float):
  # ✅ Alternate feet
  var foot = "left" if _last_step_foot == "right" else "right"
  var target_node = left_foot_target if foot == "left" else right_foot_target

  # ✅ Calculate horizontal position
  var base = global_position
  var side = foot_spacing if foot == "left" else -foot_spacing
  var forward = -_player.global_transform.basis.z
  var phase = _walk_phase + (PI if foot == "left" else 0.0)

  target_node.global_position.x = base.x + side + forward.x * cos(phase) * stride_length
  target_node.global_position.z = base.z + forward.z * cos(phase) * stride_length

  # ✅ Raycast for ground height
  var ray_start = Vector3(target_node.global_position.x, base.y + 0.5, target_node.global_position.z)
  var ray_end = Vector3(target_node.global_position.x, base.y - raycast_length, target_node.global_position.z)
  var hit = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ray_start, ray_end))

  var ground_y = hit.position.y if hit else base.y - hip_height

  # ✅ Apply ground height + step arc
  target_node.global_position.y = ground_y + 0.05 + max(0.0, sin(phase)) * step_height

  _last_step_foot = foot

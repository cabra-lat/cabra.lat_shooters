# res://addons/cabra.lat_shooters/src/player/ik.gd
# Foot IK for the PLAYER rig (`player_ik.tscn`), which owns the GodotIK effectors.
#
# M1 DEBT (coordinator 2026-09-21): the skeleton in `player_ik.tscn` is a COPY of
# `humanoid_rig.tscn` (the SINGLE SOURCE). They must stay in sync until the dedupe
# (merge this foot IK into `HumanoidRig.set_foot_ik` and make the player instance
# the shared scene). Drift is guarded by an invariant (bone count + names/order).
extends Skeleton3D

@export_category("Foot IK Settings")
@export var left_foot_target: Node3D
@export var right_foot_target: Node3D

@export_category("Step Parameters")
@export var stride_length: float = 1.2
@export var step_height: float = 0.3
@export var step_speed: float = 5.0
@export var foot_spacing: float = 0.25
@export var max_foot_distance: float = 1.5
@export var foot_lerp_speed: float = 8.0

@export_category("Ground Detection")
@export var raycast_length: float = 2.0
@export var hip_height: float = 1.0
@export_flags_3d_physics var terrain_collision_mask: int = 1

## The body this rig is attached to. Any CharacterBody3D works (player or
## bot) — only the foot-IK ground query needs it; the rest of the rig
## (skeleton, mesh, IK effectors, look modifiers) is body-agnostic. See the
## shared-rig interface (HumanoidRig).
var _body: CharacterBody3D
var _body_collision_rid: RID

# Foot state variables
var left_foot_pos: Vector3
var left_foot_target_pos: Vector3
var right_foot_pos: Vector3
var right_foot_target_pos: Vector3

# Step timing
var left_foot_step_progress: float = 0.0
var right_foot_step_progress: float = 0.0
var is_left_foot_moving: bool = false
var is_right_foot_moving: bool = false

func _ready() -> void:
  _body = get_parent() as CharacterBody3D
  if not _body:
    # Generic rig without a body (e.g. a detached prop): skip foot IK, the
    # rest of the rig still works. The player/NPC always have a body.
    push_warning("HumanoidRig: foot IK needs a CharacterBody3D parent; skipping.")
    return

  _body_collision_rid = _body.get_rid()

  # Initialize foot positions relative to skeleton
  var base_pos = Vector3.ZERO
  left_foot_pos = base_pos + Vector3(foot_spacing, 0, 0)
  right_foot_pos = base_pos + Vector3(-foot_spacing, 0, 0)
  left_foot_target_pos = left_foot_pos
  right_foot_target_pos = right_foot_pos

  for ik in get_children():
    if ik is SkeletonIK3D:
      ik.start()

func _physics_process(delta: float) -> void:
  if not _body:
    return

  for ik in get_children():
    if ik is SkeletonIK3D:
      ik.start()
  _update_foot_placement(delta)
  _apply_foot_movement(delta)

# ─── FOOT IK METHODS (existing code) ──────────────────────────────────────────

func _update_foot_placement(delta: float) -> void:
  if not _body:
    return

  var body_velocity = _body.velocity
  var speed = body_velocity.length()
  var is_moving = speed > 0.1

  # Calculate desired foot positions relative to skeleton
  var body_forward = -global_transform.basis.z
  var body_right = global_transform.basis.x

  var left_foot_desired = Vector3(foot_spacing, 0, 0)
  var right_foot_desired = Vector3(-foot_spacing, 0, 0)

  if is_moving:
    # Add forward offset based on movement direction, scaled by planar speed.
    var stride_scale := clampf(speed / 4.0, 0.4, 1.2)
    var forward_offset = body_forward * stride_length * stride_scale * 0.3
    left_foot_desired += forward_offset
    right_foot_desired += forward_offset

  # Convert to world space for raycasting
  var world_left_desired = to_global(left_foot_desired)
  var world_right_desired = to_global(right_foot_desired)

  # Raycast to find ground position
  var world_left_ground = _get_ground_position(world_left_desired)
  var world_right_ground = _get_ground_position(world_right_desired)

  # Convert back to local space
  left_foot_desired = to_local(world_left_ground)
  right_foot_desired = to_local(world_right_ground)

  # Check if feet need to move
  var left_distance = left_foot_pos.distance_to(left_foot_desired)
  var right_distance = right_foot_pos.distance_to(right_foot_desired)

  # Start stepping if foot is too far and other foot is planted
  if left_distance > max_foot_distance and not is_left_foot_moving:
    if not is_right_foot_moving or right_foot_step_progress > 0.5:
      left_foot_target_pos = left_foot_desired
      is_left_foot_moving = true
      left_foot_step_progress = 0.0

  if right_distance > max_foot_distance and not is_right_foot_moving:
    if not is_left_foot_moving or left_foot_step_progress > 0.5:
      right_foot_target_pos = right_foot_desired
      is_right_foot_moving = true
      right_foot_step_progress = 0.0

func _apply_foot_movement(delta: float) -> void:
  # Handle left foot movement
  if is_left_foot_moving:
    left_foot_step_progress += delta * step_speed

    if left_foot_step_progress >= 1.0:
      left_foot_step_progress = 1.0
      is_left_foot_moving = false
      left_foot_pos = left_foot_target_pos
    else:
      # Parabolic foot trajectory
      var t = left_foot_step_progress
      var height = sin(t * PI) * step_height
      var new_pos = left_foot_pos.lerp(left_foot_target_pos, t)
      new_pos.y += height
      left_foot_pos = new_pos
  else:
    # Keep foot planted with slight smoothing
    var current_world_pos = to_global(left_foot_pos)
    var ground_pos = _get_ground_position(current_world_pos)
    var local_ground_pos = to_local(ground_pos)
    left_foot_pos = left_foot_pos.lerp(local_ground_pos, delta * foot_lerp_speed)

  # Handle right foot movement
  if is_right_foot_moving:
    right_foot_step_progress += delta * step_speed

    if right_foot_step_progress >= 1.0:
      right_foot_step_progress = 1.0
      is_right_foot_moving = false
      right_foot_pos = right_foot_target_pos
    else:
      # Parabolic foot trajectory
      var t = right_foot_step_progress
      var height = sin(t * PI) * step_height
      var new_pos = right_foot_pos.lerp(right_foot_target_pos, t)
      new_pos.y += height
      right_foot_pos = new_pos
  else:
    # Keep foot planted with slight smoothing
    var current_world_pos = to_global(right_foot_pos)
    var ground_pos = _get_ground_position(current_world_pos)
    var local_ground_pos = to_local(ground_pos)
    right_foot_pos = right_foot_pos.lerp(local_ground_pos, delta * foot_lerp_speed)

  # Apply to target nodes in local space
  if left_foot_target:
    left_foot_target.position = left_foot_pos
  if right_foot_target:
    right_foot_target.position = right_foot_pos

func _get_ground_position(world_pos: Vector3) -> Vector3:
  var ray_start = world_pos + Vector3.UP * raycast_length * 0.5
  var ray_end = world_pos + Vector3.DOWN * raycast_length

  var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
  if _body_collision_rid.is_valid():
    query.exclude = [_body_collision_rid]
  query.collision_mask = terrain_collision_mask
  query.collide_with_areas = false

  var hit = get_world_3d().direct_space_state.intersect_ray(query)
  if hit:
    return hit.position
  else:
    # If no ground found, use current height minus hip height as fallback
    return Vector3(world_pos.x, global_position.y - hip_height, world_pos.z)

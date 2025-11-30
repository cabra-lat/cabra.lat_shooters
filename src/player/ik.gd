extends Skeleton3D

@export_category("Foot IK Settings")
@export var left_foot_target: Node3D
@export var right_foot_target: Node3D
@export var left_foot_ik: SkeletonIK3D
@export var right_foot_ik: SkeletonIK3D

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

@export_category("Weapon Handling")
@export var right_hand_target: Node3D
@export var left_hand_target: Node3D
@export var weapon_attachment: BoneAttachment3D

var _player: PlayerController
var _player_collision_rid: RID

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

# Hip adjustment
var hip_offset: float = 0.0
var target_hip_offset: float = 0.0

# Weapon handling
var current_weapon: Weapon3D = null
var weapon_joints: Array[PinJoint3D] = []

func _ready() -> void:
  _player = get_parent() as PlayerController
  if not _player:
    push_error("Skeleton3D parent must be PlayerController!")
    return

  # Get player collision RID for exclusion
  if _player is CollisionObject3D:
    _player_collision_rid = _player.get_rid()
  else:
    var collision_object = _player.find_child("*", true, false) as CollisionObject3D
    if collision_object:
      _player_collision_rid = collision_object.get_rid()

  # Initialize foot positions relative to skeleton
  var base_pos = Vector3.ZERO
  left_foot_pos = base_pos + Vector3(foot_spacing, 0, 0)
  right_foot_pos = base_pos + Vector3(-foot_spacing, 0, 0)
  left_foot_target_pos = left_foot_pos
  right_foot_target_pos = right_foot_pos

  # Start IK
  if left_foot_ik:
    left_foot_ik.start()
  if right_foot_ik:
    right_foot_ik.start()

  for ik in get_children():
    if ik is SkeletonIK3D:
      ik.start()

  # Find weapon joints
  _find_weapon_joints()

func _find_weapon_joints():
  weapon_joints.clear()
  # Look for PinJoint3D nodes in the skeleton hierarchy
  for child in get_children():
    if child is PinJoint3D:
      weapon_joints.append(child)
    # Also check in common attachment points
    var attachments = child.find_children("*", "BoneAttachment3D", true, false)
    for attachment in attachments:
      for attachment_child in attachment.get_children():
        if attachment_child is PinJoint3D:
          weapon_joints.append(attachment_child)

func _physics_process(delta: float) -> void:
  if not _player:
    return

  for ik in get_children():
    if ik is SkeletonIK3D:
      ik.start()
  _update_foot_placement(delta)
  _apply_foot_movement(delta)
  _update_hip_offset(delta)

# ─── WEAPON HANDLING METHODS ──────────────────────────────────────────────────

func grab_weapon(weapon: Weapon):
  if not weapon or not weapon.view_model:
    return

  # Clean up old weapon
  release_weapon()

  # Instantiate new weapon
  var weapon_instance: Weapon3D = weapon.view_model.instantiate()
  weapon_instance.name = "EquippedWeapon"

  # Add to weapon attachment
  if weapon_attachment:
    weapon_attachment.add_child(weapon_instance)
    weapon_instance.position = Vector3.ZERO
    weapon_instance.rotation = Vector3.ZERO
  else:
    add_child(weapon_instance)

  current_weapon = weapon_instance

  # Configure joints for the weapon
  _configure_weapon_joints(weapon_instance)

  print("Weapon grabbed: ", weapon_instance.name)

func release_weapon():
  if current_weapon:
    _release_weapon_joints()
    current_weapon.queue_free()
    current_weapon = null
    print("Weapon released")

func _configure_weapon_joints(weapon: PhysicsBody3D):
  if not weapon or weapon_joints.is_empty():
    return

  # Configure each joint to connect to the weapon
  for joint in weapon_joints:
    if joint and weapon:
      joint.node_a = weapon.get_path()
      # Node B should already be set to the static body anchor

  print("Weapon joints configured: ", weapon_joints.size())

func _release_weapon_joints():
  # Release all weapon joints
  for joint in weapon_joints:
    if joint:
      joint.node_a = ""

  print("Weapon joints released")

func pull_trigger():
  if current_weapon and current_weapon.has_method("pull_trigger"):
    current_weapon.pull_trigger()

func release_trigger():
  if current_weapon and current_weapon.has_method("release_trigger"):
    current_weapon.release_trigger()

func throw_weapon(direction: Vector3):
  if current_weapon:
    if current_weapon.has_method("throw"):
      current_weapon.throw(direction)
      current_weapon.top_level = true
    release_weapon()

# ─── FOOT IK METHODS (existing code) ──────────────────────────────────────────

func _update_foot_placement(delta: float) -> void:
  if not _player:
    return

  var body_velocity = _player.velocity
  var speed = body_velocity.length()
  var is_moving = speed > 0.1

  # Calculate desired foot positions relative to skeleton
  var body_forward = -global_transform.basis.z
  var body_right = global_transform.basis.x

  var left_foot_desired = Vector3(foot_spacing, 0, 0)
  var right_foot_desired = Vector3(-foot_spacing, 0, 0)

  if is_moving:
    # Add forward offset based on movement direction
    var forward_offset = body_forward * stride_length * 0.3
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
  if _player_collision_rid.is_valid():
    query.exclude = [_player_collision_rid]
  query.collision_mask = terrain_collision_mask
  query.collide_with_areas = false

  var hit = get_world_3d().direct_space_state.intersect_ray(query)
  if hit:
    return hit.position
  else:
    # If no ground found, use current height minus hip height as fallback
    return Vector3(world_pos.x, global_position.y - hip_height, world_pos.z)

func _update_hip_offset(delta: float) -> void:
  if not _player:
    return

  # Calculate average foot height in world space
  var world_left_foot = to_global(left_foot_pos)
  var world_right_foot = to_global(right_foot_pos)
  var avg_foot_height = (world_left_foot.y + world_right_foot.y) * 0.5

  # Calculate target hip offset to keep feet on ground
  var current_hip_height = global_position.y
  target_hip_offset = avg_foot_height + hip_height - current_hip_height

  # Smoothly adjust hip offset
  hip_offset = lerp(hip_offset, target_hip_offset, delta * 5.0)

  # Apply offset to skeleton (this is the key fix - don't move global position)
  # Instead, we'll adjust the entire skeleton's vertical position relative to the player
  # This keeps the collision intact while allowing the mesh to adapt to terrain
  position.y = hip_offset

  # Debug info
  Debug.add("left_foot_moving", is_left_foot_moving, "ik")
  Debug.add("right_foot_moving", is_right_foot_moving, "ik")
  Debug.add("left_foot_progress", left_foot_step_progress, "ik")
  Debug.add("right_foot_progress", right_foot_step_progress, "ik")
  Debug.add("hip_offset", hip_offset, "ik")

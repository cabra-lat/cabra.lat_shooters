# world/item_3d.gd
class_name Item3D
extends Grabbable3D

# Signals for interaction
signal item_picked_up(world_item: Item3D, player: PlayerController)
signal item_dropped(world_item: Item3D)
signal item_hovered(world_item: Item3D, player: PlayerController)
signal item_exited(world_item: Item3D, player: PlayerController)

# Core properties
var data: set = _set_data, get = _get_data  # Generic data resource (Weapon, Ammo, AmmoFeed, etc.)

@export var pickup_radius: float = 1.5
@export var auto_disable_physics: bool = false
@export var physics_disable_time: float = 5.0
@export var physics_timeout_threshold: float = 0.1

# State
var physics_timer: Timer
var _is_physics_enabled: bool = false

func _init() -> void:
  gravity_scale = 1.0
  continuous_cd = false
  _is_physics_enabled = false
  _disable_physics()

  if auto_disable_physics:
    physics_timer = Timer.new()
    physics_timer.one_shot = true
    add_child(physics_timer)
    physics_timer.timeout.connect(_on_physics_timeout)

func _get_data():
  return data

func _set_data(value):
  data = value
  mass = data.mass

# Physics management
func _enable_physics():
  if _is_physics_enabled:
    return
  freeze = false
  freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
  _is_physics_enabled = true

  if auto_disable_physics and physics_timer:
    physics_timer.start(physics_disable_time)

func _disable_physics():
  if not _is_physics_enabled:
    return
  freeze = true
  freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
  linear_velocity = Vector3.ZERO
  angular_velocity = Vector3.ZERO
  _is_physics_enabled = false

  if physics_timer:
    physics_timer.stop()

func _on_physics_timeout():
  if not _is_physics_enabled:
    return
  if linear_velocity.length() < physics_timeout_threshold and angular_velocity.length() < physics_timeout_threshold:
    _disable_physics()

# Public methods - simplified to focus on physics
func throw(force: Vector3 = Vector3.ZERO, torque: Vector3 = Vector3.ZERO) -> void:
  """Activate physics and apply forces to the object"""
  _enable_physics()
  if force != Vector3.ZERO:
    apply_central_impulse(force)
  if torque != Vector3.ZERO:
    apply_torque_impulse(torque)
  super.drop()
  angular_damp = 0.5
  linear_damp = 0.1

# Static factory method
static func create_from_data(data: Resource, position: Vector3 = Vector3.ZERO) -> Item3D:
  if not data:
    push_warning("Trying to create item from null data!")
    return null

  var item_3d = Item3D.new()
  item_3d.data = data
  item_3d.position = position
  item_3d.rotate_y(randf() * PI * 2)
  return item_3d

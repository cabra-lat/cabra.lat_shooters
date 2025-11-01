class_name WeaponNode
extends Node3D

const VIEWMODEL_NAME = "Viewmodel"
const EJECTION_POINT_NAME = "EjectionPoint"

var firerate_timer: Timer
var casing_ejection: bool = true

# Optimized pooling with layer-based collision management
var casing_pools: Dictionary = {}
var current_pool: Array = []
var current_pool_key: String = ""
var casing_index: int = 0

# Performance settings
@export var max_active_casings: int = 20

@export var data: Weapon:
  get: return data
  set(value):
    if data:
      _disconnect_weapon_signals(data)
      _clear_all_pools()

    var old_vm = get_node_or_null(VIEWMODEL_NAME)
    if old_vm:
      old_vm.queue_free()

    if value and value.view_model:
      var new_vm = value.view_model.instantiate()
      new_vm.name = VIEWMODEL_NAME
      add_child(new_vm)

    data = value

    if data:
      _connect_weapon_signals(data)
      _preload_casings_for_current_mag()

func _ready():
  firerate_timer = Timer.new()
  firerate_timer.one_shot = true
  firerate_timer.connect("timeout", Callable(self,"_on_firerate_timeout"))
  add_child(firerate_timer)

func _connect_weapon_signals(weapon: Weapon):
  for sig in weapon.get_signal_list():
    var signal_name = sig.name
    if weapon.is_connected(signal_name, Callable(self, "_on_weapon_%s" % signal_name)):
      weapon.disconnect(signal_name, Callable(self, "_on_weapon_%s" % signal_name))
    weapon.connect(signal_name, Callable(self, "_on_weapon_%s" % signal_name))

func _disconnect_weapon_signals(weapon: Weapon):
  for sig in weapon.get_signal_list():
    var signal_name = sig.name
    if weapon.is_connected(signal_name, Callable(self, "_on_weapon_%s" % signal_name)):
      weapon.disconnect(signal_name, Callable(self, "_on_weapon_%s" % signal_name))

func _preload_casings_for_current_mag():
  if not data or not data.ammo_feed:
    return

  var ammo_feed: AmmoFeed = data.ammo_feed
  var magazine_capacity = ammo_feed.max_capacity

  var primary_ammo = _get_primary_ammo_type()
  if not primary_ammo or not primary_ammo.view_model:
    return

  current_pool_key = _get_ammo_pool_key(primary_ammo)

  # Clear existing pool
  if casing_pools.has(current_pool_key):
    for casing in casing_pools[current_pool_key]:
      if is_instance_valid(casing):
        casing.queue_free()

  # Preload all casings with optimized collision
  current_pool = []
  for i in range(magazine_capacity):
    var casing = primary_ammo.view_model.instantiate()
    _initialize_casing_state(casing)
    current_pool.append(casing)

  casing_pools[current_pool_key] = current_pool
  casing_index = 0

func _get_primary_ammo_type() -> Ammo:
  if not data:
    return null
  if data.chambered_round:
    return data.chambered_round
  if data.ammo_feed and not data.ammo_feed.is_empty():
    return data.ammo_feed.contents[0] as Ammo
  return null

func _get_ammo_pool_key(ammo: Ammo) -> String:
  if not ammo:
    return "invalid"
  return "%s_%s" % [ammo.caliber.replace(" ", "_"), ammo.type]

func _initialize_casing_state(casing: Node3D):
  casing.visible = false
  var rigid_body = _get_rigid_body(casing)
  if rigid_body:
    rigid_body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
    rigid_body.freeze = true
    rigid_body.linear_velocity = Vector3.ZERO
    rigid_body.angular_velocity = Vector3.ZERO

func _get_rigid_body(casing: Node3D) -> RigidBody3D:
  if casing is RigidBody3D:
    return casing
  return casing.get_node_or_null("RigidBody3D") as RigidBody3D

func _on_weapon_shell_ejected(weapon: Weapon, cartridge: Ammo):
  if not casing_ejection or not cartridge:
    return

  if not cartridge.view_model:
    return

  # Check if we've reached the maximum active casings
  if _get_active_casing_count() >= max_active_casings:
    # Reuse the oldest casing
    _reuse_oldest_casing(cartridge)
    return

  # Handle ammo type switching
  var pool_key = _get_ammo_pool_key(cartridge)
  if pool_key != current_pool_key:
    if not casing_pools.has(pool_key):
      _create_pool_for_ammo_type(cartridge)
    current_pool = casing_pools[pool_key]
    current_pool_key = pool_key
    casing_index = 0

  if current_pool.is_empty():
    return

  # Get next casing using round-robin
  var casing = current_pool[casing_index]
  casing_index = (casing_index + 1) % current_pool.size()

  # Skip if casing is still active
  if _is_casing_active(casing):
    return

  _eject_casing(casing, cartridge)

func _get_active_casing_count() -> int:
  var count = 0
  for pool in casing_pools.values():
    for casing in pool:
      if _is_casing_active(casing):
        count += 1
  return count

func _is_casing_active(casing: Node3D) -> bool:
  return is_instance_valid(casing) and casing.visible

func _reuse_oldest_casing(cartridge: Ammo):
  # Find and reuse the oldest active casing
  var oldest_casing = null
  var oldest_time = INF

  for pool in casing_pools.values():
    for casing in pool:
      if _is_casing_active(casing):
        # Simple heuristic: casings further from origin are older
        var distance = casing.global_transform.origin.length_squared()
        if distance < oldest_time:
          oldest_time = distance
          oldest_casing = casing

  if oldest_casing:
    _deactivate_casing(oldest_casing)
    _eject_casing(oldest_casing, cartridge)

func _eject_casing(casing: Node3D, cartridge: Ammo):
  var world_root = get_tree().current_scene
  if not world_root:
    return

  # Add to scene if needed
  if not casing.is_inside_tree():
    world_root.add_child(casing)

  # Position casing
  var weapon_viewmodel = get_node_or_null(VIEWMODEL_NAME)
  var ejection_point: Marker3D = weapon_viewmodel.get_node_or_null(EJECTION_POINT_NAME)
  if ejection_point:
    casing.global_transform = ejection_point.global_transform
  else:
    casing.global_transform = global_transform
    casing.global_transform.origin += global_transform.basis.x * 0.1

  # Activate casing with full collision
  _activate_casing(casing, cartridge)

  # Play sound
  if cartridge.shell_sound:
    var sound = AudioStreamPlayer3D.new()
    sound.stream = cartridge.shell_sound
    sound.global_transform.origin = global_transform.origin
    world_root.add_child(sound)
    sound.play()
    sound.finished.connect(sound.queue_free)

  # Schedule deactivation
  var deactivate_timer = Timer.new()
  deactivate_timer.wait_time = 5.0  # Longer since they're not as expensive now
  deactivate_timer.one_shot = true
  deactivate_timer.timeout.connect(func():
    _deactivate_casing(casing)
    deactivate_timer.queue_free()
  )
  world_root.add_child(deactivate_timer)

  # Apply recoil
  var player = world_root.get_node("Player")
  PlayerAnimations.apply_recoil(player, data)

func _create_pool_for_ammo_type(ammo: Ammo):
  if not data or not data.ammo_feed:
    return

  var magazine_capacity = data.ammo_feed.max_capacity
  var pool_key = _get_ammo_pool_key(ammo)
  var new_pool = []

  for i in range(magazine_capacity):
    var casing = ammo.view_model.instantiate()
    _initialize_casing_state(casing)
    new_pool.append(casing)

  casing_pools[pool_key] = new_pool

func _activate_casing(casing: Node3D, cartridge: Ammo):
  casing.visible = true

  var rigid_body = _get_rigid_body(casing)
  if rigid_body:
    rigid_body.freeze = false
    rigid_body.mass = clamp(cartridge.cartridge_mass / 1000.0, 0.005, 0.05)

    # Apply ejection force
    var force_multiplier = 1.5 + (cartridge.kinetic_energy / 5000.0)
    var ejection_force = Vector3(
      randf_range(0.5, 1.0),
      randf_range(0.2, 0.5),
      randf_range(-0.3, 0.1)
    ).normalized() * force_multiplier

    ejection_force = global_transform.basis * ejection_force
    rigid_body.apply_central_impulse(ejection_force)

    # Add spin
    rigid_body.apply_torque_impulse(Vector3(
      randf_range(-0.3, 0.3),
      randf_range(-0.2, 0.2),
      randf_range(-0.4, 0.4)
    ))

    rigid_body.angular_damp = 0.8
    rigid_body.linear_damp = 0.5

func _deactivate_casing(casing: Node3D):
  if not is_instance_valid(casing):
    return

  casing.visible = false

  var rigid_body = _get_rigid_body(casing)
  if rigid_body:
    rigid_body.freeze = true
    rigid_body.linear_velocity = Vector3.ZERO
    rigid_body.angular_velocity = Vector3.ZERO

func _on_weapon_ammo_feed_changed(weapon: Weapon, old_feed: AmmoFeed, new_feed: AmmoFeed):
  _preload_casings_for_current_mag()

func _on_weapon_weapon_racked(weapon: Weapon):
  _preload_casings_for_current_mag()

func _clear_all_pools():
  for pool_key in casing_pools:
    for casing in casing_pools[pool_key]:
      if is_instance_valid(casing):
        casing.queue_free()
  casing_pools.clear()
  current_pool.clear()
  current_pool_key = ""

# Existing weapon control methods
func _on_firerate_timeout():
  if data and data.is_automatic():
    WeaponSystem.pull_trigger(data)
    firerate_timer.start()

func _on_weapon_cartridge_fired(weapon: Weapon, cartridge: Ammo):
  pass

func pull_trigger(callback: Callable = func(): return null):
  if not firerate_timer.is_stopped():
    return
  if not data:
    return

  firerate_timer.wait_time = data.cycle_time

  if callback:
    if firerate_timer.is_connected("timeout", callback):
      firerate_timer.disconnect("timeout", callback)
    firerate_timer.timeout.connect(callback)

  WeaponSystem.pull_trigger(data)
  firerate_timer.start()

func release_trigger():
  firerate_timer.stop()
  if data:
    data.release_trigger()

func set_casing_ejection(enabled: bool):
  casing_ejection = enabled

func _exit_tree():
  _clear_all_pools()

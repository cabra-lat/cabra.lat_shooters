class_name WeaponNode
extends Node3D

const VIEWMODEL_NAME = "Viewmodel"
const EJECTION_POINT_NAME = "EjectionPoint"

var firerate_timer: Timer
var casing_ejection: bool = true

@export var data: Weapon:
  get: return data
  set(value):
    # Disconnect from old weapon
    if data and data.is_connected("cartridge_fired", Callable(self, "_on_weapon_cartridge_fired")):
      data.disconnect("cartridge_fired", Callable(self, "_on_weapon_cartridge_fired"))
      data.disconnect("shell_ejected", Callable(self, "_on_weapon_shell_ejected"))

    var old_vm = get_node_or_null(VIEWMODEL_NAME)
    if old_vm:
      old_vm.queue_free()

    if value and value.view_model:
      var new_vm = value.view_model.instantiate()
      new_vm.name = VIEWMODEL_NAME
      add_child(new_vm)

    data = value

    # Connect to new weapon
    if data:
      data.connect("cartridge_fired", Callable(self, "_on_weapon_cartridge_fired"))
      data.connect("shell_ejected", Callable(self, "_on_weapon_shell_ejected"))

# Track active casings for cleanup
var active_casings = []

func _ready():
  firerate_timer = Timer.new()
  firerate_timer.one_shot = true
  firerate_timer.connect("timeout", Callable(self,"_on_firerate_timeout"))
  add_child(firerate_timer)

  var weapon_viewmodel = get_node_or_null(VIEWMODEL_NAME)

  # Initialize ejection point
  if weapon_viewmodel and not weapon_viewmodel.has_node(EJECTION_POINT_NAME):
    var point = Marker3D.new()
    point.name = EJECTION_POINT_NAME
    point.position = Vector3(0.05, 0, 0)
    weapon_viewmodel.add_child(point)

  # Connect to weapon signals if data is already set
  if data:
    print("DEBUG: WeaponNode connecting to signals for weapon: ", data.name)
    if not data.is_connected("cartridge_fired", Callable(self, "_on_weapon_cartridge_fired")):
      data.connect("cartridge_fired", Callable(self, "_on_weapon_cartridge_fired"))
    if not data.is_connected("shell_ejected", Callable(self, "_on_weapon_shell_ejected")):
      data.connect("shell_ejected", Callable(self, "_on_weapon_shell_ejected"))
  else:
    print("DEBUG: WeaponNode has no data weapon assigned")

func _on_weapon_cartridge_fired(weapon: Weapon, cartridge: Ammo):
  if not casing_ejection or not cartridge:
    return

  if not cartridge.view_model:
    print("DEBUG: No view_model in cartridge: ", cartridge.name)
    return

  # Create the casing
  var casing_scene = cartridge.view_model
  if not casing_scene:
    print("DEBUG: Casing scene is null")
    return

  var casing = casing_scene.instantiate()
  if not casing:
    print("DEBUG: Failed to instantiate casing")
    return

  # Get the scene root to add the casing to the world
  var world_root = get_tree().current_scene
  if not world_root:
    print("DEBUG: No current scene found")
    return

  # Set position to ejection point
  var weapon_viewmodel = get_node_or_null(VIEWMODEL_NAME)
  var ejection_point: Marker3D = weapon_viewmodel.get_node_or_null(EJECTION_POINT_NAME)
  if ejection_point:
    casing.global_transform = ejection_point.global_transform
    print("DEBUG: Casing placed at ejection point: ", ejection_point.global_transform.origin)
  else:
    # Fallback: use weapon position with offset
    casing.global_transform = global_transform
    casing.global_transform.origin += global_transform.basis.x * 0.1
    print("DEBUG: Casing placed at weapon position with offset")

  # Add to scene
  world_root.add_child(casing)
  print("DEBUG: Casing added to scene: ", casing.name)

  # Store reference for cleanup
  active_casings.append(casing)

  # Apply physics - handle different casing types
  _apply_casing_physics(casing, cartridge)

  # Play sound
  if cartridge.shell_sound:
    var sound = AudioStreamPlayer3D.new()
    sound.stream = cartridge.shell_sound
    sound.global_transform.origin = global_transform.origin
    world_root.add_child(sound)
    sound.play()
    # Auto-remove sound player after playback
    sound.finished.connect(sound.queue_free)

  # Schedule casing removal
  var timer = Timer.new()
  timer.wait_time = 3.0
  timer.one_shot = true
  timer.timeout.connect(func():
    if is_instance_valid(casing):
      casing.queue_free()
    timer.queue_free()
  )
  world_root.add_child(timer)

  # Clean up invalid casings
  _cleanup_casings()

func _apply_casing_physics(casing: Node3D, cartridge: Ammo):
  # Method 1: Casing is a RigidBody3D
  if casing is RigidBody3D:
    var rb = casing as RigidBody3D
    # Set mass if it's reasonable (typical casing mass is 10-20g)
    rb.mass = clamp(cartridge.cartridge_mass / 1000.0, 0.01, 0.05)

    # Calculate ejection force (more controlled)
    var base_force = 2.0  # Base force multiplier
    var energy_factor = cartridge.kinetic_energy / 1000.0  # Scale down the energy
    var force_multiplier = base_force * min(energy_factor, 5.0)  # Cap the force

    # Ejection direction - right and slightly up/back from weapon
    var ejection_force = Vector3(
      randf_range(0.5, 1.0),      # Right
      randf_range(0.2, 0.5),      # Up
      randf_range(-0.3, 0.1)      # Slightly back
    ).normalized() * force_multiplier

    # Transform to weapon space
    ejection_force = global_transform.basis * ejection_force

    # Apply forces
    rb.apply_central_impulse(ejection_force)
    rb.apply_torque_impulse(Vector3(
      randf_range(-0.5, 0.5),
      randf_range(-0.3, 0.3),
      randf_range(-0.5, 0.5)
    ))

    print("DEBUG: Applied physics to RigidBody3D casing with force: ", ejection_force)
    return

  # Method 2: Look for RigidBody3D in children
  var rigid_body = casing.get_node_or_null("RigidBody3D")
  if rigid_body and rigid_body is RigidBody3D:
    var rb = rigid_body as RigidBody3D
    rb.mass = clamp(cartridge.cartridge_mass / 1000.0, 0.01, 0.05)

    # FIXED: Use the same energy calculation as Method 1
    var base_force = 2.0
    var energy_factor = cartridge.kinetic_energy / 1000.0  # Added missing division
    var force_multiplier = base_force * min(energy_factor, 5.0)

    var ejection_force = Vector3(
      randf_range(0.5, 1.0),
      randf_range(0.2, 0.5),
      randf_range(-0.3, 0.1)
    ).normalized() * force_multiplier

    ejection_force = global_transform.basis * ejection_force

    rb.apply_central_impulse(ejection_force)
    rb.apply_torque_impulse(Vector3(
      randf_range(-0.5, 0.5),
      randf_range(-0.3, 0.3),
      randf_range(-0.5, 0.5)
    ))

    # FIXED: Use more reasonable damping values
    rb.angular_damp = 1.0  # Reduced from 200.0
    rb.linear_damp = 0.5   # Reduced from 200.0

    print("DEBUG: Applied physics to child RigidBody3D")
    return

  # Method 3: Casing has custom method
  if casing.has_method("apply_ejection_force"):
    casing.apply_ejection_force(
      Vector3(randf_range(0.5, 1.0), randf_range(0.2, 0.5), randf_range(-0.3, 0.1)),
      Vector3(randf_range(-0.5, 0.5), randf_range(-0.3, 0.3), randf_range(-0.5, 0.5))
    )
    print("DEBUG: Applied ejection force via custom method")
    return

  print("DEBUG: No physics body found for casing")

func _cleanup_casings():
  # Remove invalid casings from tracking
  var i = 0
  while i < active_casings.size():
    if not is_instance_valid(active_casings[i]):
      active_casings.remove_at(i)
    else:
      i += 1

  # Limit total number of active casings to prevent performance issues
  var max_casings = 20
  while active_casings.size() > max_casings:
    var oldest_casing = active_casings[0]
    if is_instance_valid(oldest_casing):
      oldest_casing.queue_free()
    active_casings.remove_at(0)

func _on_firerate_timeout():
  if data and data.is_automatic():
    WeaponSystem.pull_trigger(data)
    firerate_timer.start()

func _on_weapon_shell_ejected(weapon: Weapon, cartridge: Ammo):
  # Fallback for shell_ejected signal
  if casing_ejection and cartridge:
    _on_weapon_cartridge_fired(weapon, cartridge)

# ─── WEAPON CONTROL ───────────────────────────────

func pull_trigger(callback: Callable = func(): return null):
  if not firerate_timer.is_stopped():
    return
  if not data:
    return

  firerate_timer.wait_time = 60.0 / data.firerate

  # Connect callback if provided
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

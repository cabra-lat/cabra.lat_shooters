@icon("../assets/grabbable.svg")
class_name Weapon3D
extends Item3D

const EJECTION_POINT_NAME = "EjectionPoint"
const MAGAZINE_ATTACHMENT_POINT = "MagazinePoint"

var firerate_timer: Timer
var casing_ejection: bool = true
var magazine_3d: Magazine3D = null

# Recoil system
var is_applying_recoil: bool = false
var recoil_cooldown_timer: Timer

func _ready():
  firerate_timer = Timer.new()
  firerate_timer.one_shot = true
  firerate_timer.connect("timeout", Callable(self, "_on_firerate_timeout"))
  add_child(firerate_timer)

  # Recoil cooldown timer
  recoil_cooldown_timer = Timer.new()
  recoil_cooldown_timer.one_shot = true
  add_child(recoil_cooldown_timer)

  super._ready()

func _set_data(value: Weapon):
    if data is Weapon:
        _disconnect_weapon_signals(data as Weapon)
        _remove_magazine_3d()

    data = value
    mass = data.mass

    if data:
        _connect_weapon_signals(data as Weapon)
        _setup_magazine()

func _setup_magazine():
    _remove_magazine_3d()

    if data and (data as Weapon).ammo_feed:
        var weapon_data = data as Weapon

        var point_A = get_node_or_null(MAGAZINE_ATTACHMENT_POINT + 'A')
        var point_B = get_node_or_null(MAGAZINE_ATTACHMENT_POINT + 'B')
        var point_C = get_node_or_null(MAGAZINE_ATTACHMENT_POINT + 'C')

        if not point_A or not point_B or not point_C:
            return

        magazine_3d = weapon_data.ammo_feed.view_model.instantiate()
        if magazine_3d:
            magazine_3d.data = weapon_data.ammo_feed
            add_child(magazine_3d)
            magazine_3d.position = 0.5 * (point_A.position + point_B.position)
            var attractors: Array[Marker3D] = [ point_A, point_B, point_C ]
            magazine_3d.grab(attractors)

func _remove_magazine_3d():
    if magazine_3d and is_instance_valid(magazine_3d):
        magazine_3d.queue_free()
        magazine_3d = null

func _connect_weapon_signals(weapon: Weapon):
    weapon.shell_ejected.connect(_on_weapon_shell_ejected)
    weapon.ammo_feed_changed.connect(_on_weapon_ammo_feed_changed)

func _disconnect_weapon_signals(weapon: Weapon):
    if weapon.shell_ejected.is_connected(_on_weapon_shell_ejected):
        weapon.shell_ejected.disconnect(_on_weapon_shell_ejected)
    if weapon.ammo_feed_changed.is_connected(_on_weapon_ammo_feed_changed):
        weapon.ammo_feed_changed.disconnect(_on_weapon_ammo_feed_changed)

func _on_weapon_shell_ejected(weapon: Weapon, cartridge: Ammo):
  if not casing_ejection:
    return

  # Get or create casing
  var casing: Cartridge3D = null
  if magazine_3d:
    casing = magazine_3d.get_casing()

  if not casing:
    casing = Cartridge3D.new()
    casing.data = cartridge

  if not casing:
    return

  var world_root = get_tree().current_scene
  if not world_root:
    return

  world_root.add_child(casing)

  # Position casing at ejection point
  var ejection_point: Marker3D = get_node_or_null(EJECTION_POINT_NAME)
  if ejection_point:
    casing.global_transform = ejection_point.global_transform
  else:
    casing.global_transform = global_transform
    casing.global_transform.origin += global_transform.basis.x * 0.1

  # Apply ejection physics
  _apply_ejection_physics(casing, cartridge)

  # Apply recoil (force-based method that actually works!)
  _apply_recoil(cartridge)

func _apply_ejection_physics(casing: Cartridge3D, cartridge: Ammo):
  """Apply realistic ejection - consistent rightward ejection"""
  if not cartridge:
    return

  # Get weapon's right vector for consistent ejection direction
  var right_vector = global_transform.basis.x

  # Realistic ejection pattern - always to the weapon's right
  var ejection_force = right_vector * randf_range(3.0, 5.0) + \
    Vector3.UP * randf_range(0.5, 1.5) + \
    -global_transform.basis.z * randf_range(0.5, 1.5)

  casing._enable_physics()

  # Apply impulse
  casing.apply_central_impulse(ejection_force)

  # Add realistic spin around the right vector
  var spin_torque = right_vector * randf_range(8.0, 12.0) + \
    Vector3(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5), 0.0)

  casing.apply_torque_impulse(spin_torque)

  # Realistic damping
  casing.angular_damp = randf_range(0.8, 1.2)
  casing.linear_damp = randf_range(0.2, 0.4)

func _apply_recoil(cartridge: Ammo):
  """Force-based recoil that bypasses resting thresholds"""
  if not cartridge or is_applying_recoil or recoil_cooldown_timer.time_left > 0:
    return

  is_applying_recoil = true
  recoil_cooldown_timer.start(0.1)  # Cooldown to prevent overlapping recoils

  var impulse = cartridge.recoil_impulse

  # Store original values
  var original_linear_threshold = linear_rest_threshold
  var original_angular_threshold = angular_rest_threshold

  # Completely disable resting thresholds during recoil
  linear_rest_threshold = 1000.0  # Effectively disabled
  angular_rest_threshold = 1000.0

  # Get weapon's LOCAL basis vectors
  var weapon_basis = global_transform.basis
  var back_vector = -weapon_basis.z
  var up_vector = weapon_basis.y
  var right_vector = weapon_basis.x

  # Calculate recoil direction
  var primary_recoil_direction = (back_vector * 0.7 + up_vector * 0.3).normalized()

  # Apply continuous force for several frames (bypasses impulse limitations)
  var total_force_duration = 0.08  # 80ms of force
  var frames = 4  # Apply over 4 frames
  var force_per_frame = primary_recoil_direction * impulse * 200.0 / frames

  for i in range(frames):
    if not is_instance_valid(self):
      break

    # Apply the force
    apply_central_force(force_per_frame)

    # Apply rotational force
    var torque_per_frame = Vector3(
      randf_range(-15.0, -25.0),
      randf_range(-5.0, 5.0),
      randf_range(-3.0, 3.0)
    ) * impulse * 0.2 / frames

    apply_torque(torque_per_frame)

    # Wait for next frame
    await get_tree().physics_frame

  # Restore thresholds
  linear_rest_threshold = original_linear_threshold
  angular_rest_threshold = original_angular_threshold

  is_applying_recoil = false

func _on_weapon_ammo_feed_changed(weapon: Weapon, old_feed: AmmoFeed, new_feed: AmmoFeed):
    _setup_magazine()

func _on_firerate_timeout():
    if data is Weapon and data.is_automatic():
        WeaponSystem.pull_trigger(data as Weapon)
        firerate_timer.start()

func pull_trigger(callback: Callable = func(): return null):
    if not firerate_timer.is_stopped() or not data:
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
    WeaponSystem.release_trigger(data)

func set_casing_ejection(enabled: bool):
    casing_ejection = enabled

func pick_up(player: PlayerController) -> bool:
    return false

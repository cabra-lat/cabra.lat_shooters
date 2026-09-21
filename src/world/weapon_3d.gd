class_name Weapon3D
extends Item3D

const EJECTION_POINT_NAME = "EjectionPoint"
const MAGAZINE_ATTACHMENT_POINT = "MagazinePoint"
const MUZZLE_ATTACHMENT_POINT = "MuzzlePoint"

## Candidate marker names per Weapon.AttachmentPoint, most specific first.
## Scenes are not uniform (ScopePoint on AK/AGLC, Scope on AR15, Handguard
## fallback for rails), so mount code probes this list in order.
static func marker_names_for_point(point: int) -> Array:
  match point:
    Weapon.AttachmentPoint.MUZZLE:
      return ["MuzzlePoint"]
    Weapon.AttachmentPoint.TOP_RAIL:
      return ["TopRail", "ScopePoint", "Scope"]
    Weapon.AttachmentPoint.UNDER:
      return ["Underbarrel", "Handguard"]
    Weapon.AttachmentPoint.LEFT_RAIL:
      return ["LeftRail", "Handguard"]
    Weapon.AttachmentPoint.RIGHT_RAIL:
      return ["RightRail", "Handguard"]
    Weapon.MAGAZINE_POINT:
      return ["MagazinePoint"]
    _:
      return []

## Hide the marker's baked children (a weapon scene's default optic) while a
## mounted attachment occupies the point; store them for restore on unmount.
static func hide_baked_marker_siblings(marker: Node3D, keep: Node, store: Dictionary) -> void:
    var hidden: Array = []
    for c in marker.get_children():
        if c == keep:
            continue
        if c is Node3D and (c as Node3D).visible:
            (c as Node3D).visible = false
            hidden.append(c)
    if not hidden.is_empty():
        store[marker] = hidden

static func restore_baked_marker_siblings(store: Dictionary) -> void:
    for marker in store.keys():
        if is_instance_valid(marker):
            for c in store[marker]:
                if is_instance_valid(c):
                    (c as Node3D).visible = true
    store.clear()

var firerate_timer: Timer
var casing_ejection: bool = true
var magazine_3d: Magazine3D = null
var _mounted_attachments: Dictionary = {}
var _baked_optics_hidden: Dictionary = {}

# Muzzle flash system
var muzzle_flash_effect: MuzzleFlash3D
var is_muzzle_flash_playing: bool = false

# Recoil system
var is_applying_recoil: bool = false
var recoil_cooldown_timer: Timer

# Preloading optimization
var muzzle_flash_ready: bool = false

func _ready():
  firerate_timer = Timer.new()
  firerate_timer.one_shot = true
  firerate_timer.timeout.connect(_on_firerate_timeout)
  add_child(firerate_timer)

  # Recoil cooldown timer
  recoil_cooldown_timer = Timer.new()
  recoil_cooldown_timer.one_shot = true
  add_child(recoil_cooldown_timer)

  # Initialize muzzle flash system immediately
  _setup_muzzle_flash()

  super._ready()

func _setup_muzzle_flash():
  muzzle_flash_effect = MuzzleFlash3D.new()

  # Direction
  muzzle_flash_effect.emission_direction = Vector3(0, 0, -1)
  muzzle_flash_effect.spread_degrees = 20.0

  var muzzle_point = get_node_or_null(MUZZLE_ATTACHMENT_POINT)
  if muzzle_point:
    muzzle_point.add_child(muzzle_flash_effect)
  else:
    add_child(muzzle_flash_effect)
    muzzle_flash_effect.position = Vector3(0, 0, -0.5)

  # Mark as ready after one frame to ensure setup is complete
  _mark_muzzle_flash_ready()

func _mark_muzzle_flash_ready():
  muzzle_flash_ready = true

func _play_muzzle_flash():
  ## Play enhanced muzzle flash - optimized for immediate response
  if not muzzle_flash_effect or is_muzzle_flash_playing or not muzzle_flash_ready:
    return

  is_muzzle_flash_playing = true

  var weapon_data = data as Weapon
  var flash_size = 1.0

  # Apply suppressor reduction
  var muzzle_attachment = weapon_data.get_attachment(Weapon.AttachmentPoint.MUZZLE)
  if muzzle_attachment:
    flash_size *= (1.0 - muzzle_attachment.flash_suppression)

  muzzle_flash_effect.play_flash(flash_size)

  # Non-blocking timer to reset flag
  var timer = get_tree().create_timer(0.12)  # Slightly shorter
  timer.timeout.connect(_on_muzzle_flash_finished)

func _on_muzzle_flash_finished():
  is_muzzle_flash_playing = false

func _set_data(value: Weapon):
    if data is Weapon:
        _disconnect_weapon_signals(data as Weapon)
        _unmount_all_attachments()
        _remove_magazine_3d()

    data = value
    mass = data.mass if data != null else 0.0

    if data:
        _connect_weapon_signals(data as Weapon)
        _setup_magazine()
        for point in (data as Weapon).attachments.keys():
            _mount_attachment(point, (data as Weapon).attachments[point])

func _setup_magazine():
    _remove_magazine_3d()

    if data and (data as Weapon).ammo_feed:
        var weapon_data = data as Weapon

        var attachment_point = get_node_or_null(MAGAZINE_ATTACHMENT_POINT)

        if not attachment_point:
            return

        magazine_3d = weapon_data.ammo_feed.view_model.instantiate()
        if magazine_3d:
            magazine_3d.data = weapon_data.ammo_feed
            add_child(magazine_3d)
            magazine_3d.position = attachment_point.position
            magazine_3d.grab_single(attachment_point)

func _remove_magazine_3d():
    if magazine_3d and is_instance_valid(magazine_3d):
        magazine_3d.queue_free()
        magazine_3d = null

func _connect_weapon_signals(weapon: Weapon):
    weapon.shell_ejected.connect(_on_weapon_shell_ejected)
    weapon.ammo_feed_changed.connect(_on_weapon_ammo_feed_changed)
    weapon.attachment_added.connect(_on_attachment_added)
    weapon.attachment_removed.connect(_on_attachment_removed)
    if weapon.has_signal("weapon_malfunctioned"):
        weapon.weapon_malfunctioned.connect(_on_weapon_malfunctioned)
    if weapon.has_signal("malfunction_cleared"):
        weapon.malfunction_cleared.connect(_on_malfunction_cleared)

func _disconnect_weapon_signals(weapon: Weapon):
    if weapon.shell_ejected.is_connected(_on_weapon_shell_ejected):
        weapon.shell_ejected.disconnect(_on_weapon_shell_ejected)
    if weapon.ammo_feed_changed.is_connected(_on_weapon_ammo_feed_changed):
        weapon.ammo_feed_changed.disconnect(_on_weapon_ammo_feed_changed)
    if weapon.attachment_added.is_connected(_on_attachment_added):
        weapon.attachment_added.disconnect(_on_attachment_added)
    if weapon.attachment_removed.is_connected(_on_attachment_removed):
        weapon.attachment_removed.disconnect(_on_attachment_removed)
    if weapon.has_signal("weapon_malfunctioned") and weapon.weapon_malfunctioned.is_connected(_on_weapon_malfunctioned):
        weapon.weapon_malfunctioned.disconnect(_on_weapon_malfunctioned)
    if weapon.has_signal("malfunction_cleared") and weapon.malfunction_cleared.is_connected(_on_malfunction_cleared):
        weapon.malfunction_cleared.disconnect(_on_malfunction_cleared)

## Instantiates attachment.model_scene under the point's marker. Rigid bodies
## from the pickup scenes are frozen/ignored so a held attachment can't simulate.
func _on_attachment_added(_weapon: Weapon, attachment: Attachment, point: int) -> void:
    _mount_attachment(point, attachment)

func _on_attachment_removed(_weapon: Weapon, attachment: Attachment, point: int) -> void:
    _unmount_attachment(point)

func _attachment_marker(point: int) -> Node3D:
    for marker_name in marker_names_for_point(point):
        var n := get_node_or_null(marker_name)
        if n is Node3D:
            return n
    return self  # fallback: mount at the weapon root

func _mount_attachment(point: int, attachment: Attachment) -> void:
    _unmount_attachment(point)
    if attachment == null or attachment.model_scene == null:
        return
    var marker := _attachment_marker(point)
    var inst := attachment.model_scene.instantiate()
    if inst == null:
        return
    marker.add_child(inst)
    if inst is Node3D:
        (inst as Node3D).transform = attachment.model_transform
    if inst is RigidBody3D:
        var rb := inst as RigidBody3D
        rb.freeze = true
        rb.contact_monitor = false
        rb.collision_layer = 0
        rb.collision_mask = 0
        if rb.get("is_grabbed") != null:
            rb.set("is_grabbed", false)
    _mounted_attachments[point] = inst
    if point == Weapon.AttachmentPoint.TOP_RAIL:
        Weapon3D.hide_baked_marker_siblings(marker, inst, _baked_optics_hidden)
    if point == Weapon.MAGAZINE_POINT and magazine_3d and is_instance_valid(magazine_3d):
        magazine_3d.visible = false

func _unmount_attachment(point: int) -> void:
    if _mounted_attachments.has(point):
        var old = _mounted_attachments[point]
        if is_instance_valid(old):
            old.queue_free()
        _mounted_attachments.erase(point)
    if point == Weapon.AttachmentPoint.TOP_RAIL:
        Weapon3D.restore_baked_marker_siblings(_baked_optics_hidden)
    if point == Weapon.MAGAZINE_POINT and magazine_3d and is_instance_valid(magazine_3d):
        magazine_3d.visible = true

func _unmount_all_attachments() -> void:
    for point in _mounted_attachments.keys():
        _unmount_attachment(point)

## A fault stops any automatic fire until the weapon is cleared.
func _on_weapon_malfunctioned(_weapon: Weapon, _kind: int):
    if firerate_timer and not firerate_timer.is_stopped():
        firerate_timer.stop()

func _on_malfunction_cleared(_weapon: Weapon, _kind: int):
    pass

## Bound by the player to the Troubleshooting key/action.
func clear_malfunction() -> bool:
    if data is Weapon:
        return (data as Weapon).start_clearing()
    return false

func _process(delta: float):
    if data is Weapon:
        (data as Weapon).advance(delta)

func _on_weapon_shell_ejected(weapon: Weapon, cartridge: Ammo):
  if not casing_ejection:
    return

  # Play muzzle flash when firing
  _play_muzzle_flash()

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
  ## Apply realistic ejection - consistent rightward ejection
  if not cartridge:
    return

  # Get weapon's right vector for consistent ejection direction
  var right_vector = global_transform.basis.x
  # Weapon-exported ejection tuning (falls back to neutral defaults).
  var weapon_data := data as Weapon
  var force_mult := weapon_data.ejection_force_multiplier if weapon_data != null else 1.0
  var spin_mult := weapon_data.ejection_spin_multiplier if weapon_data != null else 1.0
  var dir_hint := weapon_data.ejection_direction if weapon_data != null else Vector3(1.0, 0.3, -0.2)

  # Realistic ejection pattern - rightward, shaped by the weapon's direction hint.
  var ejection_force = (right_vector * randf_range(3.0, 5.0)
    + Vector3.UP * randf_range(0.5, 1.5)
    + -global_transform.basis.z * randf_range(0.5, 1.5)
    + right_vector * dir_hint.x + Vector3.UP * dir_hint.y - global_transform.basis.z * dir_hint.z) * force_mult

  casing._enable_physics()

  # Apply impulse
  casing.apply_central_impulse(ejection_force)

  # Add realistic spin around the right vector
  var spin_torque = (right_vector * randf_range(8.0, 12.0) + \
    Vector3(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5), 0.0)) * spin_mult

  casing.apply_torque_impulse(spin_torque)

  # Realistic damping
  casing.angular_damp = randf_range(0.8, 1.2)
  casing.linear_damp = randf_range(0.2, 0.4)

func _apply_recoil(cartridge: Ammo):
  ## Force-based recoil that bypasses resting thresholds
  if not cartridge or is_applying_recoil or recoil_cooldown_timer.time_left > 0:
    return

  # AGENTS rule 5: held items are never physics-simulated. A held weapon is
  # frozen; recoil pose is owned by ViewmodelRig (this would double it).
  if freeze:
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
    var t = get_tree()
    if t: await t.physics_frame

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
        if firerate_timer.timeout.is_connected(callback):
            firerate_timer.timeout.disconnect(callback)
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

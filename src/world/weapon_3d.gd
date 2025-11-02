class_name Weapon3D
extends Item3D

const EJECTION_POINT_NAME = "EjectionPoint"
const MAGAZINE_ATTACHMENT_POINT = "MagazinePoint"

var firerate_timer: Timer
var casing_ejection: bool = true
var magazine_3d: Magazine3D = null

func _set_data(value: Weapon):
  if data is Weapon:
    _disconnect_weapon_signals(data as Weapon)
    _remove_magazine_3d()

  data = value

  if data:
    _connect_weapon_signals(data as Weapon)
    _setup_magazine()

func _ready():
  # Initialize timer
  firerate_timer = Timer.new()
  firerate_timer.one_shot = true
  firerate_timer.connect("timeout", Callable(self, "_on_firerate_timeout"))
  add_child(firerate_timer)
  # Call parent _ready to setup common item functionality
  super._ready()

# In Weapon3D.gd - update _setup_magazine function
func _setup_magazine():
  print("Weapon3D: Setting up magazine (simple approach)")
  _remove_magazine_3d()

  if data and (data as Weapon).ammo_feed:
    var weapon_data = data as Weapon

        # Get the main attachment point
    var main_point = get_node_or_null(MAGAZINE_ATTACHMENT_POINT + 'A')
    if not main_point:
      print("ERROR: No main attachment point found")
      return

        # Create magazine
    magazine_3d = weapon_data.ammo_feed.view_model.instantiate()
    if magazine_3d:
      # Set data first
      magazine_3d.data = weapon_data.ammo_feed

      # Add as child of the attachment point
      main_point.add_child(magazine_3d)
      # Disable physics
      magazine_3d._disable_physics()
      # Reset transform to local space of attachment point
      magazine_3d.position = Vector3.ZERO
      magazine_3d.rotation = Vector3.ZERO

      print("Magazine attached to point A at local position: ", magazine_3d.position)
      print("Magazine global position: ", magazine_3d.global_position)
    else:
      print("ERROR: Failed to instantiate magazine")
# Add this test function
func _test_magazine_preloading():
  if magazine_3d:
    print("=== Magazine Preloading Test ===")
    print("Preloaded casings: ", magazine_3d.preloaded_casings.size())
    if magazine_3d.data and magazine_3d.data.contents:
      print("Magazine contents: ", magazine_3d.data.contents.size())
    print("=== End Test ===")

func _remove_magazine_3d():
  if magazine_3d and is_instance_valid(magazine_3d):
    magazine_3d.queue_free()
    magazine_3d = null

# Signal management
func _connect_weapon_signals(weapon: Weapon):
  for sig in weapon.get_signal_list():
    var signal_name = sig.name
    if not weapon.is_connected(signal_name, Callable(self, "_on_weapon_%s" % signal_name)):
      weapon.connect(signal_name, Callable(self, "_on_weapon_%s" % signal_name))

func _disconnect_weapon_signals(weapon: Weapon):
  for sig in weapon.get_signal_list():
    var signal_name = sig.name
    if weapon.is_connected(signal_name, Callable(self, "_on_weapon_%s" % signal_name)):
      weapon.disconnect(signal_name, Callable(self, "_on_weapon_%s" % signal_name))

func _on_weapon_shell_ejected(weapon: Weapon, cartridge: Ammo):
  if not casing_ejection:
    return

  print("Shell ejected signal received for: ", cartridge.name)

    # Get preloaded casing from magazine instead of creating new one
  var casing: Cartridge3D = null
  if magazine_3d:
    casing = magazine_3d.get_casing()
    print("Got casing from magazine: ", casing != null)

    # Fallback to creating new casing if preloading failed
  if not casing:
    print("Creating new casing")
    casing = Cartridge3D.new()
    casing.data = cartridge

  if not casing:
    print("ERROR: Failed to create casing")
    return

  var world_root = get_tree().current_scene
  if not world_root:
    print("ERROR: No world root found")
    return

  # Add to scene tree now
  world_root.add_child(casing)

  # Position casing
  var ejection_point: Marker3D = get_node_or_null(EJECTION_POINT_NAME)
  if ejection_point:
    casing.global_transform = ejection_point.global_transform
    print("Casing positioned at ejection point: ", ejection_point.global_position)
  else:
    casing.global_transform = global_transform
    casing.global_transform.origin += global_transform.basis.x * 0.1
    print("Casing positioned at weapon with offset")

  # Eject the casing (this handles physics and visibility)
  casing.eject()
  print("Casing ejected, visible: ", casing.visible)

  # Apply recoil to weapon
  var weapon_data = data as Weapon
  var recoil := weapon_data.get_recoil_vector()
  var recoil_3d := Vector3(recoil.x, recoil.y, 0.0) * global_transform.basis
  apply_impulse(recoil_3d, grab_points[0].position)

func _on_weapon_ammo_feed_changed(weapon: Weapon, old_feed: AmmoFeed, new_feed: AmmoFeed):
  _setup_magazine()

# Weapon control methods
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

# Override pickup to prevent picking up equipped weapons
func pick_up(player: PlayerController) -> bool:
  # Weapons shouldn't be pickable while equipped or in use
  return false

# world/cartridge_3d.gd
class_name Cartridge3D
extends Item3D

func _ready():
  super._ready()

func eject() -> void:
  if not data or not data is Ammo:
    return

  var ammo_data = data as Ammo
  visible = true
  mass = ammo_data.cartridge_mass / 1000.0

    # Improved ejection force calculation
  var force_multiplier = 3.0 + ammo_data.kinetic_energy  # Increased base force
  var ejection_force = Vector3(
    randf_range(1.0, 2.0),    # Increased X force (forward/backward)
    randf_range(1.0, 2.0),    # Increased Y force (upward)
    randf_range(-0.5, 0.5)    # Reduced Z force (sideways)
  ).normalized() * force_multiplier

    # Apply the force in global space relative to ejection direction
  ejection_force = global_transform.basis * ejection_force

    # Add more realistic spin
  var torque_impulse = Vector3(
    randf_range(-2.0, 2.0),   # Increased spin
    randf_range(-1.0, 1.0),
    randf_range(-3.0, 3.0)
  )

    # Enable physics and apply forces
  _enable_physics()
  apply_central_impulse(ejection_force)
  apply_torque_impulse(torque_impulse)

    # Adjust damping for better physics behavior
  angular_damp = 0.3    # Reduced for more spin
  linear_damp = 0.05    # Reduced for longer travel

    # Auto-disable physics after 3 seconds
  if auto_disable_physics:
    if physics_timer:
      physics_timer.start(3.0)
    else:
            # Create timer if it doesn't exist
      physics_timer = Timer.new()
      physics_timer.one_shot = true
      add_child(physics_timer)
      physics_timer.timeout.connect(_on_physics_timeout)
      physics_timer.start(3.0)

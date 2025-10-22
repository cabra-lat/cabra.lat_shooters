class_name SpringRecoil extends Node

@export var return_speed: float = 15.0
@export var damping: float = 0.9

var rotation_offset: Vector3 = Vector3.ZERO
var position_offset: Vector3 = Vector3.ZERO
var rotation_velocity: Vector3 = Vector3.ZERO
var position_velocity: Vector3 = Vector3.ZERO

var camera: Camera3D
var weapon_node: Node3D

func _ready():
    set_physics_process(true)

func _physics_process(delta):
    # Update rotation spring
    var rotation_force = -return_speed * rotation_offset - damping * rotation_velocity
    rotation_velocity += rotation_force * delta
    rotation_offset += rotation_velocity * delta

    # Update position spring
    var position_force = -return_speed * position_offset - damping * position_velocity
    position_velocity += position_force * delta
    position_offset += position_velocity * delta

    # Apply to camera
    if camera:
        camera.rotation_degrees = rotation_offset
        camera.position = position_offset

    # Apply to weapon (more subtle)
    if weapon_node:
        weapon_node.rotation_degrees = rotation_offset * 0.3
        weapon_node.position = position_offset * 0.5

    # Reset when very close to zero
    if rotation_offset.length() < 0.001 and position_offset.length() < 0.001:
        rotation_offset = Vector3.ZERO
        position_offset = Vector3.ZERO
        rotation_velocity = Vector3.ZERO
        position_velocity = Vector3.ZERO

func add_recoil(weapon: Weapon, is_aiming: bool = false):
    if not weapon: return

    var aim_multiplier = 0.3 if is_aiming else 1.0

    # Add recoil to velocity
    rotation_velocity += Vector3(
        -weapon.recoil_vertical * aim_multiplier,
        randf_range(-weapon.recoil_horizontal, weapon.recoil_horizontal) * aim_multiplier,
        randf_range(-weapon.recoil_tilt, weapon.recoil_tilt) * aim_multiplier
    )

    position_velocity += Vector3(
        randf_range(-0.005, 0.005),
        randf_range(-0.003, 0.003),
        -weapon.recoil_kick * aim_multiplier
    )

func reset():
    rotation_offset = Vector3.ZERO
    position_offset = Vector3.ZERO
    rotation_velocity = Vector3.ZERO
    position_velocity = Vector3.ZERO

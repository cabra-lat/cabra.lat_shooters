class_name MuzzleFlash3D
extends Node3D

@export var flash_size: float = 1.0
@export var flash_duration: float = 0.15
@export var light_energy: float = 8.0
@export var light_range: float = 3.0

# Billboard properties - now properly scaled
@export var use_billboard: bool = true
@export var billboard_size: float = 2.0  # 1.0 = 10cm, 2.0 = 20cm, etc.
@export var billboard_texture: Texture2D = preload("../../assets/effects/muzzle_flash.png")

# Direction control
@export var emission_direction: Vector3 = Vector3(0, 0, -1)
@export var spread_degrees: float = 15.0

var particles: GPUParticles3D
var light: OmniLight3D
var billboard: Sprite3D
var is_playing: bool = false

# Proper scaling constants
const PIXELS_PER_METER: float = 5120.0  # 512px for 0.1m = 5120px per meter
const BASE_PIXEL_SIZE: float = 0.000195  # 0.1 / 512

func _ready():
  _setup_components()
  _force_prewarm()

func _setup_components():
  # Particles
  particles = GPUParticles3D.new()
  particles.one_shot = true
  particles.amount = 8
  particles.lifetime = 0.2
  particles.preprocess = 0.3

  var process_material = ParticleProcessMaterial.new()
  process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
  process_material.emission_sphere_radius = 0.01

  process_material.direction = emission_direction.normalized()
  process_material.spread = deg_to_rad(spread_degrees)
  process_material.gravity = Vector3(0, 0, 0)

  process_material.initial_velocity_min = 1.0
  process_material.initial_velocity_max = 2.0

  process_material.scale_min = 0.3
  process_material.scale_max = 0.8
  process_material.color_ramp = _create_flash_color_ramp()

  particles.process_material = process_material

  # Light
  light = OmniLight3D.new()
  light.omni_range = light_range
  light.light_energy = 0.0
  light.light_color = Color(1.0, 0.7, 0.3)
  light.shadow_enabled = false

  # Billboard/Sprite3D - now properly scaled
  if use_billboard:
    billboard = Sprite3D.new()
    billboard.texture = billboard_texture
    billboard.pixel_size = BASE_PIXEL_SIZE  # Properly scaled for 10cm at 512px
    billboard.modulate = Color.TRANSPARENT
    billboard.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    billboard.visible = false
    add_child(billboard)

  add_child(particles)
  add_child(light)

func _create_flash_color_ramp() -> GradientTexture1D:
  var gradient = Gradient.new()
  gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
  gradient.set_color(0.1, Color(1.0, 0.9, 0.2, 1.0))
  gradient.set_color(0.3, Color(1.0, 0.6, 0.1, 0.8))
  gradient.set_color(0.6, Color(0.8, 0.3, 0.0, 0.4))
  gradient.set_color(1.0, Color(0.5, 0.2, 0.0, 0.0))

  var texture = GradientTexture1D.new()
  texture.gradient = gradient
  return texture

func _force_prewarm():
  particles.emitting = true
  var timer = get_tree().create_timer(0.01)
  timer.timeout.connect(_stop_prewarm)

func _stop_prewarm():
  particles.emitting = false

func play_flash(custom_size: float = -1.0):
  if is_playing:
    return

  is_playing = true

  var final_size = custom_size if custom_size > 0 else flash_size

  # Scale particles
  particles.scale = Vector3.ONE * final_size

  # Play particles
  particles.restart()
  particles.emitting = true

  # Light flash
  light.light_energy = light_energy * final_size
  var tween = create_tween()
  tween.set_parallel(true)
  tween.tween_property(light, "light_energy", 0.0, flash_duration)

  # Billboard effect - now properly scaled
  if use_billboard and billboard:
    _play_billboard_effect(final_size)

  # Reset flag after duration
  var timer = get_tree().create_timer(0.2)
  timer.timeout.connect(func(): is_playing = false)

func _play_billboard_effect(flash_scale: float):
  billboard.visible = true
  billboard.modulate = Color(1.0, 1.0, 1.0, 1.0)

  # Calculate proper size based on real-world scale
  var base_size = BASE_PIXEL_SIZE * billboard_size
  billboard.pixel_size = base_size * flash_scale

  var tween = create_tween()
  tween.set_parallel(true)

  # Quick flash animation - expand and fade
  tween.tween_property(billboard, "pixel_size", base_size * 1.5 * flash_scale, 0.02)
  tween.chain().tween_property(billboard, "pixel_size", base_size * 1.2 * flash_scale, 0.05)
  tween.chain().tween_property(billboard, "pixel_size", base_size * 0.8 * flash_scale, 0.08)

  # Fade out
  tween.tween_property(billboard, "modulate:a", 0.0, 0.1)

  # Hide when done
  tween.tween_callback(func():
    if is_instance_valid(billboard):
      billboard.visible = false
  )

func stop_flash():
  particles.emitting = false
  light.light_energy = 0.0
  if billboard and is_instance_valid(billboard):
    billboard.visible = false
  is_playing = false

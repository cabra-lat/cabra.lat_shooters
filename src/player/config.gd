class_name PlayerConfig extends Resource

const NOT_MOVING: float = 0.0
const NO_BOBBING: float = 0.0

@export var gravity: float = 9.81
@export var gentle_push: float = 10.0
@export var mouse_sensitivity: float = 1.0 # this is more like a game settings

@export_group("Maximum")
@export var max_weight: float = 100 ## Maximum amount of weight player can carry
@export var letal_acceleration: float = 50 ## Maximum amount of acceleration player can take

@export_group("Default")
@export var default_fov: float = 50.0
@export var default_height: float = 1.70 # m
@export var default_shoulder: float = 0.14 # 14 cm
@export var default_bobing: float = 0.01
@export var default_turn_speed: int = 1
@export var default_lean_angle: float = deg_to_rad(30)
@export var default_speed: float = 4
@export var default_jump_impulse: float = 4

# AIMING
@export_group("Aiming")
@export var aim_fov: float = 45.0          # Narrower FOV when aiming
@export var aim_time: float = 0.25         # Time to fully aim (seconds)
@export var aim_shoulder_x: float = 0.15
@export var aim_focused_fov: float = 30    # default_fov - 20
@export var aim_focused_duration: float = 1.0 # Max duration

# WALKING
@export_group("Walking")
@export var walk_fov: float = default_fov
@export var walk_speed: float = default_speed
@export var walk_height: float = 0.9 * default_height
@export var walk_bobbing: float = default_bobing

# CROUCHING
@export_group("Crouching")
@export var crouch_time: float = 0.125 # s
@export var crouch_speed: float = 0.5 * walk_speed
@export var crouch_height: float = 0.5 * default_height
@export var crouch_bobbing: float = 0.5 * default_bobing

# SPRINTING
@export_group("Sprinting")
@export var sprint_fov: float = 1.5 * default_fov
@export var sprint_speed: float = 2.5 * walk_speed
@export var sprint_height: float = 0.85 * default_height
@export var sprint_bobbing: float = 1.5 * default_bobing

# PRONING
@export_group("Proning")
@export var prone_time: float = 0.25 # s
@export var prone_speed: float =  0.25 * walk_speed
@export var prone_height: float = 0.1 * default_height
@export var prone_bobbing: float = 0.1 * default_bobing

@export_group("Leaning")
@export var lean_angle_idle: float = 1.0 * default_lean_angle
@export var lean_angle_walk: float = 0.9 * default_lean_angle
@export var lean_speed:      float = 2.0 *  default_speed
@export var lean_time:       float = 0.25 # s

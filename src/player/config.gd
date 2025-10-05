class_name PlayerConfig
extends Resource

@export_group("Maximum")
@export var max_weight: int = 100 ## Maximum amount of weight player can carry
@export var letal_acceleration: float = 50 ## Maximum amount of acceleration player can take

@export_group("Default")
@export var default_fov: int = 50
@export var default_height: float = 2.0
@export var default_shoulder: float = 0.14
@export var not_moving: int = 0
@export var no_bobbing: int = 0
@export var turn_speed: int = 1

# AIMING
@export_group("Aiming")
@export var aim_fov: float = 45.0          # Narrower FOV when aiming
@export var aim_time: float = 0.25         # Time to fully aim (seconds)
@export var aim_down_amount: float = 0.15  # How much camera lowers when aiming
@export var aim_steady_amount: float = 0.5 # How much head bobbing is reduced
@export var aim_focused_fov: int = 20  # default_fov - 20

# WALKING
@export_group("Walking")
@export var walk_fov: int = 70
@export var walk_speed: int = 4
@export var walk_height: float = -0.1
@export var walk_bobbing: float = 0.2

# CROUCHING
@export_group("Crouching")
@export var crouch_speed: float = 2.0  # 0.5 * walk_speed
@export var crouch_height: float = 0.45  # 0.5 * default_height
@export var crouch_bobbing: float = 0.0

# SPRINTING
@export_group("Sprinting")
@export var sprint_fov: int = 80
@export var sprint_speed: float = 6.0  # 1.5 * walk_speed
@export var sprint_height: float = -0.3
@export var sprint_bobbing: float = 0.7

# PRONING
@export_group("Proning")
@export var prone_height: float = 0.09  # 0.1 * default_height
@export var prone_speed: float = 1.0  # 0.25 * walk_speed

@export_group("Leaning")
@export var lean_angle_while_idling = 45
@export var lean_angle_while_walking = 30
@export var lean_speed: float = 0.2

var speed = 4
var camera_fov: float = 70.0
var head_bobbing = 0.01
var camera_height = 0.9
var lean_angle = 0.2
var jump_impulse = 5

func idle():
	speed = not_moving
	camera_fov = default_fov
	head_bobbing = no_bobbing
	camera_height = default_height
	lean_angle = lean_angle_while_idling

func walk():
	speed = walk_speed
	camera_fov = walk_fov
	head_bobbing = walk_bobbing
	camera_height = walk_height
	lean_angle = lean_angle_while_walking

func sprint():
	speed = sprint_speed
	camera_fov = sprint_fov
	head_bobbing = sprint_bobbing
	camera_height = sprint_height

func prone():
	speed = prone_speed
	camera_fov = default_fov
	head_bobbing = no_bobbing
	camera_height = prone_height

func crouch():
	speed = crouch_speed
	camera_fov = default_fov
	head_bobbing = crouch_bobbing
	camera_height = crouch_height

func lean():
	speed = min(speed, crouch_speed)

func focus():
	camera_fov = aim_focused_fov
	head_bobbing = no_bobbing
	speed = min(speed, crouch_speed)

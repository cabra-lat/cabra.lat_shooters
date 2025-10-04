class_name PlayerConfig
extends Resource

@export var max_weight: int = 100
@export var max_slots: int = 100
@export var max_weapons: int = 100
@export var turn_speed: int = 1

@export var letal_acceleration: float = 50 # g
@export var default_fov: int = 50
@export var default_height: float = 0.9
@export var not_moving: int = 0
@export var no_bobbing: int = 0
@export var focused_fov: int = 50  # default_fov - 20

# WALKING
@export var walk_fov: int = 70
@export var walk_speed: int = 4
@export var walk_height: float = -0.1
@export var walk_bobbing: float = 0.2

# CROUCHING
@export var crouch_speed: float = 2.0  # 0.5 * walk_speed
@export var crouch_height: float = 0.45  # 0.5 * default_height
@export var crouch_bobbing: float = 0.0

# SPRINTING
@export var sprint_fov: int = 80
@export var sprint_speed: float = 6.0  # 1.5 * walk_speed
@export var sprint_height: float = -0.3
@export var sprint_bobbing: float = 0.7

# PRONING
@export var prone_height: float = 0.09  # 0.1 * default_height
@export var prone_speed: float = 1.0  # 0.25 * walk_speed

var speed = 4
var camera_fov = 70
var head_bobbing = 0
var camera_height = 0.9
var lean_angle = 0
var jump_impulse = 1

func idle():
	speed = not_moving
	camera_fov = default_fov
	head_bobbing = no_bobbing
	camera_height = default_height
	lean_angle = 10

func walk():
	speed = walk_speed
	camera_fov = walk_fov
	head_bobbing = walk_bobbing
	camera_height = walk_height
	lean_angle = 5

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
	camera_fov = focused_fov
	head_bobbing = no_bobbing
	speed = min(speed, crouch_speed)

class_name PlayerMovementParameters
extends RefCounted
## Pure stance/movement parameter selection for PlayerController.
##
## State-machine and camera side effects stay in the controller. The caller
## owns one reusable result object, so the physics hot path does not allocate;
## this method only turns state names and condition multipliers into fields.

const EYE_STAND: float = 1.62
const EYE_CROUCH: float = 1.05
const EYE_PRONE: float = 0.45
const CAPSULE_STAND: float = 1.0
const CAPSULE_CROUCH: float = 0.55
const CAPSULE_PRONE: float = 0.35

var speed: float = 0.0
var head_bobbing: float = 0.0
var camera_height: float = 0.0
var camera_fov: float = 0.0
var capsule_factor: float = CAPSULE_STAND
var lean_direction: float = 0.0

func resolve(
    config: PlayerConfig,
    moving_state: String,
    crouching_state: String,
    aiming_state: String,
    leaning_state: String,
    condition_multiplier: float,
    stamina_fov_multiplier: float) -> void:
  if config == null:
    return
  var result := self
  result.speed = config.default_speed
  result.head_bobbing = config.default_bobing
  result.camera_height = config.stand_height
  result.camera_fov = config.default_fov
  result.capsule_factor = CAPSULE_STAND
  result.lean_direction = 0.0

  match moving_state:
    "Stopped":
      result.speed = config.default_speed
      result.head_bobbing = config.default_bobing
    "Walking":
      result.speed = config.walk_speed
      result.head_bobbing = config.walk_bobbing
    "Sprinting":
      result.speed = config.sprint_speed
      result.head_bobbing = config.sprint_bobbing
    "Falling":
      pass

  match crouching_state:
    "Crouching":
      result.speed = config.crouch_speed
      result.head_bobbing = config.crouch_bobbing
    "Proning":
      result.speed = config.prone_speed
      result.head_bobbing = config.prone_bobbing

  match leaning_state:
    "LeaningRight":
      result.speed = config.lean_speed
      result.lean_direction = -1.0
    "LeaningLeft":
      result.speed = config.lean_speed
      result.lean_direction = 1.0

  match aiming_state:
    "Aiming":
      result.speed = config.crouch_speed
      result.head_bobbing = config.NO_BOBBING
      result.camera_fov = config.aim_fov
    "HoldingBreath":
      result.speed = config.prone_speed
      result.head_bobbing = config.NO_BOBBING
      result.camera_fov = config.aim_focused_fov

  match crouching_state:
    "Crouching":
      result.camera_height = EYE_CROUCH
      result.capsule_factor = CAPSULE_CROUCH
    "Proning":
      result.camera_height = EYE_PRONE
      result.capsule_factor = CAPSULE_PRONE
    _:
      result.camera_height = EYE_STAND
      result.capsule_factor = CAPSULE_STAND

  result.speed *= condition_multiplier
  result.camera_fov *= stamina_fov_multiplier

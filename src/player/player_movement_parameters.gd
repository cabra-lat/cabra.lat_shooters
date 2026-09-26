class_name PlayerMovementParameters
extends Resource
## Pure stance/movement parameter selection for PlayerController.
##
## State-machine and camera side effects stay in the controller. The caller
## owns one reusable result object, so the physics hot path does not allocate;
## this method only turns state names and condition multipliers into fields.
##
## WHY THIS IS A Resource AND NOT A RefCounted. A RefCounted carrying only consts
## has nowhere to put an authored state, so states have to live in code as string
## literals in a match ladder. Resource is what makes a state authorable as a
## .tres: the fields below are exported, so a .tres can carry a named state with
## its own values, and a state machine can select RESOURCES instead of strings.
##
## THE MUTATION HAZARD, WHICH IS WHY THIS IS NOT A DROP-IN. resolve() writes into
## the instance, and a Resource loaded from a .tres is SHARED, so writing into it
## at runtime would edit the authored asset. Every load therefore goes through
## instantiate_local() and never through load().instantiate(). The controller
## still keeps exactly one of these per frame for the no-allocation reason it
## always did: the authored .tres is the input, this object is the scratch result.

const EYE_STAND: float = 1.62
const EYE_CROUCH: float = 1.05
const EYE_PRONE: float = 0.45
const COLLIDER_STAND: float = 1.0
const COLLIDER_CROUCH: float = 0.55
const COLLIDER_PRONE: float = 0.35

## Identifies which authored state this resource represents. Empty on the scratch
## instance the controller resolves into every frame; a .tres names itself so a
## state machine can select it by identity rather than by a string literal
## repeated across files.
@export var state_id: StringName = &""

@export_group("Resolved output")
## Resolved values for the CURRENT frame, not authored constants. Exported so a
## .tres can seed a state. The controller reads these and never trusts them
## without resolve() having run first.
@export var speed: float = 0.0
@export var head_bobbing: float = 0.0
@export var camera_height: float = 0.0
@export var camera_fov: float = 0.0
@export var collider_factor: float = COLLIDER_STAND
@export var lean_direction: float = 0.0

## Private copy of an authored state. load() would hand back the SHARED asset and
## resolve() would then edit the authored state at runtime; duplicate() is the
## only safe way to get an instance this class may write into.
static func instantiate_local(state: Resource) -> PlayerMovementParameters:
  if state == null:
    return null
  var local: PlayerMovementParameters = state.duplicate() as PlayerMovementParameters
  if local == null:
    push_error("PlayerMovementParameters.instantiate_local: wrong type %s" % state.get_class())
    return null
  local.resource_local_to_scene = true
  return local


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
  # The ladder below still selects by state NAME rather than by resource. That is
  # the next step and it is deliberately not smuggled in here: this conversion
  # makes states AUTHORABLE, and selecting them is a separate change that needs
  # its own evidence. A resource that can be authored but is never selected is
  # not a state machine, and describing this commit as one would be a lie.
  var result := self
  result.speed = config.default_speed
  result.head_bobbing = config.default_bobing
  result.camera_height = config.stand_height
  result.camera_fov = config.default_fov
  result.collider_factor = COLLIDER_STAND
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
      result.collider_factor = COLLIDER_CROUCH
    "Proning":
      result.camera_height = EYE_PRONE
      result.collider_factor = COLLIDER_PRONE
    _:
      result.camera_height = EYE_STAND
      result.collider_factor = COLLIDER_STAND

  result.speed *= condition_multiplier
  result.camera_fov *= stamina_fov_multiplier

class_name PlayerMovementParameters
extends Resource

## Authored selector states, one per leaning state. The directory is a const
## because an inline long path is what I truncated once already.
const LEANING_DIR := "res://addons/cabra.lat_shooters/src/player/resources/states/leaning/"
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

  # SELECTOR LAYER (leaning axis). The authored .tres carries state_id and
  # lean_direction; speed still comes from config.lean_speed, so tuning stays in
  # one place and no config value is frozen into authored data.
  # Sign convention is owned by the CONSUMER, not by these files:
  # controller.gd reads parameters.lean_direction into _lean_dir, documented
  # there as -1 right, +1 left, and uses peek_target = -_lean_dir * OFFSET.
  #
  # The directory is ENUMERATED, not named. A hardcoded list of three keys made
  # adding a state a two-place edit where neither place fails when the other is
  # missed, so a fourth authored state would exist, be authorable, and be
  # unreachable. Content the selector cannot address is not authored data.
  # An undeclared state is LOUD, not a silent no-op returning a plausible result.
  #
  # SCOPE, WRITTEN DOWN ON PURPOSE SO THE NEXT PERSON SEES IT HERE. This
  # selector is the LEANING axis ONLY. The other three axes still select by
  # string literal in code: match moving_state, match aiming_state, and
  # crouching_state TWICE. The asymmetry is a choice, not an oversight - the
  # leaning axis was the safe first cut because it is the only one whose arms
  # set lean_direction rather than pulling config values, so neither the
  # config-freeze hazard nor the EYE_STAND default-arm override applies to it.
  # THE HAZARD THIS CREATES, STATED PLAINLY: adding a state to moving_state,
  # aiming_state or crouching_state is STILL a two-place edit, in code and in
  # its graph, and neither place fails when the other is missed. Migrating those
  # three axes is a separate card, not a quiet extension of this one.
  # KNOWN AND DELIBERATELY NOT CHANGED: crouching_state is matched twice in
  # this function, at the speed/head_bobbing arm and again at the final
  # camera_height/collider_factor arm. Same values, behaviour unaffected, and
  # folding them into one arm would be a behaviour change rather than a
  # refactor, so it does not belong in a behaviour-preserving pass. It is
  # flagged as a maintenance hazard: one axis, two literal ladders to keep in step.
  var _lean_matched := false
  for _lf in DirAccess.get_files_at(LEANING_DIR):
    if not _lf.ends_with(".tres"):
      continue
    var _ls: PlayerMovementParameters = instantiate_local(load(LEANING_DIR + _lf))
    if _ls == null or String(_ls.state_id) != leaning_state:
      continue
    result.lean_direction = _ls.lean_direction
    if String(_ls.state_id) != "NotLeaning":
      result.speed = config.lean_speed
    _lean_matched = true
    break
  if not _lean_matched:
    push_warning(
      "PlayerMovementParameters.resolve: no authored leaning state declares '%s'. "
      % leaning_state
      + "Add a .tres with that state_id under %s." % LEANING_DIR)

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

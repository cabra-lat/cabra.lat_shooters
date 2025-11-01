class_name PlayerInput
extends MultiplayerSynchronizer

# Raw input conditions - these are what the AnimationTree will use
@export var motion := Vector2()
@export var jump_pressed := false
@export var sprint_held := false
@export var crouch_held := false
@export var crouch_toggle := false
@export var prone_held := false
@export var prone_toggle := false
@export var aim_held := false
@export var focus_held := false
@export var fire_held := false
@export var reload_pressed := false
@export var firemode_pressed := false
@export var lean_left := false
@export var lean_right := false
@export var weapon_equip := false
@export var weapon_drop := false

# Mouse look
@export var mouse_delta := Vector2()

func _ready() -> void:
  if get_multiplayer_authority() == multiplayer.get_unique_id():
    set_process(true)
    set_process_input(true)
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
  else:
    set_process(false)
    set_process_input(false)

func _process(_delta: float) -> void:
  if not is_multiplayer_authority():
    return
  # Capture all raw input states - NO LOGIC, just direct input mapping
  motion = Vector2(
    Input.get_action_strength("right") - Input.get_action_strength("left"),
    Input.get_action_strength("forward") - Input.get_action_strength("back")
  )

  jump_pressed    = Input.is_action_just_pressed("jump")
  sprint_held     = Input.is_action_pressed("sprint")
  crouch_held     = Input.is_action_pressed("crouch")
  crouch_toggle   = Input.is_action_just_pressed("crouch_toggle")
  prone_held      = Input.is_action_pressed("prone")
  prone_toggle    = Input.is_action_just_pressed("prone_toggle")
  aim_held        = Input.is_action_pressed("aim")
  focus_held      = Input.is_action_pressed("focus")
  fire_held       = Input.is_action_pressed("fire")
  reload_pressed  = Input.is_action_just_pressed("reload")
  firemode_pressed = Input.is_action_just_pressed("firemode")
  lean_left        = Input.is_action_pressed("lean_left")
  lean_right       = Input.is_action_pressed("lean_right")
  weapon_equip     = Input.is_action_just_pressed("weapon_slot1")
  weapon_drop      = Input.is_action_just_pressed("weapon_drop")

func _input(event: InputEvent) -> void:
  if not is_multiplayer_authority():
    return

  if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
    mouse_delta = event.relative

  if event.is_action_pressed("ui_cancel"):
    if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
      Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    else:
      Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Reset mouse delta after it's been read
func consume_mouse_delta() -> Vector2:
  var delta = mouse_delta
  mouse_delta = Vector2.ZERO
  return delta

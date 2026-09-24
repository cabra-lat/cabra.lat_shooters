class_name PlayerInput
extends MultiplayerSynchronizer

# Raw input conditions - these are what the AnimationTree will use
@export var motion := Vector2()
@export var jump_pressed := false
@export var sprint_held := false
@export var crouch_toggle := false
@export var prone_toggle := false
@export var crouch_held := false
@export var prone_held := false
@export var uncrouch := false
@export var unprone := false
@export var aim_held := false
@export var focus_held := false
@export var fire_held := false
@export var reload_held := false
@export var firemode_held := false
@export var lean_left := false
@export var lean_right := false
@export var weapon_equip := false
@export var weapon_drop := false
@export var clear_malfunction := false

# Equipment mirror: scenes (arena/debug_range) equip programmatically, so the
# aiming SM would sit in BareHanded forever waiting for the weapon_slot1 key
# edge. Assigned by the controller in _ready; flags below OR it in.
var equipment_source: Equipment = null

# Physical gates written by the controller (survival): a tired or overloaded
# player cannot start a sprint or a jump, using the SM's own transitions.
var sprint_allowed: bool = true
var jump_allowed: bool = true

# Combat gates (inventory UI / menus): when suppressed, combat actions
# (fire, aim, reload, etc.) read false so clicks in the UI do not pull triggers.
var combat_allowed: bool = true
var inventory_ui: CanvasItem = null

func is_combat_allowed() -> bool:
  if not combat_allowed:
    return false
  if inventory_ui != null:
    if inventory_ui.visible:
      return false
  else:
    var parent = get_parent()
    if parent != null:
      var inv = parent.get("inventory_ui")
      if inv != null and inv.visible:
        return false
  return true

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

  motion = Vector2(
    Input.get_action_strength("right") - Input.get_action_strength("left"),
    Input.get_action_strength("forward") - Input.get_action_strength("back")
  )

  jump_pressed    = Input.is_action_just_pressed("jump") and jump_allowed
  sprint_held     = Input.is_action_pressed("sprint") and sprint_allowed

  # Capture raw input
  var crouch_toggle_pressed = Input.is_action_just_pressed("crouch_toggle")
  var prone_toggle_pressed = Input.is_action_just_pressed("prone_toggle")
  var raw_crouch_held = Input.is_action_pressed("crouch")
  var raw_prone_held = Input.is_action_pressed("prone")

  # Reset transition flags
  uncrouch = false
  unprone = false

  # Handle toggle presses
  if crouch_toggle_pressed:
    crouch_toggle = not crouch_toggle
    # If enabling crouch, disable prone
    if crouch_toggle:
      prone_toggle = false
      unprone = true

  if prone_toggle_pressed:
    prone_toggle = not prone_toggle
    # If enabling prone, disable crouch
    if prone_toggle:
      crouch_toggle = false
      uncrouch = true

  # Handle hold actions - these work independently of toggle states
  # When a hold button is pressed, it should override any toggle state
  if raw_crouch_held:
    # Force crouch state, cancel any prone toggle
    if prone_toggle:
      prone_toggle = false
      unprone = true
    crouch_held = true
  else:
    crouch_held = false
    # If we're not holding crouch and not in crouch toggle, signal uncrouch
    if not crouch_toggle:
      uncrouch = true

  if raw_prone_held:
    # Force prone state, cancel any crouch toggle
    if crouch_toggle:
      crouch_toggle = false
      uncrouch = true
    prone_held = true
  else:
    prone_held = false
    # If we're not holding prone and not in prone toggle, signal unprone
    if not prone_toggle:
      unprone = true

  var can_fight := is_combat_allowed()

  aim_held        = can_fight and Input.is_action_pressed("aim")
  focus_held      = can_fight and Input.is_action_pressed("focus")
  fire_held       = can_fight and Input.is_action_pressed("fire")
  reload_held     = can_fight and Input.is_action_pressed("reload")
  firemode_held   = can_fight and Input.is_action_pressed("firemode")
  lean_left       = can_fight and Input.is_action_pressed("lean_left")
  lean_right      = can_fight and Input.is_action_pressed("lean_right")
  weapon_equip    = can_fight and Input.is_action_just_pressed("weapon_slot1")
  weapon_drop     = can_fight and Input.is_action_just_pressed("weapon_drop")
  clear_malfunction = can_fight and InputMap.has_action("clear_malfunction") \
    and Input.is_action_just_pressed("clear_malfunction")
  sync_equip_flags()

## Fold real equipment state into the SM edge flags (called every frame
## from _process; also directly testable headless).
func sync_equip_flags() -> void:
  var armed := _weapon_equipped()
  weapon_equip = weapon_equip or armed
  weapon_drop = weapon_drop or not armed

func _weapon_equipped() -> bool:
  if equipment_source == null:
    return false
  return equipment_source.is_equipped("primary") \
    or equipment_source.is_equipped("secondary")

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

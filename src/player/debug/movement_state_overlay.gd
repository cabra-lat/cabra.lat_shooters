class_name MovementStateOverlay
extends CanvasLayer
## F5 movement-state debug shell (deliverable 1 of e5ba17).
##
## WHY THE BINDING KEY IS IN THE LAYOUT AT ALL, rather than the state name
## alone: a panel that prints "crouch" without the key tells you what the
## player thinks, not what you pressed. Those disagree exactly when the bug is
## a BINDING bug, which is the case this shell exists to make visible. So every
## row is "state -- key", and the key is resolved from the live InputMap at
## draw time rather than written as a literal, so a rebind shows up on the next
## frame instead of contradicting the panel for the rest of the session.
##
## An action with NO events is printed as UNBOUND rather than omitted. Omission
## would make a missing binding indistinguishable from a state that is simply
## not active, and "the row is not there" is the one thing a debug shell must
## never do to the person reading it.

const TOGGLE_ACTION := "debug_toggle_movement_overlay"

## State name (as it appears on PlayerInput) -> the action that drives it.
## Two spellings per stance on purpose: crouch and crouch_toggle are DIFFERENT
## actions with different semantics (held vs toggled) and a panel that merged
## them would hide a stuck-toggle bug behind a working hold.
const ROWS: Array[Dictionary] = [
	{"state": "motion",            "action": "",                 "kind": "axis"},
	{"state": "sprint_held",       "action": "sprint",           "kind": "hold"},
	{"state": "jump_pressed",      "action": "jump",             "kind": "edge"},
	{"state": "crouch_held",       "action": "crouch",           "kind": "hold"},
	{"state": "crouch_toggle",     "action": "crouch_toggle",    "kind": "edge"},
	{"state": "prone_held",        "action": "prone",            "kind": "hold"},
	{"state": "prone_toggle",      "action": "prone_toggle",     "kind": "edge"},
	{"state": "lean_left",         "action": "lean_left",        "kind": "hold"},
	{"state": "lean_right",        "action": "lean_right",       "kind": "hold"},
	{"state": "aim_held",          "action": "aim",              "kind": "hold"},
	{"state": "focus_held",        "action": "focus",            "kind": "hold"},
	{"state": "fire_held",         "action": "fire",             "kind": "hold"},
	{"state": "reload_held",       "action": "reload",           "kind": "edge"},
	{"state": "firemode_held",     "action": "firemode",         "kind": "edge"},
]

var _label: Label
var _player_input: Node = null


func _ready() -> void:
	layer = 100
	visible = false
	_label = Label.new()
	_label.position = Vector2(12, 12)
	_label.add_theme_font_size_override("font_size", 14)
	# Fixed width so the columns line up and a long key name does not shift the
	# state column mid-session; a panel whose layout reflows is harder to read
	# than one that is dull.
	_label.custom_minimum_size = Vector2(520, 0)
	_label.text = ""
	add_child(_label)
	_find_player_input(get_tree().current_scene)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(TOGGLE_ACTION):
		visible = not visible
		# Consume it: F5 must not also reach whatever else is listening, or the
		# shell you opened becomes a second way to break the frame.
		get_viewport().set_input_as_handled()
		return
	if visible and event is InputEventKey and event.pressed and not event.echo:
		# Any key press while open re-renders, so a rebind made live in the
		# input map is reflected without reopening the panel.
		_render()


func _process(_delta: float) -> void:
	if visible:
		_render()


func _render() -> void:
	var lines: Array[String] = ["MOVEMENT STATE  (F5 toggles)"]
	lines.append("state                 kind   key(s)                value")
	lines.append("--------------------------------------------------")
	if _player_input == null:
		# Admit blindness rather than drawing an empty panel. A shell that
		# renders header-only and looks fine is worse than one that says it
		# cannot see the player.
		lines.append("!! PlayerInput NOT FOUND -- every row is UNKNOWN, not off")
		lines.append("   (an overlay with no subject is the check-that-cannot-fail)")
	_label.text = "\n".join(lines)


## Resolve the LIVE binding for an action. Returns a human string; never an
## empty one, so a missing binding is visible rather than silent.
static func binding_text(action: String) -> String:
	if action == "":
		return "(derived from the movement axis)"
	if not InputMap.has_action(action):
		return "NO SUCH ACTION"
	var evs: Array[InputEvent] = InputMap.action_get_events(action)
	if evs.is_empty():
		return "UNBOUND"
	var parts: Array[String] = []
	for e in evs:
		if e is InputEventKey:
			parts.append(OS.get_keycode_string(e.physical_keycode) if e.physical_keycode != 0 \
				else OS.get_keycode_string(e.keycode))
		elif e is InputEventMouseButton:
			parts.append("Mouse%d" % e.button_index)
		elif e is InputEventJoypadButton:
			parts.append("Pad%d" % e.button_index)
		elif e is InputEventJoypadMotion:
			parts.append("Axis%d%s" % [e.axis, "+" if e.axis_value > 0.0 else "-"])
		else:
			parts.append(e.as_text())
	if parts.is_empty():
		return "UNMAPPED EVENT"
	return " / ".join(parts)


func _find_player_input(n: Node) -> void:
	if n == null:
		return
	if n.get_script() != null and n.get_script().get_global_name() == "PlayerInput":
		_player_input = n
		return
	for c in n.get_children():
		_find_player_input(c)
		if _player_input != null:
			return

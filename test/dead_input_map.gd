class_name DeadInputMap
extends RefCounted
## DEAD_INPUT action -> observable map for the arena tester bot (slice 1).
##
## WHY EACH ROW CARRIES A WINDOW AND NOT JUST A SIGNAL. "An action held whose
## observable effect does not occur" is not decidable without a timescale, and
## a single global timeout is the wrong tool in both directions: too short and
## it flags every SLOW action as dead, too long and it excuses every DEAD one.
## The second failure is the one that matters, because a detector that cannot
## fail wearing a longer number is the same defect as a check that passes on
## zero checks -- it looks like coverage and reports silence as health. So the
## window is part of the row, the window is printed with every verdict, and a
## verdict is meaningless without the row that produced it.
##
## ACTION NAMES, verified against project.godot rather than assumed: the
## movement actions are `forward back left right`. There is no `move_forward`;
## pressing an undefined action is a SILENT NO-OP that would make this whole
## detector report the movement path as dead.
##
## Rows are keyed by the PlayerInput state they observe (input.gd), so a state
## that changes shape shows up as an unmapped row rather than as a false pass.

enum Kind { AXIS, HOLD, EDGE }

## kind: how the state is expected to behave.
## window: physics frames after the action is held before the absence of the
##   observable is a verdict rather than a maybe. Chosen per action, not global.
const ROWS: Array[Dictionary] = [
	{
		"action": "forward", "state": "motion.y", "kind": Kind.AXIS,
		"observable": "horizontal displacement", "min_value": 0.01,
		"window": 30, "unit": "m",
		"note": "negative axis is legitimate: walking backwards down +Z is not a dead input",
	},
	{
		"action": "back", "state": "motion.y", "kind": Kind.AXIS,
		"observable": "horizontal displacement", "min_value": 0.01,
		"window": 30, "unit": "m",
	},
	{
		"action": "left", "state": "motion.x", "kind": Kind.AXIS,
		"observable": "horizontal displacement", "min_value": 0.01,
		"window": 30, "unit": "m",
	},
	{
		"action": "right", "state": "motion.x", "kind": Kind.AXIS,
		"observable": "horizontal displacement", "min_value": 0.01,
		"window": 30, "unit": "m",
	},
	{
		"action": "sprint", "state": "sprint_held", "kind": Kind.HOLD,
		"observable": "player speed exceeds the walk speed", "min_value": 0.1,
		"window": 45, "unit": "m/s over walk",
		"note": "sprint is only observable WHILE MOVING: a sprint on a standing player is VOID, not dead",
	},
	{
		"action": "jump", "state": "jump_pressed", "kind": Kind.EDGE,
		"observable": "vertical displacement on the rising edge", "min_value": 0.05,
		"window": 6, "unit": "m",
		"note": "SHORT window: 6 frames, because a jump resolves fast and a long window would excuse a dead jump",
	},
	{
		"action": "crouch", "state": "crouch_held", "kind": Kind.HOLD,
		"observable": "stance state becomes crouched", "min_value": 1.0,
		"window": 10, "unit": "state",
		"note": "held; distinct from crouch_toggle, which is a separate action with separate semantics",
	},
	{
		"action": "crouch_toggle", "state": "crouch_toggle", "kind": Kind.EDGE,
		"observable": "stance state flips once per press", "min_value": 1.0,
		"window": 10, "unit": "transition",
	},
	{
		"action": "prone", "state": "prone_held", "kind": Kind.HOLD,
		"observable": "stance state becomes prone", "min_value": 1.0,
		"window": 10, "unit": "state",
		"note": "prone and prone_toggle are BOTH bound to Z in this project - two actions, one key",
	},
	{
		"action": "prone_toggle", "state": "prone_toggle", "kind": Kind.EDGE,
		"observable": "stance state flips once per press", "min_value": 1.0,
		"window": 10, "unit": "transition",
	},
	{
		"action": "fire", "state": "fire_held", "kind": Kind.HOLD,
		"observable": "a shot is emitted", "min_value": 1.0,
		"window": 20, "unit": "shots",
		"note": "an empty magazine is a DIFFERENT defect (NO_FEEDBACK) and must not be reported as DEAD_INPUT",
	},
	{
		"action": "reload", "state": "reload_held", "kind": Kind.EDGE,
		"observable": "magazine state changes", "min_value": 1.0,
		"window": 90, "unit": "state",
		"note": "LONG window on purpose: a reload legitimately takes about a second",
	},
	{
		"action": "aim", "state": "aim_held", "kind": Kind.HOLD,
		"observable": "aim state becomes true", "min_value": 1.0,
		"window": 10, "unit": "state",
	},
	{
		"action": "firemode", "state": "firemode_held", "kind": Kind.EDGE,
		"observable": "fire mode changes", "min_value": 1.0,
		"window": 10, "unit": "transition",
	},
]

## The STUCK threshold, kept here rather than in the caller so the two
## detectors cannot drift apart. 0.1 m over 30 frames, per the card.
const STUCK_DISTANCE := 0.1
const STUCK_FRAMES := 30


## Look up a row by action name. Returns {} when absent, and the caller must
## treat that as VOID -- never as "did not fire" and never as a pass.
static func row_for(action: String) -> Dictionary:
	for r in ROWS:
		if r["action"] == action:
			return r
	return {}


## Human-readable table, printed alongside every verdict so a reader can audit
## what was covered AND what the thresholds were, instead of taking a count on
## trust. Coverage that is asserted rather than shown is the thing this whole
## session has been about.
static func coverage_table() -> String:
	var lines: Array[String] = []
	lines.append("DEAD_INPUT map  (action | state | observable | window)")
	lines.append("-------------------------------------------------------------")
	for r in ROWS:
		lines.append("%-14s %-16s %-34s %3d frames" % [
			r["action"], r["state"], r["observable"], r["window"]])
		var n: String = r.get("note", "")
		if n != "":
			lines.append("%14s ^ %s" % ["", n])
	lines.append("")
	lines.append("rows=%d   unmapped actions are VOID, never passing" % ROWS.size())
	return "\n".join(lines)


## Actions a caller may exercise, i.e. the ones with a live binding. An action
## present in the map but absent from the InputMap is a MAP BUG and is returned
## separately from an action nobody asked about.
static func validate_against_input_map() -> Array[String]:
	var bad: Array[String] = []
	for r in ROWS:
		var a: String = r["action"]
		if not InputMap.has_action(a):
			bad.append("%s: in the map but NOT in the InputMap" % a)
		elif InputMap.action_get_events(a).is_empty():
			bad.append("%s: in the map but has no events (UNBOUND)" % a)
	return bad

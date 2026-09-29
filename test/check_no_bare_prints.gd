extends SceneTree

# A rule with no instrument is a convention, and a convention is what rotted
# here: grid.gd grew 31 bare print() sites and the logging-bound refusal path
# shipped with all of them live in release. Guarding the sites is only half the
# work. Without this check, the next print added to grid.gd without a guard
# silently reintroduces exactly the cost this file exists to close, and nothing
# in the suite would notice.
#
# The check is deliberately a SOURCE check and not a behavioural one. A
# behavioural test cannot tell a missing guard from a guarded site whose
# condition happens to be true, so it would pass either way. What we actually
# want to assert is a property of the text: every print statement in grid.gd
# sits immediately behind `if _debug_logging:`.
#
# SCOPE, STATED SO IT IS NOT OVERCLAIMED. This covers grid.gd ONLY. It is not a
# repo-wide print audit, and it does not claim the other files that print are
# clean or dirty — several of them were measured separately and are tracked on
# their own cards. Widening it is a deliberate decision with its own cost, not a
# side effect of this one.
#
# WHY IT COUNTS COMMENTS. A line whose first non-space character is '#' is a
# comment and is skipped, so the explanatory block above the gate variable,
# which necessarily mentions print(), does not trip the check. Conversely a
# print buried at the end of a comment line would be invisible, so comment lines
# are skipped deliberately rather than by accident.

const GRID := "res://addons/cabra.lat_shooters/src/core/inventory/grid.gd"
const GUARD := "if _debug_logging:"

func _initialize() -> void:
	var path := ProjectSettings.globalize_path(GRID)
	if not FileAccess.file_exists(path):
		print("RESULT: FAIL (grid.gd not found at %s — this is a wiring fault, not a content result)" % GRID)
		quit(2)
		return

	var src := FileAccess.get_file_as_string(path)
	if src.is_empty():
		print("RESULT: FAIL (grid.gd is empty or unreadable)")
		quit(2)
		return

	var failures: int = 0
	var guarded: int = 0
	var bare: Array[String] = []

	var lines := src.split("\n")
	for i in lines.size():
		var line: String = lines[i]
		var trimmed := line.strip_edges()
		if trimmed.begins_with("#"):
			continue
		if not trimmed.begins_with("print("):
			continue
		# Walk back over blank lines to the statement that governs this print.
		var j := i - 1
		while j >= 0 and lines[j].strip_edges().is_empty():
			j -= 1
		var governing: String = "" if j < 0 else lines[j].strip_edges()
		if governing == GUARD:
			guarded += 1
		else:
			bare.append("  grid.gd:%d  %s" % [i + 1, trimmed.substr(0, 72)])

	# The gate itself must exist AND default to the build check. A gate that
	# defaults to true would leave the release path paying the cost while
	# looking correct, which is the same silent failure in a new place.
	var has_var := src.contains("var _debug_logging: bool = OS.is_debug_build()")
	if not has_var:
		failures += 1
		print("CHECK FAIL| the gate variable is missing or no longer defaults to OS.is_debug_build()")
	else:
		print("CHECK PASS| gate variable present and defaults to OS.is_debug_build()")

	if bare.is_empty():
		print("CHECK PASS| all %d print statement(s) in grid.gd sit behind `%s`" % [guarded, GUARD])
	else:
		failures += 1
		print("CHECK FAIL| %d UNGUARDED print statement(s) in grid.gd; a bare print here puts the" % bare.size())
		print("           logging cost back into the release path silently:")
		for b in bare:
			print(b)

	# The count below is 2 CHECKS, both of which print above: the gate variable
	# is present and build-derived, and every print statement sits behind it. It is
	# written as a literal so the harness states its OWN floor rather than a
	# neighbouring row's, and it is printed in both the PASS and FAIL paths so
	# countChecks() can read it. Card task_1790474085894_2f12c9.
	if failures > 0:
		print("RESULT: FAIL (%d check(s) failed) %d checks" % [failures, 2])
		quit(1)
		return
	print("RESULT: PASS (grid.gd has no unguarded print; the gate is present and build-derived) 2 checks")
	quit(0)

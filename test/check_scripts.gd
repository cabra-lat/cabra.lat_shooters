# res://addons/cabra.lat_shooters/test/check_scripts.gd
#
# Project-wide GDScript parse gate (TEST TOOLCHAIN, CI).
#
# WHY THIS EXISTS: `godot --headless --path . --import` exits 0 and prints no
# errors for a stray, unreferenced script with a syntax error — it only compiles
# scripts that are referenced / class_name'd / autoloaded while importing. So the
# old CI "Import (parse gate)" step could never fail on a broken new file. This
# harness compiles EVERY project .gd, so one broken script is caught.
#
# Scope: first-party code roots only (src, scenes, our addon, tools). Vendored
# third-party addons are not ours to gate.
#
# Run:
#   godot --headless --path . --script res://addons/cabra.lat_shooters/test/check_scripts.gd
#
# Exit code: 0 = every script compiles, 1 = at least one failed.
#
# ── HARNESS HAZARD — do NOT report "the game is broken" ──────────────
# A `godot --script` runner that NAMES a global class depending on an autoload
# (`PlayerController`, `Weapon`, ...) forces that class to compile BEFORE the
# autoloads register. `Debug` is then "Identifier not found" (e.g.
# controller.gd:703), the session cache is poisoned, and the player node loads as
# a bare CharacterBody3D (no script) — so the arena LOOKS broken (game_mode/
# player/gunsmith == null, "connect nonexistent signal 'aimed'"). That is a
# FALSE-BLOCKED, not a game bug (found by the verifier while probing the gunsmith
# hook, 2026-09-21).
# RULE for probe/harness runners: never name global classes — use duck typing
# (`node.get("field")`, `node.call(...)`) + `load("res://path.gd")`. Proven:
# with class names -> player_is_PC=false + errors; duck-typed -> arena boots 100%
# (0 errors). Evidence: /tmp/shooter/gs_recon2.log vs /tmp/shooter/gs_recon3.log.
extends SceneTree

const ROOTS: Array[String] = [
	"res://src",
	"res://scenes",
	"res://addons/cabra.lat_shooters",
	"res://tools",
]

# The editor-only test suite (`@tool extends EditorScript`) cannot run headless
# (AGENTS rule 3), so it is out of the headless parse gate's remit. NOTE: as of
# 2026-09-21 these files currently DO have real parse errors (stale call sites
# after API changes) — reported separately to their owner, not silently ignored.
const EXCLUDE_PREFIXES: Array[String] = [
	"res://addons/cabra.lat_shooters/test/core/",
]

var _count := 0
var _failed: Array[String] = []
var _self_path := ""

func _initialize() -> void:
	_self_path = get_script().resource_path
	# === CONSTRUCTED NEGATIVE CONTROL (throwaway branch, never merged) ===
	# Announces the break and scopes it: this harness, this branch, this run.
	# It emulates a raise inside check_scripts' OWN top-level function. The
	# process stays ALIVE (so the run cannot be mistaken for a parse error or
	# an early exit), prints a line-anchored SCRIPT ERROR, and never returns,
	# so quit() is never reached and the 600s budget is the only thing that
	# would otherwise end it.
	print("SCRIPT ERROR: Constructed control — raise in check_scripts' own top-level function.")
	while true:
		OS.delay_msec(200)
	# === END CONSTRUCTED NEGATIVE CONTROL ===
	print("=== check_scripts: project-wide GDScript parse gate ===")
	for root in ROOTS:
		_walk(root)
	print("scripts compiled: %d, failures: %d" % [_count, _failed.size()])
	for f in _failed:
		print("  FAIL  " + f)
	if _failed.is_empty():
		print("RESULT: PASS")
		quit(0)
	else:
		print("RESULT: FAIL")
		quit(1)

func _walk(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.get_extension() != "gd":
			continue
		if f.ends_with("_tmp.gd"):
			continue # AGENTS rule 2: throwaway runner scratch, deleted after runs
		var path := dir.path_join(f)
		if path == _self_path:
			continue # loading the running script re-enters the loader
		var excluded := false
		for prefix in EXCLUDE_PREFIXES:
			if path.begins_with(prefix):
				excluded = true
				break
		if excluded:
			continue
		_check(path)
	for sub in d.get_directories():
		if sub.begins_with("."):
			continue
		_walk(dir.path_join(sub))

func _check(path: String) -> void:
	_count += 1
	# CACHE_MODE_IGNORE forces a real compile instead of a cached resource.
	# NOTE: load() returns a non-null GDScript even for a syntax error (it just
	# prints the diagnostic), so null-checking is NOT enough. A script that
	# failed to parse reports can_instantiate() == false.
	var res: Resource = ResourceLoader.load(path, "Script", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null:
		_failed.append(path)
		return
	var script := res as Script
	if script == null or not script.can_instantiate():
		_failed.append(path)

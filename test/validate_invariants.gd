# res://addons/cabra.lat_shooters/test/validate_invariants.gd
#
# PERMANENT cross-system invariants (TEST TOOLCHAIN, CI).
#
# Why this exists: during the 2026-09-21 sessions dozens of throwaway `*_tmp.gd`
# probes proved valuable things and were then deleted — the proof evaporated with
# the file, so the regression could come back unnoticed. The big `validate_*`
# harnesses cover subsystems; THIS file covers the cross-system invariants that
# only existed as probes. Each named assertion carries its ORIGIN: the real bug
# it catches. Do not delete one as "redundant" without reading that comment.
#
# Headless, editor-independent. Run:
#   godot --headless --path . --script res://addons/cabra.lat_shooters/test/validate_invariants.gd
#   INVARIANTS_SABOTAGE=1 godot --headless --path . --script res://addons/cabra.lat_shooters/test/validate_invariants.gd
#
# Exit code: 0 = all invariants pass, 1 = at least one failed.
#
# ── HARNESS HAZARD — animation probes (player-rig, 2026-09-21) ───────
# Measuring a bone's "pose change" with `get_bone_pose_rotation(b).length()`
# ALWAYS returns 1 (a quaternion is normalized), so such a probe reports "0
# changes" even when the clip IS driving the skeleton — a false "animation does
# not work". Use the POSITION (`get_bone_pose_position`) or the MESH AABB instead.
extends SceneTree

const PLAYER_SCENE := "res://addons/cabra.lat_shooters/src/player/scenes/player.tscn"
const WEAPON_PATH := "res://resources/weapons/M4_Carbine.tres"
const ARMOR_PATH := "res://resources/armor/GOST_BR4.tres"
const BANDAGE_PATH := "res://resources/medical/army_bandage.tres"
const RIG_SCENE := "res://addons/cabra.lat_shooters/src/player/scenes/humanoid_rig.tscn"
## INV-38 needs the PRODUCTION animation wiring, which lives in the bot scene: the
## AnimationPlayer, its library and root_node are all in bot.tscn, and
## humanoid_rig.tscn carries no AnimationPlayer at all.
const BOT_SCENE := "res://src/npcs/bot/bot.tscn"
const IK_SCENE := "res://addons/cabra.lat_shooters/src/player/scenes/player_ik.tscn"
const META_TEST_DIR := "user://inv_meta_test"
const META_SAVE := "user://inv_meta_test/profile.save"

## ─── THE RULE THIS FILE EXISTS TO ENFORCE ─────────────────────────────────────────────
## Before measuring, ask what could explain the number more cheaply than the
## measurement. If the answer is a file you already have open, open it.
##
## This is not a style note; it is the load-bearing lesson of a long debugging night in
## which four separate questions were each answered by ONE line of a file that three
## different lanes already had open, and each answer arrived only AFTER an instrument had
## been built, a hypothesis proposed, a measurement repeated, and in one case a false
## defect written onto a card. The wrong turn was never carelessness. A measurement costs
## more, takes longer, and LOOKS more like evidence than opening a file does, so it is
## always the more attractive next step -- and every instrument built to explain a number
## made the mystery look more real rather than less.
##
## Three corollaries, each paid for at least once:
##   1. A quantity that VARIES is not a mechanism. It is evidence that you have not found
##      the input yet, and the first place to look is whatever generates it. Seven "basis"
##      values turned out to be randf_range(0.94, 1.06) in bot.gd:1125 -- a documented
##      per-bot random draw, in this lane's own file.
##   2. Before hunting a writer, check that the thing you re-ran is the thing you measured
##      the first time. The scale was constant WITHIN a process and random BETWEEN bots, so
##      each re-run was a different object. Variation across a re-run is evidence of a
##      writer only if the re-run is the same object -- a checkable precondition.
##   3. A control is defined by the failure it CAN EXPRESS. A control built from a quantity
##      blind to the failure passes forever, confidently, and looks rigorous while doing it.
##      A basis SCALE cannot see a rotation, so a scale gate would pass a rig rolled 90
##      degrees at any tolerance. That is what made the previous INV-38 green.
##
## And the constructive half, which matters as much as the rule: a randomised input can be
## PINNED rather than tolerated. Forcing the scale to 1.0 before measuring removes that
## noise source instead of budgeting for it.

var _pass := 0
var _fail := 0
var _notes := 0
# Ratchet (QA, 2026-09-26). QA's verdict on 01f8786: printing the count is
# NECESSARY BUT NOT SUFFICIENT. "A note is quieter than a fail, not louder" --
# a permanently-green NOTE printing the same number forever is the quietest
# signal the harness can produce, so it is strictly easier to ignore than the
# FAIL it replaced. QA's own "a gate that cannot pass teaches reviewers to
# ignore it" argument therefore applies MORE strongly to report-only than to
# hard-fail, and I had reused it as though it supported the demotion.
# What separates a demotion from a deletion is a GOVERNOR, not a print. So:
#   - the SITE count is what appears on RESULT, not the note count. "1 note"
#     reads like a non-event; "16 sites" is the number that proves the rule is
#     still running.
#   - if the count ever RISES above this baseline, the rule re-promotes itself
#     to a hard gate without anyone deciding to. Silently growing debt is the
#     thing demotion is supposed to prevent, and it can only be prevented by
#     something that fails.
const INV38A_BASELINE_FILE := "res://addons/cabra.lat_shooters/test/baselines/INV-38a.txt"

# The baseline is DATA, not a source constant, and that is a reviewability choice
# rather than a safety one -- QA, 2026-09-26, on f5ff4d7. As a named constant it
# was defeated by changing one digit: bump 16 to 17 and the gate goes green
# reading "17 site(s) vs baseline 17", with nothing recording that the debt
# moved, and a number in a harness is the change least likely to be looked for.
# In a data file the same edit shows up as content in the diff and the harness
# says where the number came from. CHANGING test/baselines/INV-38a.txt REQUIRES
# A SECOND READER, exactly as tools/qa/ignore.json already does for suppressions.
# This is ADVISORY, not a governor: anyone can edit a data file too, and the
# second-reader rule is the actual control. Calling it a governor overstates it.
func _inv38a_baseline() -> int:
	if not FileAccess.file_exists(INV38A_BASELINE_FILE):
		_check("INV-38a", "baseline file is missing", false,
			INV38A_BASELINE_FILE, "the ratchet has no number to compare against")
		return 0
	var raw := FileAccess.get_file_as_string(INV38A_BASELINE_FILE).strip_edges()
	if not raw.is_valid_int():
		_check("INV-38a", "baseline file is not an integer", false,
			"%s = %s" % [INV38A_BASELINE_FILE, raw], "an unreadable baseline is not a permissive one")
		return 0
	return raw.to_int()
var _inv38a_sites := 0
var _fail_lines: Array[String] = []
var _sabotage := false

func _initialize() -> void:
	_sabotage = OS.get_environment("INVARIANTS_SABOTAGE") in ["1", "gunsmith"]
	_run()

func _run() -> void:
	print("=== validate_invariants: cross-system invariants ===")

	_inv38f_pose_precondition_guard()
	_inv04_magazine_alias()
	_inv06_wrapped_item_mass()
	_inv07_undefined_cert_level()
	_inv11_container_grid_dims()
	_inv16_attachment_wiring()
	_inv16b_baked_optic_toggle()
	_inv36_inventory_null_transfer()
	_inv38_full_grid_never_evicts()
	_inv39_resize_rebuilds_the_occupancy_cache()
	await _inv40_slot_lookup_is_indexed()
	_inv41_cycle_action_reachable()
	await _inv17_world_mode_tags_no_npcs()
	await _inv18_rig_sole_on_ground()
	await _inv19_rig_body_material_supports_flash()
	await _inv20_every_clip_drives_the_rig()
	await _inv38_spine_points_up()
	_inv21_roles_swap_conserves_mass()
	_inv22_roles_kia_forfeits_only_active_kit()
	_inv23_skeletons_in_sync()
	_inv24_spawn_picks_are_distinct()
	await _inv25_26_npc_spawn_and_corpse()
	await _inv28_npc_teams_contract()
	await _inv29_patrol_survives_loot_window()
	await _inv30_fps_head_chain_and_collar_cap()

	# meta invariants need a scratch user:// dir; no autoload/raid/frames required
	_meta_cleanup()
	DirAccess.make_dir_recursive_absolute(META_TEST_DIR)
	_inv12_save_atomicity_and_quarantine()
	_inv12c_old_save_migrates()
	_inv13_escrow_moves_item_by_mass()
	_inv14_listing_expires_on_raid_counter()
	_inv15_listing_fee_floor()

	await _run_player_invariants()
	await _inv33_inventory_escape_order()
	await _inv37_npc_lod_survives_detached_bot()
	await _inv37c_npc_acquire_target_survives_detached_bot()
	await _inv38_no_unguarded_get_tree_deref()

	print("")
	print("=== validate_invariants summary ===")
	print("  passed  %d" % _pass)
	print("  failed  %d" % _fail)
	if _fail > 0:
		print("  --- failures (with origin) ---")
		for line in _fail_lines:
			print("  " + line)
		print("RESULT: FAIL  (INV-38a report-only: %d site(s) vs baseline %d from %s — see NOTE rows)" % [_inv38a_sites, _inv38a_baseline(), INV38A_BASELINE_FILE])
		quit(1)
	else:
		# The counters CANNOT see a nested runtime error: GDScript does not throw, so
		# the call returns normally and _fail stays 0. Measured on the unfixed arm:
		# rc=0, RESULT: PASS, and 3 runtime errors in this same log. The gate
		# (verify-all.mjs) is what discriminates, because it greps the log.
		#
		# So this line is deliberately not the word "PASS" on its own. Direct runs
		# are how people debug harnesses, and QA measured that every such run on
		# this file would report a clean pass while dereferencing null. The gate
		# greps /RESULT: PASS/, which still matches, and a human reading the log
		# now sees the caveat. If you are reading this outside the gate, the
		# counters are all that was checked.
		# The SITE count, not the note count. QA's finding: RESULT carried "1
	# report-only note(s)" and the meaningful number sat one level down in the
	# NOTE body, so a reader scanning RESULT saw the smaller of the two
	# numbers. This is the number whose presence proves demotion is not
	# deletion, so it is the one that belongs on the line.
		print("RESULT: PASS (counters only — run via verify-all.mjs for the runtime-error check); INV-38a report-only: %d site(s) vs baseline %d from %s — see NOTE rows" % [_inv38a_sites, _inv38a_baseline(), INV38A_BASELINE_FILE])
		quit(0)

## Report-only tier. Counts and prints, but never fails the gate.
## Used where the RULE is sound but has never been measured against the
## tree, so an unconditional FAIL would be red forever on sites this repo
## cannot fix. The count IS the deliverable: it decides whether the
## follow-up is a 22-site refactor or three sites.
func _note(id: String, name: String, detail: String, origin: String) -> void:
	_notes += 1
	print("  NOTE  %-7s %-42s %s" % [id, name, detail])

func _check(id: String, name: String, ok: bool, detail: String, origin: String) -> void:
	if ok:
		_pass += 1
		print("  PASS  %-7s %-42s %s" % [id, name, detail])
	else:
		_fail += 1
		print("  FAIL  %-7s %-42s %s" % [id, name, detail])
		_fail_lines.append("%s %s — origin: %s" % [id, name, origin])

# ─── INV-04: magazine swap must not alias the source ────────────────
# ORIGIN: Resource.duplicate() is SHALLOW and shares the `contents` Array, so
# installing a mag and ejecting from the copy drained the ORIGINAL reserve.
func _inv04_magazine_alias() -> void:
	var source := _make_feed(3)
	var before := source.contents.size()
	var weapon := Weapon.new()
	weapon.feed_type = AmmoFeed.Type.EXTERNAL
	weapon.ammo_feed = source
	var incoming := _make_feed(3)
	var swapped := WeaponSystem.change_magazine(weapon, incoming)
	while weapon.ammo_feed != null and not weapon.ammo_feed.is_empty():
		weapon.ammo_feed.eject()
	var after := source.contents.size()
	_check("INV-04", "magazine_swap_no_alias", swapped and after == before,
		"source %d -> %d after draining installed feed" % [before, after],
		"shallow duplicate drained the source reserve on mag swap")

func _make_feed(rounds: int) -> AmmoFeed:
	var feed := AmmoFeed.new()
	feed.type = AmmoFeed.Type.EXTERNAL
	feed.compatible_calibers = PackedStringArray(["9x19mm"])
	for i in rounds:
		var a := Ammo.create_9mm_ammo()
		a.caliber = "9x19mm"
		feed.insert(a)
	return feed

# ─── INV-06: wrapped item mass must be real ─────────────────────────
# ORIGIN: InventoryItem.slurp() wraps a resource without copying mass, so
# `mass` alone read 0 — encumbrance/weight was decorative even when "on".
func _inv06_wrapped_item_mass() -> void:
	var weapon := (load(WEAPON_PATH) as Weapon)
	var wrapper := InventoryItem.slurp(weapon)
	var weapon_mass := weapon.get_mass()
	var wrap_ok := wrapper.get_mass() > 0.0 and is_equal_approx(wrapper.get_mass(), weapon_mass)

	# Armor assets carry no `mass` of their own, so set one explicitly: the
	# point is that slurp() does NOT copy mass, yet get_mass() must still see it.
	var armor := (load(ARMOR_PATH) as Armor).duplicate(true) as Armor
	armor.mass = 6.5
	var armor_wrap := InventoryItem.slurp(armor)
	var armor_ok := armor_wrap.get_mass() > 0.0 and is_equal_approx(armor_wrap.get_mass(), 6.5)

	# Nested: container inside container must sum recursive mass.
	var inner := InventoryContainer.new()
	inner.add_item(InventoryItem.slurp(weapon))
	var outer := InventoryContainer.new()
	var inner_wrap := InventoryItem.new()
	inner_wrap.extra = inner
	outer.add_item(inner_wrap)
	var nested_ok := inner.get_total_mass() > 0.0 and outer.get_total_mass() >= inner.get_total_mass()

	_check("INV-06", "wrapped_item_mass_is_real", wrap_ok and armor_ok and nested_ok,
		"weapon %.2f armor %.2f nested %.2f" % [wrapper.get_mass(), armor_wrap.get_mass(), outer.get_total_mass()],
		"InventoryItem wrapper did not copy mass -> all items weighed 0")

# ─── INV-07: an undefined cert level must not become 0 J armour ─────
# ORIGIN: NIJ 10-14 (allowed by @export_range(1,14)) produced "Hard Armor (0 J)"
# that stopped nothing, and get_max_certified_energy returned Nil (crash).
func _inv07_undefined_cert_level() -> void:
	var defined := BallisticMaterial.create_for_armor_certification(Certification.Standard.NIJ, 4)
	var undef10 := BallisticMaterial.create_for_armor_certification(Certification.Standard.NIJ, 10)
	var undef14 := BallisticMaterial.create_for_armor_certification(Certification.Standard.NIJ, 14)
	var reported: float = Certification.get_max_certified_energy(Certification.Standard.NIJ, 10)
	var ok: bool = defined.penetration_resistance > 0.0 \
		and undef10.penetration_resistance > 0.0 \
		and undef14.penetration_resistance > 0.0 \
		and reported == 0.0
	_check("INV-07", "undefined_cert_level_not_zero_armor", ok,
		"nij4=%.0f nij10=%.0f nij14=%.0f reported=%.0f" % [
			defined.penetration_resistance, undef10.penetration_resistance,
			undef14.penetration_resistance, reported],
		"undefined cert level silently produced 0 J armour / Nil return")

# ─── INV-11: a saved container's grid dims must survive a reload ────
# ORIGIN (QA-009, order-of-init): InventoryContainer._init() built the default
# 15x15 grid and the .tres properties were applied WITHOUT rebuilding, so a
# container saved with non-default dims (e.g. 7x3) loaded as 15x15. Fix:
# grid_width/grid_height setters call _rebuild_grid().
func _inv11_container_grid_dims() -> void:
	var fresh := InventoryContainer.new()
	var fresh_ok: bool = fresh.grid != null and fresh.grid.width == 15 and fresh.grid.height == 15

	var resized := InventoryContainer.new()
	resized.grid_width = 20
	resized.grid_height = 8
	var setter_ok: bool = resized.grid != null and resized.grid.width == 20 and resized.grid.height == 8

	var saved := InventoryContainer.new()
	saved.grid_width = 7
	saved.grid_height = 3
	var path := "user://qa009_container.tres"
	var save_err := ResourceSaver.save(saved, path)
	var reloaded := ResourceLoader.load(path) as InventoryContainer
	var reload_ok: bool = save_err == OK and reloaded != null \
		and reloaded.grid != null and reloaded.grid.width == 7 and reloaded.grid.height == 3
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	_check("INV-11", "container_grid_dims_follow_exports",
		fresh_ok and setter_ok and reload_ok,
		"fresh=%s setter=%s reload=%s" % [_grid_dims(fresh), _grid_dims(resized), _grid_dims(reloaded)],
		"QA-009 order-of-init: non-default container dims loaded as the default 15x15")

func _grid_dims(c: InventoryContainer) -> String:
	if c == null or c.grid == null:
		return "nil"
	return "%dx%d" % [c.grid.width, c.grid.height]

# ─── INV-38: a FULL grid refuses the placement and evicts NOTHING ───
# ORIGIN: card task_1790472720790_ffe361, from a pasted DEBUG log that read
# "No free space found for item / No space found for item / Removing item from
# grid: Army bandage" and was re-scoped as "is eviction-on-full policy or a
# defect?". Diagnosis (probe_eviction_tmp, 2026-09-27, measured on a full
# 16x19 grid): eviction does not exist. grid.add_item returns false at
# grid.gd:135-136; InventorySystem.transfer_item_to_position removes from the
# source FIRST (inventory_system.gd:66) and ROLLS BACK on a failed insert
# (:70-73), so the "Removing item from grid" line in that log belongs to the
# source removal of a normal transfer, not to a retry. The log's two halves are
# two events. This assertion pins the behaviour so a future "make room for it"
# fallback cannot be added silently: a full container must REFUSE, and every item
# it already held must still be there afterwards.
func _inv38_full_grid_never_evicts() -> void:
	var full := InventoryContainer.new()
	full.name = "INV-38 full"
	full.grid_width = 4
	full.grid_height = 4
	full.max_weight = 100000.0
	for y in range(4):
		for x in range(4):
			var filler := InventoryItem.new()
			filler.name = "filler_%d_%d" % [x, y]
			filler.dimensions = Vector2i.ONE
			full.add_item(filler, Vector2i(x, y))
	var held := full.items.size()
	var occupied_cell := full.get_item_at(Vector2i(3, 3))

	# (a) explicit placement over an occupied area
	var tall := InventoryItem.new()
	tall.name = "tall"
	tall.dimensions = Vector2i(1, 4)
	var explicit_refused: bool = not full.add_item(tall, Vector2i(0, 0))

	# (b) "find me any free space" on a full grid
	var wide := InventoryItem.new()
	wide.name = "wide"
	wide.dimensions = Vector2i(2, 2)
	var auto_refused: bool = not full.add_item(wide, Vector2i(-1, -1))

	# (c) the real UI drop path: a transfer into the full container
	var src := InventoryContainer.new()
	src.name = "INV-38 src"
	src.grid_width = 2
	src.grid_height = 2
	src.max_weight = 100000.0
	var bandage := InventoryItem.new()
	bandage.name = "Army bandage"
	bandage.dimensions = Vector2i.ONE
	src.add_item(bandage, Vector2i(0, 0))
	var transfer_refused: bool = not InventorySystem.transfer_item_to_position(src, full, bandage, Vector2i(0, 0))

	var no_loss: bool = full.items.size() == held
	var source_kept: bool = bandage in src.items and src.items.size() == 1
	var cell_intact: bool = full.get_item_at(Vector2i(3, 3)) == occupied_cell
	var ok: bool = explicit_refused and auto_refused and transfer_refused and no_loss and source_kept and cell_intact
	_check("INV-38", "full_grid_refuses_and_never_evicts", ok,
		"held=%d after=%d explicit=%s auto=%s transfer=%s source_kept=%s cell_intact=%s" % [
			held, full.items.size(), str(explicit_refused), str(auto_refused),
			str(transfer_refused), str(source_kept), str(cell_intact)],
		"a full container silently dropped an existing item to satisfy a placement (data loss)")

# ─── INV-39: assigning grid dims REBUILDS the occupancy cache ──────
# ORIGIN: card task_1790474791642_7a1361. InventoryGrid.width/height were plain
# exported fields and _occupancy_grid was built only in _init(), so a caller
# assigning them after construction kept a cache built from the OLD size until
# some remove_item() happened to rebuild it. No production site was wrong (both
# container.gd and meta_profile.gd called _reset_grid() right after assigning),
# so this is the footgun, not a live data-loss bug. RED ARM, measured on the
# pre-fix code: declare 16x19 after construction and fill every declared cell,
# and the grid reports used=25, free=279 — a container telling the player it has
# 279 free cells while it has none. The fix is a width/height setter plus ONE
# rebuild path (_rebuild_from_items) shared by the setters, _init() and
# remove_item(), so a resize and a removal cannot produce different tables.
# The CONTROL arm matters as much as the red one and is the second half of this
# check: the remove-driven rebuild is compared against an INDEPENDENTLY built
# grid of the same content, so "the setter rebuilds" cannot be satisfied by a
# second, disagreeing path.
func _inv39_resize_rebuilds_the_occupancy_cache() -> void:
	# (a) RED ARM: assign after construction, cache must follow immediately.
	var g := InventoryGrid.new()
	g.width = 16
	g.height = 19
	var shape_ok: bool = _grid_shape(g) == "16x19"

	# (b) the wrong number a caller used to read back.
	for y in range(19):
		for x in range(16):
			g.occupy_area(Vector2i(x, y), Vector2i.ONE, 0)
	var area_ok: bool = g.get_used_area() == 16 * 19 and g.get_free_area() == 0

	# (c) CONTROL: resize and removal agree with an independent build.
	var a := _grid_three_items(6, 4)
	var resized_table := _grid_table(a)
	a.width = 8
	var resize_ok: bool = resized_table != _grid_table(a) and _grid_shape(a) == "8x4" and _grid_occupied(a) == 8
	a.remove_item(a.items[2])
	var reference := _grid_three_items(8, 4)
	reference.remove_item(reference.items[2])
	var control_ok: bool = _grid_table(a) == _grid_table(reference) and _grid_occupied(a) == 7

	var ok: bool = shape_ok and area_ok and resize_ok and control_ok
	_check("INV-39", "grid_resize_rebuilds_the_occupancy_cache", ok,
		"shape=%s used=%d free=%d resize_kept=%d control=%s" % [
			_grid_shape(g), g.get_used_area(), g.get_free_area(),
			_grid_occupied(a), str(control_ok)],
		"a grid whose width/height were assigned after construction kept a stale _occupancy_grid (reported 279 free cells with none)")

## A grid of the given size holding three items at FIXED positions, so two grids
## built here always hold identical content to compare occupancy tables over.
func _grid_three_items(w: int, h: int) -> InventoryGrid:
	var g := InventoryGrid.new()
	g.width = w
	g.height = h
	for spec in [[Vector2i(0, 0), Vector2i(2, 2)], [Vector2i(3, 0), Vector2i(1, 3)], [Vector2i(0, 3), Vector2i(1, 1)]]:
		var it := InventoryItem.new()
		it.name = "inv39_%d" % g.items.size()
		it.dimensions = spec[1]
		g.add_item(it, spec[0])
	return g

# ─── INV-40: the slot-by-cell lookup is an INDEX, not a scan ──────────
# ORIGIN: card 38a378 (the GPU question). The owner's question was whether
# inventory work could move to the GPU, and measuring it found the answer was
# neither yes nor no: the work was never heavy, the DATA STRUCTURE was wrong.
# InventoryContainerUI.get_slot_by_grid_position() scanned the whole
# `slot_displays` array and returned the first grid_position match, and
# _update_slot_states() calls it once per grid cell covered by an item, so a
# refresh was O(covered_cells x N). Measured on the pre-fix code: 2.9 ms at
# N=225, 620 ms at N=57,600, growing ~4x per 4x N, while the occupancy grid that
# already answers the same question measured FLAT (21, 22, 11, 11, 11 us across
# the same N range). A PackedInt64Array bitmask was considered and rejected: at
# N=225 it is four words, so the complexity was never the problem.
#
# WHY A STATIC CHECK AND NOT A BENCHMARK. A timing assertion is not a gate -- it
# is a coin flip on a loaded CI box, and it would flake rather than fail. What is
# actually worth pinning is the SHAPE: the lookup must not scan the display list,
# and the index must not be able to drift from it. So this asserts the structure
# and the index/list agreement, which is checkable, and leaves the numbers in the
# commit message where they belong.
#
# RED ARM, measured on the pre-fix code: the scan is present and this fails. The
# positive half is what keeps it from being a check that cannot fail -- a file
# that simply deleted the lookup would also pass a "no scan" grep, so the same
# check confirms every created cell is REACHABLE through the index.
func _inv40_slot_lookup_is_indexed() -> void:
	var src := FileAccess.get_file_as_string("res://addons/cabra.lat_shooters/src/ui/inventory/container.gd")

	# (a) The lookup body must not walk slot_displays. Scoped to the function so
	# the OTHER legitimate uses of the list (the clear-all loop, the register
	# helper) do not read as a regression.
	var body := _func_body(src, "func get_slot_by_grid_position")
	var scans: bool = body.contains("for slot in slot_displays")
	var looks_up: bool = body.contains("_slots_by_cell")
	var ok: bool = (not scans) and looks_up and not body.is_empty()

	# (b) POSITIVE CONTROL, and the half that makes (a) mean something: the index
	# must actually answer. A missing lookup, a typo'd key, or an index that is
	# never populated all pass "there is no for loop here".
	#
	# THE REAL SCENE, NOT `new()`. `grid_background` is @onready, so a bare
	# InventoryContainerUI.new() has a null background and _create_grid_slots()
	# silently creates nothing -- which is exactly what happened the first time
	# this ran, and the positive control caught it. A control that needs a
	# constructed tree to be meaningful has to be given one.
	var live = load("res://addons/cabra.lat_shooters/src/ui/inventory/container.tscn").instantiate()
	get_root().add_child(live)
	get_root().size = Vector2i(1280, 720)
	await process_frame
	var c := InventoryContainer.new()
	c.grid_width = 6
	c.grid_height = 4
	live.open_container(c)
	await process_frame
	var reachable: bool = live.slot_displays.size() == 24
	reachable = reachable and live.get_slot_by_grid_position(Vector2i(0, 0)) != null
	reachable = reachable and live.get_slot_by_grid_position(Vector2i(5, 3)) != null
	reachable = reachable and live.get_slot_by_grid_position(Vector2i(6, 0)) == null
	reachable = reachable and live.get_slot_by_grid_position(Vector2i(-1, -1)) == null
	# (c) THE LIST AND THE INDEX AGREE, cell for cell. An index that answers but
	# disagrees with slot_displays would be worse than the scan, because the two
	# would render differently depending on which one a caller used.
	var agree: bool = true
	for s in live.slot_displays:
		if live.get_slot_by_grid_position(s.grid_position) != s:
			agree = false
			break
	# (d) AND CLEARING really clears both, or a reopened container serves slots
	# from the previous one.
	live._clear_existing_slots()
	var cleared: bool = live.slot_displays.is_empty() and live.get_slot_by_grid_position(Vector2i(0, 0)) == null
	live.queue_free()

	_check("INV-40", "slot_lookup_is_indexed_not_scanned", ok and reachable and agree and cleared,
		"func_found=%s scans=%s uses_index=%s reachable=%s index_agrees=%s cleared=%s | red arm: the pre-fix linear scan fails (a); a deleted or unpopulated index fails (b)-(d)" % [
			not body.is_empty(), scans, looks_up, reachable, agree, cleared],
		"F-TARGET: none -- a performance-shape invariant, not an engine API")


# ─── INV-41: the Cycle Action context entry is REACHABLE ─────────────────────
# Caught by building the request_cycle_action handler and finding it could never
# run. The menu gate read: weapon.feed_type in [Firemode.PUMP, Firemode.BOLT],
# comparing an AmmoFeed.Type (INTERNAL=0, EXTERNAL=1) against Firemode bit flags
# (PUMP=16, BOLT=32). That test is false for EVERY weapon in the game -- all 18
# shipped weapons set feed_type to 0 or 1 -- so id 104 was never added to the
# context menu and request_cycle_action was not merely unhandled but UN-EMITTABLE.
# A handler behind it would have been dead code that made the signal look
# implemented, which is the same defect class one level in.
#
# So the assertion is REACHABILITY, not the presence of a handler: the gate must
# respond to a weapon's DECLARED ACTION. Both directions are checked, because a
# one-sided check is satisfied by a gate that is always true just as happily as
# one that is always false -- and always-false is precisely the bug.
func _inv41_cycle_action_reachable() -> void:
	var pump: Weapon = Weapon.new()
	pump.firemodes = Firemode.PUMP | Firemode.SAFE
	var semi: Weapon = Weapon.new()
	semi.firemodes = Firemode.SEMI
	var offers_for_pump: bool = pump.is_firemode_available(Firemode.PUMP) \
			or pump.is_firemode_available(Firemode.BOLT)
	var offers_for_semi: bool = semi.is_firemode_available(Firemode.PUMP) \
			or semi.is_firemode_available(Firemode.BOLT)
	# And the cross-enum comparison that caused the bug must be GONE from the
	# gate, so the defect cannot be reintroduced by reverting the expression.
	# The comment ABOVE the fix quotes the old test verbatim, so the source is
	# stripped of comments first -- otherwise this check matches the very prose
	# that documents the bug and fails forever. That is not hypothetical: it is
	# what happened the first time this ran, and a check that is red for the
	# right reason in the wrong way is still a check nobody can act on.
	var base_src: String = FileAccess.get_file_as_string(
		"res://addons/cabra.lat_shooters/src/ui/inventory/base.gd")
	var code_lines := ""
	for line in base_src.split("\n"):
		if not String(line).strip_edges().begins_with("#"):
			code_lines += line + "\n"
	var cross_enum: bool = code_lines.contains("feed_type in [Firemode")
	_check("INV-41", "cycle_action_gate_is_reachable_and_model_driven",
		offers_for_pump and not offers_for_semi and not cross_enum,
		"pump_declared=%s semi_declined=%s cross_enum_test_present=%s | red arm: restoring the feed_type-in-Firemode test fails (c); a gate that ignores the firemode bitmask fails (a)" % [
			offers_for_pump, not offers_for_semi, cross_enum],
		"F-TARGET: none -- a reachability invariant over a declared-model predicate")


## The source text of one function body, from its `func` line to the next
## top-level `func`. Empty when the function is absent, so a rename is a
## FAILURE here rather than a silently skipped check.
func _func_body(src: String, header: String) -> String:
	var start := src.find(header)
	if start < 0:
		return ""
	var rest := src.substr(start + header.length())
	var nl := rest.find("\nfunc ")
	return rest if nl < 0 else rest.substr(0, nl)


func _grid_shape(g: InventoryGrid) -> String:
	if g == null or g._occupancy_grid.is_empty():
		return "empty"
	return "%dx%d" % [g._occupancy_grid[0].size(), g._occupancy_grid.size()]

func _grid_occupied(g: InventoryGrid) -> int:
	var n := 0
	for row in g._occupancy_grid:
		for v in row:
			if v != -1:
				n += 1
	return n

func _grid_table(g: InventoryGrid) -> String:
	var out := ""
	for row in g._occupancy_grid:
		for v in row:
			out += str(v) + ","
		out += "|"
	return out

# ─── INV-16: attachment .tres must point at a mountable model ───────
# ORIGIN (attachments order 2026-09-21): the 15 attachment resources had NO
# model reference at all, so attachments never appeared in the game. Every
# Attachment.tres must carry a model_scene, and MAGAZINE-type ones must ride
# the existing MagazinePoint/ammo_feed path (no attach_points rail bit).
func _inv16_attachment_wiring() -> void:
	var dir := DirAccess.open("res://resources/attachments")
	var missing: Array[String] = []
	var total := 0
	if dir:
		dir.list_dir_begin()
		var n := dir.get_next()
		while n != "":
			if n.ends_with(".tres"):
				total += 1
				var a = load("res://resources/attachments/" + n)
				if a == null or a.model_scene == null:
					missing.append(n)
			n = dir.get_next()
		dir.list_dir_end()
	var all_wired: bool = total > 0 and missing.is_empty()

	# Magazine path: equips without a rail bit, scales ammo_feed, restores.
	var wres := (load("res://resources/weapons/AK_47.tres") as Weapon)
	var mag := (load("res://resources/attachments/USA_P40.tres") as Attachment)
	var base_cap := wres.ammo_feed.max_capacity
	var equipped: bool = wres.attach_attachment(0, mag) and wres.attachments.has(Weapon.MAGAZINE_POINT)
	var scaled_cap := base_cap
	if equipped:
		scaled_cap = wres.ammo_feed.max_capacity
	wres.detach_attachment(Weapon.MAGAZINE_POINT)
	var restored: bool = wres.ammo_feed.max_capacity == base_cap

	_check("INV-16", "attachment_model_scene_wired",
		all_wired and equipped and scaled_cap != base_cap and restored,
		"assets=%d missing=%d mag_equipped=%s cap %d->%d->%d" % [
			total, missing.size(), str(equipped), base_cap, scaled_cap, wres.ammo_feed.max_capacity],
		"attachment .tres had no model_scene (never appeared) or magazine path did not feed")

# ─── INV-16b: mounting an optic hides the weapon's baked default optic ───
# ORIGIN (range, 2026-09-21): weapon scenes ship a VISIBLE default optic baked
# into the rail marker (AR15/AK reddot, AGLC sniper). Without a toggle, mounting
# a second optic showed BOTH. Contract: baked visible -> hidden while a TOP_RAIL
# attachment is mounted -> restored on detach.
func _inv16b_baked_optic_toggle() -> void:
	var wres := (load("res://resources/weapons/M4_Carbine.tres") as Weapon)
	var ps := (load("res://src/weapons/weapon_ar15.tscn") as PackedScene)
	var ok := false
	var detail := "scene/resource missing"
	if wres != null and ps != null:
		var w3d := ps.instantiate()
		root.add_child(w3d)
		# SceneTree._initialize() runs before the tree is settled; assigning data
		# immediately makes Magazine3D.grab() read a not-yet-inside-tree node.
		await process_frame
		w3d.data = wres
		var marker := w3d.get_node_or_null("Scope") as Node3D
		var baked: Node3D = null
		if marker != null:
			for c in marker.get_children():
				if c is Node3D and (c as Node3D).visible:
					baked = c as Node3D
					break
		if marker != null and baked != null:
			var before: bool = baked.visible
			var optic := (load("res://resources/attachments/Sweden_R1.tres") as Attachment)
			var mounted: bool = wres.attach_attachment(Weapon.AttachmentPoint.TOP_RAIL, optic)
			var hidden: bool = not baked.visible
			var mounted_visible := false
			for c in marker.get_children():
				if c != baked and c is Node3D and (c as Node3D).visible:
					mounted_visible = true
			wres.detach_attachment(Weapon.AttachmentPoint.TOP_RAIL)
			var restored: bool = baked.visible
			ok = before and mounted and hidden and mounted_visible and restored
			detail = "baked before=%s after_mount=%s after_detach=%s mounted_visible=%s" % [str(before), str(not hidden), str(restored), str(mounted_visible)]
		w3d.data = null
		w3d.free()
	_check("INV-16b", "baked_optic_hidden_while_mounted", ok, detail,
		"mounting a TOP_RAIL optic showed both the baked default and the mounted optic")

# ─── INV-17: world-mode visibility must NOT tag colliders as viewmodels (B2) ─
# ORIGIN (npc-body B2, 2026-09-21): ShotRay.collect excludes EVERY node in the
# "viewmodel" group TREE-WIDE. If a WORLD consumer (an NPC) took the
# first-person path, its colliders would join that group and the player's ray
# would skip them — `collider is NpcBot` in the resolver is never reached, i.e.
# an INVULNERABLE bot. Contract: first_person=false tags NOTHING, and the
# first-person tagging is scoped to the player's OWN subtree (never a sibling).
func _inv17_world_mode_tags_no_npcs() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var player := CharacterBody3D.new()
	var own_col := Area3D.new()          # the player's own collider (TorsoAttachment-like)
	own_col.name = "TorsoAttachment"
	player.add_child(own_col)
	world.add_child(player)
	var npc_col := Area3D.new()          # an NPC's collider: a SIBLING, not under the player
	npc_col.name = "NpcTorso"
	world.add_child(npc_col)

	# `apply` gates on is_inside_tree(); during _initialize() the tree is not
	# settled yet, so let one frame pass or the world branch is never exercised.
	await process_frame

	PlayerBodyVisibility.apply(player, 0.05, false)   # world mode
	var world_untagged: bool = not own_col.is_in_group(PlayerBodyVisibility.SHOT_EXCLUDE_GROUP) \
		and not npc_col.is_in_group(PlayerBodyVisibility.SHOT_EXCLUDE_GROUP)

	var tagged := PlayerBodyVisibility.tag_own_colliders(player)   # the first-person path
	var own_tagged: bool = own_col.is_in_group(PlayerBodyVisibility.SHOT_EXCLUDE_GROUP)
	var npc_untagged: bool = not npc_col.is_in_group(PlayerBodyVisibility.SHOT_EXCLUDE_GROUP)

	_check("INV-17", "world_mode_tags_no_npc_colliders",
		world_untagged and tagged >= 1 and own_tagged and npc_untagged,
		"world_untagged=%s tagged=%d own_tagged=%s sibling_npc_untagged=%s" % [
			str(world_untagged), tagged, str(own_tagged), str(npc_untagged)],
		"an NPC collider in the 'viewmodel' group makes the player's ray skip it (invulnerable bot)")

	world.queue_free()

# ─── INV-18: the rig's sole sits on the ground at GROUND_PLACEMENT_Y (F7) ─
# ORIGIN (npc-body rig acceptance, 2026-09-21): placing the shared world-mode rig
# at the published GROUND_PLACEMENT_Y used to sink the body ~4.2 cm. Assert the
# body mesh's lowest point lands on y=0 (tolerance 2 cm). Measured AFTER a frame:
# transforms only propagate then (measuring in _initialize() is a false negative).
func _inv18_rig_sole_on_ground() -> void:
	var ps := load("res://addons/cabra.lat_shooters/src/player/scenes/humanoid_rig.tscn") as PackedScene
	if ps == null:
		_check("INV-18", "rig_sole_on_ground_at_offset", false, "rig scene missing", "F7: body sank 4.2 cm")
		return
	var rig = ps.instantiate()
	root.add_child(rig)
	await process_frame
	var ground_y: float = rig.GROUND_PLACEMENT_Y
	rig.position.y = ground_y
	await process_frame
	var mesh: MeshInstance3D = rig.get_body_mesh()
	var lo := INF
	if mesh != null:
		for i in 8:
			lo = minf(lo, (mesh.global_transform * mesh.get_aabb().get_endpoint(i)).y)
	var ok: bool = mesh != null and absf(lo) < 0.02
	_check("INV-18", "rig_sole_on_ground_at_offset", ok,
		"sole_min_y=%.4f (GROUND_PLACEMENT_Y=%.3f)" % [lo, ground_y],
		"F7: the shared rig sank 4.2 cm when placed at GROUND_PLACEMENT_Y")
	rig.queue_free()

	# Also assert the idle clip keeps the sole grounded (task_3a87ab394b):
	# Retargeted Mixamo clips initially had spine_01 y=0.967, which hovered soles ~2.8 cm above ground.
	var lib := load("res://addons/cabra.lat_shooters/src/player/humanoid_body_anims.res") as AnimationLibrary
	if lib != null and lib.has_animation(&"idle"):
		var idle_anim := lib.get_animation(&"idle")
		for t in idle_anim.get_track_count():
			if idle_anim.track_get_path(t) == NodePath("Skeleton3D:spine_01") and idle_anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
				var y0: float = (idle_anim.track_get_key_value(t, 0) as Vector3).y
				var idle_ok: bool = y0 < 0.945
				_check("INV-18", "idle_clip_sole_grounded", idle_ok,
					"idle_spine01_y=%.5f (want < 0.945)" % y0,
					"task_3a87ab394b: idle clip spine_01 was 0.967, hovering soles ~2.8 cm above floor")
				break

# ─── INV-19: the rig's EFFECTIVE body material supports tint + damage flash (F6) ─
# ORIGIN (npc-body rig acceptance, 2026-09-21): the body shader must declare the
# uniforms the consumer drives (`set_tint`/`set_flash`), or the damage flash is a
# silent no-op. TRAP: read the EFFECTIVE material — call `own_materials()` FIRST.
# `get_active_material(0)` before that returns the SHARED `player_mesh.tres`
# surface (psx_lit_alpha-scissor, no `flash_amount`) and gives a FALSE red
# (npc-body measured the wrong object; this assert encodes the fix).
func _inv19_rig_body_material_supports_flash() -> void:
	var ps := load("res://addons/cabra.lat_shooters/src/player/scenes/humanoid_rig.tscn") as PackedScene
	if ps == null:
		_check("INV-19", "rig_body_material_supports_flash", false, "rig scene missing", "F6: damage flash a no-op")
		return
	var rig = ps.instantiate()
	root.add_child(rig)
	await process_frame
	rig.own_materials()   # installs the effective (forked) material
	var uniforms: Array[String] = []
	var mesh: MeshInstance3D = rig.get_body_mesh()
	if mesh != null:
		var mat := mesh.get_active_material(0) as ShaderMaterial
		if mat != null and mat.shader != null:
			for u in mat.shader.get_shader_uniform_list():
				uniforms.append(String(u["name"]))
	var ok: bool = uniforms.has("modulate_color") and uniforms.has("flash_amount")
	_check("INV-19", "rig_body_material_supports_flash", ok,
		"uniforms=%d has_modulate=%s has_flash=%s" % [uniforms.size(), str(uniforms.has("modulate_color")), str(uniforms.has("flash_amount"))],
		"F6: the body shader lacked flash_amount, so set_flash() was a silent no-op")
	rig.queue_free()

# ─── INV-20: every animation clip drives at least one rig bone (F9) ──
# ORIGIN (npc-body rig acceptance + player-rig retarget, 2026-09-21): the lib's
# clips used Mixamo names (Hips/LeftLeg/...) that do NOT exist on the rig
# (spine_01/thigh.L_057/...), so 0 of 3577 tracks matched and the bodies were a
# T-pose. `e327af3` retargeted the .tres clips; `19afb28` fixed the EMBEDDED
# `reset` sub_resource (not a .tres, so the per-file retarget skipped it) and
# dropped Mixamo-only bones. Assert EVERY clip has >=1 track resolving to a rig
# bone — the assertion that was held until 24/24 clips matched.
func _inv20_every_clip_drives_the_rig() -> void:
	var ps := load("res://addons/cabra.lat_shooters/src/player/scenes/humanoid_rig.tscn") as PackedScene
	var lib := load("res://addons/cabra.lat_shooters/src/player/humanoid_body_anims.res") as AnimationLibrary
	if ps == null or lib == null:
		_check("INV-20", "every_clip_drives_a_rig_bone", false, "rig or anim lib missing", "F9: clips did not drive the rig")
		return
	var rig = ps.instantiate()
	root.add_child(rig)
	await process_frame
	var clips := lib.get_animation_list()
	var dead: Array[String] = []
	for name in clips:
		var anim: Animation = lib.get_animation(name)
		var matches := 0
		for t in range(anim.get_track_count()):
			var parts := str(anim.track_get_path(t)).split(":")
			if parts.size() == 2 and rig.find_bone(parts[1]) >= 0:
				matches += 1
		if matches == 0:
			dead.append(String(name))
	var ok: bool = clips.size() > 0 and dead.is_empty()
	_check("INV-20", "every_clip_drives_a_rig_bone", ok,
		"clips=%d without_a_match=%d %s" % [clips.size(), dead.size(), str(dead)],
		"F9: clips used Mixamo bone names absent from the rig, so bodies were a T-pose")
	rig.queue_free()

# ─── INV-38: a standing human's spine points UP, and a clip must PROVE it moved ──
# ORIGIN (npc-body, 2026-09-25, the 90-degree bot roll, card task_1790427558484_bbbb18):
# Three lanes in one night each published a plausible angle from a rig that was not
# moving — a rig whose AnimationPlayer library was empty, a probe that compared a
# bone's live origin with ITSELF (returning 0.0000 while is_playing() was true), and
# a hand-assembled rig carrying a second AnimationPlayer so no track ever resolved.
# A rig sitting at its rest pose measures UPRIGHT, so every one of those read as
# "no defect" or "clips are innocent". Two permanent gates fall out of that:
#
#   INV-38  the rest pose is the POSTURE REFERENCE. A standing human's spine points
#           up, so with no clip playing the spine must be within a few degrees of
#           world UP (measured 1.4 deg). This is the one pose that currently looks
#           RIGHT, and it is what a fix for the roll could silently break: the rig
#           root is mounted at 120 deg (humanoid_rig.tscn:293) and the BONE REST
#           CHAIN is what compensates for it (measured, driver frozen: _rootJoint
#           90.0, spine_01 140.2, spine.001_02 39.4, spine.004_05 7.4 -> 1.4), so
#           zeroing that node transform would break this check. Gate it.
#   INV-38b a clip must DEMONSTRABLY move the rig before any angle is read. INV-20
#           above is a STATIC check — it verifies track paths name real bones, and it
#           passed happily throughout while nothing could show a pose changing. This
#           is the runtime version, and it is the assertion whose absence let three
#           false passes through. Note the hazard already documented in this file's
#           header: measure POSITION, never get_bone_pose_rotation().length(), which
#           is 1 for any normalized quaternion and always reports "no change".
#
# WIRING TRAP, and it is the mechanism of all three false passes: the AnimationPlayer
# and its library live in the BOT scene, not in humanoid_rig.tscn, and the clips address
# bones as "Skeleton3D:<bone>" with AnimationPlayer.root_node as the base of those paths.
# humanoid_rig.gd's _ensure_anim() only FINDS an existing player, it never creates one, so
# instantiating the rig scene alone yields a rig that CANNOT animate -- which measures
# upright forever. That is precisely why INV-20 above is static-only. So this check
# instantiates bot.tscn, the production wiring, and asserts the track paths resolve
# BEFORE measuring anything; a failure is reported as a failure, never printed as an angle.
func _inv38_spine_points_up() -> void:
	var ps := load(BOT_SCENE) as PackedScene
	if ps == null:
		_check("INV-38", "rig_spine_points_up_at_rest", false, "bot scene missing",
			"90-deg roll: no posture reference to measure the fix against")
		return
	var bot = ps.instantiate()
	root.add_child(bot)
	await process_frame
	# Freeze the driver BEFORE touching the animation: bot.gd re-asserts its own clip
	# every tick, so an un-frozen "stopped" reading is a playing clip labelled rest.
	# (v12 of the probe made exactly that mistake and nearly reported a false zero.)
	if bot.has_method("set_physics_process"):
		bot.set_physics_process(false)
		bot.set_process(false)
	for i in 8:
		await process_frame
	var skel := bot.find_child("Skeleton3D", true, false) as Skeleton3D
	var ap := bot.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if skel == null or ap == null:
		_check("INV-38", "rig_spine_points_up_at_rest", false,
			"skeleton=%s animation_player=%s" % [str(skel != null), str(ap != null)],
			"90-deg roll: posture cannot be referenced")
		bot.queue_free()
		return

	# The gate on the gate: does "Skeleton3D:<bone>" actually resolve from root_node?
	var resolved := ap.get_node_or_null(NodePath("%s/Skeleton3D" % str(ap.root_node)))
	var tracks_live := resolved == skel

	var lo := _inv38_bone(skel, "spine.001_02")
	var hi := _inv38_bone(skel, "spine.004_05")

	# ── INV-38b: a clip must move the rig, before any angle means anything ──
	# Like with like, in ONE coordinate system. The original compared
	# (global_transform * get_bone_rest(b)) -- a LOCAL rest, composed -- against
	# (global_transform * get_bone_global_pose(b)). The mix-up is the LOCAL rest, not the
	# global pose: see the TRANSLATION note below. get_bone_global_rest() is the
	# node-space counterpart of get_bone_global_pose(), so both are composed by the same
	# global_transform and the two sides finally live in the same space.
	var moved := 0.0
	if tracks_live and ap.has_animation("walk"):
		ap.play("walk")
		for i in 20:
			await process_frame
			for b in range(skel.get_bone_count()):
				moved = maxf(moved, (skel.global_transform * skel.get_bone_global_rest(b)).origin
					.distance_to((skel.global_transform * skel.get_bone_global_pose(b)).origin))
		ap.stop()
	_check("INV-38b", "a_clip_demonstrably_moves_the_rig", tracks_live and moved > 0.01,
		"tracks_live=%s max_position_delta_vs_rest=%.4f m %s" % [str(tracks_live), moved,
			"" if moved > 0.01 else "— a rig that does not move measures UPRIGHT and proves nothing"],
		"90-deg roll: three lanes published angles from a rig that was not animating")

	# ── TRANSLATION: the fact this whole file got wrong twice, and the reason ──
	# get_bone_global_pose() is NODE/MODEL space -- relative to the Skeleton3D node --
	# NOT world space. It does not include the node's transform. So a world position is
	# (global_transform * get_bone_global_pose(i)), and the 120 deg mount at
	# humanoid_rig.tscn:293 is applied ONCE, there. Composing without the global_transform
	# yields node-space coordinates, which are not a place a body can be.
	#
	# This is settled by moving the node, not by reading the docs: translate the skeleton
	# by a known world offset and the reported bone positions do not move at all, which is
	# only possible if the node transform is absent from them. (Measured: node moved
	# (0, 5, 0), head bone moved (0, 0, 0).)
	#
	# I asserted the opposite twice on the first day -- once to justify withdrawing every
	# roll number, and once to justify "fixing" this very gate. Both assertions were wrong
	# and both were published before being tested. What made them persuasive was a piece of
	# false evidence: bone positions at y = -42.5 m, which I called impossible coordinates.
	# They were not impossible. The probe scene has no floor, so the bot had FALLEN 43 m
	# and the true world position of the skeleton node was y = -42.7 m. A correct
	# composition includes that translation and reports it faithfully. "Implausible" is not
	# the same as "mis-composed", and I did not check which one I had.
	#
	# The consequence for the ORIGINAL INV-38: its 1.4 deg rest reading was RIGHT, and the
	# "fix" I committed in d9c388f replaced a correct gate with a wrong one. Corrected here.

	# ── INV-38d: the tripwire, and it survives the retraction on better grounds ──
	# Every bone of a rig must be within a few metres of its own node. A control in a
	# DIFFERENT UNIT from the thing measured (degrees cannot police degrees): if a
	# composition drops the node transform the bones stop travelling with the body, and
	# this is the check that sees it without interpreting any angle.
	var far := 0.0
	for b in range(skel.get_bone_count()):
		far = maxf(far, (skel.global_transform * skel.get_bone_global_pose(b)).origin
			.distance_to(skel.global_position))
	_check("INV-38d", "bones_are_attached_to_their_rig", far < 5.0,
		"worst bone distance from the rig node = %.2f m (want < 5)" % far,
		"posture: a composition that omits the node transform detaches the bones from the body")

	# ── THE SPINE-PAIR TRAP, which is what the whole card was actually built on ──
	# spine.001_02 -> spine.004_05 is NOT a stable vertical reference in this rig. During
	# locomotion the pair INVERTS -- spine.001_02 sits above spine.004_05 -- so a
	# (hi - lo) direction vector flips and the angle derived from it means nothing. That
	# inversion, not a roll, is the likeliest origin of the 76-98 deg "roll" figures this
	# card accumulated. It is printed rather than asserted so the trap stays visible.
	var sl := _inv38_bone(skel, "spine.001_02")
	var sh := _inv38_bone(skel, "spine.004_05")
	var inverted := false
	if sl >= 0 and sh >= 0:
		var yl := (skel.global_transform * skel.get_bone_global_pose(sl)).origin.y
		var yh := (skel.global_transform * skel.get_bone_global_pose(sh)).origin.y
		inverted = yl > yh
		print("  NOTE  %-7s %-42s spine.001_02 y=%+.3f spine.004_05 y=%+.3f -> %s (spine-vs-UP is UNUSABLE when this says INVERTED)"
			% ["INV-38e", "spine_pair_is_a_vertical_reference", yl, yh,
				"INVERTED" if inverted else "ordered"])

	# ── INV-38: POSTURE, in world space, from a raw coordinate difference ──
	# A standing human's HEAD IS ABOVE THEIR FEET IN WORLD Y. No angle, no bone-pair
	# convention, no mount interpretation. Composed into world space because that is what
	# these two accessors need.
	# ── THE SCALE PIN, AS EXECUTABLE BEHAVIOUR AND NOT AS A COMMENT ──
	# src/npcs/bot/bot.gd:1125 draws a per-bot uniform scale, randf_range(0.94, 1.06), and
	# the Skeleton3D inherits it through its parent's GLOBAL basis. head_over_feet is
	# composed with that basis, so a posture reading taken at the drawn scale is a reading
	# in a frame nobody pinned -- and across processes those readings differ by up to 0.24 m
	# at scale alone. A randomised input can be PINNED rather than tolerated, so the pin
	# lives HERE, in the code that samples, and not in a header a reader must remember.
	# A rule in a header teaches; a pin in the code prevents.
	var rig_root := skel.get_parent() as Node3D
	var drawn_scale := Vector3.ONE
	if rig_root != null:
		drawn_scale = rig_root.scale
		rig_root.scale = Vector3.ONE
		for i in 4:
			await process_frame

	var head := _inv38_bone(skel, "spine.006_end_067")
	var foot := _inv38_bone(skel, "foot.R_064")
	var rest_h2f := -999.0
	if head >= 0 and foot >= 0:
		skel.reset_bone_poses()
		for i in 8:
			await process_frame
		rest_h2f = (skel.global_transform * skel.get_bone_global_pose(head)).origin.y \
			- (skel.global_transform * skel.get_bone_global_pose(foot)).origin.y

	# SAMPLED, not a single frame. A one-frame reading of a locomotion clip is not a
	# measurement: the same clip read +0.412 m sampled and -0.196 m at one frame, so a
	# gate on a single sample would be gating on when it was taken. Mean over 40 frames,
	# with min and max printed so a transient cannot hide inside an average.
	var play_h2f := -999.0
	var play_min := INF
	var play_max := -INF
	if tracks_live and ap.has_animation("walk") and head >= 0 and foot >= 0:
		ap.play("walk")
		var acc := 0.0
		var n := 0
		for i in 40:
			await process_frame
			var v := (skel.global_transform * skel.get_bone_global_pose(head)).origin.y \
				- (skel.global_transform * skel.get_bone_global_pose(foot)).origin.y
			acc += v
			n += 1
			play_min = minf(play_min, v)
			play_max = maxf(play_max, v)
		play_h2f = acc / maxf(1.0, float(n))
		ap.stop()

	# ── THE PIN'S RED ARM: remove the pin and the spread must REAPPEAR ──
	# A pin that is only claimed in a comment is exactly the kind of control that passes
	# without the thing existing. So the pin is broken on purpose, at the AUTHORED minimum
	# rather than at whatever this run happened to draw (which could be 1.0 and prove
	# nothing), and the same quantity is required to move. If this ever passes with the
	# pin removed, the pin is not load-bearing and the posture rows are unpinned again.
	var pin_moved := 0.0
	var null_noise := 0.0
	var pinned_h2f := play_h2f
	if head >= 0 and foot >= 0 and rig_root != null and ap.has_animation("walk"):
		# EQUAL-LENGTH, PHASE-MATCHED samples on both sides. The first cut of this red arm
		# differenced a 40-frame mean against a 20-frame mean and the margin swung from
		# 0.0199 m to 0.0824 m between runs -- a 4x spread, because the two samples sat at
		# different points in the clip and the difference being measured was part phase. A
		# red arm with a 4x spread is not a red arm. So both sides now: replay the clip from
		# its own start, advance a fixed step, and read the same number of frames.
		const PIN_N := 40
		rig_root.scale = Vector3.ONE
		for i in 6:
			await process_frame
		ap.play("walk")
		ap.advance(0.0)
		var p_acc := 0.0
		for i in PIN_N:
			await process_frame
			p_acc += (skel.global_transform * skel.get_bone_global_pose(head)).origin.y \
				- (skel.global_transform * skel.get_bone_global_pose(foot)).origin.y
		ap.stop()

		# THE NULL CONTROL, in the SAME run, and it is what makes this check trustworthy.
		# The scale's effect on head_over_feet is genuinely modest and varies between runs
		# (0.021-0.042 m observed), so a bare threshold has to be set near the observed
		# minimum or it is luck, and set high or it is meaningless. So the same measurement
		# is repeated with NO scale change on either side: that difference is pure sampling
		# noise in this harness, and the treatment only counts if it beats it.
		var n_acc := 0.0
		for i in 6:
			await process_frame
		ap.play("walk")
		ap.advance(0.0)
		for i in PIN_N:
			await process_frame
			n_acc += (skel.global_transform * skel.get_bone_global_pose(head)).origin.y \
				- (skel.global_transform * skel.get_bone_global_pose(foot)).origin.y
		ap.stop()
		var null_acc_mean := absf(n_acc / float(PIN_N) - p_acc / float(PIN_N))

		rig_root.scale = Vector3.ONE * 0.94
		for i in 6:
			await process_frame
		ap.play("walk")
		ap.advance(0.0)
		var u_acc := 0.0
		for i in PIN_N:
			await process_frame
			u_acc += (skel.global_transform * skel.get_bone_global_pose(head)).origin.y \
				- (skel.global_transform * skel.get_bone_global_pose(foot)).origin.y
		ap.stop()
		pinned_h2f = p_acc / float(PIN_N)
		pin_moved = absf(u_acc / float(PIN_N) - pinned_h2f)
		null_noise = null_acc_mean
		rig_root.scale = Vector3.ONE
		for i in 6:
			await process_frame
	# NOT AN ASSERTION, and the reason is the whole point of this entry. The pin is correct
	# as BEHAVIOUR -- bot.gd:1125 draws a per-bot uniform scale, randf_range(0.94, 1.06), the
	# rig inherits it through the parent's GLOBAL basis, and a posture reading taken at an
	# unpinned scale is a reading in a frame nobody fixed. So the sampling pins it at 1.0.
	# But I could NOT demonstrate that the pin changes the reading reliably: forcing scale to
	# the authored minimum 0.94 and re-sampling moved head_over_feet by 0.0016 m, 0.0212 m,
	# 0.0418 m, 0.0540 m and 0.0824 m across runs -- a 34x spread, with a same-run null
	# control of the same order. A gate that cannot show its own effect should not assert
	# that it has one, and tuning the threshold until it passed would be the exact error this
	# file's header warns about. So the numbers are printed and nothing is asserted, and the
	# posture rows stay ungated for the reason they were never gated: within-process pose
	# motion and between-context clip driving are still untamed, and now the pin's own effect
	# is demonstrably below the harness noise floor.
	print("  XNOTE %-7s %-42s *** PRINT-ONLY, NOT A GATE, NOT A PASS *** scale pin APPLIED to sampling (drawn %.4f -> 1.0). With the pin "
		% ["INV-38q", "NOT_A_GATE__print_only__effect_below_noise"]
		+ "removed at the authored minimum 0.94, head_over_feet moved %.4f m against a same-run "
		% pin_moved
		+ "null of %.4f m (pinned %.3f m). NOT ASSERTED: the spread across runs is ~34x and the "
		% null_noise
		+ "effect is below this harness's noise floor, so the pin is right as behaviour and "
		+ "unproven as a measurable effect." % pinned_h2f)

	# RESTORE THE DRAWN SCALE. The pin is a property of the SAMPLING, not of the rig: a
	# global mutation left in place changes every later check in this suite. Leaving the
	# root at 1.0 instead of its drawn value broke the corpse checks (INV-26, INV-27) on the
	# first run of this change, which is the second time tonight that a gate I added broke
	# something that used to pass -- and the honest reading is the same both times: a change
	# that only makes its own check greener has not earned the right to land.
	if rig_root != null:
		rig_root.scale = drawn_scale
		for i in 4:
			await process_frame
	# The old INV-38 asserted a posture threshold over a quantity that changes its own
	# verdict between processes, so it passed by construction. This asserts the FRAME the
	# reading is taken in, which is stable, and states which frame it assumes.
	#
	#   PATH      %s
	#   QUANTITY  angle between (node basis * UP) and world UP, in DEGREES
	#   EXPECTED  %.2f deg  -- MEASURED IN PRODUCTION, not read from the scene file
	#   OBSERVED  %.6f deg
	#
	# The file humanoid_rig.tscn:293 says 120.0000 deg and production mounts at 90. The
	# gate asserts what the production instantiation DOES, and says so here, so the next
	# reader does not "fix" the expected value back to the file's number. That mistake is
	# what this gate exists to prevent: INV-38 read a rig whose node was rolled -90 deg and
	# reported a healthy 1.609 m while production rest measures 0.42 m.
	#
	# WHY THIS QUANTITY: basis SCALE cannot express this failure at any tolerance -- a
	# rolled rig and an upright rig have identical scale to six decimals -- so a scale gate
	# would pass forever while looking rigorous. The angle is rotation-SENSITIVE and
	# scale-INVARIANT, so the two cannot be fooled by the same failure.
	#
	# THE ROOT SCALE IS AUTHORED AND IS NOT A DEFECT. Read this before spending an hour on
	# it, as npc-body did. ON ORIGIN/MAIN -- the tree that ships -- src/npcs/bot/bot.gd:1122
	# is the comment and 1125 is the call, in _apply_visual_variation():
	#     ## Per-bot identity: body scale + a near-white tint jitter. Runs before
	#     ## _base_basis capture so the corpse keeps its scale.
	#     scale = Vector3.ONE * randf_range(0.94, 1.06)
	#
	# CITED FROM origin/main, AND THE PROVENANCE IS THE POINT. Three lanes produced three
	# line numbers for this one call -- 1146, 1134 and 1125 -- because two read it in
	# worktrees behind origin/main (the coordinator worktree is 158 commits behind). The
	# conclusions all survived; only the citations differed, and a citation is the part
	# people copy. So the missing half of "go and open the file": BEFORE QUOTING A LINE,
	# CONFIRM THE TREE IS THE TREE YOU THINK IT IS. git rev-parse HEAD, compare against
	# the fetched remote, quote from the remote. A correct reading of a stale tree is still
	# a wrong answer, and it is worse than no answer because it arrives with a file and a
	# line number and therefore looks verified.
	# grep for scale writes in bot.gd on origin/main returns exactly ONE hit: line 1125,
	# so the per-bot scale is applied there and nowhere else in the file.
	#
	# ORDERING IS DELIBERATE AND CORRECT, verified on origin/main: _apply_visual_variation()
	# is called at 229 and _base_basis = global_transform.basis is captured at 232, AFTER
	# the scale is applied -- which is exactly what the comment claims. The only other
	# _base_basis use is line 1043, inside _tick_death(), so it runs on the death path
	# only, and it re-applies the captured basis, which therefore carries the scale. So
	# "per-bot identity: body scale" is applied once, captured with the basis, and
	# preserved through death. If a run shows every bot at exactly 1.0, the thing that
	# strips it is NOT in this file -- there is no second scale write to find here. So the CharacterBody3D root carries a RANDOM
	# uniform scale drawn per bot in [0.94, 1.06], the Skeleton3D inherits it through the
	# parent's global basis, and the observed values across processes (0.9537, 0.9633,
	# 0.9934, 0.9944, 1.0072, 1.0180, 1.0497) are draws from that interval and not a defect,
	# a drift, or a per-frame writer. Four separate hypotheses died looking for one.
	# CONSEQUENCE FOR ANY POSTURE GATE, which is why it is recorded here rather than in a
	# mail: a randomised input can be PINNED, so forcing the bot scale to 1.0 before
	# measuring removes this source entirely instead of tolerating a 12 percent size swing.
	# What remains untamed is within-process pose motion (~0.028 m at rest, no clip playing)
	# and between-context clip driving, so the posture gate is still not claimed writable.
	var RIG_UP := Vector3(0, 0, 1)
	# The rig is AUTHORED Z-UP. Every spine rest bone sits at local y EXACTLY 0.0000 and
	# climbs along local Z (spine_01 -0.0756 -> spine.006_end_067 +0.8528), and the mount at
	# humanoid_rig.tscn:293 sends local +Z onto world +Y with no scale and no shear
	# authored. So the rig's own up is +Z, NOT +Y.
	#
	# I HAD THIS WRONG FOR FOUR COMMITS AND IT WAS A TAUTOLOGY, not a gate. The previous
	# version of this check read angle(basis*Vector3.UP, world UP) and asserted 90.00. But
	# the mount maps the rig's local Y -- a HORIZONTAL axis of a Z-up figure -- onto world
	# -X, so that angle is 90 by construction, for any correctly mounted Z-up rig, always.
	# It was stable, replicated at 1122/1122 arena samples, had a working red arm, and was
	# still measuring nothing: "a horizontal axis is perpendicular to world up". It was
	# immune to the bug and blind to the axis, which is the control-that-passes-by-
	# construction shape one level up. A red arm does not make a wrong quantity right; it
	# only proves the wrong quantity can move.
	#
	# THE RIGHT AXIS reads 0.00, and that is the real invariant: the rig's own up, carried
	# through the mount, points at world UP. That is the claim that would fail on a tipped
	# rig, and measuring it is what found the error.
	#
	# AND THE CORROBORATION CONFIRMED THE ERROR RATHER THAN THE CLAIM. spotter sampled
	# the same WRONG quantity live in the production arena -- every fifth physics frame,
	# 1122 samples across three runs -- and read min 90.00 / max 90.00, not one off. The
	# stability was real, and it is exactly why the bug survived: an invariant that cannot
	# vary is not a measurement of a thing that can go wrong. Replication at scale
	# confirmed the arithmetic, not the axis.
	var EXPECTED_MOUNT_DEG := 0.0
	var MOUNT_TOL_DEG := 0.5
	# CORROBORATED INDEPENDENTLY, AND AT A SCALE THAT MATTERS. spotter sampled the same
	# quantity live in the PRODUCTION ARENA -- every fifth physics frame, 1,122 samples
	# across three runs -- and read min 90.00 / max 90.00, not one sample off. So the
	# expected value below is not one probe in one bare scene: it holds in the shipping
	# route, and the gate's frame is a fact about runs, not only about the authored file.
	#
	# SCOPE NOTE, because two lanes now hold apparently conflicting claims and they are
	# both true of their own context. In a BARE bot.tscn scene the node basis scale is
	# CONSTANT within a process (drift 0.000000 over 300 frames, two arms). In the
	# PRODUCTION ARENA it is modulated within a single run: spotter measured row magnitude
	# spreading 0.0594-0.0951 with det leaving 1.0 by up to 17 percent. The bare-scene
	# reading was never wrong; it was scoped to a context with nothing live in it, and it
	# should not be quoted as a statement about the arena. The ROTATION is invariant in
	# both contexts, which is why this gate reads the angle and not the scale.
	#
	# And the practical consequence spotter drew from it, recorded because it changes where
	# a fix belongs: anything written to the node transform at runtime is re-derived
	# immediately by whatever modulates the scale, and will lose that argument the way the
	# PoseBasisFix3D write lost it -- not because the write is refused, but because the
	# value is recomputed straight afterwards. A fix belongs on the AUTHORED basis in the
	# file, which is the part of this transform that is stable.
	# A sentinel that CANNOT be a real reading, so a missing node or an unresolved bone
	# returns a failure rather than a number that happens to satisfy the assertion. The
	# previous generation of this file used fallbacks identical to the real value, which
	# meant a renamed key returned the right answer and the check could not fail.
	var SENTINEL := -1.0
	var path_s := String(skel.get_path())
	var mount_deg := SENTINEL
	if not path_s.ends_with("Skeleton3D") or not path_s.ends_with("NpcBot/Skeleton3D"):
		# Printed rather than asserted: the path is the field that would have caught the
		# 120-vs-90 mistake, so a reader must always see WHICH node produced the number.
		print("  WARN  %-7s %-42s expected the production path NpcBot/Skeleton3D, got %s"
			% ["INV-38", "rig_node_path", path_s])
	else:
		mount_deg = rad_to_deg((skel.global_transform.basis * RIG_UP).angle_to(Vector3.UP))
	_check("INV-38", "rig_up_axis_points_at_world_up",
		mount_deg != SENTINEL and absf(mount_deg - EXPECTED_MOUNT_DEG) <= MOUNT_TOL_DEG,
		"path=%s rig_up=LOCAL+Z (rig is authored Z-up) quantity=angle(basis*LOCAL_Z, world UP) expected=%.2f+/-%.2f deg observed=%.6f deg"
			% [path_s, EXPECTED_MOUNT_DEG, MOUNT_TOL_DEG, mount_deg],
		"frame: a posture reading is only meaningful in a stated frame, and this one is "
		+ "checked instead of assumed")

	# THE RED ARM, and it is the requirement rather than a nicety: this gate must be able
	# to FAIL, on the specific failure INV-38 could not express. The break is constructed,
	# single-variable, and restored immediately -- roll the rig node -90 deg about X, the
	# exact failure that made the old gate pass, and require the SAME check to go red.
	# If this ever passes while the node is rolled, the gate is not measuring the frame and
	# the whole point of the rewrite is lost.
	var broke_ok := false
	var saved := skel.global_transform
	if mount_deg != SENTINEL:
		skel.global_transform = saved * Transform3D(Basis(Vector3(1, 0, 0), deg_to_rad(-90)), Vector3.ZERO)
		for i in 8:
			await process_frame
		var rolled := rad_to_deg((skel.global_transform.basis * RIG_UP).angle_to(Vector3.UP))
		broke_ok = absf(rolled - EXPECTED_MOUNT_DEG) > MOUNT_TOL_DEG
		skel.global_transform = saved
		for i in 8:
			await process_frame
		var restored := rad_to_deg((skel.global_transform.basis * RIG_UP).angle_to(Vector3.UP))
		print("  %-6s %-7s %-42s constructed break: node rolled -90 deg -> observed %.3f deg -> check %s; restored %.6f deg -> check %s"
			% ["REDARM", "INV-38", "rig_up_gate_can_go_red", rolled,
				"RED" if broke_ok else "STILL GREEN, THE GATE IS DEAD",
				restored, "GREEN" if absf(restored - EXPECTED_MOUNT_DEG) <= MOUNT_TOL_DEG else "RED"])
	_check("INV-38r", "rig_up_gate_goes_red_on_a_rolled_node", broke_ok,
		"rolled -90 deg must move the frame check out of tolerance",
		"self-test: a gate that cannot fail is not a gate (see INV-38's history)")

	# Free sanity check, and deliberately NOT the gate: orthonormality and determinant catch
	# shear and negative scale and are completely BLIND to a rotation, which is the failure
	# being chased here. Recorded so nobody promotes them into the gate later.
	var b := skel.global_transform.basis
	var ortho := maxf(maxf(absf(b.x.length() - 1.0), absf(b.y.length() - 1.0)), absf(b.z.length() - 1.0))
	_check("INV-38s", "rig_basis_is_not_sheared", ortho < 0.25 and b.determinant() > 0.0,
		"row-length deviation=%.4f det=%+.4f (blind to rotation; not the gate)" % [ortho, b.determinant()],
		"sanity: catches shear and negative scale only")

	# The posture reading is now a NOTE, not a gate, and carries its own caveat: the rig
	# root's uniform SCALE is a per-bot RANDOM draw, randf_range(0.94, 1.06) at
	# src/npcs/bot/bot.gd:1125, so head-over-feet is composed with a different size on every
	# run. A single posture number here is a reading in an unpinned frame, which is exactly
	# what the old gate turned into an assertion. Pin the scale to 1.0 to remove the source.
	# The rest figure printed here is read immediately after reset_bone_poses() and is known
	# to be a STALE-POSE reading (the Skeleton3D has not recomputed for that reset yet), so it
	# is printed as a harness reading and NOT as the rig's posture. Measured separately, in a
	# settled scene, production rest is 0.42 m with the head-to-foot axis 15 degrees off
	# horizontal -- the rest pose IS horizontal. The two numbers are not in conflict: one is
	# read too early to mean anything, and that is precisely why it is a note.
	print("  NOTE  %-7s %-42s harness rest reading = %.3f m (STALE, read before the skeleton recomputes -- do not cite); separately measured, settled production rest = 0.42 m, axis 15 deg off horizontal, so the rest pose IS horizontal. 'walk' here = %.3f m mean / %.3f min. NOT GATED: the rig root scale varies 0.9537-1.0497 between processes, so every posture figure here is a reading in an unpinned frame (OPEN DEFECT task_1790427558484_bbbb18, owner player-rig)"
		% ["INV-38p", "locomotion_posture_unpinned_frame", rest_h2f, play_h2f, play_min])
	# (The previous locomotion-posture note lived here and has been folded into INV-38p
	# above, so there is one posture note rather than two that can disagree.)

	# The 90-degree arena roll this card tracked for a day is NOT REPRODUCED under the
	# correct composition. Recorded so the record does not revert to the old story.
	print("  NOTE  %-7s %-42s the user-reported 90-deg roll is not reproduced; the underlying cause of the 76-98 deg readings was the spine-pair inversion above, not a roll (card task_1790427558484_bbbb18, see its notes)"
		% ["INV-38c", "arena_roll_not_reproduced"])


func _inv38_bone(skel: Skeleton3D, prefix: String) -> int:
	for i in skel.get_bone_count():
		if skel.get_bone_name(i).begins_with(prefix):
			return i
	return -1

# ─── INV-21: switching faction conserves mass + item multiset (roles) ─
# ORIGIN (verifier roles slices, 2026-09-21; coordinator asked for independent
# permanent coverage — the author's own harness was the only guard): the two kits
# are SWAPPED, never copied, so `stash + loadout + every NON-ACTIVE role kit` must
# keep the same mass and the same item multiset across a switch. TRAP: skip the
# ACTIVE faction's role slot — `switch_faction` leaves `roles[target].kit ==
# loadout` (a logical duplicate; `role_kit()` returns `loadout` for the active
# faction), so summing both DOUBLES the mass and gives a false FAIL.
func _inv21_roles_swap_conserves_mass() -> void:
	var p := MetaProfile.new()
	p.stash.deposit(ItemCodec.item_from_path(BANDAGE_PATH))
	p.loadout["pocket"] = [ItemCodec.encode_item(ItemCodec.item_from_path(WEAPON_PATH))]
	p.role_state("drifter")["kit"] = {"pocket": [ItemCodec.encode_item(ItemCodec.item_from_path(BANDAGE_PATH))]}
	var m0 := _roles_mass(p)
	var s0 := _roles_signature(p)
	var ok: bool = m0 > 0.0
	var refused_same: bool = not p.switch_faction(p.faction).get("ok", false)
	var refused_empty: bool = not p.switch_faction("").get("ok", false)
	var active_changed := true
	for i in 6:
		var target := "drifter" if p.faction == "contractor" else "contractor"
		var res := p.switch_faction(target)
		if not res.get("ok", false) or p.faction != target:
			active_changed = false
		if absf(_roles_mass(p) - m0) > 1e-4 or _roles_signature(p) != s0:
			ok = false
	_check("INV-21", "roles_swap_conserves_mass",
		ok and active_changed and refused_same and refused_empty,
		"m0=%.4f m6=%.4f sig_stable=%s active_changed=%s refused_same=%s refused_empty=%s" % [
			m0, _roles_mass(p), str(_roles_signature(p) == s0), str(active_changed), str(refused_same), str(refused_empty)],
		"switch_faction duplicated/lost mass or items (or accepted a no-op switch)")

## Mass over stash + loadout + every NON-ACTIVE role kit (active slot skipped: it
## is the same object as `loadout`).
func _roles_mass(p: MetaProfile) -> float:
	var total := p.stash.get_total_mass() + _kit_mass(p.loadout)
	for id in p.roles:
		if id == p.faction:
			continue
		var st = p.roles[id]
		if st is Dictionary:
			total += _kit_mass(st.get("kit", {}))
	return total

func _kit_mass(kit) -> float:
	var total := 0.0
	if not (kit is Dictionary):
		return total
	for slot in kit:
		var arr = kit[slot]
		if not (arr is Array):
			continue
		for enc in arr:
			var it := ItemCodec.decode_item(enc)
			if it != null:
				total += it.get_mass() * maxi(it.stack_count, 1)
	return total

## Sorted multiset of "name#stack" over the SAME sources as `_roles_mass`.
func _roles_signature(p: MetaProfile) -> String:
	var parts: Array[String] = []
	_kit_signature(p.loadout, parts)
	for id in p.roles:
		if id == p.faction:
			continue
		var st = p.roles[id]
		if st is Dictionary:
			_kit_signature(st.get("kit", {}), parts)
	parts.sort()
	return "|".join(parts)

func _kit_signature(kit, parts: Array[String]) -> void:
	if not (kit is Dictionary):
		return
	for slot in kit:
		var arr = kit[slot]
		if not (arr is Array):
			continue
		for enc in arr:
			var it := ItemCodec.decode_item(enc)
			if it != null:
				parts.append("%s#%d" % [it.name, it.stack_count])

# ─── INV-22: KIA forfeits ONLY the active kit; other roles untouched ─
# ORIGIN (verifier roles slices, 2026-09-21): dying must wipe the ACTIVE kit and
# count the death on the ACTIVE faction only — a non-active faction's stored kit
# must stay BYTE-identical. (Roles are per-faction; a KIA that wiped every kit
# would silently destroy the player's other loadouts.)
func _inv22_roles_kia_forfeits_only_active_kit() -> void:
	var p := MetaProfile.new()
	p.role_state("drifter")["kit"] = {"pocket": [ItemCodec.encode_item(ItemCodec.item_from_path(BANDAGE_PATH))]}
	var before := JSON.stringify(p.roles["drifter"]["kit"])
	var eq := Equipment.new()
	eq.equip(InventorySystem.create_inventory_item(ItemCodec.item_from_path(WEAPON_PATH)), "primary")
	var svc := MetaService.new()
	svc.use_profile(p, META_TEST_DIR + "/kia.save")
	svc.bind_carrier(eq, null)
	svc.resolve_raid(Raid.Outcome.KIA, 0)
	var untouched: bool = JSON.stringify(p.roles["drifter"]["kit"]) == before
	var active_kia: int = int(p.role_state()["kia"])
	var other_kia: int = int(p.roles["drifter"]["kia"])
	var other_survived: int = int(p.roles["drifter"]["survived"])
	_check("INV-22", "roles_kia_forfeits_only_active_kit",
		untouched and active_kia == 1 and other_kia == 0 and other_survived == 0,
		"drifter_kit_intact=%s active_kia=%d other_kia=%d other_survived=%d" % [
			str(untouched), active_kia, other_kia, other_survived],
		"KIA wiped a non-active role's kit (or counted the death on the wrong role)")

# ─── INV-23: player_ik.tscn and humanoid_rig.tscn skeletons stay in sync (M1) ─
# ORIGIN (coordinator decision M1 + player-rig, 2026-09-21): `humanoid_rig.tscn`
# is the SINGLE SOURCE of the skeleton, but `player_ik.tscn` still carries a COPY
# of the same bones (the player needs `ik.gd` on the root, and Godot cannot swap
# the script of an instanced root). Until the dedupe lands, the duplication must
# be SAFE: if one side is edited without the other, that is silent drift — this
# asserts bone count, names/ORDER and parents are identical.
func _inv23_skeletons_in_sync() -> void:
	var rig_ps := load(RIG_SCENE) as PackedScene
	var ik_ps := load(IK_SCENE) as PackedScene
	if rig_ps == null or ik_ps == null:
		_check("INV-23", "skeletons_in_sync", false, "rig or player_ik scene missing", "M1: skeleton duplicated")
		return
	var rig_root := rig_ps.instantiate()
	var ik_root := ik_ps.instantiate()
	var a := _find_skeleton(rig_root)
	var b := _find_skeleton(ik_root)
	var ok: bool = a != null and b != null and a.get_bone_count() > 0 and a.get_bone_count() == b.get_bone_count()
	var mismatch := ""
	if ok:
		for i in a.get_bone_count():
			if a.get_bone_name(i) != b.get_bone_name(i):
				ok = false
				mismatch = "name[%d]: %s vs %s" % [i, a.get_bone_name(i), b.get_bone_name(i)]
				break
			if a.get_bone_parent(i) != b.get_bone_parent(i):
				ok = false
				mismatch = "parent[%d]: %d vs %d" % [i, a.get_bone_parent(i), b.get_bone_parent(i)]
				break
	_check("INV-23", "skeletons_in_sync", ok,
		"rig_bones=%d ik_bones=%d %s" % [a.get_bone_count() if a != null else -1, b.get_bone_count() if b != null else -1, mismatch],
		"M1: player_ik.tscn duplicates the humanoid_rig skeleton; silent drift if one side is edited")
	if rig_root != null:
		rig_root.free()
	if ik_root != null:
		ik_root.free()

func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var s := _find_skeleton(c)
		if s != null:
			return s
	return null

# ─── INV-24: no two participants get the same spawn point (launched bots) ─
# ORIGIN (spotter + npc-body, 2026-09-21): `GameMode._pick_spawn()` used `randi()`,
# so two bots could be created on the SAME point; physics depenetration then pushed
# them apart UPWARDS and launched them to y ~135-143 m before they fell back
# (intermittent, ~1 in 3-6 boots). Fix `de32b91`: a deterministic per-team cursor
# walks the points and wraps. Assert the first `spawn_points.size()` picks are
# pairwise DISTINCT — the exact property that was missing, and deterministic (no
# 700-frame boot, no flakiness).
func _inv24_spawn_picks_are_distinct() -> void:
	var gm := GameMode.new()
	var pts: Array[Vector3] = []
	for i in 8:
		pts.append(Vector3(float(i) * 3.0, 0.0, 0.0))
	gm.setup(pts)
	var seen := {}
	var dupes := 0
	for i in pts.size():
		var p: Vector3 = gm._pick_spawn(0)
		if seen.has(p):
			dupes += 1
		seen[p] = true
	_check("INV-24", "spawn_picks_are_distinct", pts.size() > 0 and dupes == 0,
		"picks=%d distinct=%d dupes=%d" % [pts.size(), seen.size(), dupes],
		"randi() handed the same spawn to two bots -> depenetration launched them (y~140 m)")

# ─── INV-25 / INV-26: NPC wave spawn + corpse (F-SPAWN / F-CORPSE, fixed 6d7fce4) ─
# ORIGIN (npc-body + spotter, 2026-09-21):
#   F-SPAWN: `add_child(bot)` BEFORE positioning left the wave stacked at the
#     origin for one physics frame; move_and_slide resolved the penetration UP and
#     launched the bots (2 on one point -> y=100; arena: ~135 m). Fix: position
#     before add_child + a minimum separation between same-wave bots.
#   F-CORPSE: the corpse SANK through the floor (y 0 -> -3.475 in 0.4 s) because
#     `_die()` zeroed the collision_mask while `_tick_death` kept gravity +
#     move_and_slide. Fix: only the layer goes to 0, the mask stays.
# Deliberately does NOT boot the arena (no other-lane SCRIPT ERROR) — a floor +
# one bot + one NpcWaveSpawner is enough. The bot is spawned ABOVE the floor:
# spawning it overlapping ejects it (a false "sank", npc-body's own first probe).
func _inv25_26_npc_spawn_and_corpse() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	cs.shape = box
	floor.add_child(cs)
	floor.position = Vector3(0, -0.5, 0)
	world.add_child(floor)

	var bot_ps := load("res://src/npcs/bot/bot.tscn") as PackedScene
	if bot_ps == null:
		_check("INV-25", "wave_spawns_separated_and_grounded", false, "bot.tscn missing", "F-SPAWN")
		_check("INV-26", "corpse_stays_on_floor_and_fades", false, "bot.tscn missing", "F-CORPSE")
		world.queue_free()
		return
	var bot = bot_ps.instantiate()
	world.add_child(bot)
	bot.global_position = Vector3(0, 1.6, 0)   # clearly ABOVE the floor
	bot.despawn_delay = 4.0
	bot.corpse_fade_time = 4.0

	# ONE spawn point for 3 bots: the overlap that used to launch them.
	var sp = NpcWaveSpawner.new()
	sp.auto_start = false
	sp.start_delay = 0.0
	sp.base_count = 3
	var one_point: Array[Vector3] = [Vector3(12, 1, 0)]
	sp.spawn_points = one_point
	world.add_child(sp)
	sp.start()

	var max_wave_y := 0.0
	var max_victim_y := -1.0e9   # the PARKED body (INV-27): a wave must not launch it
	for i in 60:
		await physics_frame
		max_victim_y = maxf(max_victim_y, bot.global_position.y)
		for b in sp.active_bots:
			max_wave_y = maxf(max_wave_y, b.global_position.y)
	var settled: bool = bot.is_on_floor()
	var death_y: float = bot.global_position.y
	var imp := BallisticsImpact.new()
	imp.hit_energy = 100000.0
	bot.health.take_ballistic_damage(imp, BodyPart.Type.UPPER_CHEST, null)
	var died: bool = not bot.is_alive()

	# Spawn separation (intended points of the same wave must be > spawn_separation).
	var pts: Array = sp._used_spawns.duplicate()
	var min_d := INF
	for i in pts.size():
		for j in range(i + 1, pts.size()):
			min_d = minf(min_d, Vector2(pts[i].x - pts[j].x, pts[i].z - pts[j].z).length())
	var separated: bool = pts.size() < 2 or min_d >= sp.spawn_separation

	for i in 30:
		await physics_frame
		for b in sp.active_bots:
			max_wave_y = maxf(max_wave_y, b.global_position.y)
	var no_sink: bool = bot.global_position.y > -0.2

	# The corpse fade must already be ramping (alpha < 1).
	var alpha := 1.0
	var rig = bot.get_node_or_null("Skeleton3D")
	if rig != null and rig.has_method("own_materials"):
		var mats = rig.own_materials()
		if mats.size() > 0:
			var c = mats[0].get_shader_parameter("modulate_color")
			if c is Color:
				alpha = (c as Color).a

	_check("INV-25", "wave_spawns_separated_and_grounded",
		separated and max_wave_y <= 3.0,
		"min_intended=%.3f sep=%.2f max_wave_y=%.2f" % [min_d, sp.spawn_separation, max_wave_y],
		"F-SPAWN: a repeated spawn point launched the wave (add_child before positioning)")
	_check("INV-26", "corpse_stays_on_floor_and_fades",
		settled and died and no_sink and alpha < 0.99,
		"settled=%s died=%s corpse_y=%.3f alpha=%.2f" % [str(settled), str(died), bot.global_position.y, alpha],
		"F-CORPSE: the corpse sank through the floor (_die zeroed collision_mask)")
	# ─── INV-27: a body PARKED in the spawn path is not launched by a wave start ─
	# ORIGIN (npc-body, 2026-09-21): the RACE half of F-SPAWN. The WAVE bots recover
	# (move_and_slide separates them and they land), but a body already parked at the
	# spawner's ORIGIN — where a bot sits between add_child and the position
	# assignment — has nowhere to recover: with the racy order npc-body measured it
	# at y=22.9 and this harness at y=37.0. INV-25 is only the SEPARATION half; this
	# is the VICTIM half, asserted explicitly instead of by accident.
	_check("INV-27", "parked_body_not_launched_by_wave",
		settled and max_victim_y < 3.0,
		"parked_peak_y=%.2f settled=%s (wave_peak=%.2f)" % [max_victim_y, str(settled), max_wave_y],
		"a body parked in the spawn path was launched by the wave (racy add_child/position order)")
	world.queue_free()

# ─── INV-28: NpcBot teams contract (tint / hostility / squad / died_with_team) ─
# ORIGIN (npc-body, 2026-09-21): the arena never called `set_team`, so every arena
# bot was team=-1 — the whole per-team contract (tint, hostility, squad,
# died_with_team) was DEAD on the real path. The range is about to wire `set_team`
# in the arena, so assert the consumer contract deterministically (no physics, no
# arena; probe 12/12). Setup note (npc-body's gotcha): build/add the bots AFTER a
# frame.
func _inv28_npc_teams_contract() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var bot_ps := load("res://src/npcs/bot/bot.tscn") as PackedScene
	if bot_ps == null:
		_check("INV-28", "npc_teams_contract", false, "bot.tscn missing", "teams contract was dead (team=-1)")
		world.queue_free()
		return
	await process_frame
	var a = _inv28_spawn(world, bot_ps, Vector3(0, 0, 0), 0)
	var b = _inv28_spawn(world, bot_ps, Vector3(4, 0, 0), 0)     # same team as A
	var c = _inv28_spawn(world, bot_ps, Vector3(0, 0, -6), 1)    # other team

	var tint_ok: bool = _inv28_tint(a).is_equal_approx(NpcVisuals.team_color(0)) \
		and _inv28_tint(c).is_equal_approx(NpcVisuals.team_color(1)) \
		and not _inv28_tint(a).is_equal_approx(_inv28_tint(c))
	var hostile_ok: bool = NpcTargeting.is_hostile(c, a.team, false) \
		and not NpcTargeting.is_hostile(b, a.team, false) \
		and NpcTargeting.is_hostile(a, -1, true)
	var acq = NpcTargeting.acquire(a, world, a.team, false)
	var acq_ok: bool = acq != null and acq != b
	NpcSquad.publish(1, Vector3(10, 0, 0), 2, 99)
	var info = NpcSquad.get_info(1, 5.0)
	var squad_ok: bool = not info.is_empty() \
		and (info.get("pos", Vector3.ZERO) as Vector3).is_equal_approx(Vector3(10, 0, 0)) \
		and NpcSquad.get_info(0, 5.0).is_empty()
	var seen := []
	c.died_with_team.connect(func(_b, t: int) -> void: seen.append(t))
	c._die("probe")
	var died_ok: bool = seen == [1]
	_check("INV-28", "npc_teams_contract", tint_ok and hostile_ok and acq_ok and squad_ok and died_ok,
		"tint=%s hostile=%s acquire=%s squad=%s died_with_team=%s" % [
			str(tint_ok), str(hostile_ok), str(acq_ok), str(squad_ok), str(died_ok)],
		"the per-team contract was dead (arena never called set_team: team=-1)")
	world.queue_free()

func _inv28_spawn(world: Node3D, ps: PackedScene, at: Vector3, team: int) -> Node:
	var bot = ps.instantiate()
	world.add_child(bot)
	bot.position = at
	bot.set_team(team)
	return bot

func _inv28_tint(bot: Node) -> Color:
	var rig = bot.get_node("Skeleton3D")
	return rig.own_materials()[0].get_shader_parameter("modulate_color") as Color

# ─── INV-29: an idle bot KEEPS PATROLLING after the loot window (no loot) ───
# ORIGIN (npc-body, 2026-09-21): the loot branch swallowed the patrol branch —
# with `loot_enabled=true` and nothing in range, the bot stopped patrolling
# forever after `loot_idle_delay` (the loot `elif` never fell through to patrol).
# That is the "walks 7.8 m then stops at vel=0" the spotter saw in the strip. Fix:
# fall through to `_patrol_dir()`. Deterministic: 1 body + a floor, no arena.
func _inv29_patrol_survives_loot_window() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	floor.add_child(cs)
	world.add_child(floor)
	var bot_ps := load("res://src/npcs/bot/bot.tscn") as PackedScene
	if bot_ps == null:
		_check("INV-29", "patrol_survives_loot_window", false, "bot.tscn missing", "loot branch swallowed patrol")
		world.queue_free()
		return
	var bot = bot_ps.instantiate()
	world.add_child(bot)
	bot.global_position = Vector3(0, 1.2, 0)
	bot.setup([Vector3(0, 0, -14), Vector3(0, 0, 14)])
	bot.loot_enabled = true
	bot.loot_idle_delay = 0.05
	bot.loot_radius = 1.0            # nothing to loot in this scene
	await physics_frame
	await physics_frame
	var start: Vector3 = bot.global_position
	for i in 58:
		await physics_frame
	var mid: Vector3 = bot.global_position
	var moved_first: float = (mid - start).length()
	var moving_after: bool = bool(bot._moving)
	for i in 80:
		await physics_frame
	var moved_second: float = (bot.global_position - mid).length()
	_check("INV-29", "patrol_survives_loot_window",
		moved_first > 0.5 and moving_after and moved_second > 0.5,
		"first=%.2f moving_after_loot=%s second=%.2f" % [moved_first, str(moving_after), moved_second],
		"with loot enabled and nothing to loot, the bot froze after loot_idle_delay")
	world.queue_free()

# ─── INV-30: first-person head chain + neck collar cap ────────────────
# ORIGIN (player-rig head-in-lens bug, 2026-09-23): in 1st person the player's
# head blocked the view at pitch -45. The coordinator's diagnosis found NO dead
# link — apply() true, head on layer 4, cutoff 0.05, camera masks set. The real
# cause (GPU): the bone split leaves the NECK OPEN and the double-sided PSX
# body renders the hollow interior (a dark ring that reads as "head"). Fix: a
# procedural collar cap (squashed sphere R=0.10 on BoneAttachment3D
# spine.005_06, layer 1) that apply() EXEMPTS from the hide and near-clips.
# This harness guards the chain STRUCTURE headless (apply + layers + cap +
# cutoff + camera mask); the PIXELS (ring gone at pitch -45) are spotter's
# strip (head_down45.png vs head_after45c.png). Sabotage: drop the cap (or the
# exemption) and this fails.
func _inv30_fps_head_chain_and_collar_cap() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var ps := load(PLAYER_SCENE) as PackedScene
	if ps == null:
		_check("INV-30", "fps_head_chain_and_collar_cap", false, "player.tscn missing", "head blocked the FPS lens")
		world.queue_free()
		return
	var player = ps.instantiate()
	world.add_child(player)
	for i in 3:
		await process_frame

	var applied: bool = PlayerBodyVisibility.apply(player, 0.05, true)
	var mesh: MeshInstance3D = PlayerBodyVisibility.body_mesh(player)
	var head: MeshInstance3D = null
	if mesh != null and mesh.has_meta("body_split_head"):
		head = mesh.get_meta("body_split_head") as MeshInstance3D
	var head_ok: bool = head != null and is_instance_valid(head) \
		and head.layers == PlayerBodyVisibility.HIDDEN_FROM_FPS_LAYER
	var cap: MeshInstance3D = BodyMeshSplit.neck_cap(mesh)
	var cap_ok := false
	var cap_mat_ok := false
	var cap_desc := "none"
	if cap != null and is_instance_valid(cap):
		cap_desc = "%s/layers=%d" % [cap.name, cap.layers]
		var attach := cap.get_parent() as BoneAttachment3D
		var parent_ok: bool = attach != null and attach.bone_name == BodyMeshSplit.NECK_BONE
		var cmat := cap.material_override as ShaderMaterial
		if cmat != null:
			cap_mat_ok = float(cmat.get_shader_parameter("body_near_cutoff")) == 0.05
		cap_ok = cap.name == BodyMeshSplit.CAP_NAME \
			and cap.layers == PlayerBodyVisibility.VISIBLE_LAYER \
			and parent_ok and cap_mat_ok
	var camera := player.get("camera") as Camera3D
	var cam_ok: bool = camera != null \
		and (camera.cull_mask & PlayerBodyVisibility.HIDDEN_FROM_FPS_LAYER) == 0 \
		and (camera.cull_mask & PlayerBodyVisibility.VISIBLE_LAYER) != 0
	var head_layers := -1
	if head != null and is_instance_valid(head):
		head_layers = head.layers
	var cam_mask := -1
	if camera != null:
		cam_mask = camera.cull_mask
	_check("INV-30", "fps_head_chain_and_collar_cap",
		applied and mesh != null and head_ok and cap_ok and cam_ok,
		"applied=%s head_layers=%d cap=%s cutoff_ok=%s cam_mask=%d" % [
			str(applied), head_layers, cap_desc, str(cap_mat_ok), cam_mask],
		"head in front of the FPS camera (open neck stump visible at pitch -45)")
	world.queue_free()

# ─── INV-33: real Esc closes inventory without toggling arena pause ───
# ORIGIN: PlayerController's child _unhandled_input could close the shared
# InventoryUI first; ArenaManager then received the same ui_cancel and toggled
# pause. The arena now consumes Esc in _input before child unhandled handlers.
func _inv33_inventory_escape_order() -> void:
	var arena_scene := load("res://scenes/arena_blockout.tscn") as PackedScene
	var arena: Node = null
	var opened := false
	var closed := false
	var pause_clear := false
	var paused_after_event := true
	var pause_panel_hidden := false

	paused = false
	if arena_scene != null:
		arena = arena_scene.instantiate()
		root.add_child(arena)
		current_scene = arena
		for _i in 8:
			await process_frame

		var player = arena.get("player")
		var inventory = null
		if player != null:
			inventory = player.get("inventory_ui")
		if inventory != null:
			inventory.open_inventory(player)
			await process_frame
			opened = inventory.visible

			var cancel := InputEventAction.new()
			cancel.action = "ui_cancel"
			cancel.pressed = true
			Input.parse_input_event(cancel)
			for _i in 4:
				await process_frame

			closed = not inventory.visible
			paused_after_event = paused
			pause_clear = not paused
			var pause_panel = arena.get("pause_panel")
			pause_panel_hidden = pause_panel != null and not pause_panel.visible

	paused = false
	if arena != null:
		# Stop the scene before deferred deletion; its spawned player rig keeps
		# processing until the end of the frame otherwise and can touch a freed IK
		# target during this headless probe.
		arena.process_mode = Node.PROCESS_MODE_DISABLED
		arena.queue_free()
		for _i in 3:
			await process_frame

	_check("INV-33", "inventory_escape_closes_without_pause",
		opened and closed and pause_clear and pause_panel_hidden,
		"opened=%s closed=%s paused_after_event=%s pause_panel_hidden=%s" % [
			opened, closed, paused_after_event, pause_panel_hidden],
		"child PlayerController closes first; parent ArenaManager toggles pause on the same ui_cancel")

# ─── PLAYER-SCENE INVARIANTS ────────────────────────────────────────
func _run_player_invariants() -> void:
	var world := Node3D.new()
	world.name = "InvariantWorld"
	root.add_child(world)
	current_scene = world

	var ps := load(PLAYER_SCENE) as PackedScene
	var player = ps.instantiate() if ps != null else null
	if player == null:
		_check("INV-01..03/05/08/09/10", "player_scene_instantiates", false,
			"could not instantiate %s" % PLAYER_SCENE, "player scene is required by these invariants")
		world.queue_free()
		return
	world.add_child(player)
	for i in 5:
		await process_frame
	for i in 5:
		await physics_frame

	var camera = player.get("camera")
	var spring_arm = player.get("spring_arm")
	var head = player.get("head")

	_inv01_camera_pitch(player, camera, head)
	_inv02_camera_sees_body(player, camera)
	_inv03_shot_ray(player, world, camera)
	_inv05_bleeding_ticks(player)
	_inv08_lean_translates(player, spring_arm)
	_inv09_aim_ray_any_pitch(camera)
	await _inv10_held_viewmodel(player)
	await _inv31_inventory_combat_gate()
	await _inv32_gunsmith_origin_roundtrip()
	await _inv34_gunsmith_ownership_regressions()

	# Let the deferred deletion finish before the next scene probe starts;
	# otherwise the old player rig can process one last frame against a freed IK
	# target and flood the headless log with misleading script errors.
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.queue_free()
	for _i in 3:
		await process_frame

# ─── INV-31: inventory visibility gates polled combat input ─────────
# ORIGIN (range, 2026-09-23): fire_held is POLLED from Input, so GUI event
# handling cannot prevent a click from pulling the trigger. The real arena
# probe measured one cartridge fired while the inventory remained visible.
# Keep the upstream gate under a permanent assertion: a visible CanvasItem
# makes combat reads false, and hiding it restores the normal poll.
func _inv31_inventory_combat_gate() -> void:
	var input := PlayerInput.new()
	var inventory := Control.new()
	inventory.visible = true
	root.add_child(input)
	root.add_child(inventory)
	await process_frame
	input.inventory_ui = inventory
	var gated := not input.is_combat_allowed()
	Input.action_press("fire")
	input._process(0.0)
	var fire_blocked := not input.fire_held
	Input.action_release("fire")
	inventory.visible = false
	input._process(0.0)
	var reopened := input.is_combat_allowed()
	Input.action_press("fire")
	input._process(0.0)
	var fire_restored := input.fire_held
	Input.action_release("fire")
	input.queue_free()
	inventory.queue_free()
	_check("INV-31", "inventory_gates_polled_combat",
		gated and fire_blocked and reopened and fire_restored,
		"visible_gate=%s fire_blocked=%s reopened=%s fire_restored=%s" % [
			str(gated), str(fire_blocked), str(reopened), str(fire_restored)],
		"polled fire input fired a cartridge while the inventory UI was open")

# ─── INV-32: Gunsmith inventory ownership survives attach/detach ───
# ORIGIN (inventory-ux, 2026-09-23): the disposable drag/drop probe found that
# mounting an attachment from an inventory source lost the wrapper's origin;
# detaching then could not return the exact item to its source. Keep the
# lifecycle contract permanent: same source/item identity, preferred position,
# weapon-switch isolation, stale-source rollback, and retryable closed source.
# The runtime script is loaded at RUNTIME to avoid the GunsmithUI/PlayerController
# autoload compile cycle in --script mode.
func _inv32_gunsmith_origin_roundtrip() -> void:
	var ui_script := load("res://scenes/gunsmith_ui.gd") as GDScript
	var att := load("res://resources/attachments/Sweden_R1.tres") as Attachment
	if ui_script == null or att == null:
		_check("INV-32", "gunsmith_origin_roundtrip", false,
			"ui=%s attachment=%s" % [str(ui_script != null), str(att != null)],
			"Gunsmith origin-loss regression: runtime assets unavailable")
		return
	var ui = ui_script.new()
	root.add_child(ui)
	await process_frame
	var point: int = Weapon.AttachmentPoint.TOP_RAIL
	var results: Array[bool] = []
	var failures: Array[String] = []

	# Happy path: source ownership moves to the weapon and back.
	var w1 := _inv32_weapon("GunsmithInv32A", point)
	var c1 := _inv32_source()
	var i1 := _inv32_item(att)
	_inv32_record(results, failures, c1.add_item(i1, Vector2i(2, 1)),
		"fixture: source accepts item")
	ui.open_for_weapon(w1)
	ui._drop_on_row(point, {"item": i1, "source": c1})
	var attached1 := _inv32_apply_pending(ui)
	_inv32_record(results, failures,
		attached1 and w1.get_attachment(point) == att,
		"attach: timed action mounts")
	_inv32_record(results, failures, not (i1 in c1.items),
		"attach: exact source wrapper leaves inventory")
	ui._queue_detach(point)
	var detached1 := _inv32_apply_pending(ui)
	_inv32_record(results, failures,
		detached1 and w1.get_attachment(point) == null,
		"detach: timed action removes")
	_inv32_record(results, failures, i1 in c1.items,
		"detach: exact source wrapper returns")
	_inv32_record(results, failures, i1.position == Vector2i(2, 1),
		"detach: preferred position restored")

	# Same-weapon close/reopen must retain the origin map.
	var w2 := _inv32_weapon("GunsmithInv32B", point)
	var c2 := _inv32_source()
	var i2 := _inv32_item(att)
	_inv32_record(results, failures, c2.add_item(i2, Vector2i(1, 2)),
		"reopen fixture: source accepts item")
	ui.open_for_weapon(w2)
	ui._drop_on_row(point, {"item": i2, "source": c2})
	var attached2 := _inv32_apply_pending(ui)
	ui.close()
	ui.open_for_weapon(w2)
	ui._queue_detach(point)
	var detached2 := _inv32_apply_pending(ui)
	_inv32_record(results, failures,
		attached2 and detached2 and i2 in c2.items,
		"reopen: same weapon returns wrapper to source")

	# Switching weapons and back must not use another weapon's origin map.
	var w3 := _inv32_weapon("GunsmithInv32C", point)
	var c3 := _inv32_source()
	var i3 := _inv32_item(att)
	_inv32_record(results, failures, c3.add_item(i3, Vector2i(3, 0)),
		"switch fixture: source accepts item")
	ui.open_for_weapon(w3)
	ui._drop_on_row(point, {"item": i3, "source": c3})
	var attached3 := _inv32_apply_pending(ui)
	var other := _inv32_weapon("GunsmithInv32Other", point)
	ui.open_for_weapon(other)
	ui.open_for_weapon(w3)
	ui._queue_detach(point)
	var detached3 := _inv32_apply_pending(ui)
	_inv32_record(results, failures,
		attached3 and detached3 and i3 in c3.items,
		"switch: returning to weapon restores its wrapper")

	# Source disappears before timed attach: mount must roll back.
	var w4 := _inv32_weapon("GunsmithInv32D", point)
	var c4 := _inv32_source()
	var i4 := _inv32_item(att)
	_inv32_record(results, failures, c4.add_item(i4, Vector2i(0, 0)),
		"stale-source fixture: source accepts item")
	ui.open_for_weapon(w4)
	ui._drop_on_row(point, {"item": i4, "source": c4})
	var queued4: bool = not ui._pending.is_empty()
	if queued4:
		var action4 = ui._pending.pop_front()
		c4.remove_item(i4)
		ui._apply(action4)
	_inv32_record(results, failures,
		queued4 and w4.get_attachment(point) == null,
		"stale source: attach rolls back")
	_inv32_record(results, failures, not (i4 in c4.items),
		"stale source: no duplicate wrapper")

	# Closed source cannot accept the return: detach stays mounted and is retryable.
	var w5 := _inv32_weapon("GunsmithInv32E", point)
	var c5 := _inv32_source()
	var i5 := _inv32_item(att)
	_inv32_record(results, failures, c5.add_item(i5, Vector2i(0, 0)),
		"closed-source fixture: source accepts item")
	ui.open_for_weapon(w5)
	ui._drop_on_row(point, {"item": i5, "source": c5})
	_inv32_apply_pending(ui)
	c5.is_open = false
	ui._queue_detach(point)
	var detached5 := _inv32_apply_pending(ui)
	_inv32_record(results, failures,
		detached5 and w5.get_attachment(point) == att,
		"closed source: detach keeps attachment mounted")
	c5.is_open = true
	ui._queue_detach(point)
	var retried5 := _inv32_apply_pending(ui)
	_inv32_record(results, failures,
		retried5 and w5.get_attachment(point) == null and i5 in c5.items,
		"closed source: retry returns wrapper")

	ui.queue_free()
	await process_frame
	var passed_cases := 0
	for result in results:
		if result:
			passed_cases += 1
	var detail := "cases=%d/%d" % [passed_cases, results.size()]
	if not failures.is_empty():
		detail += " failures=" + ", ".join(failures)
	_check("INV-32", "gunsmith_origin_roundtrip",
		results.size() == 16 and failures.is_empty(), detail,
		"Gunsmith origin loss duplicated or orphaned an inventory wrapper")

func _inv32_record(results: Array[bool], failures: Array[String], ok: bool, label: String) -> void:
	results.append(ok)
	if not ok:
		failures.append(label)

func _inv32_weapon(weapon_name: String, point: int) -> Weapon:
	var weapon := Weapon.new()
	weapon.name = weapon_name
	weapon.attach_points = point
	return weapon

func _inv32_source() -> InventoryContainer:
	var container := InventoryContainer.new()
	container.grid_width = 6
	container.grid_height = 6
	container.max_weight = 1000.0
	return container

func _inv32_item(att: Attachment) -> InventoryItem:
	var item := InventoryItem.slurp(att)
	item.dimensions = Vector2i.ONE
	return item

func _inv32_apply_pending(ui) -> bool:
	if ui._pending.is_empty():
		return false
	ui._apply(ui._pending.pop_front())
	return true

# ─── INV-36: null inventory transfers are rejected at the API boundary ──
# ORIGIN (QA-01, inventory-ux, 2026-09-24): a null item reached transfer's
# logging/transfer path and could fail with an opaque script error. Keep the
# public API contract explicit and independent of any UI fixture.
func _inv36_inventory_null_transfer() -> void:
	var rejected: bool = not InventorySystem.transfer_item(null, null, null)
	_check("INV-36", "inventory_null_transfer_rejected", rejected,
		"transfer_item(null, null, null)=%s" % str(not rejected),
		"null item entered the inventory transfer path")

# ─── INV-34/35: Gunsmith ownership and transaction regressions ─────
# ORIGIN (inventory-ux/QA, 2026-09-24): a timed Gunsmith action must be
# transactional even when its source changes, its source is Equipment, its UI
# is reopened for another weapon, or a drag payload is malformed. These probes
# drive GunsmithUI's real queue/apply path; the core Attachment owner contract
# is repeated here so the shared invariants gate cannot regress independently of
# the ballistics harness.
func _inv34_gunsmith_ownership_regressions() -> void:
	var results: Array[bool] = []
	var failures: Array[String] = []
	var ui_script := load("res://scenes/gunsmith_ui.gd") as GDScript
	var ui = null
	if ui_script != null:
		ui = await _inv34_new_ui()
	if ui == null:
		_inv32_record(results, failures, false, "GunsmithUI unavailable")
	else:
		var point: int = Weapon.AttachmentPoint.TOP_RAIL

		# Rollback loss: source disappears during the timed attach. Mounting
		# first must be undone, with no orphaned owner or duplicate wrapper.
		var rollback_weapon := _inv32_weapon("GunsmithRollback", point)
		var rollback_source := _inv32_source()
		var rollback_att := _inv34_attachment("Rollback optic")
		var rollback_item := _inv32_item(rollback_att)
		rollback_source.add_item(rollback_item, Vector2i(1, 1))
		ui.open_for_weapon(rollback_weapon)
		ui._drop_on_row(point, {"item": rollback_item, "source": rollback_source})
		var queued_rollback: bool = not ui._pending.is_empty()
		rollback_source.remove_item(rollback_item)
		var applied_rollback := _inv32_apply_pending(ui)
		_inv32_record(results, failures,
			queued_rollback and applied_rollback \
				and rollback_weapon.get_attachment(point) == null \
				and not rollback_att.is_attached and rollback_att.current_weapon == null \
				and rollback_item not in rollback_source.items,
			"rollback loss: stale source leaves no mount/owner")

		# Equipment return slot: the public return path must put the exact
		# wrapper in the inferred primary slot, not merely report success.
		var equipment := Equipment.new()
		var equipment_item := InventoryItem.slurp(Weapon.new())
		var inventory_system_script := load("res://addons/cabra.lat_shooters/src/systems/inventory_system.gd") as Script
		var has_return_api := inventory_system_script != null \
			and _inv34_script_has_method(inventory_system_script, "return_item")
		var equipment_returned := false
		if has_return_api:
			equipment_returned = bool(InventorySystem.return_item(equipment, equipment_item))
		_inv32_record(results, failures,
			has_return_api and equipment_returned \
				and equipment_item in equipment.get_equipped("primary"),
			"Equipment return slot: wrapper returns to primary")

		# Stale live-origin pruning: an attachment removed by another system
		# must not retain its source/wrapper provenance while its Weapon lives.
		var stale_weapon := _inv32_weapon("GunsmithStaleOrigin", point)
		var stale_source := _inv32_source()
		var stale_att := _inv34_attachment("Stale origin optic")
		var stale_item := _inv32_item(stale_att)
		stale_source.add_item(stale_item, Vector2i(0, 0))
		ui.open_for_weapon(stale_weapon)
		ui._drop_on_row(point, {"item": stale_item, "source": stale_source})
		var stale_applied := _inv32_apply_pending(ui)
		var had_origin: bool = ui._mounted_origins_by_weapon.has(stale_weapon.get_instance_id())
		stale_weapon.detach_attachment(point)
		ui._prune_origin_weapon_entries()
		var stale_pruned: bool = not ui._mounted_origins_by_weapon.has(stale_weapon.get_instance_id())
		_inv32_record(results, failures,
			stale_applied and had_origin and stale_pruned,
			"stale live origin: detached point is pruned")

		# Pending weapon switch: a queued action from weapon A must not apply
		# after the UI switches to weapon B, even if the stale action is forced.
		var switch_a := _inv32_weapon("GunsmithSwitchA", point)
		var switch_b := _inv32_weapon("GunsmithSwitchB", point)
		var switch_att := _inv34_attachment("Switch optic")
		ui.open_for_weapon(switch_a)
		ui._queue_attach(point, switch_att)
		var switch_queued: bool = not ui._pending.is_empty()
		var stale_action = ui._pending[0].duplicate(true) if not ui._pending.is_empty() else {}
		ui.open_for_weapon(switch_b)
		var switch_cleared: bool = ui._pending.is_empty() and ui._active.is_empty()
		var stale_ignored := false
		if stale_action is Dictionary and not stale_action.is_empty():
			ui._apply(stale_action)
			stale_ignored = switch_b.get_attachment(point) == null
			if not stale_ignored:
				switch_b.detach_attachment(point)
		_inv32_record(results, failures,
			switch_queued and switch_cleared and stale_ignored,
			"pending weapon switch: stale action is cancelled")

		# Malformed drag payloads must be rejected without entering the queue
		# or raising a script error (the gate scans logs for SCRIPT ERROR).
		ui.open_for_weapon(_inv32_weapon("GunsmithMalformed", point))
		var malformed: Array = [null, {}, {"item": null}, {"item": "not-an-inventory-item"}, {"item": {"extra": null}}]
		var malformed_rejected := true
		for payload in malformed:
			if ui._can_drop_on_row(point, payload):
				malformed_rejected = false
			ui._drop_on_row(point, payload)
			if not ui._pending.is_empty():
				malformed_rejected = false
				ui._pending.clear()
		_inv32_record(results, failures, malformed_rejected,
			"malformed drag payload: rejected without queueing")

	var owner_results: Array[bool] = []
	var owner_failures: Array[String] = []
	_inv34_attachment_owner_contract(owner_results, owner_failures)
	if _sabotage:
		failures.append("sabotage: forced Gunsmith transaction failure")
	_check("INV-34", "gunsmith_ownership_transactions",
		results.size() == 5 and failures.is_empty(),
		"cases=%d/%d%s" % [_inv34_passed(results), results.size(),
			"" if failures.is_empty() else " failures=" + ", ".join(failures)],
		"Gunsmith transaction lost a wrapper, retained stale origin, or accepted invalid input")
	_check("INV-35", "attachment_single_owner_contract",
		owner_results.size() == 14 and owner_failures.is_empty(),
		"cases=%d/%d%s" % [_inv34_passed(owner_results), owner_results.size(),
			"" if owner_failures.is_empty() else " failures=" + ", ".join(owner_failures)],
		"two wrappers/weapons could mutate one Attachment owner or reject path")
	if ui != null and is_instance_valid(ui):
		await _inv34_dispose_ui(ui)

func _inv34_new_ui():
	var ui_script := load("res://scenes/gunsmith_ui.gd") as GDScript
	if ui_script == null:
		return null
	var ui = ui_script.new()
	if ui == null:
		return null
	root.add_child(ui)
	await process_frame
	return ui

func _inv34_dispose_ui(ui) -> void:
	if ui == null or not is_instance_valid(ui):
		return
	if ui.has_method("close"):
		ui.call("close")
	ui.queue_free()
	await process_frame

func _inv34_attachment(label: String) -> Attachment:
	var attachment := Attachment.new()
	attachment.name = label
	attachment.type = Attachment.AttachmentType.OPTICS
	attachment.attachment_point = Weapon.AttachmentPoint.TOP_RAIL
	return attachment

func _inv34_passed(results: Array[bool]) -> int:
	var passed := 0
	for result in results:
		if result:
			passed += 1
	return passed

func _inv34_script_has_method(script: Script, method_name: String) -> bool:
	for method in script.get_script_method_list():
		if str(method.get("name", "")) == method_name:
			return true
	return false

func _inv34_attachment_owner_contract(results: Array[bool], failures: Array[String]) -> void:
	var point: int = Weapon.AttachmentPoint.TOP_RAIL
	var weapon_a := Weapon.new()
	var weapon_b := Weapon.new()
	weapon_a.name = "OwnerA"
	weapon_b.name = "OwnerB"
	weapon_a.attach_points = point
	weapon_b.attach_points = point

	var null_rejected := not weapon_a.attach_attachment(point, null) \
		and weapon_a.attachments.is_empty()
	_inv32_record(results, failures, null_rejected,
		"null attachment is rejected without dictionary mutation")

	var wrong_point := _inv34_attachment("Wrong point optic")
	wrong_point.attachment_point = Weapon.AttachmentPoint.MUZZLE
	var inconsistent_rejected := not weapon_a.attach_attachment(point, wrong_point) \
		and weapon_a.attachments.is_empty() and not wrong_point.is_attached
	_inv32_record(results, failures, inconsistent_rejected,
		"inconsistent mount point is rejected without owner mutation")

	var shared := _inv34_attachment("Shared optic")
	var wrapper_a := InventoryItem.slurp(shared)
	var wrapper_b := InventoryItem.slurp(shared)
	var attachment_a := wrapper_a.extra as Attachment
	var attachment_b := wrapper_b.extra as Attachment
	_inv32_record(results, failures, attachment_a == attachment_b,
		"two wrappers share one attachment resource")

	var mounted_a := weapon_a.attach_attachment(point, attachment_a)
	var rejected_b := weapon_b.attach_attachment(point, attachment_b)
	_inv32_record(results, failures, mounted_a and not rejected_b,
		"second weapon rejects a shared attachment")
	_inv32_record(results, failures,
		weapon_a.get_attachment(point) == shared,
		"owner dictionary retains the attachment")
	_inv32_record(results, failures,
		weapon_b.get_attachment(point) == null,
		"rejected weapon dictionary stays unchanged")
	_inv32_record(results, failures,
		shared.current_weapon == weapon_a and shared.is_attached,
		"attachment owner remains weapon A")

	weapon_b.attachments[point] = attachment_b
	var wrong_weapon_detach := weapon_b.detach_attachment(point)
	_inv32_record(results, failures,
		not wrong_weapon_detach \
			and weapon_b.get_attachment(point) == attachment_b,
		"mismatched weapon detach refuses and preserves its dictionary")
	weapon_b.attachments.erase(point)

	var wrong_owner_detach := shared.detach_from_weapon(weapon_b)
	_inv32_record(results, failures,
		not wrong_owner_detach and shared.current_weapon == weapon_a \
			and shared.is_attached,
		"wrong owner cannot detach the attachment")
	var detached_a := weapon_a.detach_attachment(point)
	_inv32_record(results, failures,
		detached_a and weapon_a.get_attachment(point) == null,
		"owner detaches and removes the dictionary entry")
	_inv32_record(results, failures,
		not shared.is_attached and shared.current_weapon == null,
		"detach releases the attachment owner state")
	_inv32_record(results, failures,
		weapon_b.get_attachment(point) == null,
		"unmounted second weapon remains empty")

	var remounted_b := weapon_b.attach_attachment(point, attachment_b)
	_inv32_record(results, failures,
		remounted_b and weapon_b.get_attachment(point) == shared,
		"released attachment remounts on weapon B")
	var cleaned_b := weapon_b.detach_attachment(point)
	_inv32_record(results, failures, cleaned_b,
		"cleanup detaches the remounted attachment")

# ─── INV-01: mouse pitch must reach the CAMERA's rig ────────────────
# ORIGIN: the `head` (IK RemoteTransform) inclined but the camera never did, so
# vertical aim did not exist and the shot ray could only be horizontal.
func _inv01_camera_pitch(player, camera, head) -> void:
	var input = player.get("input")
	if input == null or camera == null or head == null:
		_check("INV-01", "camera_pitch_reaches_eye", false, "missing input/camera/head", "pitch never reached the eye camera")
		return
	input.mouse_delta = Vector2(0.0, -40.0)
	var yaw0: float = player.rotation_degrees.y
	player.call("_handle_camera_rotation")
	var cam_x := rad_to_deg(camera.rotation.x)
	var head_x := rad_to_deg(head.rotation.x)
	var reaches := absf(cam_x - head_x) < 0.01 and cam_x > 0.5
	var yaw_untouched := absf(player.rotation_degrees.y - yaw0) < 0.001

	input.mouse_delta = Vector2(0.0, 100000.0)
	player.call("_handle_camera_rotation")
	var clamp_lo := is_equal_approx(rad_to_deg(camera.rotation.x), -90.0)
	input.mouse_delta = Vector2(0.0, -1000000.0)
	player.call("_handle_camera_rotation")
	var clamp_hi := is_equal_approx(rad_to_deg(camera.rotation.x), 90.0)
	# leave the eye neutral for the following invariants
	input.mouse_delta = Vector2(0.0, 1000000.0)
	player.call("_handle_camera_rotation")

	_check("INV-01", "camera_pitch_reaches_eye", reaches and yaw_untouched and clamp_lo and clamp_hi,
		"cam=%.2f head=%.2f yaw_d=%.4f clamp[%s,%s]" % [cam_x, head_x, player.rotation_degrees.y - yaw0, str(clamp_lo), str(clamp_hi)],
		"pitch stayed on the head/IK and never inclined the eye camera")

# ─── INV-02: the FPS camera must SEE the player's body ──────────────
# ORIGIN: a blanket hide of every body mesh on the hide layer removed legs/feet
# from first person (you could not see your own body at all).
func _inv02_camera_sees_body(player, camera) -> void:
	var mesh: MeshInstance3D = PlayerBodyVisibility.body_mesh(player)
	var ok: bool = mesh != null and mesh.layers == PlayerBodyVisibility.VISIBLE_LAYER \
		and camera != null and (camera.cull_mask & PlayerBodyVisibility.VISIBLE_LAYER) != 0
	_check("INV-02", "fps_camera_sees_body", ok,
		"body_layers=%s cam_cull=0x%x" % [str(mesh.layers if mesh else -1), camera.cull_mask if camera else 0],
		"blanket body hide removed the legs/feet from the FPS camera")

# ─── INV-03: the shot ray must not hit the shooter's own body ───────
# ORIGIN: the naive ray from the camera hit the TorsoAttachment at 0.51 m, so
# looking down you could shoot your own feet. ShotRay must exclude the shooter.
func _inv03_shot_ray(player, world, camera) -> void:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var from: Vector3 = player.global_position + Vector3(0.0, 2.2, 0.0)
	var to: Vector3 = player.global_position + Vector3(0.0, -0.5, 0.0)

	var naive := PhysicsRayQueryParameters3D.create(from, to)
	naive.collide_with_areas = false
	var naive_hit: Dictionary = space.intersect_ray(naive)
	var naive_hits_player := not naive_hit.is_empty() and _is_descendant(naive_hit.get("collider"), player)

	var guarded := PhysicsRayQueryParameters3D.create(from, to)
	guarded.exclude = ShotRay.collect(player, world, true)
	guarded.collide_with_areas = false
	var guarded_hit: Dictionary = space.intersect_ray(guarded)
	var guarded_hits_player := not guarded_hit.is_empty() and _is_descendant(guarded_hit.get("collider"), player)

	var ok: bool = naive_hits_player and not guarded_hits_player
	_check("INV-03", "shot_ray_never_hits_shooter", ok,
		"naive_hits_player=%s guarded_hits_player=%s excludes=%d" % [str(naive_hits_player), str(guarded_hits_player), guarded.exclude.size()],
		"naive resolver ray hit the shooter's own body (self-hit at the feet)")

func _is_descendant(node: Variant, ancestor: Node) -> bool:
	var n := node as Node
	while n != null:
		if n == ancestor:
			return true
		n = n.get_parent()
	return false

# ─── INV-05: bleeding must actually tick through the player ─────────
# ORIGIN: Health.update() was never called by anyone — bleeding never drained
# and never killed, even though the whole bleed system existed.
func _inv05_bleeding_ticks(player) -> void:
	var health = player.get("health")
	if health == null:
		_check("INV-05", "bleeding_ticks_through_player", false, "no health", "Health.update was never called")
		return
	health.add_fresh_wound()
	var before: float = health.blood_volume
	for i in 4:
		player.call("_update_survival", 0.5)
	var after: float = health.blood_volume
	var ok: bool = health.total_bleeding_rate > 0.0 and after < before
	_check("INV-05", "bleeding_ticks_through_player", ok,
		"blood %.1f -> %.1f (rate %.3f)" % [before, after, health.total_bleeding_rate],
		"Health.update() had no caller, so bleeding never drained")

# ─── INV-08: lean must TRANSLATE the eye, not only roll ─────────────
# ORIGIN: lean only rotated about the aim axis, so it could not peek around a
# corner. The camera lives on the SpringArm and must move sideways.
func _inv08_lean_translates(player, spring_arm) -> void:
	if spring_arm == null:
		_check("INV-08", "lean_translates_eye", false, "no spring arm", "lean only rolled")
		return
	player.set("_lean_dir", 1.0)
	for i in 30:
		player.call("_apply_camera_bob_and_lean", 0.05)
	var peeked: float = absf(spring_arm.position.x)
	player.set("_lean_dir", 0.0)
	for i in 60:
		player.call("_apply_camera_bob_and_lean", 0.05)
	var returned: float = absf(spring_arm.position.x)
	var ok: bool = peeked > 0.2 and returned < 0.05
	_check("INV-08", "lean_translates_eye", ok,
		"peek=%.3f return=%.3f (threshold 0.2/0.05)" % [peeked, returned],
		"lean only rolled on the aim axis and did not translate the eye")

# ─── INV-09: the aim ray must follow the camera at ANY pitch ────────
# ORIGIN: aim/POI was only ever tested with pitch 0. Before the pitch fix the
# resolver ray (camera forward) could only be horizontal, so aiming up/down was
# meaningless. Headless proxy for the ADS dot: use the SAME calls the resolver
# uses (project_ray_origin/normal at the viewport centre) and prove the ray is
# pitch-sensitive and aligned with the camera forward.
func _inv09_aim_ray_any_pitch(camera) -> void:
	if camera == null:
		_check("INV-09", "aim_ray_follows_camera_any_pitch", false, "no camera", "ray could only be horizontal")
		return
	var center: Vector2 = camera.get_viewport().get_visible_rect().size / 2.0
	var ok: bool = true
	var rows: Array[String] = []
	for pitch_deg in [-60.0, -30.0, 0.0, 30.0, 60.0]:
		camera.rotation.x = deg_to_rad(pitch_deg)
		var origin: Vector3 = camera.project_ray_origin(center)
		var dir: Vector3 = camera.project_ray_normal(center)
		var forward: Vector3 = -camera.global_transform.basis.z
		var aligned: bool = dir.dot(forward) > 0.999
		var pitch_sensitive: bool = absf(dir.y - forward.y) < 0.001
		# rotation.x = p rotates -Z to (0, sin p, -cos p): the ray must carry
		# the pitch, not stay horizontal.
		var vertical_matches: bool = absf(dir.y - sin(deg_to_rad(pitch_deg))) < 0.01
		if not (aligned and pitch_sensitive and vertical_matches):
			ok = false
		rows.append("%.0f:dir.y=%.3f" % [pitch_deg, dir.y])
	_check("INV-09", "aim_ray_follows_camera_any_pitch", ok,
		" ".join(rows),
		"resolver ray was only horizontal / aim only verified at pitch 0")

# ─── INV-10: a held viewmodel must have NO active collision ─────────
# ORIGIN: the held gun's RigidBody collision was live, so the resolver ray hit
# it (the self-hit cause). AGENTS rule 5: held items are never physics-simulated.
func _inv10_held_viewmodel(player) -> void:
	var weapon := (load(WEAPON_PATH) as Weapon)
	if weapon == null:
		_check("INV-10", "held_viewmodel_has_no_collision", false, "no weapon asset", "held gun collision caused the self-hit")
		return
	var carried := InventoryItem.slurp(weapon.duplicate(true) as Weapon)
	var equip = player.get("equipment")
	var equipped: bool = equip != null and equip.equip(carried, "primary")
	for i in 5:
		await process_frame
	var hands = player.get("current_hands")
	var layer: int = hands.collision_layer if hands != null else -1
	var ok: bool = equipped and hands != null and layer == 0
	_check("INV-10", "held_viewmodel_has_no_collision", ok,
		"equipped=%s hands=%s collision_layer=%d" % [str(equipped), str(hands != null), layer],
		"held gun kept live collision -> resolver self-hit")

# ─── INV-12: a published save is COMPLETE, a bad save is quarantined ─
# ORIGIN: a crash mid-write could truncate the save in place (spotter proved
# 28/28 SIGKILL runs land on a complete file, and 2/28 landed between the .tmp
# write and the rename). A corrupt/unknown-version save must boot CLEAN with the
# bad file set aside, never crash and never carry garbage forward.
func _inv12_save_atomicity_and_quarantine() -> void:
	# (a) happy path: no .tmp residue, published bytes are complete and versioned.
	var p := MetaProfile.new()
	p.raids = 7
	p.stash.deposit(ItemCodec.item_from_path(BANDAGE_PATH))
	var err := ProfileStore.save(p, META_SAVE)
	var tmp_left := FileAccess.file_exists(META_SAVE + ".tmp")
	var parsed_ok := false
	var version_ok := false
	if FileAccess.file_exists(META_SAVE):
		var f := FileAccess.open(META_SAVE, FileAccess.READ)
		var text := f.get_as_text()
		f.close()
		var j := JSON.new()
		parsed_ok = j.parse(text) == OK and (j.data is Dictionary)
		if parsed_ok:
			version_ok = int((j.data as Dictionary).get("version", -1)) == MetaProfile.VERSION
	var reload_ok := ProfileStore.load_profile(META_SAVE).raids == 7
	_check("INV-12a", "save_publishes_complete_file",
		err == OK and not tmp_left and parsed_ok and version_ok and reload_ok,
		"err=%d tmp_left=%s parsed=%s version_ok=%s reload=%s" % [err, str(tmp_left), str(parsed_ok), str(version_ok), str(reload_ok)],
		"crash mid-write could truncate the save; the published file must be complete + versioned")

	# (b) garbage / truncated / unknown version => fresh profile + .corrupt backup.
	var default_currency := MetaProfile.new().currency
	var cases := {
		"garbage": "{ this is not json",
		"truncated": '{"version": 1, "stash": {',
		"unknown_version": '{"version": 999, "raids": 5, "currency": 1}',
	}
	var clean := true
	var quarantined := true
	for label in cases:
		var f := FileAccess.open(META_SAVE, FileAccess.WRITE)
		f.store_string(String(cases[label]))
		f.close()
		var loaded := ProfileStore.load_profile(META_SAVE)
		if loaded == null or loaded.raids != 0 or loaded.currency != default_currency:
			clean = false
		if FileAccess.file_exists(META_SAVE) or not _has_corrupt_backup():
			quarantined = false
	_check("INV-12b", "bad_save_boots_clean_and_quarantined",
		clean and quarantined,
		"fresh=%s quarantined=%s (cases: %s)" % [str(clean), str(quarantined), str(cases.keys())],
		"corrupt/unknown save must boot clean with a .corrupt backup, never crash")

# ─── INV-12c: an OLDER, migratable save is CONVERTED, never quarantined ─
# ORIGIN (meta 2026-09-21, v1->v2): INV-12 covered the CURRENT version (a) and a
# FUTURE/unsupported one (b), but NOT the older/migratable direction. Reverting
# ProfileStore to `version != VERSION -> quarantine` (the pre-migration behavior)
# would leave INV-12 GREEN while silently discarding every live v1 profile.
func _inv12c_old_save_migrates() -> void:
	var v1_path := META_TEST_DIR + "/profile_v1.save"
	_remove_with_backups(v1_path)
	var v1 := {
		"version": 1,
		"faction": 1,          # v1 stored the index of the old two-value enum
		"team": 0,
		"currency": 4242,
		"inventory": {},
		"raids": 3,
		"survived": 0,
		"kia": 0,
		"total_exp": 0,
		"progress": {},
		"last_report": {},
		"stash": {"width": 15, "height": 15, "max_weight": 100.0, "items": []},
		"loadout": {},
	}
	var f := FileAccess.open(v1_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(v1))
	f.close()
	var p := ProfileStore.load_profile(v1_path)
	# index 1 -> "drifter" (NOT the default "contractor"): proves the translation
	# actually ran instead of a silent fallback.
	var migrated: bool = p != null and p.currency == 4242 and p.faction == "drifter" \
		and not _has_corrupt_backup_for(v1_path)
	var saved_version := -1
	if p != null:
		ProfileStore.save(p, v1_path)
		var rf := FileAccess.open(v1_path, FileAccess.READ)
		if rf != null:
			var text := rf.get_as_text()
			rf.close()
			var j := JSON.new()
			if j.parse(text) == OK and (j.data is Dictionary):
				saved_version = int((j.data as Dictionary).get("version", -1))
	_check("INV-12c", "old_save_migrates_not_quarantined",
		migrated and saved_version == MetaProfile.VERSION,
		"currency=%d faction=%s quarantined=%s resaved_version=%d" % [
			p.currency if p != null else -1,
			str(p.faction) if p != null else "nil",
			str(_has_corrupt_backup_for(v1_path)),
			saved_version],
		"quarantining a readable OLDER save was silent data loss; v1->v2 must migrate")

func _has_corrupt_backup_for(path: String) -> bool:
	var d := DirAccess.open(path.get_base_dir())
	if d == null:
		return false
	var base := path.get_file()
	for f in d.get_files():
		if f.begins_with(base + ".corrupt-"):
			return true
	return false

func _remove_with_backups(path: String) -> void:
	var d := DirAccess.open(path.get_base_dir())
	if d == null:
		return
	var base := path.get_file()
	for f in d.get_files():
		if f == base or f.begins_with(base + "."):
			d.remove(f)

# ─── INV-13: escrow/buy must move the ITEM (measured by MASS) ───────
# ORIGIN: escrow and buy were only ever asserted with item COUNTS, which pass
# even when the item is duplicated (in the stash AND escrowed), lost, or
# replaced. Mass is the only check that proves the exact item moved. SENSITIVITY
# PROVEN by meta: a generated copy of flea_market.gd with the escrow's
# `TradeOps.take_from_stash(...)` line removed keeps the mass at 3.5 instead of
# 0.0, i.e. this assert catches the bug class (a count check cannot).
func _inv13_escrow_moves_item_by_mass() -> void:
	var p := MetaProfile.new()
	p.market.load_dir()
	p.flea.seed_from_market(p.market)
	var weapon := ItemCodec.item_from_path(WEAPON_PATH)
	var item_mass := weapon.get_mass()
	p.stash.deposit(weapon)
	var deposited := p.stash.get_total_mass()

	var listed := p.flea.list_from_stash(WEAPON_PATH, 100000)
	var listing: FleaListing = listed.get("listing")
	var escrowed := p.stash.get_total_mass()
	var cancel_ok := false
	var restored := -1.0
	if listing != null:
		cancel_ok = p.flea.cancel(listing.id).get("ok", false)
		restored = p.stash.get_total_mass()

	var target: FleaListing = null
	for l in p.flea.active_listings():
		if l.seller != FleaMarket.PLAYER_SELLER and (target == null or l.price < target.price):
			target = l
	var buy_delta := -1.0
	var buy_expected := -1.0
	if target != null:
		var before_buy := p.stash.get_total_mass()
		if p.flea.buy(target.id).get("ok", false):
			buy_delta = p.stash.get_total_mass() - before_buy
			var got := ItemCodec.decode_item(target.item)
			buy_expected = got.get_mass() if got != null else -1.0

	_check("INV-13", "escrow_moves_item_by_mass",
		listed.get("ok", false) and is_equal_approx(deposited, item_mass)
			and is_equal_approx(escrowed, 0.0) and cancel_ok and is_equal_approx(restored, deposited)
			and target != null and buy_delta > 0.0 and is_equal_approx(buy_delta, buy_expected),
		"item=%.3f deposited=%.3f escrow=%.3f restored=%.3f buy_delta=%.3f expected=%.3f" % [
			item_mass, deposited, escrowed, restored, buy_delta, buy_expected],
		"escrow/buy asserted only by COUNT: a duplicated/lost item still passed")

# ─── INV-14: a listing expires on the RAID COUNTER, exactly once ────
# ORIGIN: expiry rides the raid counter (the game's unit of time). An off-by-one
# either destroys escrowed loot a raid early or immortalises it forever.
func _inv14_listing_expires_on_raid_counter() -> void:
	var p := MetaProfile.new()
	p.stash.deposit(ItemCodec.item_from_path(BANDAGE_PATH))
	var before := p.stash.get_total_mass()
	var listing: FleaListing = p.flea.list_from_stash(BANDAGE_PATH, 100000).get("listing")
	if listing == null:
		_check("INV-14", "listing_expires_on_raid_counter", false, "no listing", "expiry rides the raid counter")
		return
	var due := listing.expires_at_raid() # listed_raid + expiry_raids
	p.raids = due - 1
	p.flea.on_raid_resolved()
	var early_active := listing.status == FleaListing.Status.ACTIVE
	p.raids = due
	p.flea.on_raid_resolved()
	var expired := listing.status == FleaListing.Status.EXPIRED
	var returned := is_equal_approx(p.stash.get_total_mass(), before)
	_check("INV-14", "listing_expires_on_raid_counter",
		early_active and expired and returned,
		"due=%d active_at_due-1=%s expired_at_due=%s mass_back=%.3f" % [
			due, str(early_active), str(expired), p.stash.get_total_mass()],
		"raid-counter expiry off-by-one destroys or immortalises escrowed loot")

# ─── INV-15: the listing fee is 5% with a 100 floor ─────────────────
# ORIGIN: the fee is the flea sink's price floor; it is charged on listing and
# never refunded, so its formula is economy-critical.
func _inv15_listing_fee_floor() -> void:
	var f := MetaProfile.new().flea
	var ok := f.listing_fee(1000) == 100 and f.listing_fee(0) == 100 and f.listing_fee(100000) == 5000
	_check("INV-15", "listing_fee_rate_and_floor", ok,
		"fee(1000)=%d fee(0)=%d fee(100000)=%d" % [f.listing_fee(1000), f.listing_fee(0), f.listing_fee(100000)],
		"listing fee formula is the flea sink's floor (5%, min 100)")

# ─── INV-37: the bot LOD tick must survive a bot that left the tree ──
# ORIGIN: NpcBot._tick_lod() did `var cam := get_viewport().get_camera_3d()`.
# `get_viewport()` is null once the bot is out of the tree (raid settlement and
# teardown do exactly that), so the existing `if cam == null` guard tested the
# WRONG null and the chain still dereferenced it: "Cannot call method
# 'get_camera_3d' on a null value" at bot.gd:1185, seen by spotter twice per
# settlement. Fixed by game-repo commit 12b8b99, which splits the chain and
# guards the viewport first. Promoted from npc-body's probe
# (npc_lod_viewport_tmp.gd.keep).
#
# WHY THE COUNTER CANNOT SEE THE FAULT, stated here because it is the whole
# difficulty of this class: a GDScript runtime error does NOT throw. The call
# returns normally, this harness's `_fail` stays 0, and a summary of
# "passed N failed 0" prints anyway. The null-deref half is therefore caught
# one layer up, by verify-all.mjs, which refuses a harness whose log contains a
# script-error line even when the script exits 0. Verified end to end: a probe
# printing `RESULT: PASS` with rc=0 and one runtime error in its log still fails
# the gate ("1 script error(s)").
#
# WORDING RULE, learned the hard way in the A/B that produced this entry: never
# print the literal token the gate greps for. verify-all.mjs counts
# /SCRIPT ERROR/g in the log, so a detail string containing that exact phrase
# makes a CORRECT tree fail the gate. Say "script error" or "runtime error" in
# lowercase, as below.
#
# The rule is WIDER than "detail string", and npc-body is right that the current
# wording understates it: the real rule is ANYTHING THAT CAN REACH STDOUT. A
# comment is safe today only because GDScript never echoes source to stdout; that
# stops being true the moment a failure path prints source — a code excerpt, the
# offending line, a get_stack() dump, or a harness that echoes the script under
# test. If `_check` ever grows a "here is the code" detail, the wording rule
# applies to it too. Measured 2026-09-25 against 6d7fe55: a harness whose PROSE
# printed the token was counted as a real error, and a hanging harness that
# printed it once in a sentence was reported as "raised" with the cause named
# confidently and wrongly. Line-start anchoring is what separates the two classes
# in the log (11/11 genuine errors sit at the start of a line; prose does not),
# but the discipline below is what keeps that from mattering.
#
# So the halves are split deliberately: the counters below assert what IS
# observable in-process (the valve still drives the rig, and the detached call
# really is reached), and the log is what catches the dereference. Run without
# verify-all.mjs, the detached half degrades to a smoke test — which is why the
# precondition is asserted rather than assumed.
func _inv37_npc_lod_survives_detached_bot() -> void:
	var bot_scene: PackedScene = load("res://src/npcs/bot/bot.tscn")
	if bot_scene == null:
		_check("INV-37", "npc_lod_valve_still_drives_the_rig", false,
			"bot.tscn missing", "F-LOD: cannot reach NpcBot._tick_lod() to check the guard")
		_check("INV-37b", "npc_lod_tick_survives_detached_bot", false,
			"bot.tscn missing", "F-LOD: detached path unexercised")
		return

	var bot: Node = bot_scene.instantiate()
	root.add_child(bot)
	await process_frame
	await process_frame
	var rig: Node = bot.get("_rig")
	if rig == null:
		# Do NOT report a pass: an unresolved _rig would make the valve case
		# vacuous, which is how a "green" LOD assertion proves nothing.
		_check("INV-37", "npc_lod_valve_still_drives_the_rig", false,
			"_rig unresolved after 2 frames", "F-LOD: the valve case needs a rig to drive")
		_check("INV-37b", "npc_lod_tick_survives_detached_bot", false,
			"_rig unresolved after 2 frames", "F-LOD: detached path unexercised")
		bot.queue_free()
		return

	# Valve case: at 200 m the rig must go to LOD 2, at 1 m back to 0. This is
	# what stops a future over-guard from "fixing" the crash by disabling LOD.
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.make_current()
	cam.global_position = Vector3.ZERO
	bot.global_position = Vector3(200.0, 0.0, 0.0)
	bot.call("_tick_lod")
	var far_lod := int(rig.get("_lod"))
	bot.global_position = Vector3(1.0, 0.0, 0.0)
	bot.call("_tick_lod")
	var near_lod := int(rig.get("_lod"))
	_check("INV-37", "npc_lod_valve_still_drives_the_rig", far_lod == 2 and near_lod == 0,
		"far=%d near=%d (expect 2 then 0)" % [far_lod, near_lod],
		"F-LOD: a null guard that also disables the LOD valve is not a fix (12b8b99)")

	# Detached case: assert the risky precondition is REACHED before calling, so
	# this cannot pass by never getting near the guarded line.
	cam.clear_current()
	root.remove_child(bot)
	var viewport_null: bool = bot.get_viewport() == null
	bot.call("_tick_lod")  # unfixed: runtime error at bot.gd:1185 -> gate fails
	var still_null: bool = bot.get_viewport() == null
	_check("INV-37b", "npc_lod_tick_survives_detached_bot", viewport_null and still_null,
		"viewport_null_before=%s after=%s (a runtime error here fails the gate)" % [str(viewport_null), str(still_null)],
		"F-LOD: get_viewport() is null out of tree; the receiver needs the guard (12b8b99)")
	bot.free()
	cam.free()

## INV-37c — ORIGIN: npc-body's CASE_D, on the OTHER site 712e22d guards.
# INV-37b covers _tick_lod; this covers _acquire_target (bot.gd:651), which the
# same fix guards. Measured in both directions by npc-body: 1 script error on
# 12b8b99 ("Invalid access to property or key 'current_scene' on a base object of
# type 'null instance'") and 0 on 712e22d. The guard IS on main (e28b475, by
# ancestry), so this is a permanent guard for a fix that has already shipped.
#
# Same shape as INV-37b on purpose: assert the precondition BEFORE the risky call,
# so the case cannot pass by never reaching the guarded line, and re-assert it
# after, so a harness that tore the bot down some other way cannot satisfy it.
#
# The counters cannot see the dereference -- a GDScript runtime error leaves no
# in-process trace -- so the gate's log check is the half that discriminates. Run

func _inv38_no_unguarded_get_tree_deref() -> void:
	# ORIGIN: the null-accessor family. `get_tree()` is null once a node has left
	# the tree, which is the settlement/teardown window. Four sites have already
	# been hit and fixed individually — bot.gd:1185 (12b8b99), _show_result and
	# _show_damage_direction (3ef1291), and _acquire_target().get_tree (712e22d).
	# All four are the SAME defect, and four patches is four chances to forget the
	# fifth. This asserts the class instead of the instances, so the next site
	# fails a gate rather than a playtest.
	#
	# It is a SOURCE scan, not a runtime one, on purpose: a runtime check can only
	# reach a site it knows how to construct the teardown window for, and it is
	# per-repo. The scan is cross-repo and covers the shape rather than the list.
	#
	# Two shapes are checked, because the fixes used two shapes:
	#   1. CHAINED — `something.get_tree().x` dereferences the accessor inline with
	#      no opportunity to guard it. This is 712e22d's bug verbatim.
	#   2. BOUND — `var t := get_tree()` then `t.x`, with no `t == null` in the
	#      enclosing function. Guarding the VALUES about to be dereferenced is not
	#      guarding the RECEIVER, which is what 3ef1291's comment says and what
	#      the original sites got wrong.
	var roots := ["res://src", "res://scenes", "res://addons/cabra.lat_shooters/src"]
	var chained: Array[String] = []
	var bound: Array[String] = []
	for root in roots:
		_scan_tree(root, chained, bound)

	# REPORT-ONLY (QA, 2026-09-26). The RULE is sound - a chained
	# X.get_tree().y dereferences the accessor inline and cannot be guarded,
	# which is 712e22d verbatim. But it is NEW in this commit and had never
	# been measured against the tree. As an unconditional FAIL it made the whole
	# gate permanently red on sites this repo cannot fix, 5 of them in the addon
	# repo, and a gate that cannot pass teaches reviewers to ignore it exactly
	# as effectively as one that cannot fail. The count IS the deliverable: it
	# decides whether the follow-up is a 22-site refactor or three sites.
	# Promote back to _check once triaged and measured.
	_inv38a_sites = chained.size()
	if _inv38a_sites > _inv38a_baseline():
		# Ratchet tripped: the debt grew. A report-only tier that can only fall
		# silent is deletion with a receipt, so growth has to be a failure.
		# _check(id, name, ok, detail, origin) -- ok is the VERDICT, and a
		# tripped ratchet is always false. The failure line is what names the
		# ratchet, so RESULT never has to claim it on unrelated failures.
		_check("INV-38a", "chained get_tree() deref (RATCHET TRIPPED — was report-only)",
			false,
			"%d site(s), above the %d baseline: %s" % [chained.size(), _inv38a_baseline(), ", ".join(chained)],
			"debt grew since the demotion; report-only may shrink, never grow")
	else:
		_note("INV-38a", "chained get_tree() deref (REPORT-ONLY)",
			"%d site(s): %s" % [chained.size(), (", ".join(chained) if not chained.is_empty() else "none")],
			"F-RECV: a chained X.get_tree().x dereferences the accessor inline, so it cannot be guarded at all (712e22d)")

	_check("INV-38b", "every bound get_tree() is null-checked", bound.is_empty(),
		"unguarded: %s" % (", ".join(bound) if not bound.is_empty() else "none"),
		"F-RECV: get_tree() is null after the node leaves the tree; a bound local that is dereferenced without a null check is the settlement-window crash (bot.gd:1185, 3ef1291)")

func _scan_tree(dir_path: String, chained: Array[String], bound: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with("."):
				_scan_tree(full, chained, bound)
		elif name.ends_with(".gd"):
			_scan_file(full, chained, bound)
		name = dir.get_next()
	dir.list_dir_end()

func _scan_file(path: String, chained: Array[String], bound: Array[String]) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var lines := text.split("\n")
	var i := 0
	while i < lines.size():
		var raw: String = lines[i]
		var code := raw.strip_edges()
		# Shape 1: chained accessor deref. Skip comments so a prose mention in a
		# comment cannot fail a gate — comments are not code, and an invariant that
		# reads them manufactures findings with false confidence.
		if not code.begins_with("#") and not _in_lifecycle_callback(text, i):
			var chain := RegEx.new()
			# Matches BOTH shapes: a bare `get_tree().x` and a chained
			# `X.get_tree().x`. The receiver form alone was a measured GAP, not a
			# false positive: bot.gd:444 is a bare get_tree().x and the pattern
			# required an identifier before the dot, so the most common form of
			# this defect was invisible to the check. A guard that cannot see the
			# shape it exists to catch is not a partial guard, it is decoration.
			chain.compile("get_tree\\s*\\(\\s*\\)\\s*\\.")
			if chain.search(code) != null and not _function_guards_receiver(text, i, raw):
				chained.append("%s:%d" % [path, i + 1])
		i += 1
	# Shape 2: a bound local that is dereferenced in a function with no null check.
	# Scanned per function so the null check has to be in the same scope.
	var funcs := RegEx.new()
	funcs.compile("(?s)(?:^|\\n)(?:static\\s+)?func\\s+[A-Za-z_][A-Za-z0-9_]*\\s*\\([^)]*\\)[^\\n]*\\n(.*?)(?=\\n(?:static\\s+)?func\\s|\\Z)")
	var m := funcs.search(text)
	while m != null:
		var body: String = m.get_string(1)
		var bind := RegEx.new()
		# The negative lookahead matters and was a measured false positive:
		# `var t = get_tree().create_timer(0.01)` is a CHAINED call, but this
		# pattern matched the `var t = get_tree()` prefix of it and then reported
		# it a second time as a bound local. Without the lookahead the same line
		# fails two different checks for one defect.
		bind.compile("var\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*(?::[^=]+)?=\\s*get_tree\\s*\\(\\s*\\)(?![.\\w])")
		var bm := bind.search(body)
		if bm != null:
			var v: String = bm.get_string(1)
			var deref := RegEx.new()
			deref.compile("\\b" + v + "\\s*\\.")
			var guard := RegEx.new()
			# Four accepted spellings, each added because a run measured the
			# previous set producing a false positive on guarded code:
			#   t == null / null == t   explicit
			#   if not t                 negated truthiness
			#   if t:                    plain truthiness  <- the GDScript idiom, and
			#                                   the one that was missing, so
			#                                   weapon_3d.gd's `if t: await
			#                                   t.physics_frame` was reported
			#                                   unguarded while being guarded
			#   t != null                explicit positive
			# A guard check that only accepts one spelling of a real guard
			# invents findings with the confidence of a true one.
			guard.compile("\\b" + v + "\\s*==\\s*null|null\\s*==\\s*" + v + "\\b|\\bif\\s+not\\s+" + v + "\\b|\\bif\\s+" + v + "\\s*:|" + v + "\\s*!=\\s*null")
			if deref.search(body) != null and guard.search(body) == null:
				bound.append("%s (%s)" % [path, v])
		m = funcs.search(text, m.get_end())

## True when the enclosing function already established that the node is in the
## tree. `is_inside_tree()` returning true implies `get_tree()` is non-null, so
## an `is_inside_tree()` guard IS a receiver guard and flagging past it is a
## false positive. Measured: src/npcs/bot_loot.gd:9 returns early on
## `not body.is_inside_tree()` and lines 14 and 21 dereference
## `body.get_tree()`. The guard is on the receiver's tree membership rather than
## spelled `get_tree() == null`, and a check that only accepts one spelling of a
## real guard is a check that invents findings with the confidence of a true one.
func _function_guards_receiver(text: String, line_index: int, raw_line: String) -> bool:
	# Find the start of the enclosing function, then look at its body only.
	var before := text.split("\n", true, line_index)
	var start := -1
	for i in range(before.size() - 1, -1, -1):
		# Matches `func ` and `static func ` — the latter was a measured miss, so
		# every static helper in the tree was scanned as if it had no enclosing
		# function and therefore as if it had no guard either.
		if before[i].begins_with("func ") or before[i].begins_with("static func "):
			start = i
			break
	if start < 0:
		return false
	var body := "\n".join(PackedStringArray(before.slice(start)))
	body += "\n" + raw_line
	# `is_inside_tree()` returning true implies get_tree() is non-null, so it IS a
	# receiver guard. So is an explicit `get_tree() == null` test in the same
	# function, which is how controller.gd:626 guards its own deref.
	return body.find("is_inside_tree()") != -1 or _has_null_test(body)

## True when the function body contains an explicit get_tree() null test, in
## either polarity. Added because widening INV-38a to the bare form made
## controller.gd:626 — `if get_tree() == null or get_tree().current_scene == null`
## — visible, and it is guarded by the second clause of its own condition.
## True when line index `idx` sits inside a Godot lifecycle callback.
##
## Exempting these is a MEASURED narrowing, not a stylistic preference. In
## Godot 4 `get_tree()` is VALID during `_exit_tree` - the node has not yet
## left the tree - so the null-dereference hazard INV-38a looks for is not
## present at all there. Requiring a guard in `_exit_tree` is asking for a
## check that cannot fail, which is how a gate teaches reviewers to ignore
## it. Measured on origin/main b93618e: scenes/arena_manager_core.gd lines
## 156 and 164 are bare `get_tree().get_nodes_in_group(...)` inside
## `_exit_tree`; guarding them would be noise, not defence.
##
## LIMITATION, STATED RATHER THAN PAPERED OVER: this exemption is lexical and
## the call graph is not. The same file's `_setup_raid` (317, 332) and
## `_configure_raid1_extractions` (187) are ALSO safe - reachable only from
## `_ready` with the node in the tree - but they are not lifecycle
## callbacks, so this rule still reports them. That residual is a known false
## positive class, not an oversight. Distinguishing them needs a call graph
## rather than a scan, so the real choice is between a narrower assertion and
## a resolver. See task df6502.
func _in_lifecycle_callback(text: String, line_idx: int) -> bool:
	# line_idx is a LINE index. It was previously compared against a character
	# offset (RegExMatch.get_start), so the loop broke at whichever func happened
	# to sit past that character position and the exemption returned the wrong
	# function name. The result: the lifecycle exemption did not exempt anything,
	# and _physics_process / _unhandled_input were reported as unguarded.
	# Walk lines and track the last func declaration at or before line_idx.
	var re := RegEx.new()
	re.compile("^(?:static\\s+)?func\\s+([A-Za-z_][A-Za-z0-9_]*)")
	var found := ""
	var ln := 0
	for raw in text.split("\n"):
		if ln > line_idx:
			break
		var m := re.search(raw.strip_edges())
		if m != null:
			found = m.get_string(1)
		ln += 1
	return found in [
		"_ready", "_enter_tree", "_exit_tree", "_process", "_physics_process",
		"_input", "_unhandled_input", "_shortcut_input", "_gui_input",
		"_notification",
	]
	# "_init" is deliberately ABSENT. It is the one entry where get_tree() is
	# INVALID in Godot 4: _init() runs at construction, before the node is in
	# the tree. Exempting it would suppress findings in exactly the function
	# where the null-deref hazard is real. Every name above is a callback that
	# Godot only invokes with the node already inside the tree (_exit_tree
	# included: the node has not left yet when that runs).

func _has_null_test(body: String) -> bool:
	var r := RegEx.new()
	r.compile("get_tree\\s*\\(\\s*\\)\\s*(==|!=)\\s*null|null\\s*(==|!=)\\s*get_tree\\s*\\(\\s*\\)")
	return r.search(body) != null

func _inv37c_npc_acquire_target_survives_detached_bot() -> void:
	var bot_scene: PackedScene = load("res://src/npcs/bot/bot.tscn")
	if bot_scene == null:
		_check("INV-37c", "npc_acquire_target_survives_detached_bot", false,
			"bot.tscn missing", "F-TARGET: cannot reach NpcBot._acquire_target() to check the guard")
		return

	var bot: Node = bot_scene.instantiate()
	root.add_child(bot)
	await process_frame
	await process_frame

	# Detach it, so get_tree() has no receiver. Assert the precondition BEFORE the
	# call, or this can pass by never getting near the guarded line.
	root.remove_child(bot)
	var detached_before: bool = not bot.is_inside_tree()
	bot.call("_acquire_target")
	var detached_after: bool = not bot.is_inside_tree()
	_check("INV-37c", "npc_acquire_target_survives_detached_bot",
		detached_before and detached_after,
		"detached_before=%s after=%s (a runtime error here fails the gate)" % [
			str(detached_before), str(detached_after)],
		"F-TARGET: is_inside_tree() must be checked before get_tree() (712e22d)")
	bot.free()
func _has_corrupt_backup() -> bool:
	var d := DirAccess.open(META_TEST_DIR)
	if d == null:
		return false
	for f in d.get_files():
		if f.contains(".corrupt-"):
			return true
	return false

func _meta_cleanup() -> void:
	var d := DirAccess.open(META_TEST_DIR)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)

# ─── INV-38f: POSE PRECONDITION — a frozen rig makes any pose reading VOID ──
# ORIGIN: spotter's LOD measurement, 2026-09-26. Bots measured at
# speed_scale 0.000 with AnimationPlayer position advancing 0.0000 s over 240
# frames while the root travelled 6.100 m. Cause: humanoid_rig.gd:164 zeroes
# speed_scale when LOD'd, and bot.gd _tick_lod keys on distance to the active
# camera with anim_lod_distance = 45.0 (bot.gd:129).
#
# WHY THIS IS A PRECONDITION AND NOT A SCENE-WIDE ASSERTION. Written as a
# global "speed_scale must be > 0" this would FAIL IN A NORMAL GAME every time
# a player walks away from a bot, because that is production behaving correctly
# at 45 m and 90 m. A global assertion here is a false-positive generator and it
# gets deleted after it cries wolf once. So it guards the MEASUREMENT PATH: the
# thing to assert is that a pose reading is only taken from a subject that can
# move, and that a reading from a frozen subject is VOID rather than degenerate.
#
# This catches a failure that has bitten repeatedly: a valid-looking number read
# off a rig that is in a locked pose. The number is real, the arithmetic is
# right, and the subject never moved — the same shape as INV-20 passing happily
# over a rig that could not animate.
#
# THE ASSERTION IS DEMONSTRATED RED HERE, ON PURPOSE. A guard that has only
# ever been green is a hope, not a guard.
func _pose_precondition(rig: Node, cam: Camera3D) -> String:
	# Search by TYPE, the way humanoid_rig._ensure_anim() does, not by NAME.
	# The first version of this guard used get_node("AnimationPlayer") and it
	# reported "no AnimationPlayer" on a perfectly good rig, because the node in
	# humanoid_rig.tscn is not named that. A guard that looks up the wrong thing
	# reports a missing AnimationPlayer instead of a frozen pose, which is the
	# most misleading possible answer: it sends the reader to the scene file
	# instead of to the 45 m distance.
	var anim: AnimationPlayer = null
	var stack: Array = [rig]
	while not stack.is_empty() and anim == null:
		var n: Node = stack.pop_back()
		if n is AnimationPlayer:
			anim = n
		else:
			stack.append_array(n.get_children())
	if anim == null:
		return "POSE PRECONDITION FAILED: rig %s has no AnimationPlayer anywhere in its subtree — no pose reading is possible" % rig.name
	if anim.speed_scale > 0.0:
		return ""
	var d := -1.0
	if cam != null:
		d = rig.global_position.distance_to(cam.global_position)
	return "POSE PRECONDITION FAILED: rig %s has speed_scale=%.3f (frozen by LOD) and camera distance %.1f m — any pose reading from this subject is VOID, not degenerate" % [
		rig.name, anim.speed_scale, d]


func _inv38f_pose_precondition_guard() -> void:
	var rig_ps := load(RIG_SCENE) as PackedScene
	if rig_ps == null:
		_check("INV-38f", "pose precondition guard", false, "rig scene missing", "spotter LOD precondition")
		return
	var rig := rig_ps.instantiate()
	root.add_child(rig)
	await process_frame  # INV-38f: global_transform is not expressible until the node is in the tree

	# Positive arm: a rig in a live scene with no camera-driven LOD applied is a
	# VALID subject, and the guard must be quiet on it. A guard that fires on
	# everything is not a guard.
	var live := _pose_precondition(rig, null)
	_check("INV-38f", "quiet on a live (unfrozen) subject", live == "",
		"expected no precondition failure, got: %s" % (live if live != "" else "(silent)"),
		"spotter LOD precondition: the guard must not cry wolf")

	# RED ARM: the same rig, LOD'd to 1, which is production behaviour at >45 m.
	# The guard MUST fire, and the message must carry the distance so a failing
	# run says which side of 45 m the subject was on.
	rig.set_lod(1)
	var frozen := _pose_precondition(rig, null)
	if frozen == "":
		_check("INV-38f", "RED ARM: fires on an LOD-frozen subject", false,
			"guard stayed silent on a rig with speed_scale 0.0 — a guard that cannot fail",
			"spotter: the check that cannot fail")
	else:
		_check("INV-38f", "RED ARM: fires on an LOD-frozen subject",
			frozen.contains("VOID") and frozen.contains("speed_scale"),
			frozen, "spotter LOD precondition")

	# And it must go quiet again once the subject is live, so it is a PRECONDITION
	# and not a latch: a latched guard would poison every later measurement.
	rig.set_lod(0)
	var recovered := _pose_precondition(rig, null)
	_check("INV-38f", "re-arms after the subject is live again", recovered == "",
		"expected silent, got: %s" % (recovered if recovered != "" else "(silent)"),
		"a latched guard would void every later reading")

	# Distance reporting: with a camera supplied the message must carry the
	# distance, because "frozen" without "how far" sends the next reader hunting.
	var cam := Camera3D.new()
	root.add_child(cam)
	await process_frame  # INV-38f: global_position is only expressible once the node is in the tree
	cam.global_position = Vector3(0, 0, 60)
	rig.set_lod(1)
	var with_dist := _pose_precondition(rig, cam)
	rig.set_lod(0)
	var reported := with_dist.contains("60.0 m")
	_check("INV-38f", "failure message carries the camera distance", reported,
		with_dist if with_dist != "" else "(silent)",
		"a failing run must say which side of 45 m it was on")
	rig.queue_free()
	cam.queue_free()

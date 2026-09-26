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
const IK_SCENE := "res://addons/cabra.lat_shooters/src/player/scenes/player_ik.tscn"
const META_TEST_DIR := "user://inv_meta_test"
const META_SAVE := "user://inv_meta_test/profile.save"

var _pass := 0
var _fail := 0
var _fail_lines: Array[String] = []
var _sabotage := false

func _initialize() -> void:
	_sabotage = OS.get_environment("INVARIANTS_SABOTAGE") in ["1", "gunsmith"]
	_run()

func _run() -> void:
	print("=== validate_invariants: cross-system invariants ===")

	_inv04_magazine_alias()
	_inv06_wrapped_item_mass()
	_inv07_undefined_cert_level()
	_inv11_container_grid_dims()
	_inv16_attachment_wiring()
	_inv16b_baked_optic_toggle()
	_inv36_inventory_null_transfer()
	await _inv17_world_mode_tags_no_npcs()
	await _inv18_rig_sole_on_ground()
	await _inv19_rig_body_material_supports_flash()
	await _inv20_every_clip_drives_the_rig()
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
		print("RESULT: FAIL")
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
		print("RESULT: PASS (counters only — run via verify-all.mjs for the runtime-error check)")
		quit(0)

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

	_check("INV-38a", "no chained X.get_tree(). deref", chained.is_empty(),
		"chained: %s" % (", ".join(chained) if not chained.is_empty() else "none"),
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
func _in_lifecycle_callback(text: String, idx: int) -> bool:
	var re := RegEx.new()
	re.compile("(?m)^(?:static\\s+)?func\\s+([A-Za-z_][A-Za-z0-9_]*)")
	var found := ""
	for m in re.search_all(text):
		if m.get_start() > idx:
			break
		found = m.get_string(1)
	return found in [
		"_ready", "_enter_tree", "_exit_tree", "_process", "_physics_process",
		"_input", "_unhandled_input", "_shortcut_input", "_gui_input",
		"_notification", "_init",
	]

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

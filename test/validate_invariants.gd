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

func _initialize() -> void:
	_run()

func _run() -> void:
	print("=== validate_invariants: cross-system invariants ===")

	_inv04_magazine_alias()
	_inv06_wrapped_item_mass()
	_inv07_undefined_cert_level()
	_inv11_container_grid_dims()
	_inv16_attachment_wiring()
	_inv16b_baked_optic_toggle()
	await _inv17_world_mode_tags_no_npcs()
	await _inv18_rig_sole_on_ground()
	await _inv19_rig_body_material_supports_flash()
	await _inv20_every_clip_drives_the_rig()
	_inv21_roles_swap_conserves_mass()
	_inv22_roles_kia_forfeits_only_active_kit()
	_inv23_skeletons_in_sync()
	_inv24_spawn_picks_are_distinct()

	# meta invariants need a scratch user:// dir; no autoload/raid/frames required
	_meta_cleanup()
	DirAccess.make_dir_recursive_absolute(META_TEST_DIR)
	_inv12_save_atomicity_and_quarantine()
	_inv12c_old_save_migrates()
	_inv13_escrow_moves_item_by_mass()
	_inv14_listing_expires_on_raid_counter()
	_inv15_listing_fee_floor()

	await _run_player_invariants()

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
		print("RESULT: PASS")
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
		w3d.data = wres
		var marker := w3d.get_node_or_null("Scope") as Node3D
		var baked: Node3D = null
		if marker != null:
			for c in marker.get_children():
				if String(c.name).contains("attachment_scope_reddot"):
					baked = c as Node3D
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

	world.queue_free()

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

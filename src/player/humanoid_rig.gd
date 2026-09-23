# res://addons/cabra.lat_shooters/src/player/humanoid_rig.gd
class_name HumanoidRig
extends Skeleton3D
## Shared humanoid body rig (player <-> NPC). See the published interface.
##
## WORLD MODE by default: whole body, normal PSX material, NO foot IK, NO
## colliders, NO first-person head-cut. A bot instantiates this as a child of
## its CharacterBody3D and drives tint/flash/LOD through this API. The player
## layers its FPS behaviour ON TOP (analytic arm IK below + foot IK +
## PlayerBodyVisibility), reusing the same skeleton/mesh so nothing is
## duplicated. The arm solver is analytic (law of cosines, skeleton-local
## global-pose overrides) — the GodotIK GDExtension proved to never apply its
## solve (effector moved 1 m, hand moved 0.0000, isolated, 2026-09-22), so no
## code path may depend on it for arms.
##
## Hard rules (consumer MUSTs): material is duplicated PER INSTANCE (never the
## shared resource); world mode never tags colliders into the shot-exclude group
## (B2: ShotRay excludes that group tree-wide -> an NPC would be un-hittable).
##
## TRAP if this scene ever gains its own AnimationPlayer: `AnimationPlayer.root_node`
## is the base of the track paths, and the clips address the skeleton as
## `Skeleton3D:<bone>`. With the player inside the rig (default `root_node = ..`)
## that resolves to a CHILD named "Skeleton3D", which does not exist, so the clip
## plays and moves nothing (silently). Set `root_node` explicitly, or name the rig
## node "Skeleton3D" and keep the player above it (what npc-body's bot.tscn does).
##
## M1 DEBT (coordinator decision 2026-09-21): `humanoid_rig.tscn` is the SINGLE
## SOURCE of the skeleton, but the player (`player_ik.tscn`) still carries a COPY
## of the same 87 bones (it needs `ik.gd`'s foot IK on the root). They must stay
## in sync until the dedupe lands: merge foot IK into HumanoidRig (`set_foot_ik`)
## and make the player instance this scene. Drift is guarded by an invariant
## (bone count + names/order) until then.

## LIGHTING: the body renders with the PSX **LIT** shader, so a scene that
## instantiates this rig WITHOUT a light draws the body BLACK — add a
## DirectionalLight3D (the rig is not broken).
const VISIBLE_LAYER := 1

## Body reference (M7) — INTENTIONAL HOOKS, consumer pending. The body swap must
## not change shot/eye resolution: these carry NUMERIC PARITY with NpcBot's
## eye/chest heights (1.5 / 1.2). A look-at/anchor consumer reads them; none does
## yet, so they are documented hooks (not dead code) until M7 is wired.
const HEAD_BONE := "spine.006_07" ## head/eye bone (M7 reference)
const CHEST_BONE := "spine.003_04" ## chest bone (M7 reference)
const EYE_HEIGHT := 1.5 ## M7 numeric parity (NpcBot eye_height)
const CHEST_HEIGHT := 1.2 ## M7 numeric parity (NpcBot chest height)
## Feet-on-ground placement (C2): the same skeleton the player uses sits at
## y=0.851 (player.tscn), so the ankle (local z=-0.784) lands ~0.067 m up =
## the sole thickness. A world consumer places the rig node at this Y to put
## the soles on the floor (NOT 0.784, which sinks the sole).
const GROUND_PLACEMENT_Y := 0.893
## F7: 0.851 is the player's node Y (ankle 0.067 up), but the boot SOLE then
## sits 4.2 cm below the floor (measured AABB min y = -0.042). A world consumer
## wants the sole ON the floor, so add that 4.2 cm.

@export var anim_enabled: bool = true
@export var visible_range: float = 0.0 ## 0 = always visible (per-bot valve, M9).

var _lod: int = 0
var _anim: AnimationPlayer
var _mats: Array[ShaderMaterial] = []
var _fork: Shader = null
## Our body shader fork (body_psx_base.gdshaderinc): the shared surface shader
## (psx_base) has no `flash_amount`, so tint works but the damage flash would be
## written to a uniform nobody reads (F6).
const BODY_SHADER := "res://addons/cabra.lat_shooters/src/player/psx_lit_body_nearclip.gdshader"

func _ready() -> void:
	_ensure_anim()

# ─── GEOMETRY ──────────────────────────────────────────────────────────────────
func get_body_mesh() -> MeshInstance3D:
	var direct := get_node_or_null("MESH") as MeshInstance3D
	if direct != null:
		return direct
	for c in get_children():
		if c is MeshInstance3D:
			return c
	return null

## Every MeshInstance3D the rig owns (body + the bone-split head part). M4.
func get_all_meshes() -> Array:
	var out: Array = []
	var stack: Array = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			out.append(n)
		stack.append_array(n.get_children())
	return out

# ─── MATERIAL (M4 / B1) ────────────────────────────────────────────────────────
## Duplicate the body material PER INSTANCE across every mesh and surface and
## return the copies. NEVER mutates the shared resource. The surface is a
## ShaderMaterial (not StandardMaterial3D), so the consumer must not cast by
## type — use set_tint()/set_flash() below.
func own_materials() -> Array[ShaderMaterial]:
	if not _mats.is_empty():
		return _mats
	_mats = []
	for mi in get_all_meshes():
		var count := 1
		if mi.mesh != null:
			count = maxi(mi.mesh.get_surface_count(), 1)
		for s in range(count):
			var src: Material = mi.get_active_material(s)
			var mat: ShaderMaterial = null
			if src is ShaderMaterial:
				mat = (src as ShaderMaterial).duplicate() as ShaderMaterial
			else:
				mat = ShaderMaterial.new()
				if src is BaseMaterial3D:
					mat.albedo_color = (src as BaseMaterial3D).albedo_color
			mi.set_surface_override_material(s, mat)
			# F6: force the body fork shader (has flash_amount) and disable the
			# near-clip (world mode = whole body). Params survive the swap by name.
			if _fork == null:
				_fork = load(BODY_SHADER) as Shader
			if _fork != null:
				mat.shader = _fork
				mat.set_shader_parameter("body_near_cutoff", 0.0)
			_mats.append(mat)
	return _mats

## Team tint (works on the PSX ShaderMaterial via `modulate_color`).
func set_tint(color: Color) -> void:
	for mat in own_materials():
		mat.set_shader_parameter("modulate_color", color)

## White damage flash 0..1 (new `flash_amount` uniform in body_psx_base).
func set_flash(amount: float) -> void:
	var a := clampf(amount, 0.0, 1.0)
	for mat in own_materials():
		mat.set_shader_parameter("flash_amount", a)

# ─── PERF / LOD (M9 / B4) ──────────────────────────────────────────────────────
## 0 = full, 1 = anim frozen (keeps drawing), 2 = hidden (cuts draw + skinning).
func set_lod(level: int) -> void:
	_lod = clampi(level, 0, 2)
	visible = _lod < 2
	_apply_anim_speed()

func set_anim_enabled(on: bool) -> void:
	anim_enabled = on
	_apply_anim_speed()

## Per-bot distance valve (M9): the body is culled past `m` metres. 0 = off.
## Applied to the meshes so it actually does something (F1).
func set_visible_range(m: float) -> void:
	visible_range = m
	for mi in get_all_meshes():
		if m > 0.0:
			mi.visibility_range_end = m
			mi.visibility_range_end_margin = maxf(m * 0.1, 0.5)
		else:
			mi.visibility_range_end = 0.0

## Single writer for AnimationPlayer.speed_scale: LOD and the on/off flag
## COMPOSE, so set_lod(1) followed by set_anim_enabled(true) cannot re-animate
## a bot frozen by distance (F2).
func _apply_anim_speed() -> void:
	var a := _ensure_anim()
	if a != null:
		a.speed_scale = 1.0 if (anim_enabled and _lod == 0) else 0.0

# ─── ANIMATION (M3) ────────────────────────────────────────────────────────────
func play(anim: StringName) -> bool:
	var a := _ensure_anim()
	if a == null or not a.has_animation(anim):
		return false
	a.play(anim)
	return true

func anim_names() -> PackedStringArray:
	var a := _ensure_anim()
	return a.get_animation_list() if a != null else PackedStringArray()

# ─── BODY REFERENCE BONES (M7) ─────────────────────────────────────────────────
## Head/eye bone index for a look-at / eye anchor (M7). No caller yet.
func head_bone_index() -> int:
	return find_bone(HEAD_BONE)

## Chest bone index for aim/anchor points (M7). No caller yet.
func chest_bone_index() -> int:
	return find_bone(CHEST_BONE)

## World-space origin of a named bone (eye/chest/hand), for LOS/aim (M7).
func bone_global_position(bone_name: String) -> Vector3:
	var idx := find_bone(bone_name)
	if idx < 0:
		return global_position
	return global_transform * get_bone_global_rest(idx).origin

# ─── ANALYTIC ARM IK (replaces the GodotIK arm path) ─────────────────────────
## Two-bone analytic solve (shoulder→elbow→wrist) driven by live Node3D grips.
## The ViewmodelRig passes its gun-child grips; this solver poses
## upper_arm/forearm/hand from the grip every _process via persistent
## skeleton-local global-pose overrides (which compose ON TOP of whatever the
## AnimationPlayer wrote that frame — clips and IK never fight over one
## writer because the override always wins for these 3 bones).
## Until the clip cleanup lands (phase 2, coordinator order), the hand/forearm
## animation tracks still drive the REST pose underneath; the override hides
## them whenever a target is set.
const UPPER_L := "upper_arm.L_09"
const FORE_L := "forearm.L_010"
const HAND_L := "hand.L_011"
const UPPER_R := "upper_arm.R_032"
const FORE_R := "forearm.R_033"
const HAND_R := "hand.R_034"

## side ("right_hand" | "left_hand") -> target Node3D (grip, live-followed).
var _ik_targets: Dictionary = {}
var _ik_idx: Dictionary = {}

## side -> target Node3D. Accepts "right_hand"/"left_hand" ("R"/"L" short).
## A null target clears that side. Targets are followed live in _process.
func set_ik_target(side: StringName, target: Node3D) -> void:
	var s := _ik_side(side)
	if s == &"":
		push_warning("HumanoidRig: unknown IK side '%s' (want right_hand/left_hand)." % side)
		return
	if target == null:
		clear_ik_target(s)
		return
	_ik_targets[s] = target

func clear_ik_target(side: StringName) -> void:
	var s := _ik_side(side)
	_ik_targets.erase(s)
	# Skeleton3D only clears ALL overrides at once; the remaining sides are
	# re-applied on the next _process (same frame cost, no stale pose).
	clear_bones_global_pose_override()

func clear_all_ik_targets() -> void:
	_ik_targets.clear()
	clear_bones_global_pose_override()

func has_ik_target(side: StringName) -> bool:
	return _ik_targets.has(_ik_side(side))

## World-space distance hand-bone origin -> its target origin. -1 when off
## (no target, unknown bones, or target freed). Probe/spotter readout.
func arm_ik_error(side: StringName) -> float:
	var s := _ik_side(side)
	if not _ik_targets.has(s) or not is_inside_tree():
		return -1.0
	var t: Node3D = _ik_targets[s] as Node3D
	if t == null or not is_instance_valid(t):
		return -1.0
	var bones := _ik_bones(s)
	var h: int = _ik_bone(bones[2])
	if h < 0:
		return -1.0
	var hand_world: Vector3 = global_transform * get_bone_global_pose(h).origin
	return hand_world.distance_to(t.global_transform.origin)

func _ik_side(side: StringName) -> StringName:
	var s := side.to_lower()
	if s in [&"right_hand", &"right", &"r"]:
		return &"right_hand"
	if s in [&"left_hand", &"left", &"l"]:
		return &"left_hand"
	return &""

func _ik_bones(s: StringName) -> Array:
	if s == &"right_hand":
		return [UPPER_R, FORE_R, HAND_R]
	return [UPPER_L, FORE_L, HAND_L]

func _ik_bone(bone_name: String) -> int:
	if _ik_idx.has(bone_name):
		return int(_ik_idx[bone_name])
	var i := find_bone(bone_name)
	_ik_idx[bone_name] = i
	return i

func _process(_delta: float) -> void:
	if _ik_targets.is_empty() or not is_inside_tree():
		return
	for s in _ik_targets.keys():
		_apply_arm_ik(StringName(s))

## One arm, all in skeleton-local space (bone global poses live there).
func _apply_arm_ik(s: StringName) -> void:
	var t: Node3D = _ik_targets.get(s) as Node3D
	if t == null or not is_instance_valid(t):
		_ik_targets.erase(s)
		return
	var names := _ik_bones(s)
	var u := _ik_bone(names[0])
	var f := _ik_bone(names[1])
	var h := _ik_bone(names[2])
	if u < 0 or f < 0 or h < 0:
		return
	var inv: Transform3D = global_transform.affine_inverse()
	var t_local: Transform3D = inv * t.global_transform
	_solve_arm(u, f, h, t_local.origin, t_local.basis.orthonormalized())

func _solve_arm(u: int, f: int, h: int, goal: Vector3, goal_basis: Basis) -> void:
	var rs: Transform3D = get_bone_global_rest(u)
	var re: Transform3D = get_bone_global_rest(f)
	var rw: Transform3D = get_bone_global_rest(h)
	var S := rs.origin
	var E0 := re.origin
	var W0 := rw.origin
	var L1 := S.distance_to(E0)
	var L2 := E0.distance_to(W0)
	if L1 < 1e-6 or L2 < 1e-6:
		return
	# Clamp the goal to the reachable shell (never divide by ~0 at S).
	var T := goal
	var d := S.distance_to(T)
	var max_reach := (L1 + L2) * 0.999
	if d > max_reach:
		T = S + (T - S) / d * max_reach
		d = max_reach
	if d < 1e-5:
		return
	var dir := (T - S) / d
	# Shoulder angle (law of cosines) between upper segment and S->T.
	var cos_a := clampf((L1 * L1 + d * d - L2 * L2) / (2.0 * L1 * d), -1.0, 1.0)
	var sin_a := sqrt(maxf(0.0, 1.0 - cos_a * cos_a))
	# Bend plane: keep the rest-time elbow side (pole) so the arm cannot flip.
	var pole := (E0 - S) - dir * (E0 - S).dot(dir)
	if pole.length() < 1e-6:
		# Rest arm is straight along dir: elbows point down + slightly back
		# (skeleton faces -Z, so back is +Z).
		pole = Vector3(0.0, -1.0, 0.35) - dir * Vector3(0.0, -1.0, 0.35).dot(dir)
	if pole.length() < 1e-8:
		pole = dir.cross(Vector3.UP)
		if pole.length() < 1e-8:
			pole = dir.cross(Vector3.RIGHT)
	pole = pole.normalized()
	var E := S + dir * (L1 * cos_a) + pole * (L1 * sin_a)
	var W := T
	# Rest segment directions -> desired directions (quaternion deltas).
	var du := (E0 - S).normalized()
	var df := (W0 - E0).normalized()
	var want_u := (E - S).normalized()
	var q_u := _quat_from_to(du, want_u)
	var carried_f := (q_u * df).normalized()
	var want_f := df
	if W.distance_to(E) > 1e-8:
		want_f = (W - E).normalized()
	var q_f := _quat_from_to(carried_f, want_f)
	var bu := Basis(q_u) * rs.basis
	var bf := Basis(q_f) * Basis(q_u) * re.basis
	set_bone_global_pose_override(u, Transform3D(bu, S), 1.0, true)
	set_bone_global_pose_override(f, Transform3D(bf, E), 1.0, true)
	set_bone_global_pose_override(h, Transform3D(goal_basis, W), 1.0, true)

func _quat_from_to(a: Vector3, b: Vector3) -> Quaternion:
	var d := clampf(a.normalized().dot(b.normalized()), -1.0, 1.0)
	if d > 0.9999:
		return Quaternion.IDENTITY
	if d < -0.9999:
		var axis := a.cross(Vector3.UP)
		if axis.length() < 1e-4:
			axis = a.cross(Vector3.RIGHT)
		return Quaternion(axis.normalized(), PI)
	return Quaternion(a.normalized(), b.normalized())

## Lazy + recursive (F3): the AnimationPlayer may be nested, and play() can be
## called before _ready().
func _ensure_anim() -> AnimationPlayer:
	if _anim != null and is_instance_valid(_anim):
		return _anim
	var stack: Array = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is AnimationPlayer:
			_anim = n
			return _anim
		stack.append_array(n.get_children())
	return null

extends SceneTree
# res://addons/cabra.lat_shooters/test/validate_scope_reticle.gd
#
# PERMANENT INVARIANT for the physical scope reticle (player-rig, optics card
# task_1790520029648_915731).
#
# WHAT IT PINS, and why each part is here:
#
# 1. LAYER SEPARATION. The reticle lives in the scope's SubViewport, and every
#    scope sets `own_world_3d = false`, so the reticle sits in the SHARED world.
#    Without a layer of its own it would also be drawn by the gameplay camera and
#    would float in front of the player whenever the scope is not raised. So the
#    reticle must be invisible to a `cull_mask = 1` camera and visible to a camera
#    that inherits 1048575. This is the assertion that would catch someone
#    "simplifying" SCOPE_RETICLE_LAYER from 8 to 4, which would collide with
#    PlayerBodyVisibility.HIDDEN_FROM_FPS_LAYER - the integer 4 is bit 2, which is
#    LAYER 3, and layer 3 holds the player's head and backpack.
#
# 2. PARALLAX, WHICH IS THE WHOLE POINT. `scope_lenses.gdshader` already ships a
#    reticle in `u_reticle_texture`, drawn in the lens shader. That one is locked to
#    the lens surface and CANNOT parallax, no matter where it is placed, because it
#    is painted in screen space. So a test that only checked "a reticle is visible"
#    would pass for the painted one too, and would not be testing the thing the
#    card asks for. This measures the reticle and a far target under the SAME
#    lateral weapon motion and requires the reticle to sweep further, by roughly the
#    ratio of their distances. A painted overlay scores 1.0 on that ratio and fails.
#
# 3. NON-EMPTY. A reticle that built zero instances would satisfy a naive "is it on
#    the right layer" check vacuously, so the instance count is asserted first and
#    every later check is meaningless without it.
#
# It measures GEOMETRY AND PROJECTION, never a tuned number like "the arm is 0.42 m
# long". The angular size is set by `subtended_angle_deg` and the test reads the
# consequence, so retuning the sight does not turn this red for the wrong reason.
#
# Run:
#   tools/godot-lock.sh --headless --path . \
#     --script res://addons/cabra.lat_shooters/test/validate_scope_reticle.gd

const VIEWPORT_SIZE := Vector2i(256, 256)
const NEAR_DISTANCE := 60.0      # the reticle plane
const FAR_DISTANCE := 6000.0     # the "target" it is laid over
const SWING := 0.05              # lateral weapon motion, metres
const FPS_CULL_MASK := 1         # gameplay camera, as authored in player.tscn
const VIEWMODEL_CULL_MASK := 2   # viewmodel camera, controller.gd:27

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# A stand-in for the scope's own rig: SubViewport sharing the world, a camera
	# with NO cull_mask line so it inherits 1048575, exactly as the three real
	# scope scenes are authored.
	var host := Node3D.new()
	root.add_child(host)

	var vp := SubViewport.new()
	vp.size = VIEWPORT_SIZE
	# own_world_3d = false, so the SubViewport shares the parent's world. That is
	# how all three real scope scenes are authored, and it is exactly why the
	# reticle needs its own layer.
	vp.own_world_3d = false
	host.add_child(vp)

	var scope_cam := Camera3D.new()
	scope_cam.fov = 1.7187443          # the reddot's authored value
	scope_cam.near = 0.01
	scope_cam.far = 937.3
	# deliberately NO cull_mask line: this is the inheritance under test
	vp.add_child(scope_cam)
	scope_cam.current = true
	print("scope camera cull_mask (inherited) = ", scope_cam.cull_mask)

	# A gameplay camera, to prove the reticle is NOT drawn by it.
	var fps_cam := Camera3D.new()
	fps_cam.cull_mask = FPS_CULL_MASK
	host.add_child(fps_cam)

	# ---- 3. NON-EMPTY FIRST: everything after is meaningless without it ----
	var reticle := ScopeReticle3D.new()
	host.add_child(reticle)
	reticle.reticle_distance = NEAR_DISTANCE
	reticle.attach_to(scope_cam)
	var visuals := reticle.visuals()
	_check("BUILD-1", "reticle built a non-empty set of visuals",
		visuals.size() >= 5, "visuals=%d (expected 4 arms + 1 pupil)" % visuals.size())
	if visuals.is_empty():
		_finish()
		return
	_check("BUILD-2", "reticle sits on its plane in front of the scope camera",
		is_equal_approx(reticle.global_position.distance_to(scope_cam.global_position),
			NEAR_DISTANCE),
		"distance=%.3f" % reticle.global_position.distance_to(scope_cam.global_position))

	# ---- 1. LAYER SEPARATION ---------------------------------------------
	var all_on_layer := true
	for v in visuals:
		if v.layers != ScopeReticle3D.SCOPE_RETICLE_LAYER:
			all_on_layer = false
	_check("LAYER-1", "every reticle visual is on SCOPE_RETICLE_LAYER",
		all_on_layer, "mask=%d" % ScopeReticle3D.SCOPE_RETICLE_LAYER)
	_check("LAYER-2", "SCOPE_RETICLE_LAYER is the integer 8, not 4",
		ScopeReticle3D.SCOPE_RETICLE_LAYER == 8,
		"value=%d" % ScopeReticle3D.SCOPE_RETICLE_LAYER)
	# The gameplay camera must NOT be able to draw it, or the reticle floats in the
	# world in front of the player.
	_check("LAYER-3", "the gameplay camera (cull_mask=1) cannot draw the reticle",
		(ScopeReticle3D.SCOPE_RETICLE_LAYER & FPS_CULL_MASK) == 0,
		"%d & %d = %d" % [ScopeReticle3D.SCOPE_RETICLE_LAYER, FPS_CULL_MASK,
			ScopeReticle3D.SCOPE_RETICLE_LAYER & FPS_CULL_MASK])
	_check("LAYER-4", "the viewmodel camera (cull_mask=2) cannot draw the reticle",
		(ScopeReticle3D.SCOPE_RETICLE_LAYER & VIEWMODEL_CULL_MASK) == 0,
		"%d & %d = %d" % [ScopeReticle3D.SCOPE_RETICLE_LAYER, VIEWMODEL_CULL_MASK,
			ScopeReticle3D.SCOPE_RETICLE_LAYER & VIEWMODEL_CULL_MASK])
	# The scope camera, inheriting 1048575, must still see it, or the reticle is
	# invisible inside its own tube - the failure a "fix" that over-corrects causes.
	_check("LAYER-5", "the scope camera's inherited mask still includes the reticle",
		(scope_cam.cull_mask & ScopeReticle3D.SCOPE_RETICLE_LAYER) != 0,
		"scope mask=%d" % scope_cam.cull_mask)
	# And it must NOT collide with the layer the player's head is hidden on.
	_check("LAYER-6", "reticle does not collide with HIDDEN_FROM_FPS_LAYER's bit",
		(ScopeReticle3D.SCOPE_RETICLE_LAYER & PlayerBodyVisibility.HIDDEN_FROM_FPS_LAYER) == 0,
		"reticle=%d hidden_from_fps=%d" % [ScopeReticle3D.SCOPE_RETICLE_LAYER,
			PlayerBodyVisibility.HIDDEN_FROM_FPS_LAYER])

	# ---- 2. PARALLAX, THE PROPERTY A PAINTED OVERLAY CANNOT FAKE ---------
	var far_target := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3.ONE
	far_target.mesh = fm
	far_target.layers = ScopeReticle3D.SCOPE_RETICLE_LAYER
	host.add_child(far_target)
	far_target.global_position = scope_cam.global_position \
		+ (-scope_cam.global_basis.z) * FAR_DISTANCE

	for _i in 2:
		await process_frame
	await process_frame

	var ret_before := _project(scope_cam, reticle.global_position)
	var far_before := _project(scope_cam, far_target.global_position)

	# The swing: the weapon moves, the eye does not. This is the motion the card
	# wants the reticle to respond to.
	scope_cam.global_position += scope_cam.global_basis.x * SWING
	for _i in 2:
		await process_frame
	await process_frame

	var ret_after := _project(scope_cam, reticle.global_position)
	var far_after := _project(scope_cam, far_target.global_position)

	var ret_shift: float = absf(ret_after - ret_before)
	var far_shift: float = absf(far_after - far_before)
	print("reticle shift = %.3f px over %.3f m of weapon motion" % [ret_shift, SWING])
	print("far target shift = %.3f px at %.0f m" % [far_shift, FAR_DISTANCE])
	print("ratio = %.1fx  (a painted lens reticle scores 1.0)" %
		(ret_shift / maxf(far_shift, 0.0001)))

	_check("PARALLAX-1", "the reticle moves at all under weapon motion",
		ret_shift > 0.5, "shift=%.3f px" % ret_shift)
	# Distances are 100:1, so the expected sweep ratio is ~100. Require only 10 so
	# the gate survives someone re-tuning the reticle plane, while still failing
	# anything screen-space, which lands at 1.0.
	_check("PARALLAX-2", "the reticle sweeps far more than the distant target",
		ret_shift > far_shift * 10.0, "reticle=%.3f far=%.3f" % [ret_shift, far_shift])
	# The control: if the far target did not move either, the projection is frozen
	# and the ratio above would be meaningless.
	_check("PARALLAX-3", "the control target does move, so the ratio is meaningful",
		far_shift > 0.0001, "far_shift=%.6f px" % far_shift)

	# ---- RED ARM: the gate must REJECT the painted reticle it replaces ------
	# `u_reticle_texture` in scope_lenses.gdshader is drawn in screen space, so it
	# is rigidly tied to the lens: it behaves exactly like a marker PARENTED TO
	# THE CAMERA, which is the 3D stand-in for a screen-space overlay. If the
	# parallax checks above could be satisfied by that, they would not be testing
	# the thing the card asks for.
	var painted := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3.ONE
	painted.mesh = pm
	painted.layers = ScopeReticle3D.SCOPE_RETICLE_LAYER
	scope_cam.add_child(painted)
	painted.position = Vector3(0.0, 0.0, -NEAR_DISTANCE)
	for _i in 2:
		await process_frame
	# Move the weapon, then re-measure, so this is a real comparison.
	var painted_before := _project(scope_cam, painted.global_position)
	scope_cam.global_position += scope_cam.global_basis.x * SWING
	for _i in 2:
		await process_frame
	var painted_after := _project(scope_cam, painted.global_position)
	var painted_shift := absf(painted_after - painted_before)
	var painted_ratio := painted_shift / maxf(painted_shift, 0.0001)
	print("painted stand-in shift = %.6f px, self-ratio = %.1fx" % [painted_shift, painted_ratio])
	# RED-1: the painted stand-in does not parallax. This is the failure the gate
	# exists to catch, asserted so the gate cannot be quietly weakened to a
	# "does a reticle exist" check that the shipped shader would also pass.
	_check("RED-1", "a screen-space reticle does NOT satisfy the parallax gate",
		painted_shift < ret_shift * 0.1,
		"painted=%.4f px vs physical=%.3f px" % [painted_shift, ret_shift])

	_finish()


## Horizontal position in the scope viewport, in pixels. Returns NAN if the point
## is behind the camera, so a bogus projection cannot be silently averaged in.
func _project(cam: Camera3D, world_point: Vector3) -> float:
	if cam.is_position_behind(world_point):
		return NAN
	return cam.unproject_position(world_point).x


func _check(id: String, what: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  PASS %-11s %s" % [id, what])
		return
	failures += 1
	print("  FAIL %-11s %s   [%s]" % [id, what, detail])


func _finish() -> void:
	print("")
	print("checks=%d failed=%d" % [checks, failures])
	if failures > 0:
		print("RESULT: FAIL")
		call_deferred("_quit_now", 1)
		return
	print("RESULT: PASS")
	call_deferred("_quit_now", 0)


func _quit_now(code: int) -> void:
	quit(code)

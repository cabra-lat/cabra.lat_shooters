extends SceneTree
# res://addons/cabra.lat_shooters/test/validate_lean_corner.gd
#
# PERMANENT INVARIANT, promoted from a throwaway probe (range,
# task_1790431798459_060483) after it settled a question three lanes had been
# arguing about: is the held +40% prone lean reach a corner-clipping regression?
#
# WHAT IT CAUGHT: it is not. `_clamp_lean_peek` (controller.gd:1001-1018) casts a
# SINGLE ray along the body's lateral axis, so it is CORNER-BLIND: against an
# inside corner the ray passes the wall's near edge in Z and hits NOTHING, the
# clamp returns the full desired value, and the eye ends up closer to the corner
# edge than LEAN_PEEK_MARGIN. Measured here: the ray misses entirely, and the
# eye lands 0.2125 m from the edge at the OLD prone scale (0.25) and 0.1741 m at
# the HELD scale (0.35) - BOTH violate the 0.25 m margin. Holding 0.35 behind a
# corner gate would have been holding it for the wrong reason: the gate is red
# at 0.25 too.
#
# So this file pins CURRENT behaviour, and that is the point. It is written to
# go RED the day someone gives the clamp corner awareness (a second probe ray, a
# shape cast, a diagonal margin), at which point the correct question becomes
# "how much margin does a corner owe?" - a product call, not this file's.
#
# It measures GEOMETRY, never the peek value: "the eye keeps LEAN_PEEK_MARGIN of
# clearance" cannot be satisfied by a change that moves the number it is
# supposed to constrain. Asserting "the peek equals X" is the shape that
# cannot fail, and that is the failure class this project has been paying for.
#
# Run:
#   tools/godot-lock.sh --headless --path . \
#     --script res://addons/cabra.lat_shooters/test/validate_lean_corner.gd
# Exit code: 0 = the documented gap still holds, 1 = it changed.
#
# READ THIS BEFORE "FIXING" IT: because the gap is value-independent, this check
# goes red for ANY future lean change, including a correct one. That is intended.
# It is a pinned-regression check, NOT a gate on lean tuning, and the tempting
# "fix" when it goes red is to delete it — which is how the defect stops being
# recorded. If the clamp becomes corner-aware, update the expectations here in
# the same change that makes it corner-aware, and say which numbers moved.
#
# Geometry under test: an inside corner formed by a wall at x >= 0.30 and a wall
# at z >= 0.10, with the body at the origin leaning along +X.

const MARGIN := 0.25
const PEEK_FULL := 0.45
const OLD_PRONE := 0.1125   # 0.45 * 0.25 (pre-dedup stance scale)
const NEW_PRONE := 0.1575   # 0.45 * 0.35 (player-rig's held value)
const EYE_H := 0.9

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)

	# Inside corner: two wall slabs meeting, opening toward -X/-Z. The lateral
	# ray runs along +X at z = 0, so it passes the wall's near edge in Z and can
	# MISS it entirely — that is the corner-blindness under test.
	_wall(world, Vector3(0.30, 1.0, 1.0), Vector3(0.30, 1.0, 0.9))   # x >= 0.30
	_wall(world, Vector3(1.0, 1.0, 0.10), Vector3(0.9, 1.0, 0.10))   # z >= 0.10
	_wall(world, Vector3(4.0, 0.1, 4.0), Vector3(0.0, -0.05, 0.0))    # floor
	print("CHECK: corner edge at (0.30, *, 0.10); lateral ray along +X at z=0")

	var body := Node3D.new()
	world.add_child(body)
	body.global_position = Vector3.ZERO

	# Reproduce exactly what the shipped method reads: neutral eye = body origin
	# lifted by the spring arm height, lateral = body basis X.
	var neutral := body.global_transform * Vector3(0.0, EYE_H, 0.0)
	var lateral := body.global_transform.basis.x
	var q := PhysicsRayQueryParameters3D.create(neutral, neutral + lateral * (NEW_PRONE + MARGIN))
	var hit := world.get_world_3d().direct_space_state.intersect_ray(q)
	var ray_missed: bool = hit.is_empty()
	print("CHECK: lateral ray hit = %s"
		% ("yes at %.3f m" % neutral.distance_to(hit.position) if not ray_missed else "NOTHING (the clamp cannot see this corner)"))

	var failures := 0
	for pair in [["old prone scale 0.25", OLD_PRONE], ["held prone scale 0.35", NEW_PRONE]]:
		var desired: float = pair[1]
		var clamped: float = _clamp_like_shipped(world, body, desired)
		var eye: Vector3 = neutral + lateral * clamped
		# Distance from the eye to the corner EDGE (the vertical line x=0.30, z=0.10).
		var d_edge: float = Vector2(eye.x, eye.z).distance_to(Vector2(0.30, 0.10))
		var violates: bool = d_edge < MARGIN
		print("CHECK: %s desired=%.4f clamped=%.4f eye=(%.3f, %.3f) dist_to_edge=%.4f -> %s"
			% [pair[0], desired, clamped, eye.x, eye.z, d_edge,
			   "VIOLATES the %.2f m margin (documented)" % MARGIN if violates else "keeps the margin"])

		# The two facts this file pins. If either flips, corner awareness landed
		# and the margin question becomes a product call, not a code detail.
		if not ray_missed:
			failures += 1
			print("  FAIL  the lateral ray now SEES the corner: _clamp_lean_peek is no longer corner-blind")
		if not violates:
			failures += 1
			print("  FAIL  the %s peek now keeps %.2f m of corner clearance: the margin is honoured diagonally" % [pair[0], MARGIN])

	print("")
	print("=== validate_lean_corner summary ===")
	print("  documented gap still holds: %s" % ("yes" if failures == 0 else "NO"))
	print("  NOTE: pinned-regression check, not a lean-tuning gate. If it goes red")
	print("        on a correct lean change, update the expectations HERE in that")
	print("        same change - do not delete this file.")
	if failures > 0:
		print("RESULT: FAIL")
		call_deferred("_quit_now", 1)
		return
	print("RESULT: PASS")
	call_deferred("_quit_now", 0)

## Byte-for-byte the shipped algorithm from controller.gd:1001-1018.
func _clamp_like_shipped(world: Node3D, body: Node3D, desired: float) -> float:
	if absf(desired) < 0.001:
		return desired
	var sgn := signf(desired)
	var neutral: Vector3 = body.global_transform * Vector3(0.0, EYE_H, 0.0)
	var lateral: Vector3 = body.global_transform.basis.x * sgn
	var reach := absf(desired) + MARGIN
	var q := PhysicsRayQueryParameters3D.create(neutral, neutral + lateral * reach)
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return desired
	var allowed: float = neutral.distance_to(hit.position) - MARGIN
	return sgn * clampf(allowed, 0.0, absf(desired))

func _wall(world: Node3D, size: Vector3, centre: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = centre
	world.add_child(body)
	return body

func _quit_now(code: int) -> void:
	quit(code)

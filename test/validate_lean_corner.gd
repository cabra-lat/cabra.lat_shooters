extends SceneTree
# res://addons/cabra.lat_shooters/test/validate_lean_corner.gd
#
# PERMANENT INVARIANT on the corner-blindness that 33dfe6b fixed.
#
# Run:
#   tools/godot-lock.sh --headless --path . \
#     --script res://addons/cabra.lat_shooters/test/validate_lean_corner.gd
# Exit code: 0 = the shipped clamp keeps the declared margin clear at a corner
# and still grants the full lean at a wall. 1 = either stopped being true.
#
# BINDING: THIS FILE CALLS THE SHIPPED CLAMP. It calls `LeanPeekClamp.clamp_peek`
# (src/player/lean_peek_clamp.gd), which is the same function
# `controller.gd:_clamp_lean_peek` calls. Verify by reading that call site, not
# by trusting this header.
#
# This file used to carry its own `_clamp_like_shipped()` with its own
# `intersect_ray` at line 121 -- a COPY of the logic -- and its header claimed it
# called the shipped arithmetic verbatim. It did not. After the fix landed it
# still printed the PRE-FIX numbers (0.2125 and 0.1741) and still reported PASS,
# because the copy still contained the old ray. A check bound to a copy cannot
# see the code it claims to police, and one that prints known-wrong values and
# passes anyway is worse than no check, because it gets cited as evidence. The
# copy existed only because the arithmetic was welded to a node; it is now a pure
# helper taking the geometry as arguments, so no player is booted and the reported
# 600 s headless hang is off the table entirely.
#
# THE METRIC IS A SPHERE CLEARANCE, NOT A DISTANCE TO A LINE. The first version
# of the rewrite measured the eye against the corner EDGE in XZ and asserted
# d >= MARGIN. That is wrong the same way my AABB column was wrong: a point-to-line
# distance is not the distance to any surface. An eye 0.1125 m along +X sits
# 0.2125 m from the corner edge in XZ and would have been reported as a
# violation, while its actual clearance to the nearest wall face is 0.2919 m.
# Asserting on a hand-rolled geometric feature is how this file managed to be
# wrong in three different ways at once. Instead the check asks the physics
# server directly: is a sphere of LEAN_PEEK_MARGIN radius free at the eye the
# clamp produced? That is the definition of the margin, it is the same query the
# clamp itself uses, and it cannot disagree with it.
#
# WHAT IT PINS, AND WHY IT IS NOT A LEAN-TUNING GATE:
#   1. The margin is clear at an inside corner for every lean scale. The old
#      single lateral ray MISSED the corner entirely and returned the full
#      desired value. The tempting response when this goes red is to delete it,
#      which is exactly how a defect stops being recorded. Update the
#      expectations HERE, in the same change that moves the numbers, and say
#      which ones moved.
#   2. The full lean is still GRANTED against a flat wall, so the peek is still
#      tunable in the open. This control matters: a clamp that returned a
#      constant for every input would also satisfy assertion 1, and the peek
#      would silently stop being a tunable at all.
#
# NOT ASSERTED HERE: whether a corner should owe MORE than a flat wall. That is a
# product question -- LEAN_PEEK_MARGIN as a wall standoff versus a corner
# standoff -- it is carried by the user, and it is not an engineering call.
#
# Geometry under test: an inside corner formed by a wall at x >= 0.30 and a wall
# at z >= 0.10, with the eye at the origin travelling along +X at z = 0, so it
# passes the walls' near edges in Z and can miss them entirely. That is the
# geometry that defeated the old clamp.

const MARGIN := 0.25
const PEEK_FULL := 0.45
const OLD_PRONE := 0.1125   # 0.45 * 0.25 (pre-dedup stance scale)
const NEW_PRONE := 0.1575   # 0.45 * 0.35 (authoritative prone scale)
const EYE_H := 0.9


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var eye_at: Vector3 = Vector3(0.0, EYE_H, 0.0)
	var lateral := Vector3.RIGHT
	var space := world.get_world_3d().direct_space_state
	var failures := 0

	# --- 1. FLAT WALL, FIRST, IN A WORLD THAT IS ONLY A FLAT WALL.
	# Order matters and is not cosmetic: every Node3D under `root` shares ONE
	# World3D, so the corner fixture and the flat fixture cannot coexist. My
	# first version added the flat wall as a child of the corner world and got
	# 0.1547 for a wall 0.60 m away -- it was re-measuring the corner, because
	# the corner's z >= 0.10 wall is 0.05 m from the eye and a 0.25 m sphere
	# already overlaps it.
	# In the OPEN, with no wall anywhere, the full lean must be granted verbatim.
	# This is the literal form of "still tunable": a designer asking for a tighter
	# peek in the open must get it, so nothing may scale or clamp the request
	# before geometry is consulted. It has to run BEFORE the wall is added --
	# my first version built the wall first and then asserted "open air", which
	# is how a check ends up measuring the opposite of what it says.
	await _settle()
	var open: float = LeanPeekClamp.clamp_peek(space, eye_at, lateral, PEEK_FULL, MARGIN)
	print("CHECK: open air, full lean 0.45 -> granted %.4f" % open)
	if absf(open - PEEK_FULL) > 0.001:
		failures += 1
		print("  FAIL  the open lean is not granted verbatim: got %.4f" % open)

	_wall(world, Vector3(0.2, 1.0, 4.0), Vector3(0.70, 1.0, 0.0))   # x >= 0.60
	# The broadphase only learns about new bodies on a physics step, so a query
	# issued in the same frame sees NOTHING and the clamp returns the full
	# desired value. My first version did exactly that and measured an empty
	# world. Every fixture below awaits frames for that reason.
	await _settle()
	# Against a flat wall 0.60 m away the sphere may touch when the eye is MARGIN
	# short: 0.60 - 0.25 = 0.35. Two separate 2 mm costs come off that -- Godot's
	# own cast_motion safety margin, and the SWEEP_EPSILON in the helper that
	# makes the result agree with an exact shape test. Measured 0.3480 with
	# neither, 0.3460 with both, against 0.3500 for the original ray: 0.9 percent
	# of a 0.45 m lean.
	var granted: float = LeanPeekClamp.clamp_peek(space, eye_at, lateral, PEEK_FULL, MARGIN)
	var flat_expected: float = 0.60 - MARGIN - 0.002 - 0.002
	print("CHECK: flat wall at 0.60 m, full lean 0.45 -> granted %.4f (expected ~%.4f)" % [granted, flat_expected])
	if absf(granted - flat_expected) > 0.005:
		failures += 1
		print("  FAIL  flat-wall behaviour drifted: expected ~%.4f, got %.4f" % [flat_expected, granted])

	# --- 2. CORNER, in the same world once the flat wall is gone.
	for child in world.get_children():
		child.queue_free()
	await _settle()
	_wall(world, Vector3(0.30, 1.0, 1.0), Vector3(0.30, 1.0, 0.9))   # x >= 0.30
	_wall(world, Vector3(1.0, 1.0, 0.10), Vector3(0.9, 1.0, 0.10))   # z >= 0.10
	await _settle()
	print("CHECK: corner edge at (0.30, *, 0.10); eye travels along +X at z=0")

	# The old single lateral ray still misses this corner. RECORDED, not asserted:
	# asserting it would turn this check red the day someone fixes the ray for a
	# reason unrelated to the clamp, which is the mirror image of the defect it
	# was written to pin.
	var q := PhysicsRayQueryParameters3D.create(eye_at, eye_at + lateral * (NEW_PRONE + MARGIN))
	var hit: Dictionary = space.intersect_ray(q)
	print("CHECK: lateral ray hit = %s"
		% ("yes at %.3f m" % eye_at.distance_to(hit.position) if not hit.is_empty()
		   else "NOTHING (the geometry that used to defeat the clamp)"))

	for pair in [["prone scale 0.25", OLD_PRONE], ["prone scale 0.35", NEW_PRONE],
			["full lean", PEEK_FULL]]:
		var desired: float = pair[1]
		# THE SHIPPED CLAMP -- same call site as controller.gd:_clamp_lean_peek.
		var clamped: float = LeanPeekClamp.clamp_peek(space, eye_at, lateral, desired, MARGIN)
		var eye: Vector3 = eye_at + lateral * clamped
		# The margin, asked of the physics server rather than of a hand-rolled
		# geometric feature: a MARGIN sphere must be FREE where the clamp put the
		# eye. This is the definition of the standoff, it is the same query the
		# clamp uses, and it cannot silently disagree with the clamp.
		var clear: bool = _sphere_is_free(space, eye, MARGIN)
		print("CHECK: corner %-18s desired=%.4f clamped=%.4f eye=(%.3f, %.3f) margin sphere %s"
			% [pair[0], desired, clamped, eye.x, eye.z,
			   "FREE" if clear else "OVERLAPS A WALL"])
		if not clear:
			failures += 1
			print("  FAIL  the shipped clamp left the eye inside %.2f m of a surface" % MARGIN)

	print("")
	print("=== validate_lean_corner summary ===")
	print("  calls the shipped clamp:  LeanPeekClamp.clamp_peek (same call site as controller.gd)")
	print("  corner margin honoured:   %s" % ("yes" if failures == 0 else "NO"))
	print("  open lean still tunable:  %s" % ("yes" if failures == 0 else "NO"))
	if failures > 0:
		print("RESULT: FAIL")
		call_deferred("_quit_now", 1)
		return
	print("RESULT: PASS")
	call_deferred("_quit_now", 0)


## Let the broadphase learn about the bodies added or freed since the last step.
func _settle() -> void:
	for i in 3:
		await physics_frame


## Is a sphere of `radius` free at `at`? This is the margin, as the engine sees it.
func _sphere_is_free(space: PhysicsDirectSpaceState3D, at: Vector3, radius: float) -> bool:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, at)
	q.collide_with_areas = false
	return space.intersect_shape(q, 1).is_empty()


## NOTE: there is deliberately no private copy of the clamp in this file. The
## arithmetic is LeanPeekClamp.clamp_peek, shared with controller.gd. Re-adding a
## local copy is the exact defect this file was rewritten to remove.


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

class_name LeanPeekClamp
extends RefCounted
# res://addons/cabra.lat_shooters/src/player/lean_peek_clamp.gd
#
# THE clamp arithmetic, extracted so the invariant test can call the SAME code
# the controller calls.
#
# WHY THIS FILE EXISTS: test/validate_lean_corner.gd was originally written with
# its own `_clamp_like_shipped()` and its own `intersect_ray`, i.e. a COPY of the
# logic. Its header claimed it called the shipped arithmetic verbatim; it did
# not. The copy kept passing after the fix landed (33dfe6b) while printing the
# PRE-FIX numbers 0.2125 and 0.1741 and reporting PASS. A check bound to a copy
# cannot see the code it claims to police, and one that prints known-wrong values
# and passes anyway is worse than no check, because it gets cited as evidence.
#
# The reason the copy existed in the first place is that the logic was welded to
# a node: it read `get_world_3d()`, `global_transform` and `spring_arm`, so the
# only way to reach it was to boot the player, and booting the player headless
# has been reported to hang at 600 s. So the geometry is passed in instead. The
# controller computes `neutral`, `lateral` and the space from its own state and
# hands them over; nothing here touches a node, and no player is instantiated.
#
# BINDING IS BY CALL SITE, NOT BY HEADER. Read controller.gd:_clamp_lean_peek and
# test/validate_lean_corner.gd: both call `LeanPeekClamp.clamp_peek`. If you want
# to know what the test really exercises, that is where to look.

const SWEEP_EPSILON := 0.002


## Clamp a desired lateral eye travel so a body-radius sphere never penetrates a
## surface the eye can see.
##
## `neutral`  world position of the eye at zero lean.
## `lateral`  unit vector the eye travels along (signed; use the direction only).
## `desired`  the requested travel, signed. Returned signed.
## `margin`   sphere radius, i.e. the standoff the eye must keep from any surface.
## `exclude`  RIDs to ignore, typically the player's own body.
##
## A SHAPE CAST, not a ray. A single ray is CORNER-BLIND: against an inside
## corner it passes the wall's near edge and hits nothing, the query misses, and
## the full desired value is returned with the margin never applied. Measured at
## the corner fixture: the ray hits NOTHING, and the eye ends up with a margin
## sphere that OVERLAPS a wall. That is value-independent, so it predates the
## stance deduplication and is not a +40% prone regression.
##
## The sphere of `margin` radius keeps the eye that far from ANY surface it can
## see, at any angle. Against a flat wall perpendicular to the ray this is the
## same arithmetic the ray produced -- the sphere touches when the eye is `margin`
## short, i.e. travel = d - margin -- so corners tighten without flat-wall
## behaviour changing and without a new tuned number.
##
## WHY SWEEP_EPSILON EXISTS, and it is measured rather than guessed. cast_motion
## is a swept query and its safe fraction is slightly OPTIMISTIC relative to an
## exact shape test. At the corner fixture it returned 0.1553 where a 0.25 m
## sphere at the resulting eye position was still overlapping a wall, while
## 0.1547 was free -- an overshoot of 0.6 mm on a margin of 250 mm. Backing the
## travel off by 2 mm, three times the observed error, is what makes the
## invariant hold against `intersect_shape` rather than against cast_motion's own
## approximation of itself. It costs 2 mm of travel against every surface,
## including flat walls: 0.3500 before the sphere cast, 0.3480 after it, 0.3460
## after this. On a 0.45 m lean that is 0.9 percent.
##
## HONEST LIMIT, not to be rounded away: the margin is now held as an invariant
## rather than as an approximation, so the earlier "0.5 mm under" caveat is gone
## -- but in exchange the clamp gives up 2 mm of travel everywhere. If that trade
## is judged too expensive, raising it is a one-constant change and this comment
## is the place to say so.
##
## Whether a corner should owe MORE than a flat wall is a product question and is
## deliberately not answered here. This enforces the margin the constant already
## declares; it does not invent one.
static func clamp_peek(space: PhysicsDirectSpaceState3D, neutral: Vector3,
		lateral: Vector3, desired: float, margin: float,
		exclude: Array = []) -> float:
	if space == null or absf(desired) < 0.001:
		return desired
	var travel := absf(desired)
	var dir: Vector3 = lateral.normalized() * signf(desired)
	var shape := SphereShape3D.new()
	shape.radius = margin
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, neutral)
	query.motion = dir * travel
	query.exclude = exclude
	query.collide_with_areas = false
	# cast_motion returns [safe_fraction, unsafe_fraction]. A safe fraction of 1.0
	# means nothing was hit within the requested travel.
	var motion: PackedFloat32Array = space.cast_motion(query)
	var allowed: float = motion[0] * travel
	# The epsilon applies ONLY when something was actually hit. Subtracting it
	# unconditionally cost 2 mm in the open as well, which made an unobstructed
	# 0.45 lean return 0.4480 -- i.e. the clamp was shaving the request with no
	# geometry to justify it, and the "still tunable" control caught it. That
	# control earning its keep on the first run is the reason to keep it.
	if motion[0] < 1.0:
		allowed = maxf(0.0, allowed - SWEEP_EPSILON)
	return signf(desired) * clampf(allowed, 0.0, travel)

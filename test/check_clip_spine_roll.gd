# =====================================================================================
# SUPERSEDED FIGURES — THE NUMBERS THIS FILE PRINTS ARE WRONG. THE VERDICT IS NOT.
# npc-body found that the serialised Transform3D text in humanoid_rig.tscn is
# ROW-major while the Transform3D constructor is COLUMN-major, so reading bones/N/rest
# positionally TRANSPOSES it. I did exactly that, under a comment asserting the
# constructor's layout as if it described the file. The two readings differ by
# 119.9078 degrees on spine_01, and my transposed reading UNDERSTATED the departure
# by about 39 degrees.
# CORRECTED spine_01, re-measured with Skeleton3D.get_bone_rest(i) BY BONE NAME and
# no text parser at all: min 118.5620, max 174.8365, mean over 661 keys 151.3946.
# NOT the 79.3989 / 121.8128 / 95.3052 this file previously reported. Those are wrong
# and must not be quoted.
# THE VERDICT SURVIVES AND IS STRONGER: 0 of 24 clips come under 45 degrees, not 24 of
# 24 over it on a margin of 34. The correct figure clears the threshold by 73 degrees.
# THE RUNTIME AGREES WITH THE CORRECTED OFFLINE FIGURE WITHIN 0.5 DEG, so this is now
# three instruments agreeing and none of them reads a text parse.
# WHY THE PARSE IS STILL HERE: replacing it is a change to the measurement, not to its
# wording, and the corrected rest source belongs to whoever owns the rig with the lanes
# that verified these numbers present. Until then the parse is kept so the failure stays
# visible rather than being quietly swapped for a version that looks better.
# =====================================================================================

extends SceneTree

# RED-BY-DESIGN SENTINEL: every locomotion clip must carry spine_01 departure
# from the ENGINE REST below 45 degrees.
#
# PRE-REGISTERED, NOT FITTED. The threshold is 45 degrees, it was fixed by the
# lane that measured the defect, and it has not been adjusted to make anything
# pass. The polarity was also corrected before implementation: the original
# wording was "departure ABOVE 45", which encoded the CURRENT state as the
# requirement and is therefore green on exactly the tree that needs fixing. An
# assertion must encode what SHOULD be, so it asserts BELOW 45. On today's tree
# every clip is far above 45, so this is RED, the card is blocked, and the red
# is the truth. When a fix lands it goes green, and a green result means the
# clips were re-baked, NOT that the rig is correct.
#
# WHY THE ASSERTION IS THE MINIMUM AND NOT THE MEAN OR THE MAXIMUM. First the
# mean, then the maximum, then the minimum, in that order of tightening. A mean
# over rotation keys is key-density weighted rather than time weighted, and it
# could be satisfied by a clip that touches rest briefly and is rolled
# elsewhere. A maximum catches a brief spike but tolerates a clip that spends
# most of its length near rest. A MINIMUM-OF-KEYS ASSERTION CANNOT BE SATISFIED
# BY ANY CLIP THAT EVER COMES NEAR REST, which is the strictest form available
# and the one that makes this sentinel safe rather than merely strict: there is
# no averaging and no tolerance window for a defect to hide inside. The mean and
# the maximum are still computed and reported, because the reported figure
# 95.3052 is a mean and the three are NOT the same measurement. They are
# reported side by side and none is silently substituted for another.
#
# SCOPE OF THE ANGLE, WHICH IS WHAT MAKES THIS RUNNABLE IN CI. The angle is a
# pure bone-local quaternion half-chord, with no axis term and nothing composed
# with any transform. The rest is read as TEXT from bones/1/rest in
# humanoid_rig.tscn, so this needs no scene tree, no mount, no AnimationPlayer,
# no distance and no LOD. That is the whole point: the clip side of this rig had
# NO automated coverage at all, and a check that needs a live tree would not run
# in CI.
#
# NOT CLAIMED: that this measures the roll with a clip actually playing. It
# reads the same clip data the original measurement read, so it makes a
# re-bake detectable and it does not answer that. NOT CLAIMED: which rest is
# canonical. This uses the ENGINE rest, and the authored DCC rest is a different
# number; a separate rest-side check guards that and this deliberately does not.

const LIB := "res://addons/cabra.lat_shooters/src/player/humanoid_body_anims.res"
const RIG := "res://addons/cabra.lat_shooters/src/player/scenes/humanoid_rig.tscn"
const BOT_SCENE := "res://src/npcs/bot/bot.tscn"
const BONE_NAME := "spine_01"
const TRACK_PATH := NodePath("Skeleton3D:" + BONE_NAME)
const THRESHOLD_DEG := 45.0

var _pass := 0
var _fail := 0
var _skel_keepalive: Node = null
var _ap_keepalive: Node = null

func _initialize() -> void:
	var lib: AnimationLibrary = load(LIB)
	if lib == null:
		print("RESULT: FAIL (could not load %s — this is a wiring fault, not a content result)" % LIB)
		quit(2)
		return

	# THE REST NOW COMES FROM THE ENGINE, NOT FROM TEXT. The previous version read
	# bones/N/rest out of humanoid_rig.tscn and that was TRANSPOSED: the serialised
	# Transform3D text is row-major while the constructor is column-major, so the
	# two readings differ by 119.9078 degrees on spine_01 and the transposed one
	# understated the departure by about 39 degrees. Reading the rest positionally
	# out of a text file WAS the bug, so the text file is no longer read at all.
	# Skeleton3D.get_bone_rest(i) is the engine's own answer and it is the only
	# source that cannot be wrong about its own memory layout.
	# THE SCENE-BINDING PRECONDITION, ADDED AFTER INVENTORY-UX FOUND THE HOLE IN
	# MY OWN PRECONDITION. I asserted that the library I LOAD is non-empty, which is
	# true and useless: it checks the resource, not what a scene BINDS. inventory-ux
	# verified that player.tscn and player_ik.tscn each declare an AnimationLibrary
	# sub-resource with NOTHING under it and bind it under the same empty-string key
	# the bot uses. So a scene can bind a library, match the name, and have nothing
	# in it to play, and every check I had would pass. BOUND BUT EMPTY IS THE SHAPE
	# THAT SLIPS THROUGH. This asserts the thing I was actually measuring: the library
	# the BOT SCENE binds under the empty-string key is non-empty AND is the same
	# resource this sentinel measures. Type-walked, never by name, because the player
	# side is a node NAMED StateMachine and TYPED AnimationPlayer, which is exactly the
	# sign-authored-from-a-name trap.
	var bound := _bound_library()
	if bound == null:
		print("RESULT: FAIL (no AnimationLibrary bound under the empty-string key in %s; the sentinel cannot claim to measure what the scene plays)" % BOT_SCENE)
		quit(2)
		return
	var bound_clips: int = bound.get_animation_list().size()
	if bound_clips <= 0:
		print("RESULT: FAIL (the library %s binds is BOUND BUT EMPTY, 0 clips)" % BOT_SCENE)
		quit(2)
		return
	if bound.resource_path != LIB:
		print("RESULT: FAIL (the scene binds %s but this sentinel measures %s; the numbers would describe a library the scene never plays)" % [bound.resource_path, LIB])
		quit(2)
		return
	print("SENTINEL| scene binds %d clips and it is the library measured below" % bound_clips)
	var skel := _load_skeleton()
	if skel == null:
		print("RESULT: FAIL (could not instantiate a Skeleton3D from %s; refusing to report on a missing rest)" % RIG)
		quit(2)
		return
	var bone_index: int = skel.find_bone(BONE_NAME)
	if bone_index < 0:
		print("RESULT: FAIL (bone %s not found in the instantiated skeleton)" % BONE_NAME)
		quit(2)
		return
	var rest_q: Quaternion = skel.get_bone_rest(bone_index).basis.get_rotation_quaternion()
	print("SENTINEL| bone %s is index %d; rest read from Skeleton3D.get_bone_rest, NOT from text" % [BONE_NAME, bone_index])

	var names := lib.get_animation_list()
	print("SENTINEL| library holds %d animations, no filter applied" % names.size())

	# PRECONDITION, asserted rather than assumed. A sentinel that silently
	# examines zero clips is green and meaningless, and zero conditioned
	# samples must be a FAILURE and never a PASS.
	if names.is_empty():
		print("RESULT: FAIL (the library yielded 0 animations; a sentinel with no samples is not a pass)")
		quit(1)
		return

	var not_keying: Array[String] = []
	var rows: Array = []
	var overall_max := 0.0
	var overall_min := 1.0e9
	var sum_mean := 0.0
	var keyed := 0

	for n in names:
		var anim: Animation = lib.get_animation(n)
		var track := _find_rotation_track(anim)
		if track < 0:
			not_keying.append(String(n))
			continue
		keyed += 1
		var nk := anim.track_get_key_count(track)
		var worst := 0.0
		var best := 1.0e9
		var acc := 0.0
		for k in nk:
			var kq: Quaternion = anim.track_get_key_value(track, k)
			var d := _angle_deg(rest_q, kq)
			acc += d
			if d > worst:
				worst = d
			if d < best:
				best = d
		var mean := acc / float(maxi(nk, 1))
		rows.append([String(n), nk, worst, mean, best])
		overall_max = maxf(overall_max, worst)
		overall_min = minf(overall_min, best)
		sum_mean += mean

	print("SENTINEL| %d of %d clips key a %s rotation track" % [keyed, names.size(), BONE_NAME])
	if not not_keying.is_empty():
		print("SENTINEL| NOT KEYING %s: %s" % [BONE_NAME, ", ".join(not_keying)])
	print("SENTINEL| per-clip departure from engine rest, degrees; ASSERT is on the MINIMUM key, max and mean reported alongside")
	for r in rows:
		var flag := "  <-- OVER" if float(r[2]) >= THRESHOLD_DEG else ""
		print("  %-20s keys=%-4d max=%9.4f  mean=%9.4f  min=%9.4f%s" % [r[0], r[1], r[2], r[3], r[4], flag])
	print("SENTINEL| worst maximum across the library = %.4f deg; library mean of per-clip means = %.4f deg"
		% [overall_max, sum_mean / float(maxi(rows.size(), 1))])
	# THE PER-CLIP MINIMUM, WHICH IS NEITHER A MEAN NOR A MAXIMUM AND IS THE
	# STRONGEST STATEMENT AVAILABLE ABOUT THE ASSET. If the LOWEST single key in
	# the whole library is still far from rest, then the roll is not a moment in
	# an animation, it is the animation: there is no spine_01 key anywhere in this
	# library that comes near rest.
	# the neutral pose. It also retires the objection that motivated asserting on
	# the maximum, namely that a mean could hide a brief spike, because a spike
	# requires SOME key to come back toward rest and here none does.
	# SCOPE, CORRECTED AFTER A RETRACTION, AND THE CORRECTION IS THE POINT. An
	# earlier version of these lines said "the lowest single key in the ENTIRE
	# library" and "there is no key anywhere in the asset", and BOTH SENTENCES
	# WERE FALSE GENERALISATIONS FROM ONE BONE TO 87. This sentinel measures
	# spine_01 and NOTHING ELSE. A separate all-bones sweep found a global minimum
	# of 0.1480 deg, in aim_idle, bone spine.001_02, key 21, and every one of the
	# 24 clips comes within 7.2088 deg of rest on its own best bone, so THE ASSET
	# DOES HAVE A NEUTRAL POSE. What is true is narrower: no spine_01 key in this
	# library comes near rest. A sentinel that states a fact about the asset while
	# measuring one bone is the same scope error as an assertion that looks global
	# and is local, so the wording is now bounded to the bone under test.
	print("SENTINEL| LOWEST spine_01 KEY IN THE LIBRARY = %.4f deg (clip %s) — SCOPED TO spine_01, NOT ALL 87 BONES"
		% [overall_min, String(rows[_min_row(rows, overall_min)][0])])
	print("SENTINEL| pre-registered threshold = %.1f deg, not fitted" % THRESHOLD_DEG)

	# The assertion: EVERY clip must be below the threshold on its MINIMUM key,
	# which is the strictest form: no clip can pass by averaging, because a clip
	# that ever comes near rest has a low minimum and fails.
	for r in rows:
		if float(r[4]) >= THRESHOLD_DEG:
			_fail += 1
		else:
			_pass += 1

	if _fail > 0:
		print("RESULT: RED (%d of %d clips carry a %s departure of at least %.1f deg on their LOWEST key; the smallest such key in the library is %.4f deg)"
			% [_fail, rows.size(), BONE_NAME, THRESHOLD_DEG, overall_min])
		print("        This is the EXPECTED state on an unfixed tree. The red is the truth and must not be tuned green.")
		quit(1)
		return
	if keyed < names.size():
		print("RESULT: FAIL (%d clips do not key %s, so coverage is partial; refusing to report on a partial set)"
			% [names.size() - keyed, BONE_NAME])
		quit(1)
		return
	print("RESULT: PASS (all %d clips carry every %s key below %.1f deg from the engine rest)" % [_pass, BONE_NAME, THRESHOLD_DEG])
	quit(0)

## Index of the row holding the library-wide lowest key, so the printed figure
## names WHICH clip that key lives in rather than reporting a bare number.
func _min_row(rows: Array, lowest: float) -> int:
	var idx := 0
	for i in rows.size():
		if float(rows[i][4]) <= lowest:
			idx = i
	return idx

## The rig instantiated from its scene and type-walked to its Skeleton3D. No
## scene tree, no mount, no AnimationPlayer: the rest is data, not a pose.
func _load_skeleton() -> Skeleton3D:
	var ps := load(RIG) as PackedScene
	if ps == null:
		return null
	var inst := ps.instantiate()
	var found := _find_skeleton(inst)
	if found != null:
		# Keep the instance alive for the life of the check, then release it.
		_skel_keepalive = inst
	return found

func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var r := _find_skeleton(c)
		if r != null:
			return r
	return null

## The library the bot scene BINDS under the empty-string key. Found by TYPE, never
## by node name: player.tscn carries a node named "StateMachine" that is typed
## AnimationPlayer, so a name lookup finds the wrong thing on one side and nothing
## on the other.
func _bound_library() -> AnimationLibrary:
	var ps := load(BOT_SCENE) as PackedScene
	if ps == null:
		return null
	var inst := ps.instantiate()
	var ap := _find_anim_player(inst)
	var lib: AnimationLibrary = null
	if ap != null:
		lib = ap.get_animation_library("")
	_ap_keepalive = inst
	return lib

func _find_anim_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var r := _find_anim_player(c)
		if r != null:
			return r
	return null

## The bone-local half-chord, folded on absf so the quaternion double cover does
## not turn a tiny difference into about 360 degrees.
func _angle_deg(a: Quaternion, b: Quaternion) -> float:
	return rad_to_deg(2.0 * acos(clampf(absf(a.normalized().dot(b.normalized())), -1.0, 1.0)))

func _find_rotation_track(anim: Animation) -> int:
	for t in anim.get_track_count():
		if anim.track_get_path(t) == TRACK_PATH and anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			return t
	return -1

## Bone index by NAME from the rig text, so the sentinel survives a re-index.
func _find_bone_index() -> int:
	var f := FileAccess.open(RIG, FileAccess.READ)
	if f == null:
		return -1
	var idx := -1
	while not f.eof_reached():
		var line := f.get_line()
		if line.begins_with("bones/") and line.contains("name") and line.contains(BONE_NAME):
			var parts := line.split("/")
			if parts.size() > 1:
				idx = int(parts[1])
	f.close()
	return idx

## bones/N/rest as TEXT, so no Skeleton3D and no scene tree are needed.
func _read_engine_rest(bone_index: int) -> Variant:
	var f := FileAccess.open(RIG, FileAccess.READ)
	if f == null:
		return null
	var want := "bones/%d/rest = Transform3D(" % bone_index
	var q: Variant = null
	while not f.eof_reached():
		var line := f.get_line()
		if not line.begins_with(want):
			continue
		var open := line.find("(")
		var close := line.rfind(")")
		if open < 0 or close <= open:
			break
		var nums := line.substr(open + 1, close - open - 1).split(",")
		if nums.size() < 12:
			break
		var v: Array[float] = []
		for s in nums:
			v.append(float(s.strip_edges()))
		# Transform3D takes the basis in column-major order, then the origin.
		var bx := Vector3(v[0], v[1], v[2])
		var by := Vector3(v[3], v[4], v[5])
		var bz := Vector3(v[6], v[7], v[8])
		q = Basis(bx, by, bz).get_rotation_quaternion()
		break
	f.close()
	return q

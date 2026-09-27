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
# WHY THE MEASUREMENT IS THE MAXIMUM AND NOT THE MEAN. A mean over rotation
# keys is key-density weighted, not time weighted, so an exporter that writes
# dense keys in a stiff section weights a clip differently from one sampled
# uniformly. Worse, a clip that sits near rest for most of its length and spikes
# briefly would report a LOW mean and PASS a below-45 sentinel while carrying
# the exact defect being hunted. The maximum is the strictly better statistic
# for a defect detector. The mean is still computed and reported, because the
# headline figure 95.3052 is a mean and the two are NOT the same measurement.
# They are reported side by side and neither is silently substituted.
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
const BONE_NAME := "spine_01"
const TRACK_PATH := NodePath("Skeleton3D:" + BONE_NAME)
const THRESHOLD_DEG := 45.0

var _pass := 0
var _fail := 0

func _initialize() -> void:
	var lib: AnimationLibrary = load(LIB)
	if lib == null:
		print("RESULT: FAIL (could not load %s — this is a wiring fault, not a content result)" % LIB)
		quit(2)
		return

	# Locate the bone index by NAME, not by a hardcoded 1. The index is 1 in this
	# tree, but an index that is only correct by coincidence is a latent failure.
	var bone_index := _find_bone_index()
	if bone_index < 0:
		print("RESULT: FAIL (bone %s not found in %s; the sentinel cannot run and must not report PASS)" % [BONE_NAME, RIG])
		quit(2)
		return

	var rest_q := _read_engine_rest(bone_index)
	if rest_q == null:
		print("RESULT: FAIL (could not read the engine rest for bone %d; refusing to report on a missing value)" % bone_index)
		quit(2)
		return
	print("SENTINEL| bone %s is index %d; engine rest read as text from bones/%d/rest" % [BONE_NAME, bone_index, bone_index])

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
		var acc := 0.0
		for k in nk:
			var kq: Quaternion = anim.track_get_key_value(track, k)
			var d := _angle_deg(rest_q, kq)
			acc += d
			if d > worst:
				worst = d
		var mean := acc / float(maxi(nk, 1))
		rows.append([String(n), nk, worst, mean])
		overall_max = maxf(overall_max, worst)
		sum_mean += mean

	print("SENTINEL| %d of %d clips key a %s rotation track" % [keyed, names.size(), BONE_NAME])
	if not not_keying.is_empty():
		print("SENTINEL| NOT KEYING %s: %s" % [BONE_NAME, ", ".join(not_keying)])
	print("SENTINEL| per-clip departure from engine rest, degrees; ASSERT is on the MAXIMUM")
	for r in rows:
		var flag := "  <-- OVER" if float(r[2]) >= THRESHOLD_DEG else ""
		print("  %-20s keys=%-4d max=%9.4f  mean=%9.4f%s" % [r[0], r[1], r[2], r[3], flag])
	print("SENTINEL| worst maximum across the library = %.4f deg; library mean of per-clip means = %.4f deg"
		% [overall_max, sum_mean / float(maxi(rows.size(), 1))])
	print("SENTINEL| pre-registered threshold = %.1f deg, not fitted" % THRESHOLD_DEG)

	# The assertion: EVERY clip must be below the threshold on its MAXIMUM.
	for r in rows:
		if float(r[2]) >= THRESHOLD_DEG:
			_fail += 1
		else:
			_pass += 1

	if _fail > 0:
		print("RESULT: RED (%d of %d clips carry a %s departure of at least %.1f deg on the maximum; the worst is %.4f deg)"
			% [_fail, rows.size(), BONE_NAME, THRESHOLD_DEG, overall_max])
		print("        This is the EXPECTED state on an unfixed tree. The red is the truth and must not be tuned green.")
		quit(1)
		return
	if keyed < names.size():
		print("RESULT: FAIL (%d clips do not key %s, so coverage is partial; refusing to report on a partial set)"
			% [names.size() - keyed, BONE_NAME])
		quit(1)
		return
	print("RESULT: PASS (all %d clips carry %s departure below %.1f deg on the maximum)" % [_pass, BONE_NAME, THRESHOLD_DEG])
	quit(0)

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

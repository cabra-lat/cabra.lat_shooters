# res://addons/cabra.lat_shooters/test/report_locomotion_posture.gd
#
# NON-GATING REPORT. Prints a per-frame posture table for every rig clip and
# asserts nothing, deliberately. It exists so that a MEAN can never again be
# published in place of a SHAPE: npc-body's 24-clip table reported `run` and
# `rifle_run` as standing at +0.52, and the per-frame minimum is +0.006, so a
# running bot goes to within 6 mm of horizontal and returns. The mean hid it
# because the other half of the cycle is high. Any posture claim from here is a
# per-frame MINIMUM, never a mean.
#
# WHY PER-FRAME MINIMUM, in one paragraph. head_over_feet is a raw world-Y
# difference between the spine end bone and a foot bone, so it needs no angle,
# no mount interpretation, and no reference that can change sign. It is still a
# single scalar per frame, and a scalar sampled once per clip is a mean, and a
# mean over a cycle with a dip is a number that describes no frame anybody will
# ever see. The minimum is the frame the player will see.
#
# WORLD SPACE, AND THIS IS THE PART THAT IS EASY TO GET BACKWARDS. In Godot 4
# get_bone_global_pose() is NODE (Skeleton3D) space, NOT world space, and the
# composition below by global_transform is required. Settled by npc-body's
# root-bone test: a root bone is authored at the skeleton origin, so node space
# must read (0,0,0) and world space must read the node's world position. This
# exact confusion cost three lanes an evening, and the symptom is specific and
# worth recognising: the node-space form reads 1.30-1.73 for EVERY clip in this
# family, including clips whose true world reading is 0.049. A body lying on its
# side looks perfectly upright until you compose. A posture harness that reads
# the wrong frame reports a healthy rig for a broken one, and it is not a noisy
# wrong answer, it is a confident one.
#
# THE NULL GUARD IS THE MOST IMPORTANT LINE IN THIS FILE. A clip that does not
# actually drive is NOT REPORTED. A rig that has not animated returns its
# current pose for every sample, which is a rest pose wearing a clip's name, and
# that is precisely how several plausible-looking but meaningless numbers entered
# this project's history. An undriven clip is recorded as UNDRIVEN and excluded;
# it is never printed as a number. If a future reader sees fewer clips than they
# expect, that is the guard working and it is not a gap to be filled in by hand.
#
# WHAT THE INSTRUMENT CAN AND CANNOT SUPPORT, which is less than an earlier
# version of this file claimed. npc-body's basis sweep varied the rig node's
# basis scale over 0.980-1.030 for ONE clip and ONE pose and got head_over_feet
# from 0.1369 to 0.3792: a 0.242 m span from a basis difference alone. The
# control disagreement between the bare scene and the arena is 0.236 m, i.e.
# INSIDE that span, so the two contexts' control rows do not need a second
# mechanism to explain each other. Consequently the three-way classification
# below is recorded as UNCLASSIFIED for the constant-offset rows, not as
# "basis error => re-export". Those rows sit inside the instrument's own noise
# and the instrument does not support a recommendation for them.
# The rows that SURVIVE are the transient ones, because they go BELOW ZERO and
# nothing in the 0.137-0.379 band reaches there. Below-zero is outside the
# demonstrated range by more than the range's own span, which is the only kind
# of margin argument available here.
# The uncomfortable shape, kept in writing because it should reduce confidence in
# the table and increase it in the guard: the rows that looked CLEANEST, constant
# with tiny spans and an obvious basis story, are the rows this instrument
# cannot support, and the rows that looked noisiest are the ones it can.
#
# THE THREE INSTRUMENT FIXES npc-body asked for, all applied:
#   1. SAMPLE BY CLIP TIME, not by frame count, so animation phase is a
#      controlled variable rather than a free one. Re-sampling the same clip
#      without re-playing it drifted 0.0165 m, because the phase was uncontrolled.
#   2. PRINT THE RIG NODE'S BASIS beside every reading. World head_over_feet is a
#      property of a pose COMPOSED WITH a basis that is demonstrably not stable,
#      so the basis is part of the measurement and not part of the context.
#   3. MIN over a fixed number of equal-time samples.
# Any future sweep summary must be MIN-TO-MAX SPAN. npc-body's own verdict line
# compared the first and last step of a NON-MONOTONIC curve and threw away the
# range, and the verdict flipped. A verdict that depends on which two points of
# a curve you compare is not a verdict.
#
# Metric: head_over_feet = world Y of spine.006_end_067 minus world Y of
# foot.R_064. STANDING_MIN is the bar a clip must clear on its WORST frame.
# HOW MUCH ANY NUMBER IN EITHER HARNESS IS WORTH, written by npc-body at
# player-rig's request, because the honest version is easier to say about
# someone else's instrument than your own.
#
# THIS FILE IS A NULL-DETECTOR WITH OCCASIONAL READINGS ATTACHED. IT IS NOT A
# MEASUREMENT. Which clips drive is NOT stable across runs: 6 of 14 on one run
# and 6 of 14 on the next, with DIFFERENT membership. run_backwards drove and
# read -0.156 on one run and was UNDRIVEN and refused on the next; strafe_1 went
# the other way. So the guard is doing far more work than the table is, and the
# consequences are worth stating as rules rather than as caveats:
#   - a clip APPEARING in this table is not reproducible evidence on its own;
#   - a clip MISSING from it is not evidence of anything at all.
#
# AND THE ARENA NUMBERS ARE WORTH EXACTLY AS MUCH, which is the sentence I was
# asked to write and the reason it is not a criticism of this file. npc-body's
# production-route figures are single uncontrolled observations in a frame whose
# rig-node basis has now taken three values across three runs of the same scene
# with no edits -- 1.018, 0.993, 0.9606 -- and at 0.9606 the run_backwards
# reading moved from MIN -0.153 to MIN +0.078, which ERASED the transient dips
# that classification rested on. Two harnesses, two contexts, neither of them
# classification-grade, and the honest summary is that neither set of numbers
# can currently support a re-export call.
#
# WHAT SURVIVES IS WHAT DOES NOT DEPEND ON A POSTURE FIGURE, and it is worth more
# than every table above it: get_bone_global_pose() is NODE space and the wrong
# frame reads healthy; the spine bone pair inverts during locomotion so no
# spine-vs-UP figure is usable; the rest pose measures 0.42 m of head-over-feet
# with the axis 15 degrees off horizontal; and facing is ruled out, head_over_feet
# being exactly invariant under +/-90 and 180 degrees of yaw.
#
# THE PREREQUISITE IS BIGGER THAN THE CLASSIFICATION: a harness that drives a
# KNOWN SET of clips DETERMINISTICALLY, and a basis that does not move between
# runs. Until both exist, a clip row is a reading and not a result.
#
extends SceneTree

const BOT_SCENE := "res://src/npcs/bot/bot.tscn"
const HEAD_BONE := "spine.006_end_067"
const FOOT_BONE := "foot.R_064"
const SAMPLES := 40
const STEP := 0.1
const STANDING_MIN := 0.30
## A separate band, NOT a second threshold inside the failing range. npc-body
## measured strafe_left and strafe_right at 0.253-0.325, upright to within a
## centimetre, and had been counting them as defects because the 0.30 line was
## drawn before the data had a shape. Reporting them as NOT STANDING would spend
## a re-export on two clips that are not broken, so a clip that clears this but
## not STANDING_MIN is reported as MARGINAL and is explicitly not a failure.
const MARGINAL_MIN := 0.25
const MIN_TRAVEL := 0.05
## Classified by npc-body's span discriminator run, log /tmp/shooter/locospan.log.
## Recorded so the two categories are not re-derived from a mean by a later
## reader, and so a re-export is aimed at the right clips.
const CLASSIFIED := {
	"reset": "UNCLASSIFIED/inside-noise", "strafe_1": "constant-offset/UNSUPPORTED",
	"strafe_2": "UNCLASSIFIED/inside-noise", "rifle_jump": "UNCLASSIFIED/inside-noise",
	"walk": "transient/pose-below-zero", "walking": "transient/pose-below-zero",
	"walking_backwards": "transient/pose-below-zero", "run_backwards": "transient/pose-below-zero",
	"run": "transient/pose-below-zero", "rifle_run": "transient/pose-below-zero",
	"strafe_left": "marginal/not-defective", "strafe_right": "marginal/not-defective",
	"reload": "upright/control-DISPUTED", "reloading": "upright/control-DISPUTED",
}

var _sk: Skeleton3D
var _ap: AnimationPlayer


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var world := Node3D.new()
	root.add_child(world)
	var fl := StaticBody3D.new()
	var fls := CollisionShape3D.new()
	var flb := BoxShape3D.new()
	flb.size = Vector3(200.0, 1.0, 200.0)
	fls.shape = flb
	fl.add_child(fls)
	fl.position = Vector3(0.0, -0.5, 0.0)
	world.add_child(fl)

	var host := CharacterBody3D.new()
	world.add_child(host)
	var bot: Node = (load(BOT_SCENE) as PackedScene).instantiate()
	host.add_child(bot)
	for i in 8:
		await process_frame
	_sk = bot.get_node("Skeleton3D")
	_ap = _anim(_sk)
	if _ap == null:
		print("P|FAIL no AnimationPlayer on the rig")
		quit(1)
		return
	var hi := _sk.find_bone(HEAD_BONE)
	var fi := _sk.find_bone(FOOT_BONE)
	if hi < 0 or fi < 0:
		print("P|FAIL bones missing: %s=%d %s=%d" % [HEAD_BONE, hi, FOOT_BONE, fi])
		quit(1)
		return

	print("P|clip              MIN     MAX    SPAN  | basis_scale  y_off | verdict  | classified")
	var undriven: Array = []
	for clip in _clips():
		var r := await _sample(clip, hi, fi)
		if r == null:
			undriven.append(clip)
			continue
		print("P|%-16s %+.3f  %+.3f  %.3f  |    %6.3f  %6.3f | %-8s | %s" % [
			clip, r["min"], r["max"], r["span"],
			_sk.transform.basis.get_scale().x, _sk.global_position.y,
			_band(r["min"]), CLASSIFIED.get(clip, "-")])
	if undriven.size() > 0:
		print("P|")
		print("P|UNDRIVEN, EXCLUDED, NOT REPORTED AS NUMBERS (%d): %s" % [
			undriven.size(), str(undriven)])
		print("P|  These clips did not animate. The rig returned a current pose for every")
		print("P|  sample, which is a rest pose wearing a clip's name. Reporting them would")
		print("P|  manufacture confident nonsense, so the guard refuses. Do not fill these in")
		print("P|  by hand from another context.")
	print("P|")
	print("P|NON-GATING. Asserts nothing. Read the MIN column, not a mean: a mean over a")
	print("P|cycle with a dip describes no frame anybody will ever see.")
	quit(0)


## Three bands, and the middle one is deliberately not a failure. A mean over a
## cycle with a dip describes no frame anybody will ever see, and run reporting
## +0.52 as standing when its per-frame minimum is +0.006 is the concrete case:
## a running bot goes to within 6 mm of horizontal and comes back.
func _band(v: float) -> String:
	if v > STANDING_MIN:
		return "STANDING"
	if v >= MARGINAL_MIN:
		return "MARGINAL"
	return "NOT-STD"


func _clips() -> Array:
	var out: Array = []
	for lib in _ap.get_animation_library_list():
		var l := _ap.get_animation_library(lib)
		for k in l.get_animation_list():
			var s := str(k)
			if CLASSIFIED.has(s) and not out.has(s):
				out.append(s)
	out.sort()
	return out


## Returns null when the clip did not drive. Never returns a rest pose as data.
## Samples by CLIP TIME, not by frame count, so phase is controlled.
func _sample(clip: String, hi: int, fi: int) -> Variant:
	if not _sk.play(clip):
		return null
	_ap.speed_scale = 1.0
	_ap.advance(0.0)
	for i in 3:
		await process_frame
	var travel: float = await _travel(hi, 8)
	if travel < MIN_TRAVEL:
		return null
	# Equal-time samples across the clip's real length.
	var length: float = 0.0
	for lib in _ap.get_animation_library_list():
		var a := _ap.get_animation_library(lib).get_animation(clip)
		if a != null and a.length > 0.0:
			length = a.length
			break
	var step: float = (length if length > 0.0 else 1.0) / float(SAMPLES)
	var lo := INF
	var his := -INF
	for s in SAMPLES:
		_ap.advance(step)
		await process_frame
		# WORLD space. The multiply is required; see the header.
		var hp: Vector3 = (_sk.global_transform * _sk.get_bone_global_pose(hi)).origin
		var fp: Vector3 = (_sk.global_transform * _sk.get_bone_global_pose(fi)).origin
		var v: float = hp.y - fp.y
		lo = minf(lo, v)
		his = maxf(his, v)
	return {"min": lo, "max": his, "span": his - lo}


func _travel(hi: int, frames: int) -> float:
	var a: Vector3 = _sk.get_bone_global_pose(hi).origin
	for i in frames:
		_ap.advance(STEP)
		await process_frame
	return a.distance_to(_sk.get_bone_global_pose(hi).origin)


func _anim(sk: Skeleton3D) -> AnimationPlayer:
	var st: Array[Node] = [sk]
	while not st.is_empty():
		var n: Node = st.pop_back()
		if n is AnimationPlayer:
			return n
		for c in n.get_children():
			st.append(c)
	return null

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

## The bones a clip DRIVES, from its own rotation track paths.
func _driven_bones(clip: String) -> Dictionary:
	var out := {}
	for lib in _ap.get_animation_library_list():
		var a := _ap.get_animation_library(lib).get_animation(clip)
		if a == null:
			continue
		for t in a.get_track_count():
			if a.track_get_type(t) != Animation.TYPE_ROTATION_3D:
				continue
			var p := String(a.track_get_path(t))
			if p.begins_with("Skeleton3D:"):
				out[p.substr("Skeleton3D:".length())] = true
	return out

## Is this a bone the quantity is allowed to be anchored to? The axis of interest
## is the body axis, so the candidate set is the spine chain and the legs and feet.
## Fingers and thumb bones are excluded on purpose: the previous attempt picked
## anchors by highest and lowest driven bone in the rest pose and got FINGERS,
## which turned the quantity into a finger-to-finger distance while the column
## still claimed posture. A candidate set has to be chosen by MEANING, not by
## whichever extreme happens to be available.
func _is_axis_bone(n: String) -> bool:
	return n.begins_with("spine") or n.begins_with("thigh") or n.begins_with("shin") \
		or n.begins_with("foot") or n.begins_with("toe")

## Upper and lower anchor for THIS clip, from the axis bones it drives: the driven
## axis bone highest in the rest pose, and the lowest. Returns [] if the clip
## drives no usable axis pair, in which case the clip gets NO number rather than a
## number anchored somewhere that does not mean what the column says.
## The measurement pair, fixed by the coordinator and NOT chosen by this harness.
## spine.006_end_067 -- which this file used to anchor on -- is a Blender TIP joint
## driven by NO clip in the library, so it inherits its parent chain instead of
## being keyed. Every head-over-foot reading taken on that pair, including the
## 88.24 that reached the user, was chain-damped and biased low by construction.
## spine.006_07 and foot.R_064 are both rotation-driven, so the vector joins two
## bones that the clip actually moves.
## TOMBSTONE. spine.006_end_067 is the head tip and is keyed by NO clip in
## humanoid_body_anims.res; it inherits its parent chain instead. Any head-anchored
## quantity therefore pairs a moving foot with a bone that never participates, which
## is how the 88.24 degree reading was manufactured. Kept as a named dead constant
## so that reintroducing it is a visible, greppable act rather than a quiet default.
const HEAD_BONE := "spine.006_end_067"  ## DO NOT ANCHOR A MEASUREMENT HERE
const FOOT_BONE := "foot.R_064"
const HI_BONE := "spine.006_07"
const LO_BONE := "foot.R_064"

## THE QUANTITY IS THE SPINE-TO-FOOT ANGLE, NOT A BODY AXIS.
##
## OBTAINABILITY, RECORDED SO NOBODY RE-ATTEMPTS IT. A body-axis measurement needs a
## bone at the top of the body that the clip actually keys. The head tip,
## spine.006_end_067, is driven by NO clip in humanoid_body_anims.res -- it is a
## Blender tip joint that inherits its parent chain instead of being keyed. So any
## head-anchored quantity necessarily pairs a MOVING foot against a bone that NEVER
## PARTICIPATES, and that is not a slightly wrong number, it is a number about
## something else. It is what produced the 88.24 degree reading that reached the
## user, what produced this file's own original head-over-foot column, and what
## would produce a fresh wrong number under any new name. THE BODY AXIS IS
## UNOBTAINABLE FROM THIS ASSET. It is a property of the clip set, not a defect in
## the sampler, and the correct response is to record that rather than to go hunting
## for a substitute head bone and publish whatever it finds under the old header.
##
## The anchors below are both rotation-driven, which is the requirement that
## matters: the vector joins two bones the clip moves. The pair is printed on every
## row, and a row whose anchors cannot be checked is a row whose anchors cannot be
## trusted.

## The pair for this clip, or [] if the clip does not drive both ends. A refusal
## is the correct outcome for a clip that does not: better no number than a number
## anchored to a bone that is not participating.
func _anchors(clip: String) -> Array:
	var driven := _driven_bones(clip)
	if not (driven.has(HI_BONE) and driven.has(LO_BONE)):
		return []
	var hi: int = _sk.find_bone(HI_BONE)
	var lo: int = _sk.find_bone(LO_BONE)
	if hi < 0 or lo < 0:
		return []
	return [hi, lo, HI_BONE, LO_BONE]
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
var _root: Node3D
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
	# Keep the subject INSIDE anim_lod_distance (45 m) of an active camera so
	# production humanoid_rig _apply_anim_speed sets speed_scale = 1.0 by itself.
	# The previous fixture left the bot far away, production correctly froze it,
	# and the harness was reading frame 0.0 -- and wrote speed_scale itself to try
	# to fix it, into a value the single writer overwrites every frame.
	if world.get_node_or_null("ProbeCam") == null:
		var cam := Camera3D.new()
		cam.name = "ProbeCam"
		world.add_child(cam)
		cam.current = true
		cam.position = Vector3(0.0, 1.6, 0.0)
	host.position = Vector3(0.0, 0.0, -20.0)
	for i in 8:
		await process_frame
	_sk = bot.get_node("Skeleton3D")
	_root = bot as Node3D
	_ap = _anim(_sk)
	if _ap == null:
		print("P|FAIL no AnimationPlayer on the rig")
		quit(1)
		return

	# PIN THE SCALE. The NpcBot root carries an authored per-bot uniform scale,
	# bot.gd _apply_visual_variation: scale = Vector3.ONE * randf_range(0.94,
	# 1.06), under a comment reading "Per-bot identity: body scale". It is not a
	# defect and there is no writer to find, but it IS a per-run redraw, and a
	# world-space posture reading composes with it, so a MIN or a SPAN taken
	# across clips is a reading of differently-sized bodies. The remedy is not to
	# tolerate that noise but to remove its source: a randomised input can be
	# PINNED. Forcing the scale to 1.0 makes that whole class of contamination
	# disappear rather than setting a tolerance wide enough to survive it.
	#
	# Pinning is a CLAIM about the measurement, so it gets the same treatment as
	# every other intervention on this board: prove it applied, and prove the
	# quantity is sensitive to it. The scale is pinned, READ BACK, and the run is
	# VOID if the readback is not exactly 1.0 -- a pin that silently fails would
	# leave a contaminated table wearing a clean label.
	var authored_scale: float = _root.global_transform.basis.get_scale().x
	_root.scale = Vector3.ONE
	for i in 4:
		await process_frame
	var pinned_scale: float = _sk.global_transform.basis.get_scale().x
	print("P|SCALE authored=%.6f  pinned=%.6f  %s" % [
		authored_scale, pinned_scale,
		"PIN APPLIED" if is_equal_approx(pinned_scale, 1.0) else "PIN FAILED -- RUN VOID"])
	if not is_equal_approx(pinned_scale, 1.0):
		quit(1)
		return

	var hi := _sk.find_bone(HEAD_BONE)
	var fi := _sk.find_bone(FOOT_BONE)
	if hi < 0 or fi < 0:
		print("P|FAIL bones missing: %s=%d %s=%d" % [HEAD_BONE, hi, FOOT_BONE, fi])
		quit(1)
		return

	# CONTROLS, in that order, because a control has to be shown able to fail
	# before its result means anything. RED: restore the authored scale, so the
	# quantity under test is shown SENSITIVE to the pin rather than immune to it.
	# If the two rows agreed, the pin would be moving nothing and the pinned table
	# below would not be the clean measurement it claims to be.
	# A hardcoded control clip is a control that can be silently VOID, and this
	# one already was: it was pinned to "walk", which this harness does not
	# drive, so both control rows came back UNDRIVEN and the sensitivity check
	# produced no data at all while still looking like it had run. The clip is
	# therefore DISCOVERED at runtime -- the first one that actually drives in
	# THIS process -- and if none does, the controls are reported VOID loudly
	# instead of passing quietly.
	var ctl_clip: String = await _pick_drivable(hi, fi)
	if ctl_clip == "":
		print("C|ALL VOID -- no clip drives in this process, so the scale pin has no control and the table below is NOT the clean measurement it claims to be")
	else:
		print("C|control clip (discovered, not assumed): %s" % ctl_clip)
		_ctl(ctl_clip, hi, fi, authored_scale)
		_ctl(ctl_clip, hi, fi, 1.0)

	print("P|SPINE_TO_FOOT_ANGLE -- NOT a body axis. The head tip spine.006_end_067 is keyed by\nP|NO clip, so a head-anchored quantity would pair a moving foot with a bone that\nP|never participates. The body axis is UNOBTAINABLE from this clip set.\nP|\nP|clip  KIND  MIN     MAX    SPAN  | rig node path                 SCALE  MOUNT_DEG | verdict  | classified")
	var undriven: Array = []
	for clip in _clips():
		var r := await _sample(clip, hi, fi)
		if r == null:
			undriven.append(clip)
			continue
		# FOUR fields, because a gate that cannot say which node it read cannot
		# notice it read the wrong one. The coordinator extended this from three
		# to four: PATH, QUANTITY, EXPECTED, OBSERVED. What that extension is FOR
		# is the 120-versus-90 error, which was invisible precisely because nobody
		# recorded which number was an instantiation and which was a file.
		#
		# MOUNT_DEG is a control in a DIFFERENT UNIT from the scale beside it, and
		# that is the reason it is here rather than the scale. A basis scale is a
		# LENGTH RATIO, so rotation does not change it: a scale gate passes a rig
		# rolled ninety degrees at any tolerance, which is why INV-38 went green
		# against a rig whose node was rolled -90. The angle between the node's
		# basis applied to UP and world UP is rotation sensitive and scale
		# invariant, so the two cannot both be fooled by the same failure.
		var gb: Basis = _sk.global_transform.basis
		var up: Vector3 = (gb * Vector3.UP).normalized()
		var mount_deg: float = rad_to_deg(acos(clampf(up.dot(Vector3.UP), -1.0, 1.0)))
		print("P|%-16s %-5s %+.3f  %+.3f  %.3f  | %-32s %.4f  %7.2f | %-8s | drove %d/%d %-14s | %s..%s | %s" % [
			clip, "POSE", r["min"], r["max"], r["span"],
			str(_sk.get_path()), gb.get_scale().x, mount_deg,
			_band(r["min"]), int(r["driven"]), int(r["of"]), r["as"],
			str(r["hi"]).substr(0, 14), str(r["fi"]).substr(0, 10),
			CLASSIFIED.get(clip, "-")])
		# REST on the same pair, same node, same frame, so the row above has a
		# baseline it can be read against. REST and POSE are never mixed and never
		# compared without both being named; that confusion is what put a 0.422 m
		# POSE reading and a 1.660 m REST reading on this board as if they were
		# rival measurements of one quantity.
		print("P|%-16s %-5s %+.3f  %+.3f  %.3f  | %s" % [
			clip, "REST", r["rest"], r["rest"], 0.0,
			"anchors %s..%s from the SKELETON REST, not the clip" % [
				str(r["hi"]).substr(0, 14), str(r["fi"]).substr(0, 10)]])
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
# The first clip that actually animates in this process, found by asking rather
# than assumed. The drivable set is NOT stable across runs -- eight clips were
# undriven in one run and a different eight in the next -- so any control naming
# a clip by hand is a control that will be void on some run without saying so.
func _pick_drivable(hi: int, fi: int) -> String:
	for clip in _clips():
		if await _sample(clip, hi, fi) != null:
			return clip
	return ""


# One clip, one explicit scale, printed as MIN/MAX/SPAN so each row compares
# against the table below on the same quantity and the same clip. The scale is set
# at the call site so this is a pure reader, and the READBACK is printed next to
# the value that was asked for, because a scale that did not take is a silently
# contaminated row rather than a loud failure.
func _ctl(clip: String, hi: int, fi: int, want: float) -> void:
	_root.scale = Vector3.ONE * want
	var g0: float = _sk.global_transform.basis.get_scale().x
	for i in 4:
		await process_frame
	var g1: float = _sk.global_transform.basis.get_scale().x
	var r := await _sample(clip, hi, fi)
	if not is_equal_approx(g0, want):
		print("C|%s want=%.6f did NOT take on write (read %.6f) -- VOID" % [clip, want, g0])
		return
	var held: bool = is_equal_approx(g1, want)
	# THREE outcomes, all of them informative, and none of them a pass by
	# construction: HELD means the pin is a usable measurement; LOST means the
	# root's own scale was rewritten from a stored basis within four frames, which
	# is a finding about the rig rather than about the clip; NO_RESULT means the
	# clip did not drive, so the control produced no data and says so.
	var verdict: String = "HELD" if held else ("LOST -- root scale rewritten from a stored basis" if not is_equal_approx(_root.scale.x, want) else "LOST -- node rewritten")
	if r == null:
		print("C|%s want=%.6f read=%.6f pin=%s  UNDRIVEN (excluded, not a result)" % [clip, want, g1, verdict])
		return
	print("C|%s want=%.6f read=%.6f pin=%s  min=%+.4f max=%+.4f span=%.4f" % [
		clip, want, g1, verdict, r["min"], r["max"], r["span"]])


func _sample(clip: String, hi: int, fi: int) -> Variant:
	# Anchor to axis bones THIS clip actually drives. A fixed pair is not safe:
	# spine.006_end_067 is driven by NO clip in the library, so every row that used
	# it was comparing a moving foot against a stationary head.
	var anchors: Array = _anchors(clip)
	if anchors.is_empty():
		return null
	hi = anchors[0]
	fi = anchors[1]
	if not _sk.play(clip):
		return null
	# DO NOT write speed_scale here. humanoid_rig.gd:164 is the single writer and
	# it re-applies every frame, so setting it from a harness is writing into a
	# value production immediately overwrites -- which is exactly how this file
	# produced a confident table of UNDRIVEN rows: the clip sat at position 0.0
	# and a paused clip and a clip that will not drive look identical.
	# The correct intervention is spatial, not a written value: the subject is
	# placed within anim_lod_distance of an active camera so PRODUCTION sets
	# speed_scale = 1.0. Then we assert it rather than assume it.
	_ap.advance(0.0)
	for i in 3:
		await process_frame
	# Void check, loud, BEFORE any number is read. speed_scale 0.000 is a known
	# and checkable disqualifier, and a pose reading taken on a frozen subject is
	# not a small error -- it is a reading of frame zero presented as a cycle.
	var ss: float = _ap.speed_scale
	if ss <= 0.0:
		print("P|VOID clip %s: speed_scale=0.000, subject is LOD-frozen. A pose" % clip)
		print("P|VOID   reading here would be frame 0.0 presented as a cycle." % clip)
		print("P|VOID   Keep the bot within anim_lod_distance of the camera.")
		return null
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
	# PER-SAMPLE CLIP EVIDENCE. This is the repair. The old sampler called play(),
	# advanced, read get_bone_global_pose(), and reported the result as a pose
	# without ever checking that the clip was the thing driving it. A bone read and
	# a driven-pose read are indistinguishable in the output, which is how a rest
	# pose gets reported as an animated one -- the same unlabelled quantity that
	# produced tonight's central disagreement, in the other direction. Every
	# sample now records what is actually playing and where, and a clip whose
	# samples were not driven by that clip is REFUSED rather than reported. A row
	# that cannot say what drove it does not get to be a number.
	var driven: int = 0
	var pos_lo := INF
	var pos_hi := -INF
	var drove_as := ""
	for s in SAMPLES:
		_ap.advance(step)
		await process_frame
		if _ap.current_animation == StringName(clip):
			driven += 1
			drove_as = String(_ap.current_animation)
			pos_lo = minf(_ap.current_animation_position, pos_lo)
			pos_hi = maxf(_ap.current_animation_position, pos_hi)
		_ap.advance(step)
		await process_frame
		# WORLD space. The multiply is required; see the header.
		var hp: Vector3 = (_sk.global_transform * _sk.get_bone_global_pose(hi)).origin
		var fp: Vector3 = (_sk.global_transform * _sk.get_bone_global_pose(fi)).origin
		var v: float = hp.y - fp.y
		lo = minf(v, lo)
		his = maxf(v, his)
	if driven == 0:
		return null
	# REST angle on the same bone pair, from the skeleton rest rather than the
	# clip, so every POSE row ships with the baseline it has to be judged against.
	#
	# get_bone_global_rest is Skeleton3D SPACE, not world. The skeleton node in this
	# fixture carries a 90 degree mount -- MOUNT_DEG reads 90.00 on every row -- so
	# comparing the raw rest vector against Vector3.UP compares a SKELETON-SPACE
	# vector to a WORLD vector and produced REST +86.164 against POSE +0.318. That
	# gap is not a posture finding, it is a space mismatch, and it is the same
	# mistake as the 1.000-versus-1.0197 disagreement earlier tonight wearing the
	# opposite sign. Compose the skeleton basis onto the rest vector first, exactly
	# as the POSE path composes global_transform * get_bone_global_pose.
	var rest_hi: Transform3D = _sk.get_bone_global_rest(hi)
	var rest_lo: Transform3D = _sk.get_bone_global_rest(fi)
	var rest_v: Vector3 = (_sk.global_transform.basis * (rest_hi.origin - rest_lo.origin))
	var rest: float = 0.0
	if rest_v.length() > 0.0001:
		rest = rad_to_deg(acos(clampf(rest_v.normalized().dot(Vector3.UP), -1.0, 1.0)))
	return {"min": lo, "max": his, "span": his - lo, "driven": driven,
		"of": SAMPLES, "as": drove_as, "pos": [pos_lo, pos_hi], "rest": rest,
		"hi": anchors[2], "fi": anchors[3]}


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

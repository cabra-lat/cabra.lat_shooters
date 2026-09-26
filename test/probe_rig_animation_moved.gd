extends SceneTree
## PERMANENT probe. Asserts the rig's body actually MOVES before it reports an
## angle about it.
##
## WHY THIS EXISTS. On 2026-09-26 a measurement said the humanoid body stood at
## 1.7 deg from vertical with any locomotion clip playing, and that was used to
## argue the animation library was healthy and the defect lay elsewhere. It was
## false. The harness had added its own AnimationPlayer to a skeleton that
## humanoid_rig.gd already drives through its own, the track paths never
## resolved, and the rig sat at its authored rest pose -- which measures
## upright. A still rig reported as a result. The same artefact had already
## produced a 0.4 deg "control" reading from a player whose AnimationLibrary is
## an empty sub_resource and who therefore could not move either.
##
## A number from a harness that cannot fail is not a measurement, so every
## sample here is gated on POSE_MOVED: the pose must depart from its rest pose
## by more than MIN_POSE_DELTA degrees before its angle is allowed to print. If
## the rig has not moved, the run FAILS instead of reporting health.
##
## The rig is driven through the PRODUCTION wiring -- bot.tscn's own
## AnimationPlayer, library and root_node -- and the clips are started with the
## rig's own HumanoidRig.play(). No second AnimationPlayer is ever created,
## because that is the mistake this probe exists to catch.
##
## Samples are only attributed to a clip when the AnimationPlayer confirms that
## clip is the one playing, so a state machine switching clips underneath cannot
## silently mislabel a reading.
##
## Run: godot --headless --path . --script \
##   res://addons/cabra.lat_shooters/test/probe_rig_animation_moved.gd
## Exit 0 = the rig moved on every sampled clip. Exit 1 = it did not, and every
## angle printed alongside is void.

const LIB := "res://addons/cabra.lat_shooters/src/player/humanoid_body_anims.res"
const RIG_SCENE := "res://addons/cabra.lat_shooters/src/player/scenes/humanoid_rig.tscn"
const CLIPS := ["idle", "walk", "walking", "run", "aim_idle", "reload", "reloading",
	"strafe_left", "strafe_right", "turn_left", "fire", "firing_rifle", "hit",
	"rifle_run", "rifle_aiming_idle", "toss_grenade", "walking_backwards",
	"run_backwards", "turning_right_45", "hit_reaction", "rifle_jump", "reset"]
const MIN_POSE_DELTA := 1.0   ## deg. Below this the rig did not move and the sample is void.
const SETTLE := 8              ## frames to let a clip reach a representative pose
const ANIM_PATH := "Skeleton3D/AnimationPlayer"

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var host := CharacterBody3D.new()
	root.add_child(host)
	# Production wiring: the same AnimationPlayer child, AnimationLibrary and
	# root_node that bot.tscn ships with, taken from the scene rather than
	# rebuilt, so the track paths resolve exactly as they do in game.
	var bot: Node = (load("res://src/npcs/bot/bot.tscn") as PackedScene).instantiate()
	host.add_child(bot)
	for i in 3:
		await process_frame

	var sk: Skeleton3D = bot.get_node_or_null("Skeleton3D")
	if sk == null:
		print("PROBE|FAIL no Skeleton3D under the bot")
		quit(1)
		return
	var ap: AnimationPlayer = sk.get_node_or_null("AnimationPlayer")
	if ap == null:
		print("PROBE|FAIL no AnimationPlayer on the rig")
		quit(1)
		return
	print("PROBE|setup root_node=%s library_clips=%d" % [str(ap.root_node), ap.get_animation_list().size()])

	var lo: int = sk.find_bone("spine_01")
	var hi: int = sk.find_bone("spine.006_07")
	if lo < 0 or hi < 0:
		print("PROBE|FAIL spine bones not found")
		quit(1)
		return

	for clip in CLIPS:
		if not sk.play(clip):
			print("PROBE|%-20s UNAVAILABLE in the rig's own library" % clip)
			continue
		var angles: Array[float] = []
		var moved := 0.0
		var matched := 0
		for f in SETTLE:
			await process_frame
			ap.advance(0.1)
			sk.force_update_all_bone_transforms()
			# GATE 1: did the pose depart from rest at all? Without this the
			# angle below is meaningless.
			moved = maxf(moved, _max_delta_from_rest(sk))
			# GATE 2: only attribute a sample to the clip we asked for.
			if ap.current_animation != clip:
				continue
			matched += 1
			# World space, not skeleton-local: get_bone_global_pose() is relative
			# to the Skeleton3D node and will happily report a rolled rig as
			# upright. Both coordinate-space traps in one defect, hence both gates.
			var a: Vector3 = sk.global_transform * sk.get_bone_global_pose(hi).origin
			var c: Vector3 = sk.global_transform * sk.get_bone_global_pose(lo).origin
			angles.append(rad_to_deg(acos(clampf((a - c).normalized().dot(Vector3.UP), -1.0, 1.0))))
		if moved < MIN_POSE_DELTA:
			_failed = true
			print("PROBE|%-20s POSE_MOVED=%.2f deg  VOID -- rig did not move, angle withheld" % [clip, moved])
			continue
		if matched == 0:
			_failed = true
			print("PROBE|%-20s POSE_MOVED=%.2f deg  VOID -- clip never confirmed playing" % moved)
			continue
		var mean := 0.0
		for x in angles:
			mean += x
		mean /= angles.size()
		var verdict := "upright" if mean < 10.0 else ("ROLLED" if mean > 60.0 else "leaning")
		print("PROBE|%-20s POSE_MOVED=%6.1f deg  samples=%d  world_spine_vs_UP=%5.1f deg  %s" % [
			clip, moved, matched, mean, verdict])

	print("PROBE|RESULT %s" % ("FAIL -- see VOID lines above" if _failed else "PASS -- rig moved on every sampled clip"))
	quit(1 if _failed else 0)


## Largest rotation, in degrees, between any bone's posed and rest global
## orientation. This is the assertion that a rig which is merely standing still
## cannot masquerade as a rig that is animating correctly.
func _max_delta_from_rest(sk: Skeleton3D) -> float:
	var worst := 0.0
	for i in sk.get_bone_count():
		var posed: Quaternion = sk.get_bone_global_pose(i).basis.get_rotation_quaternion()
		var rest: Quaternion = sk.get_bone_global_rest(i).basis.get_rotation_quaternion()
		var ang: float = rad_to_deg(posed.angle_to(rest))
		if ang > worst:
			worst = ang
	return worst

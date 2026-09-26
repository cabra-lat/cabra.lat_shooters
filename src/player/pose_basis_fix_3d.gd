class_name PoseBasisFix3D
extends SkeletonModifier3D
## Compensates for a basis disagreement between two authored conventions in the
## same rig, which is what made the bots walk sideways.
##
## THE TWO CONVENTIONS. humanoid_rig.tscn mounts the Skeleton3D node at 120
## degrees about (1,-1,-1)/sqrt3:
##
##   transform = Transform3D(-4.3711385e-08, -0.9999999, -4.371139e-08, 0,
##                            -4.3711385e-08, 1, -0.9999999, 4.3711385e-08,
##                            1.9106855e-15, 0, 0, 0)
##
## trace = -8.74e-08, so acos((trace-1)/2) = 120.0000 degrees, det = +1. The
## BIND data in the same file is authored to compensate for that mount, which is
## why reset_bone_poses() measures 1.4 degrees upright. The clips in
## humanoid_body_anims.res are NOT authored to compensate, so any clip drives
## the spine 68 to 93 degrees from world UP. The rig looks correct standing still
## and rolled the moment it animates, which is why this survived: the one rig
## anybody had seen upright is the player's, whose AnimationLibrary is an empty
## sub_resource and therefore cannot play a single clip.
##
## WHY THE ROOT BONE. The correction is a single global rotation, so pre-
## rotating the root bone's LOCAL pose propagates to every child while leaving
## each bone's own animation intact. It is not a per-clip pose fix and it does
## not touch a single clip.
##
## MEASURED, not assumed. Applying Quaternion(axis, -120) to the root's local
## pose moves world spine vs UP on the real rig from
##
##   walk 92.7 -> 7.5    strafe_left 78.0 -> 14.6   idle 78.2 -> 16.2
##   hit 81.7 -> 16.3    reload 80.5 -> 16.1        run 68.5 -> 22.3
##   firing_rifle 70.4 -> 30.6
##
## and was confirmed by two independent routes -- rotating the node basis itself
## gives the same numbers, and the optimum is a sharp minimum exactly at -120
## (at -60 the clips read 34 to 54, at +120 they read 68 to 85).
##
## The alternative, de-rotating the node to identity, also makes the clips read
## 7 to 31, but it breaks the bind data and the mesh, which are authored in the
## -120 convention. Correcting the animation is the one-sided fix.
##
## GATED ON ANIMATION. At rest the bones come from the compensated bind data, so
## applying this with no clip playing would roll the rest pose by 120 degrees.
## The rig's own AnimationPlayer is the authority on whether a clip is driving.
##
## Verify with addons/cabra.lat_shooters/test/probe_rig_animation_moved.gd, which
## refuses to report an angle for a rig it has not first caught moving.

## Axis of the node mount the clips fail to compensate for.
const MOUNT_AXIS := Vector3(-0.5773503, 0.5773503, 0.5773503)
## -120 degrees cancels the +120 degree mount.
const CORRECTION_DEG := -120.0

@export var correction_deg: float = CORRECTION_DEG:
	set(v):
		correction_deg = v
		_dirty = true
@export var root_bone: int = 0
## When false the rig is left exactly as authored. Escape hatch, not a default.
@export var enabled: bool = true

var _dirty := true
var _last_correction := Quaternion.IDENTITY


func _process_modification() -> void:
	if not enabled:
		return
	var skel := get_skeleton()
	if skel == null:
		return
	# The rig's own AnimationPlayer, resolved the same way HumanoidRig does it.
	var ap := _find_anim(skel)
	if ap == null or not ap.is_playing():
		return
	if _dirty or _last_correction != Quaternion(MOUNT_AXIS, deg_to_rad(correction_deg)):
		_last_correction = Quaternion(MOUNT_AXIS, deg_to_rad(correction_deg))
		_dirty = false
	# Absolute, every frame: pre-rotating relative to the current pose would
	# accumulate across frames and walk the rig away.
	skel.set_bone_pose_rotation(root_bone, _last_correction)


func _find_anim(n: Node) -> AnimationPlayer:
	var stack: Array[Node] = [n]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is AnimationPlayer:
			return cur
		for c in cur.get_children():
			stack.append(c)
	return null

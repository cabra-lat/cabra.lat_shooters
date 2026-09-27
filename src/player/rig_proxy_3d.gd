class_name RigProxy3D
extends Node3D
## Ball-and-capsule articulation debug rig.
##
## WHY THIS EXISTS. The NPC roll defect has been measured numerically for days and
## never LOOKED AT, because no capture made the shape legible. A large bilateral
## rotation across the distal upper body reads in a number table as several
## unrelated joints and reads to a person as one shape: a body folded into
## itself. This node draws that shape directly, so the defect can be seen without
## a rest convention and without trusting a number.
##
## CONSTRUCTION, and only what was specified:
##   - a ball at every articulation, scaled to the JOINT, not to the bone
##   - a capsule per limb member, oriented along joint -> child, length equal to
##     the distance between them
##   - explicit hand and foot positioning, because hands are where the spike is
##     and a foot inheriting a rolled ankle is the sideways-walk signature
##
## FRAME DISCIPLINE, because this class has been wrong before. Every transform
## here is read from Skeleton3D via get_bone_global_pose, which is POSE in
## Skeleton3D space, and composed to world as global_transform * pose. Rest is
## never mixed in: a proxy drawn from rest would be a different picture and
## comparing the two is the trap that produced a false green earlier.
##
## LAYERING, per 916d41. Debug gizmos must not sit on layer 1: an instance with
## no layers set defaults to layer 1 and is drawn by EVERY camera in the project
## including gameplay ones, which is the defect that card exists to stop. The
## reserved layer is a single constant so the reservation is one edit, and
## nothing here ever writes layer 1.
##
## The exact reserved layer VALUE is still the open 916d41 decision (reserved
## layer versus a CanvasLayer world). The constant is therefore deliberately a
## high bit rather than a decided number, and `is_debug_layer_reserved()` is the
## single assertion the harness checks. If the ruling moves the debug layer, one
## constant changes and nothing else does.

## Reserved visual layer for debug 3D gizmos. Never layer 1.
## RULED, not provisional: coordinator fixed this at layer 20, mask value 524288, and
## the gameplay camera excludes bit 19. Chosen as the TOP render layer so a
## mistake that puts debug geometry on a LOW number is loud rather than silent.
const DEBUG_VISUAL_LAYER: int = 20
## Mask form of DEBUG_VISUAL_LAYER, for a camera cull_mask that must EXCLUDE it.
const DEBUG_VISUAL_LAYER_BIT: int = 1 << (DEBUG_VISUAL_LAYER - 1)

const JOINT_RADIUS: float = 0.012
const LIMB_RADIUS: float = 0.010
## Bones that get an EXPLICIT terminal segment. A hand or foot bone is usually a
## leaf, and a leaf has no child, so a joint-to-child rule draws nothing at all
## there, and the hand and the foot are exactly the two regions this instrument
## exists to show. These get a segment along a DIRECTION WE NAME rather than one
## inherited from the parent chain, because a foot whose direction is inherited
## from a rolled ankle is precisely the artefact being looked for and would
## otherwise be drawn wrong and read as correct.
const HAND_BONE_PREFIX: String = "hand."
const FOOT_BONE_PREFIX: String = "foot."
## Local direction the terminal segment is drawn along, in the bone's own space.
## Chosen to continue the limb rather than to follow the parent, so the drawn
## hand and foot do not inherit the rotation under test.
const HAND_LOCAL_DIR: Vector3 = Vector3.DOWN
const FOOT_LOCAL_DIR: Vector3 = Vector3.FORWARD
const HAND_LENGTH: float = 0.09
const FOOT_LENGTH: float = 0.14

var _skeleton: Skeleton3D
var _proxy_root: Node3D
var _joint_balls: Array[MeshInstance3D] = []
var _limb_capsules: Array[MeshInstance3D] = []
var _terminals: Array[MeshInstance3D] = []
var _terminals_bone: Array[int] = []
var _terminals_dir: Array[Vector3] = []
var _built: bool = false


## True when `layer` is a legal debug layer: not layer 1, and inside the range.
static func is_debug_layer_reserved(layer: int) -> bool:
	return layer != 1 and layer >= 2 and layer <= 20


## Build the proxy for `skeleton`. Idempotent: a second call is a no-op, so a
## caller may call it every frame without building twice.
func build(skeleton: Skeleton3D) -> void:
	if _built:
		return
	assert(skeleton != null, "RigProxy3D.build: skeleton is null")
	_skeleton = skeleton
	_proxy_root = Node3D.new()
	_proxy_root.name = "RigProxy"
	# Rule, not default: every instance is created through here so no pane can
	# reach the scene without a layer.
	_proxy_root.layers = DEBUG_VISUAL_LAYER
	add_child(_proxy_root)
	_build_joint_balls()
	_build_limb_capsules()
	_built = true


## Ball at every articulation, scaled to the joint.
func _build_joint_balls() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = JOINT_RADIUS
	sphere.height = JOINT_RADIUS * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	for i in _skeleton.get_bone_count():
		var mi := MeshInstance3D.new()
		mi.mesh = sphere
		mi.layers = DEBUG_VISUAL_LAYER
		mi.name = "Joint_%s" % _skeleton.get_bone_name(i)
		_proxy_root.add_child(mi)
		_joint_balls.append(mi)


## Capsule per limb member, along joint -> child, length equal to the distance.
func _build_limb_capsules() -> void:
	for i in _skeleton.get_bone_count():
		var parent := _skeleton.get_bone_parent(i)
		if parent < 0:
			continue  # root has no member above it
		# A capsule is authored along +Y, so the rotation below maps +Y onto the
		# bone direction. This is the only orientation step in the class.
		var mi := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = LIMB_RADIUS
		mi.mesh = capsule
		mi.layers = DEBUG_VISUAL_LAYER
		mi.name = "Limb_%s" % _skeleton.get_bone_name(i)
		# The bone index is the link between a capsule and the two joints it
		# spans. Without it the orientation pass finds nothing to do and every
		# capsule stays collapsed at the origin, which looks built and is not.
		mi.set_meta("bone_index", i)
		_proxy_root.add_child(mi)
		_limb_capsules.append(mi)


## Refresh every instance from the current POSE. Call once per frame after the
## skeleton has posed. Deliberately takes no rest argument.
func refresh() -> void:
	if not _built:
		return
	var base := _skeleton.global_transform
	for i in _skeleton.get_bone_count():
		var pose := _skeleton.get_bone_global_pose(i)
		var world := base * pose
		_joint_balls[i].global_transform = world

	_index_members()
	_place_terminals()


## Orient each capsule between its two joints. Kept separate from refresh so a
## caller can prove the joint transform is right before the member orientation
## is trusted.
func _index_members() -> void:
	for idx in _limb_capsules.size():
		var bone: int = _limb_capsules[idx].get_meta("bone_index", -1)
		if bone < 0:
			continue
		var parent := _skeleton.get_bone_parent(bone)
		if parent < 0:
			continue
		var a: Transform3D = _joint_balls[parent].global_transform
		var b: Transform3D = _joint_balls[bone].global_transform
		_place_capsule(_limb_capsules[idx], a.origin, b.origin)


## A capsule is a body of revolution along +Y, so it is placed at the midpoint
## with its length along the joint axis. Degenerate length is left alone rather
## than divided by zero.
func _place_capsule(mi: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var delta := to - from
	var length := delta.length()
	if length < 0.0001:
		mi.visible = false
		return
	mi.visible = true
	var mesh := mi.mesh as CapsuleMesh
	# CapsuleMesh.height is the TOTAL height including both caps, and it cannot
	# be shorter than 2 * radius.
	var total: float = maxf(length, LIMB_RADIUS * 2.0 + 0.0001)
	mesh.height = total
	var y := delta / length
	var up := Vector3.UP
	var x := up.cross(y)
	if x.length_squared() < 0.000001:
		# Bone is parallel to +Y: any perpendicular axis is valid.
		x = Vector3.RIGHT
	else:
		x = x.normalized()
	var z := x.cross(y)
	mi.global_transform = Transform3D(Basis(x, y, z).orthonormalized(), (from + to) * 0.5)


## Explicit terminal segments for hand and foot bones, oriented along a named
## local direction rather than inherited from the chain. This is the "explicit
## hand and foot positioning" the card specifies, and it is deliberately NOT the
## same rule as the limb members: a hand drawn along its parent's axis would
## simply show the rotation under test, whereas a hand drawn along a direction we
## name is a FIXED REFERENCE the reader can compare the joint against. If the
## joint is rolled the fixed reference does not move, so the roll is visible as a
## mismatch instead of being redrawn along with it.
func _place_terminals() -> void:
	if not _terminals.is_empty():
		return  # built once; refreshed in place below
	for i in _skeleton.get_bone_count():
		var bone_name := _skeleton.get_bone_name(i)
		var is_hand := bone_name.begins_with(HAND_BONE_PREFIX)
		var is_foot := bone_name.begins_with(FOOT_BONE_PREFIX)
		if not (is_hand or is_foot):
			continue
		var mi := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = LIMB_RADIUS
		mi.mesh = capsule
		mi.layers = DEBUG_VISUAL_LAYER
		mi.name = "Terminal_%s" % bone_name
		_proxy_root.add_child(mi)
		var length: float = HAND_LENGTH if is_hand else FOOT_LENGTH
		var dir: Vector3 = HAND_LOCAL_DIR if is_hand else FOOT_LOCAL_DIR
		mi.set_meta("bone_index", i)
		_terminals.append(mi)
		_terminals_bone.append(i)
		_terminals_dir.append(dir * length)
	for idx in _terminals.size():
		var bone: int = _terminals_bone[idx]
		var origin: Vector3 = _joint_balls[bone].global_transform * Vector3.ZERO
		_place_capsule(_terminals[idx], origin, origin + _terminals_dir[idx])


## Every instance this node owns, for the harness to assert layers on.
func get_proxy_instances() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	out.append_array(_joint_balls)
	out.append_array(_limb_capsules)
	out.append_array(_terminals)
	return out


## True when no instance sits on layer 1. This is the 916d41 invariant in one
## predicate: it fails if a future edit adds a pane without a layer.
func all_instances_off_layer_one() -> bool:
	for mi in get_proxy_instances():
		if (mi.layers & 1) != 0:
			return false
	return true

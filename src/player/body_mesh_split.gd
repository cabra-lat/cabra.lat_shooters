# res://addons/cabra.lat_shooters/src/player/body_mesh_split.gd
class_name BodyMeshSplit
extends RefCounted
## Bone-based split of the first-person body: separate the vertices dominated
## by the HEAD/NECK bones into their own MeshInstance3D so that part can be
## hidden from the FPS camera alone (layer), without touching the skin.
##
## Why bone-based and not a distance/plane cut (coordinator decision, from GPU
## frames): the head sits exactly where the eye is and the IK arms stretch in
## front, so any distance cutoff that removes the head also removes the legs —
## and a plane cut would break the skin weights. Splitting by dominant bone
## keeps every vertex's weights intact and lets the PiP cameras keep rendering
## the whole character.

## Default head/neck bones of the shipped player skeleton (87 bones):
## spine.005_06 = neck, spine.006_07 = head. spine.006_end is not weighted.
const DEFAULT_HEAD_BONES: Array[int] = [6, 7]

## Split [member] into body + head parts. Returns the new head MeshInstance3D
## (child of [param mi]'s parent, skinned to the same skeleton) or null when the
## mesh is not skinned / already split.
static func split(mi: MeshInstance3D, head_bones: Array[int] = DEFAULT_HEAD_BONES) -> MeshInstance3D:
	if mi == null or mi.mesh == null or mi.mesh.get_surface_count() == 0:
		return null
	if mi.has_meta("body_split_head"):
		return mi.get_meta("body_split_head") as MeshInstance3D
	var src: ArrayMesh = mi.mesh as ArrayMesh
	if src == null:
		return null
	var arrays: Array = src.surface_get_arrays(0)
	if arrays.size() <= Mesh.ARRAY_WEIGHTS or arrays[Mesh.ARRAY_WEIGHTS] == null:
		return null # not skinned: nothing to split by bone

	var vert_count: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		indices = PackedInt32Array()
		for i in range(vert_count):
			indices.append(i)

	var bone_set := {}
	for b in head_bones:
		bone_set[b] = true
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]

	var body_idx := PackedInt32Array()
	var head_idx := PackedInt32Array()
	var t := 0
	while t + 2 < indices.size():
		if _tri_is_head(indices, t, bones, weights, bone_set):
			head_idx.append(indices[t])
			head_idx.append(indices[t + 1])
			head_idx.append(indices[t + 2])
		else:
			body_idx.append(indices[t])
			body_idx.append(indices[t + 1])
			body_idx.append(indices[t + 2])
		t += 3
	if head_idx.is_empty():
		return null

	var mat := src.surface_get_material(0)
	var body_mesh := _mesh_from(arrays, body_idx, mat)
	var head_mesh := _mesh_from(arrays, head_idx, mat)
	if body_mesh == null or head_mesh == null:
		return null

	# Head part: same skin/skeleton, hidden from the FPS camera by layer.
	var head_mi := MeshInstance3D.new()
	head_mi.name = "MESH_HEAD"
	head_mi.mesh = head_mesh
	head_mi.skin = mi.skin
	head_mi.skeleton = mi.skeleton
	head_mi.material_overlay = mi.material_overlay
	head_mi.cast_shadow = mi.cast_shadow
	mi.get_parent().add_child(head_mi)

	# Body keeps everything else on the FPS-visible layer.
	mi.mesh = body_mesh
	mi.set_meta("body_split_head", head_mi)
	return head_mi

## Does this triangle belong to the head? Dominant bone = largest summed
## weight across the three vertices (weights are untouched, only indices split).
static func _tri_is_head(indices: PackedInt32Array, t: int,
		bones: PackedInt32Array, weights: PackedFloat32Array, bone_set: Dictionary) -> bool:
	var totals := {}
	for k in [t, t + 1, t + 2]:
		var v: int = indices[k]
		for c in 4:
			var bi := v * 4 + c
			if bi >= bones.size():
				continue
			var b := bones[bi]
			var w := weights[bi]
			totals[b] = float(totals.get(b, 0.0)) + w
	var dom := -1
	var best := -1.0
	for b in totals:
		if float(totals[b]) > best:
			best = float(totals[b])
			dom = int(b)
	return bone_set.has(dom)

static func _mesh_from(arrays: Array, index_array: PackedInt32Array, mat: Material) -> ArrayMesh:
	if index_array.is_empty():
		return null
	var out: Array = arrays.duplicate()
	out[Mesh.ARRAY_INDEX] = index_array
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	m.surface_set_material(0, mat)
	return m

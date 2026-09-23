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

## Neck bone carrying the collar cap + cap tuning (GPU-measured 2026-09-23:
## the split leaves the neck OPEN and the double-sided PSX body shows the
## hollow interior when pitching down — the "head in front of the camera").
const NECK_BONE := "spine.005_06"
const CAP_NAME := "MESH_NECK_CAP"
const CAP_RADIUS := 0.10
const CAP_SQUASH := 0.45
## Collar color: the body's orange comes from its decal TEXTURE (sphere UVs
## sample a white texel region — measured white dome on GPU 2026-09-23), so the
## cap carries its own flat material on the near-clip shader instead.
const CAP_SHADER := "res://addons/cabra.lat_shooters/src/player/psx_lit_body_nearclip.gdshader"
const CAP_COLOR := Color(1.0, 0.38, 0.05)

## Split [member] into body + head parts. Returns the new head MeshInstance3D
## (child of [param mi]'s parent, skinned to the same skeleton) or null when the
## mesh is not skinned / already split. Also builds the neck collar cap
## (see _neck_cap) so the stump is plugged; read it via neck_cap().
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
	_neck_cap(mi)
	return head_mi

## Collar cap plugging the open neck stump: a squashed sphere riding the neck
## bone (BoneAttachment3D, so it follows head/lean animation), skinned-look via
## the body's own surface material. From outside it hides UNDER the head mesh;
## from the FPS lens it closes the hollow hole. Idempotent via meta.
## Returns the cap or null (non-skeleton parent / missing neck bone).
## Flat collar material: near-clip shader (same discard as the body) with the
## suit orange baked in. Params survive apply()'s install_nearclip by name.
static func _cap_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(CAP_SHADER) as Shader
	m.set_shader_parameter("modulate_color", CAP_COLOR)
	m.set_shader_parameter("body_near_cutoff", 0.05)
	return m

static func _neck_cap(mi: MeshInstance3D) -> MeshInstance3D:
	var old = neck_cap(mi)
	if old != null:
		return old
	var skel := mi.get_parent() as Skeleton3D
	if skel == null:
		return null
	if skel.find_bone(NECK_BONE) < 0:
		return null
	var attach := BoneAttachment3D.new()
	attach.name = "NeckCapAttachment"
	attach.bone_name = NECK_BONE
	skel.add_child(attach)
	var sphere := SphereMesh.new()
	sphere.radius = CAP_RADIUS
	sphere.height = CAP_RADIUS * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var cap := MeshInstance3D.new()
	cap.name = CAP_NAME
	cap.mesh = sphere
	cap.scale = Vector3(1.0, CAP_SQUASH, 1.0)
	# material_override (NOT the surface override): install_nearclip() duplicates
	# from material_override, and a mesh-level override wins over the surface
	# one — a surface-level cap material would be buried under an empty
	# near-clip copy and render white (measured on GPU).
	cap.material_override = _cap_material()
	cap.cast_shadow = mi.cast_shadow
	attach.add_child(cap)
	mi.set_meta("body_split_cap", cap)
	return cap

## Existing collar cap for a split mesh, or null (not split / cap freed).
static func neck_cap(mi: MeshInstance3D) -> MeshInstance3D:
	if mi != null and mi.has_meta("body_split_cap"):
		var cap := mi.get_meta("body_split_cap") as MeshInstance3D
		if cap != null and is_instance_valid(cap):
			return cap
		mi.remove_meta("body_split_cap")
	return null

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

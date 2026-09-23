# res://addons/cabra.lat_shooters/src/player/player_body_visibility.gd
class_name PlayerBodyVisibility
extends RefCounted
## First-person body visibility (P0: the player must be able to see their own
## legs/feet).
##
## History: scenes hid EVERY body MeshInstance3D on BODY_HIDE_LAYER (4) and the
## FPS camera culled that bit, which also removed legs/feet. Instead we keep the
## body on the camera's layers and cut only the shell that would clip into the
## lens, using a distance discard in the material (see
## psx_lit_body_nearclip.gdshader).
##
## Used by the player itself (deferred, so it also undoes a scene that hid the
## body earlier in its own _ready) — scenes can call `apply(player)` too; it is
## idempotent.

const NEARCLIP_SHADER := "res://addons/cabra.lat_shooters/src/player/psx_lit_body_nearclip.gdshader"
## Tiny camera-distance cut, only so the body never scrapes the near plane.
## The head/neck are handled by the bone split, NOT by this (coordinator
## decision: a distance cut cannot separate head from legs on this mesh).
const DEFAULT_NEAR_CUTOFF := 0.05
const VISIBLE_LAYER := 1
## Everything else the player carries (backpack, IK look-target quads) stays
## hidden from the FPS camera exactly as the old blanket hide did — the PiP
## cameras keep rendering them (they do not clear this bit).
const HIDDEN_FROM_FPS_LAYER := 4
## ShotRay (scenes/shot_ray.gd) excludes everything tagged with this group.
## The player's own body colliders must never be hit by the player's own shot,
## so they are tagged here too — see the note in `tag_own_colliders`.
const SHOT_EXCLUDE_GROUP := "viewmodel"

static func apply(player: Node, near_cutoff: float = DEFAULT_NEAR_CUTOFF, first_person: bool = true) -> bool:
	if player == null or not player.is_inside_tree():
		return false
	# B2 (bot invulnerability): the FPS head-cut, the layer scheme AND the
	# collider tagging are PLAYER-ONLY. A world consumer (NPC) MUST pass
	# first_person=false -> whole body on VISIBLE_LAYER and, critically, NO
	# collider enters SHOT_EXCLUDE_GROUP. ShotRay excludes that group across
	# the WHOLE tree, so tagging an NPC collider would make the player shoot
	# straight through the bot (shot_resolver never reaches `collider is NpcBot`).
	if not first_person:
		for other in all_meshes(player):
			other.layers = VISIBLE_LAYER
		return true
	var mesh := body_mesh(player)
	if mesh == null:
		return false
	# The head/neck are carved out by BONE and hidden from the FPS camera only
	# (distance cuts could not separate head from legs on this mesh, and a plane
	# cut would break the skin — see BodyMeshSplit).
	var head := BodyMeshSplit.split(mesh)
	if head != null:
		head.layers = HIDDEN_FROM_FPS_LAYER
	# The collar cap plugs the open neck stump: it MUST stay on the FPS-visible
	# layer, otherwise the lens looks into the hollow body (double-sided PSX).
	var cap := BodyMeshSplit.neck_cap(mesh)
	# Body visible (legs/feet), everything else the player carries stays out of
	# the FPS camera like before (a backpack filling the lens when you look down
	# was the first artifact of a naive "show every mesh").
	for other in all_meshes(player):
		if other == mesh or other == cap:
			other.layers = VISIBLE_LAYER
		elif other == head:
			other.layers = HIDDEN_FROM_FPS_LAYER
		else:
			other.layers = HIDDEN_FROM_FPS_LAYER
	install_nearclip(mesh, near_cutoff)
	if cap != null:
		install_nearclip(cap, near_cutoff)
	tag_own_colliders(player)
	return true

## Every MeshInstance3D under the player.
static func all_meshes(player: Node) -> Array:
	var out: Array = []
	var stack: Array = [player]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			out.append(n)
		stack.append_array(n.get_children())
	return out

## Body mesh of the first-person body (player_ik.tscn "MESH" under the skel).
static func body_mesh(player: Node) -> MeshInstance3D:
	var skel = player.get("skeleton")
	if skel == null:
		return null
	var direct := skel.get_node_or_null("MESH") as MeshInstance3D
	if direct != null:
		return direct
	for c in skel.get_children():
		if c is MeshInstance3D:
			return c
	return null

## Swap a mesh's materials for near-clip copies, preserving the look (same
## shader include + the material's own parameters). Both the base material and
## the overlay get it, otherwise the pass without the discard keeps drawing the
## head. Public so the collar cap gets the same treatment as the body.
static func install_nearclip(mesh: MeshInstance3D, near_cutoff: float) -> void:
	var shader := load(NEARCLIP_SHADER) as Shader
	if shader == null:
		return
	var base := mesh.material_override
	if base == null and mesh.mesh != null:
		base = mesh.mesh.surface_get_material(0)
	var made_base := _nearclip_copy(base, shader, near_cutoff)
	if made_base != null:
		mesh.material_override = made_base
	var overlay := mesh.material_overlay
	var made_overlay := _nearclip_copy(overlay, shader, near_cutoff)
	if made_overlay != null:
		mesh.material_overlay = made_overlay

## Copy a material (or build one from scratch) onto the near-clip shader.
## Shader parameters survive the swap because the uniform names are the same.
static func _nearclip_copy(src: Material, shader: Shader, near_cutoff: float) -> Material:
	var out: ShaderMaterial = null
	if src is ShaderMaterial:
		out = (src as ShaderMaterial).duplicate() as ShaderMaterial
	else:
		out = ShaderMaterial.new()
	out.shader = shader
	out.set_shader_parameter("body_near_cutoff", near_cutoff)
	return out

static func set_near_cutoff(player: Node, near_cutoff: float) -> void:
	var mesh := body_mesh(player)
	if mesh == null:
		return
	var targets: Array = [mesh, BodyMeshSplit.neck_cap(mesh)]
	for mi in targets:
		if mi == null:
			continue
		for mat in [(mi as MeshInstance3D).material_override, (mi as MeshInstance3D).material_overlay]:
			if mat is ShaderMaterial:
				(mat as ShaderMaterial).set_shader_parameter("body_near_cutoff", near_cutoff)

static func get_near_cutoff(player: Node) -> float:
	var mesh := body_mesh(player)
	if mesh == null:
		return 0.0
	var mat := mesh.material_override
	if mat is ShaderMaterial:
		return float((mat as ShaderMaterial).get_shader_parameter("body_near_cutoff"))
	return 0.0

## The player's own colliders (e.g. TorsoAttachment/StaticBody3D) must not be
## valid targets for the player's own shot — especially now that the camera can
## pitch down at the feet. ShotRay excludes the SHOT_EXCLUDE_GROUP, which is
## how viewmodels are already handled; body colliders join it. (`range` owns
## scenes/shot_ray.gd and was asked to alias the group name for clarity.)
static func tag_own_colliders(player: Node) -> int:
	var tagged := 0
	var stack: Array = [player]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CollisionObject3D and n != player and not n.is_in_group(SHOT_EXCLUDE_GROUP):
			n.add_to_group(SHOT_EXCLUDE_GROUP)
			tagged += 1
		stack.append_array(n.get_children())
	return tagged

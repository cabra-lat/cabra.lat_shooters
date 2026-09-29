class_name ScopeReticle3D
extends Node3D
## A reticle that is PHYSICALLY IN THE SCOPE, not painted on the lens.
##
## WHY THIS EXISTS. `scope_lenses.gdshader` already ships `u_reticle_texture` and
## `u_reticle_tint`, and that reticle is drawn in the lens shader from a gradient
## texture. It is locked to the lens surface, so it has ZERO parallax: the reticle
## and the target move together no matter how the weapon moves, which is the single
## clearest "this is a picture, not glass" tell. This class replaces it with real
## geometry placed at a finite distance inside the scope's SubViewport, so weapon
## motion sweeps the reticle across the target the way a real reticle does.
##
## WHAT THE SHADER ALREADY DOES AND THIS DOES NOT REDO. Chromatic and geometric
## aberration (`u_chromatic_aberration`), the angled coating sheen
## (`u_reflection_intensity`, `u_front_tint_color`, `u_rear_tint_color`), the finite
## magnified-view edge (`u_front_lens_radius`, `u_front_squircle_exponent`,
## `u_bezel_color`) and the dark surround (`u_vignette_strength`) are all lens
## effects and stay in the lens. This class is only the reticle.
##
## LAYERS, AND THE TRAP IN THE NAME. Every visual instance goes on
## `SCOPE_RETICLE_LAYER`. That is the INTEGER 8, which is bit 3, which is LAYER 4.
## Do not "simplify" it to 4: `PlayerBodyVisibility.HIDDEN_FROM_FPS_LAYER` is the
## integer 4, which is bit 2, which is LAYER 3, and that layer holds the player's
## own head, backpack and carried meshes. A reticle on 4 would collide with it.
## Layer 4 is currently unused, which is why it was free to take.
## The scope's own Camera3D carries no `cull_mask` line and therefore inherits
## 1048575, so it already sees this. The FPS camera is `cull_mask = 1` and the
## viewmodel camera is `cull_mask = 2`; neither includes bit 3, so neither sees the
## reticle and no camera needs editing for the split to work.

## Integer mask, NOT a layer number. Bit 3 = layer 4.
const SCOPE_RETICLE_LAYER := 8

## How far in front of the scope camera the reticle plane sits, in metres. This is
## the reticle's distance, and it is what produces parallax: the same lateral
## weapon motion shifts a near reticle further across the image than a far target.
## A value that is too large flattens the effect toward zero; too small and the
## reticle detaches from the image when the weapon swings.
@export var reticle_distance := 60.0
## Length of one crosshair arm, as a fraction of the subtended sight radius.
@export var arm_length_ratio := 0.34
## Half-thickness of one arm, same units as arm_length_ratio.
@export var arm_thickness_ratio := 0.022
## Clear radius at the centre, so the arms do not meet. This is the dark gap the
## eye reads as the exit pupil's surround.
@export var pupil_gap_ratio := 0.055
## Diameter of the small bright central dot - the exit pupil highlight.
@export var pupil_diameter_ratio := 0.030
## Sight radius in radians. 0.5 degrees is a typical 1x-ish red dot.
@export var subtended_angle_deg := 0.5
## Reticle colour. Bright and unshaded; it is the only thing in the tube that is
## allowed to be self-lit.
@export var tint := Color(1.0, 0.12, 0.12, 1.0)

var _built := false


## Build the reticle geometry. Safe to call more than once.
func build() -> void:
	if _built:
		return
	_built = true
	var sight_radius := reticle_distance * deg_to_rad(subtended_angle_deg) * 0.5
	# Unshaded and bright: a reticle is emissive, and a lit material in a scope
	# tube would fall off with the tube's own shading.
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = tint
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Depth test stays ON. A real reticle sits at the focal plane, so an occluder
	# in front of the scope hides it. Turning this off would let the reticle
	# float through walls, which is the giveaway of a screen-space overlay.
	mat.no_depth_test = false
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var arm_len := sight_radius * arm_length_ratio
	var arm_thick := sight_radius * arm_thickness_ratio
	var gap := sight_radius * pupil_gap_ratio
	var pupil := sight_radius * pupil_diameter_ratio

	# Four arms, each starting at the pupil gap and reaching outward.
	var inner := gap
	var outer := gap + arm_len
	var mid := (inner + outer) * 0.5
	var half := arm_len * 0.5
	_arm(mat, Vector3(mid, 0.0, 0.0), Vector3(arm_thick, arm_len, arm_thick))
	_arm(mat, Vector3(-mid, 0.0, 0.0), Vector3(arm_thick, arm_len, arm_thick))
	_arm(mat, Vector3(0.0, mid, 0.0), Vector3(arm_len, arm_thick, arm_thick))
	_arm(mat, Vector3(0.0, -mid, 0.0), Vector3(arm_len, arm_thick, arm_thick))
	# Central dot: the small bright exit pupil highlight.
	_arm(mat, Vector3.ZERO, Vector3(pupil, pupil, pupil))

	# Sit on the reticle plane, in front of the camera, which looks down -Z.
	position = Vector3(0.0, 0.0, -reticle_distance)


func _arm(mat: Material, at: Vector3, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = at
	mi.material_override = mat
	# VisualInstance3D owns `layers`; Node3D does not. Setting it on the wrong
	# node type aborts the build and yields zero instances.
	mi.layers = SCOPE_RETICLE_LAYER
	add_child(mi)


## Place the reticle relative to a scope camera and orient it to face that camera.
## Call after the scope's SubViewport and Camera3D exist.
func attach_to(scope_camera: Node3D) -> void:
	if scope_camera == null or not scope_camera.is_inside_tree():
		return
	build()
	global_position = scope_camera.global_position \
		+ (-scope_camera.global_basis.z) * reticle_distance
	# Face back down the tube toward the eye.
	var look := global_position - scope_camera.global_position
	if look.length_squared() > 0.000001:
		look_at(look, Vector3.UP, true)


## Every MeshInstance3D this class created, for gates and for layer assertions.
func visuals() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c in get_children():
		if c is MeshInstance3D:
			out.append(c)
	return out

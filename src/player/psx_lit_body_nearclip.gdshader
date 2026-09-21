shader_type spatial;

// First-person body material: the PSX lit look (CULL disabled + alpha scissor,
// same as the body's original psx_lit_alpha-scissor) plus ONE addition — the
// near-camera discard. `body_psx_base.gdshaderinc` is a fork of
// shaders/psx/psx_base.gdshaderinc with that statement baked into fragment()
// (Godot has no fragment hook and renaming the entry point breaks COLOR).
//
// In fragment() VERTEX is the view-space position, so length(VERTEX) is the
// distance from the camera: everything closer than `body_near_cutoff` (the
// skull/chest shell around the eye) is dropped, while legs/feet — further away
// — stay visible. Tunable; see PlayerBodyVisibility.

#define LIT diffuse_lambert, vertex_lighting
#define CULL cull_disabled
#define DEPTH depth_prepass_alpha
#define BLEND blend_mix
#define ALPHA_SCISSOR
#define EXTERNAL

#include "body_psx_base.gdshaderinc"

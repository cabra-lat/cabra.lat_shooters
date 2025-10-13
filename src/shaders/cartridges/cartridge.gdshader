//#define DEBUG
#define CARTRIDGE_STAMP
#define BULLET_PHYSICS

shader_type spatial;
render_mode cull_front, depth_draw_always, depth_prepass_alpha;
// ======================
const float EPS = 1e-6;

// Surface type constants
const int SURFACE_DISCARD      = -1;
const int SURFACE_PRIMER       = 0;
const int SURFACE_RIM          = 1;
const int SURFACE_CASE         = 2;
const int SURFACE_BULLET_BASE  = 3;
const int SURFACE_BULLET_BODY  = 4;
const int SURFACE_BULLET_TIP   = 5;
const int SURFACE_TRACER       = 6;

// ======================
// UNIFORMS (kept from your shader)
group_uniforms Mesh;
uniform int mesh_segments_length = 64;
uniform int mesh_segments_circumference = 64;
uniform int gap_segments = 1;

group_uniforms Scale_And_Transform;
uniform float scale : hint_range(0.1, 1000.0, 0.1) = 1.0;
uniform float center_of_mass: hint_range(0.0, 1.0, 0.01) = 0.05;
uniform float bullet_extraction_mm : hint_range(0.0, 1000000.0, 0.1) = 0.0;

group_uniforms Cartridge_Dimensions;
uniform float land_diameter_mm       : hint_range(0.0, 20.0, 0.1) = 5.56;
uniform float bullet_diameter_mm     : hint_range(0.0, 20.0, 0.1) = 5.70;
uniform float case_length_mm         : hint_range(0.0, 100.0, 0.1) = 44.70;
uniform float overall_length_mm      : hint_range(0.0, 100.0, 0.1) = 57.40;
uniform float case_wall_thickness_mm : hint_range(0.0, 1.0, 0.0001) = 0.01;

group_uniforms Case.Geometry;
uniform float neck_diameter_mm     : hint_range(0.0, 20.0, 0.1) = 6.43;
uniform float shoulder_diameter_mm : hint_range(0.0, 20.0, 0.1) = 9.00;
uniform float head_diameter_mm     : hint_range(0.0, 20.0, 0.1) = 9.58;
uniform float rim_diameter_mm      : hint_range(0.0, 20.0, 0.1) = 9.60;
uniform float rim_thickness_mm     : hint_range(0.0, 20.0, 0.1) = 1.27;
uniform float primer_diameter_mm   : hint_range(0.0, 5.0, 0.01) = 3.00;
uniform float extractor_groove_diameter_mm : hint_range(0.0, 20.0, 0.1) = 8.0;

group_uniforms Case.Proportions;
uniform float neck_percent     : hint_range(0.0, 1.0, 0.01) = 0.90;
uniform float shoulder_percent : hint_range(0.0, 1.0, 0.01) = 0.85;
uniform float head_percent     : hint_range(0.0, 1.0, 0.01) = 0.20;
uniform float rim_roundness    : hint_range(0.0, 1.0, 0.01) = 0.5;

group_uniforms Case.Materials;
uniform vec4 case_color        : source_color = vec4(0.8, 0.6, 0.2, 1.0);
uniform vec4 primer_color      : source_color = vec4(0.37, 0.37, 0.43, 1.0);
uniform vec4 rim_color         : source_color = vec4(0.88, 0.66, 0.22, 1.0);
uniform vec4 rim_tint_color    : source_color = vec4(0.9, 0.3, 0.2, 1.0);
uniform float rim_tint_percent : hint_range(0.0,1.0,0.001) = 0.0;

uniform float case_metallic    : hint_range(0,1) = 0.8;
uniform float case_roughness   : hint_range(0,1) = 0.3;
uniform float primer_metallic  : hint_range(0,1) = 0.8;
uniform float primer_roughness : hint_range(0,1) = 0.3;
uniform float rim_metallic     : hint_range(0,1) = 0.8;
uniform float rim_roughness    : hint_range(0,1) = 0.3;

group_uniforms Bullet.Geometry;
uniform float ogive_radius_factor : hint_range(0.5, 5.0, 0.01) = 1.0;
uniform int tip_profile           : hint_enum("Cone","Tangent","Secant","Elliptical") = 1;
uniform float bullet_base_percent : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float bullet_tip_percent  : hint_range(0.0, 1.0, 0.01) = 0.7;

group_uniforms Bullet.Materials;
uniform vec4 bullet_color               : source_color = vec4(0.7, 0.4, 0.2, 1.0);
uniform vec4 bullet_tip_color           : source_color = vec4(0.9, 0.8, 0.7, 1.0);
uniform vec4 bullet_base_color          : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform float bullet_base_color_percent : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float bullet_tip_color_percent  : hint_range(0.0, 1.0, 0.01) = 0.7;

uniform float bullet_metallic  : hint_range(0,1) = 0.6;
uniform float bullet_roughness : hint_range(0,1) = 0.2;
uniform bool bullet_heat_with_distance_enable = true;
uniform float bullet_heat_proportion = 2.0;

group_uniforms Textures;
uniform sampler2D case_texture : source_color;
uniform sampler2D case_normal: hint_normal;
uniform float case_texture_scale_x: hint_range(0.0, 10.0, 0.01) = 1.0;
uniform float case_texture_scale_y: hint_range(0.0, 10.0, 0.01) = 1.0;
uniform sampler2D bullet_texture : source_color;
uniform sampler2D bullet_normal: hint_normal;
uniform float bullet_texture_scale_x: hint_range(0.0, 10.0, 0.01) = 1.0;
uniform float bullet_texture_scale_y: hint_range(0.0, 10.0, 0.01) = 1.0;
uniform sampler2D primer_texture : source_color;
uniform sampler2D primer_normal: hint_normal;
uniform float primer_texture_scale_x: hint_range(0.0, 10.0, 0.01) = 1.0;
uniform float primer_texture_scale_y: hint_range(0.0, 10.0, 0.01) = 1.0;
uniform sampler2D rim_texture : source_color;
uniform sampler2D rim_normal: hint_normal;
uniform float rim_texture_scale_x: hint_range(0.0, 10.0, 0.01) = 1.0;
uniform float rim_texture_scale_y: hint_range(0.0, 10.0, 0.01) = 1.0;

group_uniforms Wear_Aging;
uniform float wear_amount : hint_range(0,1) = 0.1;

// HELPER
float to_meters(float mm) { return mm * 0.001 * scale; }
float safe_div(float a, float b) { return a / max(b, EPS); }
float my_lerp(float a, float b, float t) { return mix(a,b,clamp(t,0.0,1.0)); }

//#include "tracer.gdshaderinc"
#include "uv-mapping.gdshaderinc"
#include "geometry.gdshaderinc"

#ifdef BULLET_PHYSICS
#include "physics.gdshaderinc"
#endif

#ifdef CARTRIDGE_STAMP
#include "stamp.gdshaderinc"
#endif

// ======================
// SURFACE TYPE DETECTION - nearest ring (unchanged semantics)
int get_surface_type(float parameter_t, CartridgeGeometry geo) {
  float extraction = to_meters(bullet_extraction_mm);
  if (extraction > EPS && is_in_gap_region(parameter_t, geo)) return SURFACE_TRACER;

  int nearest = get_nearest_ring(parameter_t, geo);

  if (nearest <= geo.primer_end) return SURFACE_PRIMER;
  if (nearest <= geo.rim_end)    return SURFACE_RIM;
  if (nearest >= geo.case_start   && nearest <= geo.case_end  ) return SURFACE_CASE;
  if (nearest >= geo.mouth_start  && nearest <= geo.mouth_end ) return SURFACE_CASE;
  if (nearest >= geo.gap_start    && nearest <= geo.gap_end   ) return SURFACE_TRACER;
  if (nearest >= geo.bullet_start && nearest <= geo.last_index) {
    int bullet_count = max(1, geo.last_index - geo.bullet_start + 1);
    float t = safe_div(float(nearest - geo.bullet_start), float(max(1, bullet_count - 1)));
    if (t < bullet_base_color_percent) return SURFACE_BULLET_BASE;
    if (t > bullet_tip_color_percent) return SURFACE_BULLET_TIP;
    return SURFACE_BULLET_BODY;
  }
  return SURFACE_CASE;
}

// ======================
// NORMAL CALCULATION
// ======================
vec3 calculate_surface_normal(CartridgeGeometry geo, float parameter_t, float angle, float overall_length) {
  // For gap regions, return radial normal
  if (is_in_gap_region(parameter_t, geo)) {
    return normalize(vec3(cos(angle), 0.0, sin(angle)));
  }
  float t_forward = min(parameter_t + EPS, 1.0);
  float t_backward = max(parameter_t - EPS, 0.0);
  vec2 pf = sample_display_profile(t_forward, geo);
  vec2 pb = sample_display_profile(t_backward, geo);

  float dy = pf.x - pb.x;
  float dr = pf.y - pb.y;

  if (abs(dy) < EPS) return normalize(vec3(cos(angle), 0.0, sin(angle)));

  float dr_dy = dr / dy;
  vec3 n = normalize(vec3(cos(angle), -dr_dy, sin(angle)));
  vec3 radial = vec3(cos(angle), 0.0, sin(angle));
  if (dot(n, radial) < 0.0) n = -n;
  return n;
}

// ======================
// VERTEX
void vertex() {
  // Compute boundaries once
  CartridgeGeometry geo = compute_geometry_boundaries();
  
  float parameter_t = UV.x;
  float angle = UV.y * 2.0 * TAU;

  vec2 profile = sample_display_profile(parameter_t, geo);
  float radius = profile.y;
  float display_y = profile.x;

  float overall_length = to_meters(overall_length_mm);
  float extraction = to_meters(bullet_extraction_mm);
  float total_display_length = overall_length + extraction;
  float center_offset = center_of_mass * total_display_length;
  float y_pos = display_y - center_offset;

  vec3 base_vertex = vec3(cos(angle) * radius, y_pos, sin(angle) * radius);
#ifdef BULLET_PHYSICS
	apply_bullet_physics(base_vertex, profile, parameter_t, geo);
#endif
  VERTEX = base_vertex;
  NORMAL = calculate_surface_normal(geo, parameter_t, angle, overall_length);

  // Store the model space position for circular UV mapping
  model_space_position = base_vertex;
}

#ifndef DEBUG
// ======================
// FRAGMENT
// We now use circular UV mapping for primer and rim surfaces
void fragment() {
  // Compute boundaries once (in case vertex shader doesn't run)
  CartridgeGeometry geo = compute_geometry_boundaries();
  
  float parameter_t = UV.x;
  int surface_type = get_surface_type(parameter_t, geo);

  vec2 detail_uv;

  if (surface_type == SURFACE_PRIMER) {
      // Use improved circular mapping for primer
      vec2 detail_uv = detail_uv_circular(UV, model_space_position, primer_diameter_mm, primer_texture_scale_x, primer_texture_scale_y);
      vec3 texture_sample = texture(primer_texture, detail_uv).rgb;
      vec3 normal_sample = texture(primer_normal, detail_uv).rgb;
      ALBEDO = primer_color.rgb * texture_sample;
      ALPHA = primer_color.a;
      METALLIC = primer_metallic;
      ROUGHNESS = primer_roughness + wear_amount * 0.4;
      NORMAL = normalize(NORMAL + normal_sample);

#ifdef CARTRIDGE_STAMP
      // Apply primer bevel
      apply_primer_bevel(NORMAL, model_space_position, primer_diameter_mm);
#endif
  }
  else if (surface_type == SURFACE_RIM) {
      // Use improved rim mapping that handles bottom and sides
      vec2 detail_uv = detail_uv_rim(UV, model_space_position, rim_diameter_mm, rim_thickness_mm, rim_texture_scale_x, rim_texture_scale_y);
      vec3 texture_sample = texture(rim_texture, detail_uv).rgb;
      vec3 normal_sample = texture(rim_normal, detail_uv).rgb;
      vec3 base_albedo = rim_color.rgb * texture_sample;
      ALBEDO = mix(base_albedo, rim_tint_color.rgb, rim_tint_percent);
      ALPHA = mix(rim_color.a, rim_tint_color.a, rim_tint_percent);
      METALLIC = mix(rim_metallic, rim_metallic + 0.2 * rim_tint_percent, rim_tint_percent);
      ROUGHNESS = mix(rim_roughness, max(0.01, rim_roughness + 0.4 * rim_tint_percent), rim_tint_percent) + wear_amount * 0.2;
      NORMAL = normalize(NORMAL + normal_sample);

#ifdef CARTRIDGE_STAMP
      // Apply rim bevel
      apply_rim_bevel(NORMAL, model_space_position, rim_diameter_mm, rim_thickness_mm);
#endif
  }
  else if (surface_type == SURFACE_CASE) {
    vec2 detail_uv = detail_uv_cylindrical(UV.x, UV.y, case_texture_scale_x, case_texture_scale_y);
    vec3 texture_sample = texture(case_texture, detail_uv).rgb;
    vec3 normal_sample = texture(case_normal, detail_uv).rgb;
    ALBEDO = case_color.rgb * texture_sample;
    ALPHA = case_color.a;
    METALLIC = case_metallic;
    ROUGHNESS = case_roughness + wear_amount * 0.3;
    NORMAL = normalize(NORMAL + normal_sample);
  }
  else if (surface_type == SURFACE_BULLET_BASE) {
    vec2 detail_uv = detail_uv_cylindrical(UV.x, UV.y, bullet_texture_scale_x, bullet_texture_scale_y);
    vec3 texture_sample = texture(bullet_texture, detail_uv).rgb;
    vec3 normal_sample = texture(bullet_normal, detail_uv).rgb;
    ALBEDO = bullet_base_color.rgb * texture_sample;
    ALPHA = bullet_base_color.a;
    METALLIC = 0.1;
    ROUGHNESS = 0.8;
    NORMAL = normalize(NORMAL + normal_sample);
  }
  else if (surface_type == SURFACE_BULLET_BODY) {
    vec2 detail_uv = detail_uv_cylindrical(UV.x, UV.y, bullet_texture_scale_x, bullet_texture_scale_y);
    vec3 texture_sample = texture(bullet_texture, detail_uv).rgb;
    vec3 normal_sample = texture(bullet_normal, detail_uv).rgb;
    ALBEDO = bullet_color.rgb * texture_sample;
    ALPHA = bullet_color.a;
    METALLIC = bullet_metallic;
    ROUGHNESS = bullet_roughness + wear_amount * 0.2;
    NORMAL = normalize(NORMAL + normal_sample);
  }
  else if (surface_type == SURFACE_BULLET_TIP) {
    vec2 detail_uv = detail_uv_cylindrical(UV.x, UV.y, bullet_texture_scale_x, bullet_texture_scale_y);
    vec3 texture_sample = texture(bullet_texture, detail_uv).rgb;
    vec3 normal_sample = texture(bullet_normal, detail_uv).rgb;
    ALBEDO = bullet_color.rgb * texture_sample;
    ALPHA = bullet_tip_color.a;
    METALLIC = bullet_metallic;
    ROUGHNESS = bullet_roughness;
    NORMAL = normalize(NORMAL + normal_sample);
  }
#ifdef ENABLE_TRACER
  else if (surface_type == SURFACE_TRACER) {
    float tracer_pos = get_tracer_position(parameter_t, geo);
    float tracer_intensity = calculate_tracer_intensity(parameter_t, geo);
    float pulse = 0.5 + 0.5 * sin(TIME * tracer_pulse_speed + tracer_pos * TAU);

    ALBEDO = tracer_color.rgb * (0.9 + 0.1 * sin(tracer_pos * 20.0 + TIME * 2.0));
    ALPHA = tracer_color.a * tracer_intensity;
    EMISSION = tracer_color.rgb * tracer_emission_energy * (0.7 + 0.3 * pulse) * tracer_intensity;
    METALLIC = 0.0;
    ROUGHNESS = 0.1;
  }

  // Bullet heat emission (smooth)
  bool is_bullet_surface = (surface_type == SURFACE_BULLET_BASE) || (surface_type == SURFACE_BULLET_BODY) || (surface_type == SURFACE_BULLET_TIP);
  if (bullet_heat_with_distance_enable && is_bullet_surface) {
    EMISSION += get_heat_with_distance(surface_type, parameter_t, geo);
  }
#endif
  else if (surface_type == SURFACE_TRACER) {
    ALPHA = 0.0;
  }

#ifdef CARTRIDGE_STAMP
  if (surface_type == SURFACE_PRIMER || surface_type == SURFACE_RIM) {
    // Apply procedural stamp
    apply_stamp(ROUGHNESS, ALBEDO, NORMAL, model_space_position, to_meters(rim_diameter_mm) * 0.5, surface_type);
  }
#endif

  // subtle length gradient
  ALBEDO *= (0.8 + 0.2 * UV.x);
}
#else
#include "debug.gdshaderinc"
#endif

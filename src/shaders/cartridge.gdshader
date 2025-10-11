shader_type spatial;
render_mode cull_front, depth_draw_always;
//#define DEBUG

// ======================
const float EPS = 1e-6;

// Surface type constants
const int SURFACE_DISCARD = -1;
const int SURFACE_PRIMER = 0;
const int SURFACE_RIM = 1;
const int SURFACE_CASE = 2;
const int SURFACE_BULLET_BASE = 3;
const int SURFACE_BULLET_BODY = 4;
const int SURFACE_BULLET_TIP = 5;
const int SURFACE_TRACER = 6;

// ======================
// UNIFORMS (kept from your shader)
group_uniforms Mesh;
uniform int mesh_segments_length = 64;
uniform int mesh_segments_circumference = 64;
uniform int gap_segments = 2;

group_uniforms Scale_And_Transform;
uniform float scale : hint_range(0.1, 1000.0, 0.1) = 1.0;
uniform float center_of_mass: hint_range(0.0, 1.0, 0.01) = 0.05;
uniform float bullet_extraction_mm : hint_range(0.0, 1000000.0, 0.1) = 0.0;

uniform float muzzle_velocity_ms : hint_range(100.0, 2000.0, 1.0) = 800.0;
uniform float bullet_drop_ms2 : hint_range(0.0, 20.0, 0.1) = 9.81;
uniform float wind_velocity_ms : hint_range(-100.0, 100.0, 0.1) = 0.0;
uniform float zero_range_m : hint_range(0.0, 1000.0, 1.0) = 100.0;
uniform float ballistic_coefficient : hint_range(0.1, 1.0, 0.01) = 0.5;

group_uniforms Cartridge_Dimensions;
uniform float land_diameter_mm : hint_range(0.0, 20.0, 0.1) = 5.56;
uniform float bullet_diameter_mm : hint_range(0.0, 20.0, 0.1) = 5.70;
uniform float case_length_mm : hint_range(0.0, 100.0, 0.1) = 44.70;
uniform float overall_length_mm : hint_range(0.0, 100.0, 0.1) = 57.40;

group_uniforms Case_Geometry;
uniform float neck_diameter_mm : hint_range(0.0, 20.0, 0.1) = 6.43;
uniform float shoulder_diameter_mm : hint_range(0.0, 20.0, 0.1) = 9.00;
uniform float head_diameter_mm : hint_range(0.0, 20.0, 0.1) = 9.58;
uniform float rim_diameter_mm : hint_range(0.0, 20.0, 0.1) = 9.60;
uniform float rim_thickness_mm : hint_range(0.0, 20.0, 0.1) = 1.27;
uniform float primer_diameter_mm : hint_range(0.0, 5.0, 0.01) = 3.00;
uniform float extractor_groove_diameter_mm : hint_range(0.0, 20.0, 0.1) = 8.0;

group_uniforms Case_Proportions;
uniform float neck_percent : hint_range(0.0, 1.0, 0.01) = 0.90;
uniform float shoulder_percent : hint_range(0.0, 1.0, 0.01) = 0.85;
uniform float rim_roundness : hint_range(0.0, 1.0, 0.01) = 0.5;

group_uniforms Case_Materials;
uniform vec4 case_color : source_color = vec4(0.8, 0.6, 0.2, 1.0);
uniform vec4 primer_color : source_color = vec4(0.3, 0.3, 0.35, 1.0);
uniform vec4 rim_color : source_color = vec4(0.88, 0.66, 0.22, 1.0);
uniform vec4 rim_tint_color : source_color = vec4(0.9, 0.3, 0.2, 1.0);
uniform float rim_tint_percent : hint_range(0.0,1.0,0.001) = 0.0;

uniform float case_metallic : hint_range(0,1) = 0.8;
uniform float case_roughness : hint_range(0,1) = 0.3;
uniform float primer_metallic : hint_range(0,1) = 0.3;
uniform float primer_roughness : hint_range(0,1) = 0.7;
uniform float rim_metallic : hint_range(0,1) = 0.3;
uniform float rim_roughness : hint_range(0,1) = 0.7;
uniform float case_wall_thickness_mm : hint_range(0.0, 5.0, 0.01) = 0.0;

group_uniforms Bullet_Geometry;
uniform float ogive_radius_factor : hint_range(0.5, 5.0, 0.01) = 1.0;
uniform int tip_profile : hint_enum("Cone","Tangent","Secant","Elliptical") = 1;
uniform float bullet_base_percent : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float bullet_tip_percent : hint_range(0.0, 1.0, 0.01) = 0.7;

group_uniforms Bullet_Materials;
uniform vec4 bullet_color : source_color = vec4(0.7, 0.4, 0.2, 1.0);
uniform vec4 bullet_tip_color : source_color = vec4(0.9, 0.8, 0.7, 1.0);
uniform vec4 bullet_base_color : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform float bullet_base_color_percent : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float bullet_tip_color_percent : hint_range(0.0, 1.0, 0.01) = 0.7;

uniform float bullet_metallic : hint_range(0,1) = 0.6;
uniform float bullet_roughness : hint_range(0,1) = 0.2;
uniform bool bullet_heat_with_distance_enable = true;
uniform float bullet_heat_proportion = 2.0;

group_uniforms Tracer;
uniform bool tracer_enable = true;
uniform vec4 tracer_color : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform float tracer_emission_energy : hint_range(0.0, 10.0, 0.1) = 1.0;
uniform float tracer_radius_percent : hint_range(0.0, 1.0, 0.1) = 0.5;
uniform float tracer_pulse_speed : hint_range(0.0, 10.0, 0.1) = 1.0;
uniform float tracer_start_mm : hint_range(0.0, 1000.0, 1.0) = 100.0;
uniform float tracer_length_mm : hint_range(0.0, 2000.0, 1.0) = 500.0;
uniform float tracer_power : hint_range(0.1, 3.0, 0.1) = 1.5;

group_uniforms Textures;
uniform sampler2D case_texture : source_color;
uniform sampler2D bullet_texture : source_color;
uniform sampler2D primer_texture : source_color;
uniform sampler2D rim_texture : source_color;

group_uniforms UV_Controls;
uniform float uv_scale_x: hint_range(0.0, 100.0, 0.01) = 1.0;
uniform float uv_scale_y: hint_range(0.0, 100.0, 0.01) = 1.0;

group_uniforms Wear_Aging;
uniform float wear_amount : hint_range(0,1) = 0.1;

// ======================
// HELPERS
float to_meters(float mm) { return mm * 0.001 * scale; }
float safe_div(float a, float b) { return a / max(b, EPS); }
float my_lerp(float a, float b, float t) { return mix(a,b,clamp(t,0.0,1.0)); }
vec2 detail_uv_from_uv(vec2 uv) { return vec2(uv.y * float(mesh_segments_circumference) * uv_scale_x, uv.x * uv_scale_y); }

// ======================
// BOUNDARIES & RING ALLOCATION (same approach you used)
void compute_boundaries(out int primer_end, out int case_start, out int case_end, out int rim_end_local,
                        out int head_end_local, out int shoulder_end_local, out int neck_end_local,
                        out int mouth_start, out int mouth_end, out int gap_start, out int gap_end, out int bullet_start, out int last_index) {
    int subdivisions = max(2, mesh_segments_length);

    last_index = subdivisions - 1;

    int primer_count = 1;
    int mouth_count = 2;
    int gap_count = (to_meters(bullet_extraction_mm) > EPS) ? max(2, gap_segments) : 0;

    int reserved = primer_count + mouth_count + gap_count;
    int remaining = subdivisions - reserved;
    remaining = max(8, remaining);

    float case_len = to_meters(case_length_mm);
    float overall_len = to_meters(overall_length_mm);
    float bullet_len = max(EPS, overall_len - case_len);
    float total_len = max(EPS, case_len + bullet_len);
    float case_ratio = safe_div(case_len, total_len);

    int case_count = int(max(4.0, floor(float(remaining) * case_ratio + 0.5)));
    int bullet_count = remaining - case_count;
    bullet_count = max(4, bullet_count);

    primer_end = primer_count - 1;
    case_start = primer_end + 1;
    case_end = case_start + case_count - 1;
    mouth_start = case_end + 1;
    mouth_end = mouth_start + mouth_count - 1;
    gap_start = mouth_end + 1;
    gap_end = gap_start + gap_count - 1;
    bullet_start = gap_end + 1;

    if (bullet_start > last_index) {
        gap_end = max(gap_start, last_index - 4);
        bullet_start = gap_end + 1;
    }
    if (mouth_start > last_index) mouth_start = last_index;
    if (case_end >= mouth_start) case_end = max(case_start, mouth_start - 1);

    int case_rings = max(1, case_end - case_start + 1);
    int rim_rings = max(1, int(round(0.1 * float(case_rings))));
    int groove_rings = max(1, int(round(0.1 * float(case_rings))));
    int head_rings = max(1, int(round(0.1 * float(case_rings))));
    int shoulder_rings = max(1, int(round(0.4 * float(case_rings))));
    int neck_rings = max(1, case_rings - (rim_rings + groove_rings + head_rings + shoulder_rings));

    int idx = case_start;
    rim_end_local = idx + rim_rings - 1; idx = rim_end_local + 1;
    int groove_end_local = idx + groove_rings - 1; idx = groove_end_local + 1;
    head_end_local = idx + head_rings - 1; idx = head_end_local + 1;
    shoulder_end_local = idx + shoulder_rings - 1; idx = shoulder_end_local + 1;
    neck_end_local = idx + neck_rings - 1;
}

// ======================
// per-ring display profile
vec2 profile_display_for_ring(int idx) {
    int primer_end, case_start, case_end, rim_end_local, head_end_local, shoulder_end_local, neck_end_local, mouth_start, mouth_end, gap_start, gap_end, bullet_start, last_index;
    compute_boundaries(primer_end, case_start, case_end, rim_end_local, head_end_local, shoulder_end_local, neck_end_local, mouth_start, mouth_end, gap_start, gap_end, bullet_start, last_index);
    float case_length = to_meters(case_length_mm);
    float overall_length = to_meters(overall_length_mm);
    float bullet_length = max(EPS, overall_length - case_length);
    float extraction = to_meters(bullet_extraction_mm);

    float primer_r = to_meters(primer_diameter_mm) * 0.5;
    float rim_r = to_meters(rim_diameter_mm) * 0.5;
    float head_r = to_meters(head_diameter_mm) * 0.5;
    float shoulder_r = to_meters(shoulder_diameter_mm) * 0.5;
    float neck_r = to_meters(neck_diameter_mm) * 0.5;
    float bullet_r = to_meters(bullet_diameter_mm) * 0.5;
    float rim_thick = to_meters(rim_thickness_mm);
    float wall_thick = (case_wall_thickness_mm <= 0.0) ? max(0.0001, neck_r * 0.25) : to_meters(case_wall_thickness_mm);

    // Primer
    if (idx <= primer_end) return vec2(0.0, 0.0);

    // Case block
    if (idx >= case_start && idx <= case_end) {
        float case_block_len = float(case_end - case_start + 1);
        float local = float(idx - case_start) / max(1.0, case_block_len - 1.0);

        // rim
        int rim_count = max(1, rim_end_local - case_start + 1);
        float rim_cut = float(rim_count) / max(1.0, case_block_len);
        if (local <= rim_cut) {
            float t = safe_div(local, rim_cut);
            float y = my_lerp(0.0, rim_thick, t);
            float semicircle = sin(t * PI);
            float bulge_sign = (rim_roundness - 0.5) * 2.0;
            float bulge = semicircle * (rim_thick * 0.5) * bulge_sign;
            float r = rim_r + bulge;
            return vec2(y, max(EPS, r));
        }

        // extractor groove
        float groove_start = rim_cut;
        float groove_end = groove_start + 0.1;
        if (local <= groove_end) {
            float t = safe_div(local - groove_start, groove_end - groove_start);
            float y0 = rim_thick;
            float y1 = rim_thick + to_meters(1.0);
            float y = my_lerp(y0, y1, t);
            float groove_r = to_meters(extractor_groove_diameter_mm) * 0.5;
            float r = my_lerp(rim_r, groove_r, t);
            return vec2(y, max(EPS, r));
        }

        // head/body
        float head_start = groove_end;
        float head_end = clamp(shoulder_percent, head_start + 0.001, 0.95);
        if (local <= head_end) {
            float t = safe_div(local - head_start, head_end - head_start);
            float y0 = rim_thick + to_meters(1.0);
            float y1 = case_length * shoulder_percent;
            float y = my_lerp(y0, y1, t);
            float r = my_lerp(head_r, shoulder_r, t);
            return vec2(y, max(EPS, r));
        }

        // shoulder
        float shoulder_start_frac = head_end;
        float shoulder_end_frac = clamp(neck_percent, shoulder_start_frac + 0.001, 0.999);
        if (local <= shoulder_end_frac) {
            float t = safe_div(local - shoulder_start_frac, shoulder_end_frac - shoulder_start_frac);
            float y0 = case_length * shoulder_percent;
            float y1 = case_length * neck_percent;
            float y = my_lerp(y0, y1, t);
            float r = my_lerp(shoulder_r, neck_r, t);
            return vec2(y, max(EPS, r));
        }

        // neck
        {
            float t = safe_div(local - shoulder_end_frac, 1.0 - shoulder_end_frac);
            float y0 = case_length * neck_percent;
            float y1 = case_length;
            float y = my_lerp(y0, y1, t);
            float r_outer = neck_r;
            return vec2(y, max(EPS, r_outer));
        }
    }

    // Mouth region (internal)
    if (idx >= mouth_start && idx <= mouth_end) {
        float neck_outer = to_meters(neck_diameter_mm) * 0.5;
        float wall_thick_local = (case_wall_thickness_mm <= 0.0) ? neck_outer * 0.25 : to_meters(case_wall_thickness_mm);
        float mouth_inner_radius = max(EPS, neck_outer - wall_thick_local);
        float mouth_t = float(idx - mouth_start) / float(max(1, mouth_end - mouth_start));
        float y = mix(to_meters(case_length_mm), to_meters(rim_thickness_mm), mouth_t);
        return vec2(y, mouth_inner_radius);
    }

    // Gap region
    if (idx >= gap_start && idx <= gap_end) {
        int gap_count = max(2, gap_segments);
        float t = safe_div(float(idx - gap_start), float(max(1, gap_count - 1)));
        float y = to_meters(case_length_mm) + t * to_meters(bullet_extraction_mm);
        float r = to_meters(bullet_diameter_mm) * 0.5 * tracer_radius_percent;
        return vec2(y, max(EPS, r));
    }

    // Bullet region
    if (idx >= bullet_start && idx <= last_index) {
        float case_length = to_meters(case_length_mm);
        float overall_length = to_meters(overall_length_mm);
        float bullet_length = max(EPS, overall_length - case_length);

        int bullet_count = max(1, last_index - bullet_start + 1);
        float t = safe_div(float(idx - bullet_start), float(max(1, bullet_count - 1)));
        float y = case_length + to_meters(bullet_extraction_mm) + t * bullet_length;

        float base_section_length = bullet_length * bullet_base_percent;
        float current_pos = t * bullet_length;
        float rad = to_meters(bullet_diameter_mm) * 0.5;

        if (current_pos < base_section_length) return vec2(y, rad);

        float ogive_len = max(EPS, bullet_length - base_section_length);
        float ogive_pos = safe_div(current_pos - base_section_length, ogive_len);

        if (tip_profile == 0) {
            float tip_start = bullet_tip_percent;
            if (ogive_pos > tip_start) rad = my_lerp(rad, EPS, safe_div((ogive_pos - tip_start), (1.0 - tip_start)));
        } else if (tip_profile == 1) {
            float base_radius = rad;
            float R = (ogive_len * ogive_len + base_radius * base_radius) / (2.0 * base_radius) * ogive_radius_factor;
            float x = ogive_len * (1.0 - ogive_pos);
            float radicand = R * R - (ogive_len - x) * (ogive_len - x);
            rad = (radicand <= 0.0) ? EPS : max(EPS, sqrt(radicand) - (R - base_radius));
        } else if (tip_profile == 2) {
            float base_radius = rad * 0.9;
            float R = (ogive_len * ogive_len + base_radius * base_radius) / (2.0 * base_radius) * ogive_radius_factor;
            float x = ogive_len * (1.0 - ogive_pos);
            float radicand = R * R - (ogive_len - x) * (ogive_len - x);
            rad = (radicand <= 0.0) ? EPS : max(EPS, sqrt(radicand) - (R - base_radius));
        } else {
            float base_radius = rad;
            rad = base_radius * sqrt(max(EPS, 1.0 - ogive_pos * ogive_pos));
        }

        return vec2(y, max(EPS, rad));
    }

    return vec2(0.0, EPS);
}

// ======================
// collapsed original (used for surface type detection)
vec2 profile_original_for_ring(int idx) {
    int primer_end, case_start, case_end, rim_end_local, head_end_local, shoulder_end_local, neck_end_local, mouth_start, mouth_end, gap_start, gap_end, bullet_start, last_index;
    compute_boundaries(primer_end, case_start, case_end, rim_end_local, head_end_local, shoulder_end_local, neck_end_local, mouth_start, mouth_end, gap_start, gap_end, bullet_start, last_index);
    vec2 d = profile_display_for_ring(idx);
    float extraction = to_meters(bullet_extraction_mm);
    float case_length = to_meters(case_length_mm);

    if (idx >= gap_start && idx <= gap_end) {
        float neck_r = to_meters(neck_diameter_mm) * 0.5;
        return vec2(case_length, neck_r);
    }
    if (idx >= bullet_start) {
        return vec2(max(0.0, d.x - extraction), d.y);
    }
    return d;
}

// ======================
// IMPORTANT FIX: sampling by parameter_t
// When we cross a region boundary where one ring is gap and the other not,
// we should NOT mix the two profiles (it causes geometry/texture bleeding).
// Instead pick the nearest ring profile in that case.
vec2 sample_display_profile(float parameter_t) {
    int subdivisions = max(2, mesh_segments_length);

    float f = clamp(parameter_t, 0.0, 1.0) * float(subdivisions - 1);
    int a = int(floor(f));
    int b = min(subdivisions - 1, a + 1);
    float local = f - float(a);

    vec2 pa = profile_display_for_ring(a);
    vec2 pb = profile_display_for_ring(b);

    // compute whether each ring is gap
    int primer_end, case_start, case_end, rim_end_local, head_end_local, shoulder_end_local, neck_end_local, mouth_start, mouth_end, gap_start, gap_end, bullet_start, last_index;
    compute_boundaries(primer_end, case_start, case_end, rim_end_local, head_end_local, shoulder_end_local, neck_end_local, mouth_start, mouth_end, gap_start, gap_end, bullet_start, last_index);
    //bool a_is_gap = (a >= gap_start && a <= gap_end);
    //bool b_is_gap = (b >= gap_start && b <= gap_end);
//
    //// If crossing gap boundary, choose nearest ring's profile (no interpolation)
    //if (a_is_gap != b_is_gap) {
        //return (local < 0.5) ? pa : pb;
    //}

    // Otherwise safe to interpolate
    return mix(pa, pb, local);
}

vec2 sample_original_profile(float parameter_t) {
    int subdivisions = max(2, mesh_segments_length);

    float f = clamp(parameter_t, 0.0, 1.0) * float(subdivisions - 1);
    int a = int(floor(f));
    int b = min(subdivisions - 1, a + 1);
    float local = f - float(a);

    vec2 pa = profile_original_for_ring(a);
    vec2 pb = profile_original_for_ring(b);

    int primer_end, case_start, case_end, rim_end_local, head_end_local, shoulder_end_local, neck_end_local, mouth_start, mouth_end, gap_start, gap_end, bullet_start, last_index;
    compute_boundaries(primer_end, case_start, case_end, rim_end_local, head_end_local, shoulder_end_local, neck_end_local, mouth_start, mouth_end, gap_start, gap_end, bullet_start, last_index);
    bool a_is_gap = (a >= gap_start && a <= gap_end);
    bool b_is_gap = (b >= gap_start && b <= gap_end);

    if (a_is_gap != b_is_gap) {
        return (local < 0.5) ? pa : pb;
    }
    return mix(pa, pb, local);
}

// wrappers
float get_display_position(float parameter_t) { return sample_display_profile(parameter_t).x; }
float get_original_position(float parameter_t) { return sample_original_profile(parameter_t).x; }

// improved is_in_gap_region: use nearest ring index (not floor without +0.5)
bool is_in_gap_region(float parameter_t) {
    if (to_meters(bullet_extraction_mm) < EPS) return false;
    int subdivisions = max(2, mesh_segments_length);

    float f = clamp(parameter_t, 0.0, 1.0) * float(subdivisions - 1);
    int segment_index = int(floor(f + 0.5)); // nearest
    int primer_end, case_start, case_end, rim_end_local, head_end_local, shoulder_end_local, neck_end_local, mouth_start, mouth_end, gap_start, gap_end, bullet_start, last_index;
    compute_boundaries(primer_end, case_start, case_end, rim_end_local, head_end_local, shoulder_end_local, neck_end_local, mouth_start, mouth_end, gap_start, gap_end, bullet_start, last_index);
    return (segment_index >= gap_start && segment_index <= gap_end);
}

// improved tracer position / intensity using world positions (smooth and scale-independent)
float get_tracer_position(float parameter_t) {
    // returns normalized [0..1] along gap (0 at case mouth, 1 at bullet bottom)
    int subdivisions = max(2, mesh_segments_length);

    float f = clamp(parameter_t, 0.0, 1.0) * float(subdivisions - 1);
    int segment_index = int(floor(f + 0.5));
    int primer_end, case_start, case_end, rim_end_local, head_end_local, shoulder_end_local, neck_end_local, mouth_start, mouth_end, gap_start, gap_end, bullet_start, last_index;
    compute_boundaries(primer_end, case_start, case_end, rim_end_local, head_end_local, shoulder_end_local, neck_end_local, mouth_start, mouth_end, gap_start, gap_end, bullet_start, last_index);

    if (!(segment_index >= gap_start && segment_index <= gap_end)) {
        // fallback: compute by mapping world position into gap range
        float case_length = to_meters(case_length_mm);
        float extraction = to_meters(bullet_extraction_mm);
        if (extraction < EPS) return 0.0;
        float world_pos = get_display_position(parameter_t);
        float gap_start_world = case_length;
        float gap_end_world = case_length + extraction;
        return clamp((world_pos - gap_start_world) / max(EPS, gap_end_world - gap_start_world), 0.0, 1.0);
    }

    // compute using world positions for accuracy
    float case_length = to_meters(case_length_mm);
    float extraction = to_meters(bullet_extraction_mm);
    float world_pos = get_display_position(parameter_t);
    float gap_start_world = case_length;
    float gap_end_world = case_length + extraction;
    return clamp((world_pos - gap_start_world) / max(EPS, gap_end_world - gap_start_world), 0.0, 1.0);
}

// calculate tracer intensity using world-space interval + smoothfalloff
float calculate_tracer_intensity(float parameter_t) {
    if (!tracer_enable) return 0.0;
    float extraction = to_meters(bullet_extraction_mm);
    if (extraction < EPS) return 0.0;
    if (!is_in_gap_region(parameter_t)) return 0.0;

    float world_pos = get_display_position(parameter_t);
    float case_length = to_meters(case_length_mm);
    float bullet_base_pos = case_length + extraction;
    float tracer_start_from_bullet = to_meters(tracer_start_mm);
    float tracer_length = to_meters(tracer_length_mm);

    // ignition point (world coord)
    float tracer_ignition_point = bullet_base_pos - tracer_start_from_bullet;
    float tracer_end_world = tracer_ignition_point - tracer_length;
    // quick reject
    if (world_pos > tracer_ignition_point || world_pos < tracer_end_world) return 0.0;

    // normalized position along tracer (0..1), 0 at end, 1 at ignition
    float tracer_normalized = clamp((tracer_ignition_point - world_pos) / max(EPS, tracer_length), 0.0, 1.0);

    // pulse (smooth)
    float tracer_pos = get_tracer_position(parameter_t);
    float pulse = 0.5 + 0.5 * sin(TIME * tracer_pulse_speed + tracer_pos * TAU);
    // falloff using power but ensure smoothness
    float fall = pow(1.0 - tracer_normalized, tracer_power);

    return clamp((0.7 + 0.3 * pulse) * fall, 0.0, 1.0);
}

// ======================
// SURFACE TYPE DETECTION (nearest ring)
int get_surface_type(float parameter_t) {
    float extraction = to_meters(bullet_extraction_mm);
    if (extraction > EPS && is_in_gap_region(parameter_t)) {
        return SURFACE_TRACER;
    }

    int subdivisions = max(2, mesh_segments_length);

    float f = clamp(parameter_t, 0.0, 1.0) * float(subdivisions - 1);
    int nearest = int(floor(f + 0.5));

    int primer_end, case_start, case_end, rim_end_local, head_end_local, shoulder_end_local, neck_end_local, mouth_start, mouth_end, gap_start, gap_end, bullet_start, last_index;
    compute_boundaries(primer_end, case_start, case_end, rim_end_local, head_end_local, shoulder_end_local, neck_end_local, mouth_start, mouth_end, gap_start, gap_end, bullet_start, last_index);

    if (nearest <= primer_end) return SURFACE_PRIMER;
    if (nearest <= rim_end_local) return SURFACE_RIM;
    if (nearest >= case_start && nearest <= case_end) return SURFACE_CASE;
    if (nearest >= mouth_start && nearest <= mouth_end) return SURFACE_TRACER; // FIXME Ugly hack
    if (nearest >= gap_start && nearest <= gap_end) return SURFACE_TRACER;
    if (nearest >= bullet_start && nearest <= last_index) {
        int bullet_count = max(1, last_index - bullet_start + 1);
        float t = safe_div(float(nearest - bullet_start), float(max(1, bullet_count - 1)));
        if (t < bullet_base_color_percent) return SURFACE_BULLET_BASE;
        if (t > bullet_tip_color_percent) return SURFACE_BULLET_TIP;
        return SURFACE_BULLET_BODY;
    }
    return SURFACE_CASE;
}

// ======================
// Heat helper (kept logic but slightly smoothed)
vec3 get_heat_with_distance(int surface_type, float parameter_t) {
    float overall_heat = clamp(bullet_extraction_mm/(bullet_heat_proportion * case_length_mm), 0.0, 1.0);

    float bullet_pos = 0.0;
    if (surface_type == SURFACE_BULLET_BASE) bullet_pos = 0.0;
    else if (surface_type == SURFACE_BULLET_BODY) {
        int subdivisions = max(2, mesh_segments_length);

        float f = clamp(parameter_t, 0.0, 1.0) * float(subdivisions - 1);
        int nearest = int(floor(f + 0.5));
        int primer_end, case_start, case_end, rim_end_local, head_end_local, shoulder_end_local, neck_end_local, mouth_start, mouth_end, gap_start, gap_end, bullet_start, last_index;
        compute_boundaries(primer_end, case_start, case_end, rim_end_local, head_end_local, shoulder_end_local, neck_end_local, mouth_start, mouth_end, gap_start, gap_end, bullet_start, last_index);
        int bullet_count = max(1, last_index - bullet_start + 1);
        float t = safe_div(float(nearest - bullet_start), float(max(1, bullet_count - 1)));
        float body_start = bullet_base_color_percent;
        float body_end = bullet_tip_color_percent;
        if (t < body_start) bullet_pos = 0.0;
        else if (t > body_end) bullet_pos = 1.0;
        else bullet_pos = (t - body_start) / max(EPS, (body_end - body_start));
    } else if (surface_type == SURFACE_BULLET_TIP) bullet_pos = 1.0;

    float heat_threshold = 1.0 - overall_heat;
    if (bullet_pos <= heat_threshold) return vec3(0.0);
    float heat_depth = (bullet_pos - heat_threshold) / max(EPS, 1.0 - heat_threshold);
    heat_depth = clamp(heat_depth, 0.0, 1.0);
    float tracer_pos = get_tracer_position(parameter_t);
    float pulse = 0.5 + 0.5 * sin(TIME * tracer_pulse_speed + tracer_pos * TAU);
    float heat_intensity = overall_heat * heat_depth;
    return tracer_color.rgb * tracer_emission_energy * (0.7 + 0.3 * pulse) * heat_intensity;
}

// ======================
// NORMALS
vec3 calculate_surface_normal(float parameter_t, float angle, float overall_length) {
    if (is_in_gap_region(parameter_t)) return normalize(vec3(cos(angle), 0.0, sin(angle)));

    float t_forward = min(parameter_t + 1.0e-3, 1.0);
    float t_backward = max(parameter_t - 1.0e-3, 0.0);
    vec2 pf = sample_display_profile(t_forward);
    vec2 pb = sample_display_profile(t_backward);

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
    float parameter_t = UV.x;
    float angle = UV.y * 2.0 * TAU;

    vec2 profile = sample_display_profile(parameter_t);
    float radius = profile.y;
    float display_y = profile.x;

    float overall_length = to_meters(overall_length_mm);
    float extraction = to_meters(bullet_extraction_mm);
    float total_display_length = overall_length + extraction;
    float center_offset = center_of_mass * total_display_length;
    float y_pos = display_y - center_offset;

    vec3 base_vertex = vec3(cos(angle) * radius, y_pos, sin(angle) * radius);

    // NOTE: ballistic code was commented out in your last version; re-enable if desired.
    VERTEX = base_vertex;
    NORMAL = calculate_surface_normal(parameter_t, angle, overall_length);
}

// ======================
// FRAGMENT
// ======================
#ifndef DEBUG
void fragment() {
    float parameter_t = UV.x;
    vec2 detail_uv = detail_uv_from_uv(UV);
    int surface_type = get_surface_type(parameter_t);

    ALBEDO = vec3(0.5);
    ALPHA = 1.0;
    METALLIC = 0.0;
    ROUGHNESS = 1.0;
    EMISSION = vec3(0.0);

    if (surface_type == SURFACE_PRIMER) {
        vec3 texture_sample = texture(primer_texture, detail_uv).rgb;
        ALBEDO = primer_color.rgb * texture_sample;
        ALPHA = primer_color.a;
        METALLIC = primer_metallic;
        ROUGHNESS = primer_roughness + wear_amount * 0.4;
    }
    else if (surface_type == SURFACE_RIM) {
        vec3 texture_sample = texture(rim_texture, detail_uv).rgb;
        vec3 base_albedo = rim_color.rgb * texture_sample;
        ALBEDO = mix(base_albedo, rim_tint_color.rgb, rim_tint_percent);
        ALPHA = mix(rim_color.a, rim_tint_color.a, rim_tint_percent);
        METALLIC = mix(rim_metallic, rim_metallic + 0.2 * rim_tint_percent, rim_tint_percent);
        ROUGHNESS = mix(rim_roughness, max(0.01, rim_roughness + 0.4 * rim_tint_percent), rim_tint_percent) + wear_amount * 0.2;
    }
    else if (surface_type == SURFACE_CASE) {
        vec3 texture_sample = texture(case_texture, detail_uv).rgb;
        ALBEDO = case_color.rgb * texture_sample;
        ALPHA = case_color.a;
        METALLIC = case_metallic;
        ROUGHNESS = case_roughness + wear_amount * 0.3;
    }
    else if (surface_type == SURFACE_BULLET_BASE) {
        ALBEDO = bullet_base_color.rgb;
        ALPHA = bullet_base_color.a;
        METALLIC = 0.1;
        ROUGHNESS = 0.8;
    }
    else if (surface_type == SURFACE_BULLET_BODY) {
        vec3 texture_sample = texture(bullet_texture, detail_uv).rgb;
        ALBEDO = bullet_color.rgb * texture_sample;
        ALPHA = bullet_color.a;
        METALLIC = bullet_metallic;
        ROUGHNESS = bullet_roughness + wear_amount * 0.2;
    }
    else if (surface_type == SURFACE_BULLET_TIP) {
        vec3 texture_sample = texture(bullet_texture, detail_uv).rgb;
        ALBEDO = bullet_tip_color.rgb * texture_sample;
        ALPHA = bullet_tip_color.a;
        METALLIC = bullet_metallic;
        ROUGHNESS = bullet_roughness;
    }
    else if (surface_type == SURFACE_TRACER) {
        // tracer no longer bleeds neighbors because surface_type is determined by nearest ring,
        // and sampling avoids interpolating across the gap boundary.
        float tracer_pos = get_tracer_position(parameter_t); // 0..1 along gap
        float tracer_intensity = calculate_tracer_intensity(parameter_t);

        // smoother pulse: uses TAU * tracer_pos so frequency scales nicely across gap length
        float pulse = 0.5 + 0.5 * sin(TIME * tracer_pulse_speed + tracer_pos * TAU);

        ALBEDO = tracer_color.rgb * (0.9 + 0.1 * sin(tracer_pos * 20.0 + TIME * 2.0));
        ALPHA = tracer_color.a * tracer_intensity;
        EMISSION = tracer_color.rgb * tracer_emission_energy * (0.7 + 0.3 * pulse) * tracer_intensity;
        METALLIC = 0.0;
        ROUGHNESS = 0.1;
    }

    // Bullet heat emission (separate from tracer) - smooth and constrained
    bool is_bullet_surface = (surface_type == SURFACE_BULLET_BASE) || (surface_type == SURFACE_BULLET_BODY) || (surface_type == SURFACE_BULLET_TIP);
    if (bullet_heat_with_distance_enable && is_bullet_surface) {
        EMISSION += get_heat_with_distance(surface_type, parameter_t);
    }

    // subtle length gradient
    ALBEDO *= (0.8 + 0.2 * UV.x);
}
#else
#include "cartridge-debug.gdshaderinc"
#endif





























































































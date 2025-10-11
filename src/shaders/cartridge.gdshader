//DO NOT RECOMPILE THIS SHIT GODOT
shader_type spatial;
render_mode cull_front, depth_draw_always;

// ======================
// CONSTANTS
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
// GROUPED UNIFORMS
// ======================

// --- MESH CONFIGURATION ---
group_uniforms Mesh;
uniform int mesh_segments_length = 64;            // subdivisions between caps (user input)
uniform int mesh_segments_circumference = 64;
uniform int gap_segments = 2;                     // requested gap subdivisions (clamped when extraction>0)

// --- SCALE & TRANSFORM ---
group_uniforms Scale_And_Transform;
uniform float scale : hint_range(0.1, 5000.0, 0.1) = 1.0;
uniform float center_of_mass: hint_range(0.0, 1.0, 0.01) = 0.05;
uniform float bullet_extraction_mm : hint_range(0.0, 1000.0, 0.1) = 0.0;

// Bullet physics controls
uniform float muzzle_velocity_ms : hint_range(100.0, 2000.0, 1.0) = 800.0;
uniform float bullet_drop_ms2 : hint_range(0.0, 20.0, 0.1) = 9.81;
uniform float wind_velocity_ms : hint_range(-100.0, 100.0, 0.1) = 0.0;
uniform float zero_range_m : hint_range(0.0, 1000.0, 1.0) = 100.0;
uniform float ballistic_coefficient : hint_range(0.1, 1.0, 0.01) = 0.5;

// --- CARTRIDGE DIMENSIONS ---
group_uniforms Cartridge_Dimensions;
uniform float land_diameter_mm : hint_range(0.0, 20.0, 0.1) = 5.56;
uniform float bullet_diameter_mm : hint_range(0.0, 20.0, 0.1) = 5.70;
uniform float case_length_mm : hint_range(0.0, 100.0, 0.1) = 44.70;
uniform float overall_length_mm : hint_range(0.0, 100.0, 0.1) = 57.40;

// --- CASE GEOMETRY ---
group_uniforms Case_Geometry;
uniform float neck_diameter_mm : hint_range(0.0, 20.0, 0.1) = 6.43;
uniform float shoulder_diameter_mm : hint_range(0.0, 20.0, 0.1) = 9.00;
uniform float head_diameter_mm : hint_range(0.0, 20.0, 0.1) = 9.58;
uniform float rim_diameter_mm : hint_range(0.0, 20.0, 0.1) = 9.60;
uniform float rim_thickness_mm : hint_range(0.0, 20.0, 0.1) = 1.27;
uniform float primer_diameter_mm : hint_range(0.0, 5.0, 0.01) = 3.00;
uniform float extractor_groove_diameter_mm : hint_range(0.0, 20.0, 0.1) = 8.0;

// --- CASE PROPORTIONS ---
group_uniforms Case_Proportions;
uniform float neck_percent : hint_range(0.0, 1.0, 0.01) = 0.90; // where neck starts (close to case_length)
uniform float shoulder_percent : hint_range(0.0, 1.0, 0.01) = 0.85; // where shoulder begins
uniform float rim_roundness : hint_range(0.0, 1.0, 0.01) = 0.5; // 0 down semicircle, 0.5 rounded, 1 up semicircle

// --- CASE MATERIALS (moved rim tint here) ---
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
uniform float case_wall_thickness_mm : hint_range(0.0, 5.0, 0.01) = 0.0; // 0 = automatic inner thickness

// --- BULLET GEOMETRY CONTROLS ---
group_uniforms Bullet_Geometry;
uniform float ogive_radius_factor : hint_range(0.5, 5.0, 0.01) = 1.0;
uniform int tip_profile : hint_enum("Cone","Tangent","Secant","Elliptical") = 1;
uniform float bullet_base_percent : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float bullet_tip_percent : hint_range(0.0, 1.0, 0.01) = 0.7;

// --- BULLET MATERIALS & EFFECTS ---
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

// --- TRACER PROPERTIES ---
group_uniforms Tracer;
uniform bool tracer_enable = true;
uniform vec4 tracer_color : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform float tracer_emission_energy : hint_range(0.0, 10.0, 0.1) = 1.0;
uniform float tracer_radius_percent : hint_range(0.0, 1.0, 0.1) = 0.5;
uniform float tracer_pulse_speed : hint_range(0.0, 10.0, 0.1) = 1.0;
uniform float tracer_start_mm : hint_range(0.0, 1000.0, 1.0) = 100.0;
uniform float tracer_length_mm : hint_range(0.0, 2000.0, 1.0) = 500.0;
uniform float tracer_power : hint_range(0.1, 3.0, 0.1) = 1.5;

// --- TEXTURES ---
group_uniforms Textures;
uniform sampler2D case_texture : source_color;
uniform sampler2D bullet_texture : source_color;
uniform sampler2D primer_texture : source_color;
uniform sampler2D rim_texture : source_color;

// --- UV CONTROLS ---
group_uniforms UV_Controls;
uniform float uv_scale_x: hint_range(0.0, 100.0, 0.01) = 1.0; // circumferential tiling
uniform float uv_scale_y: hint_range(0.0, 100.0, 0.01) = 1.0; // axial tiling

// --- WEAR & AGING ---
group_uniforms Wear_Aging;
uniform float wear_amount : hint_range(0,1) = 0.1;

// ======================
// SMALL HELPERS
// ======================
float to_meters(float mm) { return mm * 0.001 * scale; }
float safe_div(float a, float b) { return a / max(b, EPS); }
float my_lerp(float a, float b, float t) { return mix(a,b,clamp(t,0.0,1.0)); }

// Map UVs nicely: circumferential around UV.y and axial along UV.x
vec2 detail_uv_from_uv(vec2 uv) {
    // UV.y wraps around circumference; UV.x along length
    return vec2(uv.y * float(mesh_segments_circumference) * uv_scale_x, uv.x * uv_scale_y);
}

// ======================
// BOUNDARIES & RING ALLOCATION
// ======================
// We'll create N = mesh_segments_length + 2 rings total (two caps included).
// Compute block indices for primer, case (with rim/head/shoulder/neck subregions), mouth cap, gap, bullet.
// In the compute_boundaries function, update the segment allocation:
void compute_boundaries(out int primer_end, out int case_start, out int case_end, out int rim_end_local,
                        out int head_end_local, out int shoulder_end_local, out int neck_end_local,
                        out int mouth_start, out int mouth_end, out int gap_start, out int gap_end, out int bullet_start, out int last_index) {
    int subdivisions = max(2, mesh_segments_length);
    int N = subdivisions + 2;
    last_index = N - 1;

    // Fixed allocation
    int primer_count = 2;
    int mouth_count = 2;  // For the mouth internal section
    int gap_count = (to_meters(bullet_extraction_mm) > EPS) ? max(2, gap_segments) : 0;

    int reserved = primer_count + mouth_count + gap_count;
    int remaining = N - reserved;
    remaining = max(8, remaining);

    float case_len = to_meters(case_length_mm);
    float overall_len = to_meters(overall_length_mm);
    float bullet_len = max(EPS, overall_len - case_len);
    float total_len = max(EPS, case_len + bullet_len);
    float case_ratio = safe_div(case_len, total_len);

    int case_count = int(max(4.0, floor(float(remaining) * case_ratio + 0.5)));
    int bullet_count = remaining - case_count;
    bullet_count = max(4, bullet_count);

    // Define indices
    primer_end = primer_count - 1;
    case_start = primer_end + 1;
    case_end = case_start + case_count - 1;
    mouth_start = case_end + 1;
    mouth_end = mouth_start + mouth_count - 1;
    gap_start = mouth_end + 1;
    gap_end = gap_start + gap_count - 1;
    bullet_start = gap_end + 1;

    // Safety clamping
    if (bullet_start > last_index) {
        gap_end = max(gap_start, last_index - 4);
        bullet_start = gap_end + 1;
    }
    if (mouth_start > last_index) mouth_start = last_index;
    if (case_end >= mouth_start) case_end = max(case_start, mouth_start - 1);

    // Subdivide case block (same as before)
    int case_rings = max(1, case_end - case_start + 1);

    // Allocate segments for each section
    int rim_rings = max(1, int(round(0.1 * float(case_rings)))); // 10% for rim
    int groove_rings = max(1, int(round(0.1 * float(case_rings)))); // 10% for extractor groove
    int head_rings = max(1, int(round(0.1 * float(case_rings)))); // 10% for head/body
    int shoulder_rings = max(1, int(round(0.4 * float(case_rings)))); // 40% for shoulder
    int neck_rings = max(1, case_rings - (rim_rings + groove_rings + head_rings + shoulder_rings)); // rest for neck

    int idx = case_start;
    rim_end_local = idx + rim_rings - 1; idx = rim_end_local + 1;
    int groove_end_local = idx + groove_rings - 1; idx = groove_end_local + 1;
    head_end_local = idx + head_rings - 1; idx = head_end_local + 1;
    shoulder_end_local = idx + shoulder_rings - 1; idx = shoulder_end_local + 1;
    neck_end_local = idx + neck_rings - 1;
}

// ======================
// PER-RING PROFILE (display mapping)
// returns vec2(y_meters, radius_meters)
// ======================
vec2 profile_display_for_ring(int idx) {
    int primer_end, case_start, case_end, rim_end_local, head_end_local, shoulder_end_local, neck_end_local, mouth_start, mouth_end, gap_start, gap_end, bullet_start, last_index;
    compute_boundaries(primer_end, case_start, case_end, rim_end_local, head_end_local, shoulder_end_local, neck_end_local, mouth_start, mouth_end, gap_start, gap_end, bullet_start, last_index);
    float case_length = to_meters(case_length_mm);
    float overall_length = to_meters(overall_length_mm);
    float bullet_length = max(EPS, overall_length - case_length);
    float extraction = to_meters(bullet_extraction_mm);

    // radii
    float primer_r = to_meters(primer_diameter_mm) * 0.5;
    float rim_r = to_meters(rim_diameter_mm) * 0.5;
    float head_r = to_meters(head_diameter_mm) * 0.5;
    float shoulder_r = to_meters(shoulder_diameter_mm) * 0.5;
    float neck_r = to_meters(neck_diameter_mm) * 0.5;
    float bullet_r = to_meters(bullet_diameter_mm) * 0.5;
    float rim_thick = to_meters(rim_thickness_mm);
    float wall_thick = (case_wall_thickness_mm <= 0.0) ? max(0.0001, neck_r * 0.25) : to_meters(case_wall_thickness_mm);

    // Primer region (bottom cap)
    if (idx <= primer_end) {
        // keep the very bottom closed at y=0 with radius 0 to create a cap
        return vec2(0.0, 0.0);
    }

	// Case block: subdivided (rim / extractor_groove / shoulder / neck)
	if (idx >= case_start && idx <= case_end) {
	    // compute normalized position inside case block
	    float case_block_len = float(case_end - case_start + 1);
	    float local = float(idx - case_start) / max(1.0, case_block_len - 1.0);

	    // Rim region: first chunk (0..rim_end_local)
	    int rim_count = max(1, rim_end_local - case_start + 1);
	    float rim_cut = float(rim_count) / max(1.0, case_block_len);

	    if (local <= rim_cut) {
	        // rim arc param from 0..1
	        float t = safe_div(local, rim_cut);

	        // vertical position along rim: 0..rim_thick
	        float y = my_lerp(0.0, rim_thick, t);

	        // rim_roundness controls the bulge direction
	        float semicircle = sin(t * PI); // 0..1..0
	        float bulge_sign = (rim_roundness - 0.5) * 2.0; // -1..1
	        float bulge = semicircle * (rim_thick * 0.5) * bulge_sign;

	        // final radius: rim base + bulge
	        float r = rim_r + bulge;
	        return vec2(y, max(EPS, r));
	    }

	    // Extractor Groove region: small section right after rim with smaller diameter
	    float groove_start = rim_cut;
	    float groove_end = groove_start + 0.1; // Small fixed section for the groove
	    if (local <= groove_end) {
	        float t = safe_div(local - groove_start, groove_end - groove_start);
	        float y0 = rim_thick;
	        float y1 = rim_thick + to_meters(1.0); // 1mm for groove depth
	        float y = my_lerp(y0, y1, t);

	        // Groove radius is smaller than rim but larger than head
	        float groove_r = to_meters(extractor_groove_diameter_mm) * 0.5;
	        float r = my_lerp(rim_r, groove_r, t);
	        return vec2(y, max(EPS, r));
	    }

	    // Head/Body region: from groove to shoulder, with base diameter
	    float head_start = groove_end;
	    float head_end = clamp(shoulder_percent, head_start + 0.001, 0.95);
	    if (local <= head_end) {
	        float t = safe_div(local - head_start, head_end - head_start);
	        float y0 = rim_thick + to_meters(1.0);
	        float y1 = case_length * shoulder_percent;
	        float y = my_lerp(y0, y1, t);

	        // Taper from head diameter to shoulder diameter
	        float r = my_lerp(head_r, shoulder_r, t);
	        return vec2(y, max(EPS, r));
	    }

	    // Shoulder region: from shoulder_percent to neck_percent
	    float shoulder_start_frac = head_end;
	    float shoulder_end_frac = clamp(neck_percent, shoulder_start_frac + 0.001, 0.999);
	    if (local <= shoulder_end_frac) {
	        float t = safe_div(local - shoulder_start_frac, shoulder_end_frac - shoulder_start_frac);
	        float y0 = case_length * shoulder_percent;
	        float y1 = case_length * neck_percent;
	        float y = my_lerp(y0, y1, t);

	        // Taper from shoulder diameter to neck diameter
	        float r = my_lerp(shoulder_r, neck_r, t);
	        return vec2(y, max(EPS, r));
	    }

	    // Neck region: from neck_percent to case_length
	    {
	        float t = safe_div(local - shoulder_end_frac, 1.0 - shoulder_end_frac);
	        float y0 = case_length * neck_percent;
	        float y1 = case_length;
	        float y = my_lerp(y0, y1, t);
	        float r_outer = neck_r;
	        return vec2(y, max(EPS, r_outer));
	    }
	}

	// Mouth region (internal bottom of case)
	if (idx >= mouth_start && idx <= mouth_end) {
	    float case_length = to_meters(case_length_mm);
	    float neck_outer = to_meters(neck_diameter_mm) * 0.5;
	    float wall_thick = (case_wall_thickness_mm <= 0.0) ? neck_outer * 0.25 : to_meters(case_wall_thickness_mm);
	    float mouth_inner_radius = max(EPS, neck_outer - wall_thick);
	    float rim_thick = to_meters(rim_thickness_mm);

	    // Mouth extends from neck position down to rim height with constant inner radius
	    float mouth_t = float(idx - mouth_start) / float(mouth_end - mouth_start);
	    float y = mix(case_length, rim_thick, mouth_t);

	    return vec2(y, mouth_inner_radius);
	}

    // Gap region (cylinder) - only present when extraction > 0
    if (idx >= gap_start && idx <= gap_end) {
        int gap_count = max(2, gap_segments);
        float t = safe_div(float(idx - gap_start), float(max(1, gap_count - 1)));
        float y = case_length + t * to_meters(bullet_extraction_mm);
        float r = to_meters(bullet_diameter_mm) * 0.5 * tracer_radius_percent;
        return vec2(y, max(EPS, r));
    }

    // Bullet region
    if (idx >= bullet_start && idx <= last_index) {
        int bullet_count = max(1, last_index - bullet_start + 1);
        float t = safe_div(float(idx - bullet_start), float(max(1, bullet_count - 1)));
        float y = case_length + to_meters(bullet_extraction_mm) + t * bullet_length;

        // bullet radius logic (base + ogive)
        float base_section_length = bullet_length * bullet_base_percent;
        float current_pos = t * bullet_length;
        float rad = bullet_r;

        if (current_pos < base_section_length) {
            rad = bullet_r;
            return vec2(y, rad);
        }

        float ogive_len = max(EPS, bullet_length - base_section_length);
        float ogive_pos = safe_div(current_pos - base_section_length, ogive_len);

        if (tip_profile == 0) { // Cone
            float tip_start = bullet_tip_percent;
            if (ogive_pos > tip_start) {
                rad = my_lerp(bullet_r, EPS, safe_div((ogive_pos - tip_start), (1.0 - tip_start)));
            } else {
                rad = bullet_r;
            }
        } else if (tip_profile == 1) { // Tangent (classic ogive)
            float base_radius = bullet_r;
            float R = (ogive_len * ogive_len + base_radius * base_radius) / (2.0 * base_radius) * ogive_radius_factor;
            float x = ogive_len * (1.0 - ogive_pos);
            float radicand = R * R - (ogive_len - x) * (ogive_len - x);
            rad = (radicand <= 0.0) ? EPS : max(EPS, sqrt(radicand) - (R - base_radius));
        } else if (tip_profile == 2) { // Secant
            float base_radius = bullet_r * 0.9;
            float R = (ogive_len * ogive_len + base_radius * base_radius) / (2.0 * base_radius) * ogive_radius_factor;
            float x = ogive_len * (1.0 - ogive_pos);
            float radicand = R * R - (ogive_len - x) * (ogive_len - x);
            rad = (radicand <= 0.0) ? EPS : max(EPS, sqrt(radicand) - (R - base_radius));
        } else { // Elliptical (profile 3)
            float base_radius = bullet_r;
            rad = base_radius * sqrt(max(EPS, 1.0 - ogive_pos * ogive_pos));
        }

        return vec2(y, max(EPS, rad));
    }

    // fallback
    return vec2(0.0, EPS);
}

// ======================
// ORIGINAL PROFILE (collapsed gap) - used for surface type detection
// ======================
vec2 profile_original_for_ring(int idx) {
    int primer_end, case_start, case_end, rim_end_local, head_end_local, shoulder_end_local, neck_end_local, mouth_start, mouth_end, gap_start, gap_end, bullet_start, last_index;
    compute_boundaries(primer_end, case_start, case_end, rim_end_local, head_end_local, shoulder_end_local, neck_end_local, mouth_start, mouth_end, gap_start, gap_end, bullet_start, last_index);
    vec2 d = profile_display_for_ring(idx);
    float extraction = to_meters(bullet_extraction_mm);
    float case_length = to_meters(case_length_mm);

    // Collapse gap into mouth (no tracer shown in collapsed original)
    if (idx >= gap_start && idx <= gap_end) {
        float neck_r = to_meters(neck_diameter_mm) * 0.5;
        return vec2(case_length, neck_r);
    }

    // bullet shifted down in original
    if (idx >= bullet_start) {
        return vec2(max(0.0, d.x - extraction), d.y);
    }

    return d;
}

// ======================
// SAMPLE PROFILES BY parameter_t (0..1) with linear interpolation between rings
// ======================
vec2 sample_display_profile(float parameter_t) {
    int subdivisions = max(2, mesh_segments_length);
    int N = subdivisions + 2;
    float f = clamp(parameter_t, 0.0, 1.0) * float(N - 1);
    int a = int(floor(f));
    int b = min(N - 1, a + 1);
    float local = f - float(a);
    vec2 pa = profile_display_for_ring(a);
    vec2 pb = profile_display_for_ring(b);
    return mix(pa, pb, local);
}

vec2 sample_original_profile(float parameter_t) {
    int subdivisions = max(2, mesh_segments_length);
    int N = subdivisions + 2;
    float f = clamp(parameter_t, 0.0, 1.0) * float(N - 1);
    int a = int(floor(f));
    int b = min(N - 1, a + 1);
    float local = f - float(a);
    vec2 pa = profile_original_for_ring(a);
    vec2 pb = profile_original_for_ring(b);
    return mix(pa, pb, local);
}

// ======================
// HELPERS FOR GAP / TRACER / CAPS
// ======================
float get_display_position(float parameter_t) { return sample_display_profile(parameter_t).x; }
float get_original_position(float parameter_t) { return sample_original_profile(parameter_t).x; }

bool is_in_gap_region(float parameter_t) {
    if (to_meters(bullet_extraction_mm) < EPS) return false;
    int subdivisions = max(2, mesh_segments_length);
    int N = subdivisions + 2;
    float f = clamp(parameter_t, 0.0, 1.0) * float(N - 1);
    int nearest = int(floor(f + 0.5));
    int primer_end, case_start, case_end, rim_end_local, head_end_local, shoulder_end_local, neck_end_local, mouth_start, mouth_end, gap_start, gap_end, bullet_start, last_index;
    compute_boundaries(primer_end, case_start, case_end, rim_end_local, head_end_local, shoulder_end_local, neck_end_local, mouth_start, mouth_end, gap_start, gap_end, bullet_start, last_index);
    return (nearest >= gap_start && nearest <= gap_end);
}

float get_tracer_position(float parameter_t) {
    if (!is_in_gap_region(parameter_t)) return 0.0;
    int subdivisions = max(2, mesh_segments_length);
    int N = subdivisions + 2;
    float f = clamp(parameter_t, 0.0, 1.0) * float(N - 1);
    int nearest = int(floor(f + 0.5));
    int primer_end, case_start, case_end, rim_end_local, head_end_local, shoulder_end_local, neck_end_local, mouth_start, mouth_end, gap_start, gap_end, bullet_start, last_index;
    compute_boundaries(primer_end, case_start, case_end, rim_end_local, head_end_local, shoulder_end_local, neck_end_local, mouth_start, mouth_end, gap_start, gap_end, bullet_start, last_index);    int gap_count = max(2, gap_segments);
    return safe_div(float(nearest - gap_start), float(max(1, gap_count - 1)));
}

// ======================
// SURFACE TYPE DETECTION
// ======================
// In get_surface_type function, add mouth detection:
int get_surface_type(float parameter_t) {
    float extraction = to_meters(bullet_extraction_mm);

    if (extraction > EPS && is_in_gap_region(parameter_t)) return SURFACE_TRACER;

    // Check if we're in the mouth section
    int subdivisions = max(2, mesh_segments_length);
    int N = subdivisions + 2;
    float f = clamp(parameter_t, 0.0, 1.0) * float(N - 1);
    int nearest = int(floor(f + 0.5));

    int primer_end, case_start, case_end, rim_end_local, head_end_local, shoulder_end_local, neck_end_local, mouth_start, mouth_end, gap_start, gap_end, bullet_start, last_index;
    compute_boundaries(primer_end, case_start, case_end, rim_end_local, head_end_local, shoulder_end_local, neck_end_local, mouth_start, mouth_end, gap_start, gap_end, bullet_start, last_index);

    if (nearest >= mouth_start && nearest <= mouth_end) {
        return SURFACE_CASE; // Mouth is part of the case interior
    }

	if (nearest <= primer_end) {
        return SURFACE_PRIMER;
    }

	if (nearest <= rim_end_local) {
        return SURFACE_RIM;
    }

    if (nearest >= case_start && nearest <= case_end) {
        return SURFACE_CASE;
    }

    if (nearest >= bullet_start && nearest <= last_index) {
        int bullet_count = max(1, last_index - bullet_start + 1);
        float t = safe_div(float(nearest - bullet_start), float(max(1, bullet_count - 1)));
		if (t < bullet_base_color_percent) return SURFACE_BULLET_BASE;
		if (t > bullet_tip_color_percent) return SURFACE_BULLET_TIP;
    	return SURFACE_BULLET_BODY;
    }

    return SURFACE_CASE; // Defaults to case surface
}

// ======================
// TRACER INTENSITY
// ======================
float calculate_tracer_intensity(float parameter_t) {
    if (!tracer_enable) return 0.0;
    float extraction = to_meters(bullet_extraction_mm);
    if (extraction < EPS) return 0.0;
    if (!is_in_gap_region(parameter_t)) return 0.0;

    float tracer_pos = get_tracer_position(parameter_t);
    float pulse = sin(TIME * tracer_pulse_speed + tracer_pos * 10.0) * 0.5 + 0.5;
    return (0.7 + 0.3 * pulse);
}

// ======================
// NORMAL CALCULATION
// ======================
vec3 calculate_surface_normal(float parameter_t, float angle, float overall_length) {
    if (is_in_gap_region(parameter_t)) {
        // radial normal for gap interior and primer cap
        return normalize(vec3(cos(angle), 0.0, sin(angle)));
    }

    float t_forward = min(parameter_t + 1.0e-3, 1.0);
    float t_backward = max(parameter_t - 1.0e-3, 0.0);

    vec2 pf = sample_display_profile(t_forward);
    vec2 pb = sample_display_profile(t_backward);

    float dy = pf.x - pb.x;
    float dr = pf.y - pb.y;

    if (abs(dy) < EPS) return normalize(vec3(cos(angle), 0.0, sin(angle)));

    float dr_dy = dr / dy;
    vec3 n = normalize(vec3(cos(angle), -dr_dy, sin(angle)));

    // ensure outward
    vec3 radial = vec3(cos(angle), 0.0, sin(angle));
    if (dot(n, radial) < 0.0) n = -n;
    return n;
}

// ======================
// VERTEX SHADER
// ======================
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

    //// --- Ballistic trajectory on projectile vertices (bullet and tracer) ---
    //float case_length = to_meters(case_length_mm);
    //bool is_projectile = (get_original_position(parameter_t) > case_length) || is_in_gap_region(parameter_t);
//
    //if (is_projectile && extraction > EPS) {
        //float distance_from_case = display_y - case_length;
        //if (distance_from_case > 0.0) {
            //float real_world_distance = distance_from_case / scale;
            //float time_in_flight = real_world_distance / muzzle_velocity_ms;
//
            //float real_world_drop = 0.5 * bullet_drop_ms2 * time_in_flight * time_in_flight;
            //float real_world_wind_drift = wind_velocity_ms * time_in_flight;
//
            //float zeroing_time = zero_range_m / muzzle_velocity_ms;
            //float zeroing_drop = 0.5 * bullet_drop_ms2 * zeroing_time * zeroing_time;
            //float real_world_drop_compensation = real_world_drop - zeroing_drop * (real_world_distance / zero_range_m);
//
            //float scaled_drop = real_world_drop_compensation * scale;
            //float scaled_wind_drift = real_world_wind_drift * scale;
//
            //base_vertex.z -= scaled_drop;
            //base_vertex.x += scaled_wind_drift;
//
            //// subtle tip tilt for bullet (not for tracer)
            //if (!is_in_gap_region(parameter_t)) {
                //float max_tip_tilt = 0.1;
                //float tilt_x = scaled_wind_drift * max_tip_tilt * 0.1;
                //float tilt_z = scaled_drop * max_tip_tilt * 0.1;
//
                //float bullet_pos = get_original_position(parameter_t) - case_length;
                //float bullet_len_local = max(EPS, overall_length - case_length);
                //float tip_factor = (bullet_pos > 0.0) ? pow(clamp(bullet_pos / bullet_len_local, 0.0, 1.0), 2.0) : 0.0;
//
                //base_vertex.x += tilt_x * tip_factor;
                //base_vertex.z += tilt_z * tip_factor;
            //}
        //}
    //}

    VERTEX = base_vertex;
    NORMAL = calculate_surface_normal(parameter_t, angle, overall_length);
}

// ======================
// FRAGMENT SHADER
// ======================
void fragment() {
    float parameter_t = UV.x;
    vec2 detail_uv = detail_uv_from_uv(UV);
    int surface_type = get_surface_type(parameter_t);

    // defaults
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
        // rim paint tint acts like a coat: blend albedo, and slightly affect metallic/roughness
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
        float tracer_pos = get_tracer_position(parameter_t);
        float pulse = sin(TIME * tracer_pulse_speed + tracer_pos * 10.0) * 0.5 + 0.5;
        float tracer_intensity = calculate_tracer_intensity(parameter_t);

        ALBEDO = tracer_color.rgb;
        ALPHA = tracer_color.a * tracer_intensity;
        EMISSION = tracer_color.rgb * tracer_emission_energy * (0.7 + 0.3 * pulse) * tracer_intensity;
        METALLIC = 0.0;
        ROUGHNESS = 0.1;

        ALBEDO *= (0.9 + 0.1 * sin(tracer_pos * 20.0 + TIME * 2.0)) * tracer_intensity;
    }
	bool is_bullet_surface = (surface_type & (SURFACE_BULLET_BASE | SURFACE_BULLET_TIP | SURFACE_BULLET_BODY)) > 0;
	if (bullet_heat_with_distance_enable && is_bullet_surface) {
        float heat_with_distance = clamp(bullet_extraction_mm/(bullet_heat_proportion * case_length_mm), 0.0, 1.0);
        float pulse = sin(TIME * tracer_pulse_speed + parameter_t * 10.0) * 0.5 + 0.5;
        EMISSION = tracer_color.rgb * tracer_emission_energy * (0.7 + 0.3 * pulse) * heat_with_distance;
    }

    // subtle length gradient for visual depth
    ALBEDO *= (0.8 + 0.2 * UV.x);
}

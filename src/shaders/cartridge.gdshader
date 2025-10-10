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
uniform int mesh_segments_length = 64;
uniform int mesh_segments_circumference = 64; 
uniform int gap_segments = 2;

// --- SCALE & TRANSFORM ---
group_uniforms Scale_And_Transform;
uniform float scale : hint_range(0.1, 5000.0, 0.1) = 1.0;
uniform float center_of_mass: hint_range(0.0, 1.0, 0.01) = 0.05;
uniform float bullet_extraction_mm : hint_range(0.0, 1000.0, 0.1) = 0.0;

// NEW: Bullet physics controls
uniform float muzzle_velocity_ms : hint_range(100.0, 2000.0, 1.0) = 800.0; // meters per second
uniform float bullet_drop_ms2 : hint_range(0.0, 20.0, 0.1) = 9.81; // gravity in m/s²
uniform float wind_velocity_ms : hint_range(-100.0, 100.0, 0.1) = 0.0; // wind in m/s
uniform float zero_range_m : hint_range(0.0, 1000.0, 1.0) = 100.0; // zeroing distance in meters
uniform float ballistic_coefficient : hint_range(0.1, 1.0, 0.01) = 0.5; // BC for drag

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
uniform float base_diameter_mm : hint_range(0.0, 20.0, 0.1) = 9.58;
uniform float rim_diameter_mm : hint_range(0.0, 20.0, 0.1) = 9.60;
uniform float rim_thickness_mm : hint_range(0.0, 20.0, 0.1) = 1.27;
uniform float primer_diameter_mm : hint_range(0.0, 5.0, 0.01) = 3.00;

// --- CASE PROPORTIONS ---
group_uniforms Case_Proportions;
uniform float neck_percent : hint_range(0.0, 1.0, 0.01) = 0.90;
uniform float shoulder_percent : hint_range(0.0, 1.0, 0.01) = 0.85;
uniform float base_percent : hint_range(0.0, 1.0, 0.01) = 0.05;
uniform float rim_percent : hint_range(0.0, 1.0, 0.001) = 0.02;
uniform float primer_percent : hint_range(0.0, 1.0, 0.001) = 0.01;

// --- BULLET GEOMETRY CONTROLS ---
group_uniforms Bullet_Geometry;
uniform float ogive_radius_factor : hint_range(0.5, 5.0, 0.01) = 1.0;
uniform int   tip_profile         : hint_range(0, 3)           =   1;
uniform float bullet_base_percent : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float bullet_tip_percent  : hint_range(0.0, 1.0, 0.01) = 0.7;

// --- TRACER PROPERTIES ---
group_uniforms Tracer;
uniform bool  tracer_enable = true;
uniform vec4  tracer_color : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform float tracer_emission_energy : hint_range(0.0, 10.0, 0.1) = 1.0;
uniform float tracer_radius_percent : hint_range(0.0, 1.0, 0.1) = 0.5;
uniform float tracer_pulse_speed : hint_range(0.0, 10.0, 0.1) = 1.0;
uniform float tracer_start_mm : hint_range(0.0, 1000.0, 1.0) = 100.0;
uniform float tracer_length_mm : hint_range(0.0, 2000.0, 1.0) = 500.0;
uniform float tracer_power : hint_range(0.1, 3.0, 0.1) = 1.5;

group_uniforms Special_Effects;
uniform bool bullet_tip_heat_enable = true;

// --- CASE MATERIALS ---
group_uniforms Case_Materials;
uniform vec4 case_color : source_color = vec4(0.8, 0.6, 0.2, 1.0);
uniform vec4 primer_color : source_color = vec4(0.3, 0.3, 0.35, 1.0);
uniform vec4 rim_color : source_color = vec4(0.88, 0.66, 0.22, 1.0);

uniform float case_metallic : hint_range(0,1) = 0.8;
uniform float case_roughness : hint_range(0,1) = 0.3;
uniform float primer_metallic : hint_range(0,1) = 0.3;
uniform float primer_roughness : hint_range(0,1) = 0.7;
uniform float rim_metallic : hint_range(0,1) = 0.3;
uniform float rim_roughness : hint_range(0,1) = 0.7;

// --- BULLET MATERIALS ---
group_uniforms Bullet_Materials;
uniform vec4 bullet_color : source_color = vec4(0.7, 0.4, 0.2, 1.0);
uniform vec4 bullet_tip_color : source_color = vec4(0.9, 0.8, 0.7, 1.0);
uniform vec4 bullet_base_color : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform float bullet_base_color_percent : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float bullet_tip_color_percent : hint_range(0.0, 1.0, 0.01) = 0.7;

uniform float bullet_metallic : hint_range(0,1) = 0.6;
uniform float bullet_roughness : hint_range(0,1) = 0.2;

// --- TEXTURES ---
group_uniforms Textures;
uniform sampler2D case_texture : source_color;
uniform sampler2D bullet_texture : source_color;
uniform sampler2D primer_texture : source_color;
uniform sampler2D rim_texture : source_color;

// --- UV CONTROLS ---
group_uniforms UV_Controls;
uniform float uv_scale_x: hint_range(0.0, 100.0, 0.01) = 20.0;
uniform float uv_scale_y: hint_range(0.0, 100.0, 0.01) = 20.0;

// --- WEAR & AGING ---
group_uniforms Wear_Aging;
uniform float wear_amount : hint_range(0,1) = 0.1;

// ======================
// INTERNAL FUNCTIONS
// ======================

// Convert millimeters to meters with scale applied
float to_meters(float millimeters) {
    return millimeters * 0.001 * scale;
}

// Linear interpolation between two radii over a segment
float lerp(float position, float position_start, float position_end, float radius_start, float radius_end) {
    if (position <= position_start) return radius_start;
    if (position >= position_end) return radius_end;
    float t = (position - position_start) / max(EPS, position_end - position_start);
    return mix(radius_start, radius_end, t);
}

// ======================
// MESH PARAMETER MAPPING
// ======================

// Get the t-values for gap boundaries
void get_gap_boundaries(in int bias, out float gap_start_t, out float gap_end_t, out float bullet_start_t) {
    float case_length = to_meters(case_length_mm);
    float overall_length = to_meters(overall_length_mm);
    
    float total_segments = float(mesh_segments_length);
    float gap_segments_count = float(gap_segments);
    float usable_segments = total_segments - gap_segments_count;
    
    float case_segments = (case_length / overall_length) * usable_segments;
    gap_start_t = case_segments / total_segments;
    gap_end_t = (case_segments + gap_segments_count + float(bias)) / total_segments;
    bullet_start_t = gap_end_t;
}

// Map from uniform mesh t [0,1] to physical position with dedicated gap segments
float remap_parameter_to_position(float parameter_t) {
    float case_length = to_meters(case_length_mm);
    float overall_length = to_meters(overall_length_mm);
    float bullet_length = overall_length - case_length;
    
    float gap_start_t, gap_end_t, bullet_start_t;
    get_gap_boundaries(-1, gap_start_t, gap_end_t, bullet_start_t);
    
    if (parameter_t <= gap_start_t) {
        // Case region - linear distribution
        float case_normalized = parameter_t / gap_start_t;
        return case_normalized * case_length;
    }
    else if (parameter_t <= gap_end_t) {
        // Gap region - these will be tracer segments
        return case_length; // Return case end position for gap vertices
    }
    else {
        // Bullet region - linear distribution  
        float bullet_normalized = (parameter_t - bullet_start_t) / (1.0 - bullet_start_t);
        return case_length + bullet_normalized * bullet_length;
    }
}

// Get original position (without extraction)
float get_original_position(float parameter_t) {
    return remap_parameter_to_position(parameter_t);
}

// Get display position (with extraction applied)
float get_display_position(float parameter_t) {
    float original_position = get_original_position(parameter_t);
    float case_length = to_meters(case_length_mm);
    float bullet_extraction = to_meters(bullet_extraction_mm);
    
    // Case stays fixed, bullet moves forward
    if (original_position <= case_length) {
        return original_position;
    } else {
        return original_position + bullet_extraction;
    }
}

// Check if current t is in the gap region
bool is_in_gap_region(float parameter_t) {
    float gap_start_t, gap_end_t, bullet_start_t;
    get_gap_boundaries(0, gap_start_t, gap_end_t, bullet_start_t);
    
    // Only show tracer when there's extraction
    if (to_meters(bullet_extraction_mm) < EPS) return false;
    return (parameter_t > gap_start_t && parameter_t <= gap_end_t);
}

// Get normalized position along the tracer (0 at case, 1 at bullet)
float get_tracer_position(float parameter_t) {
    float gap_start_t, gap_end_t, bullet_start_t;
    get_gap_boundaries(0, gap_start_t, gap_end_t, bullet_start_t);
    
    if (is_in_gap_region(parameter_t)) {
        return (parameter_t - gap_start_t) / (gap_end_t - gap_start_t);
    }
    return 0.0;
}

// ======================
// GEOMETRY GENERATION
// ======================

float calculate_radius(float parameter_t) {
    // Use original positions for geometry calculations
    float position = get_original_position(parameter_t);

    float bullet_diameter = to_meters(bullet_diameter_mm);
    float neck_diameter = to_meters(neck_diameter_mm);
    float shoulder_diameter = to_meters(shoulder_diameter_mm);
    float base_diameter = to_meters(base_diameter_mm);
    float rim_diameter = to_meters(rim_diameter_mm);
    float rim_thickness = to_meters(rim_thickness_mm);
    float case_length = to_meters(case_length_mm);
    float primer_diameter = to_meters(primer_diameter_mm);
    float overall_length = to_meters(overall_length_mm);

    // If in gap region, return tracer radius
    if (is_in_gap_region(parameter_t)) {
        return to_meters(bullet_diameter_mm) * 0.5 * tracer_radius_percent;
    }

    if (position < EPS) return EPS;
    
    // --- CASE SECTION ---
    
    // Primer
    float primer_end = case_length * primer_percent;
    if (position < primer_end) {
        return primer_diameter * 0.5;
    }
    
    // Rim
    float rim_end = primer_end + case_length * rim_percent;
    if (position < rim_end) {
        return rim_diameter * 0.5;
    }
    
    // Base taper
    float base_end = rim_end + case_length * base_percent;
    if (position < base_end) {
        return lerp(
            position,
            rim_end,
            base_end,
            rim_diameter * 0.5,
            base_diameter * 0.5
        );
    }
    
    // Shoulder (main body)
    float shoulder_end = case_length * shoulder_percent;
    if (position < shoulder_end) {
        return shoulder_diameter * 0.5;
    }
    
    // Neck taper
    float neck_end = case_length * neck_percent;
    if (position < neck_end) {
        return lerp(
            position,
            shoulder_end,
            neck_end,
            shoulder_diameter * 0.5,
            neck_diameter * 0.5
        );
    }
    
    // Neck (constant)
    if (position < case_length) {
        return neck_diameter * 0.5;
    }

    if (position > overall_length - EPS) return EPS;
    
    // --- BULLET SECTION ---
    
    float bullet_position = position - case_length;
    float bullet_section_length = overall_length - case_length;
    
    // Bullet base (cylindrical)
    float base_section_length = bullet_section_length * bullet_base_percent;
    if (bullet_position < base_section_length) {
        return bullet_diameter * 0.5;
    }
    
    // Bullet ogive section
    float ogive_length = bullet_section_length - base_section_length;
    float ogive_position = (bullet_position - base_section_length) / ogive_length;
    
    if (tip_profile == 0) {
        // Truncated cone
        float tip_start_position = bullet_tip_percent;
        if (ogive_position > tip_start_position) {
            return lerp(
                ogive_position,
                tip_start_position,
                1.0,
                bullet_diameter * 0.5,
                EPS
            );
        } else {
            return bullet_diameter * 0.5;
        }
    }
    else if (tip_profile == 1) {
        // Tangent ogive
        float base_radius = bullet_diameter * 0.5;
        float R = (ogive_length * ogive_length + base_radius * base_radius) / (2.0 * base_radius) * ogive_radius_factor;
        float x = ogive_length * (1.0 - ogive_position);
        float radicand = R * R - (ogive_length - x) * (ogive_length - x);
        if (radicand < 0.0) return EPS;
        float y = sqrt(radicand) - (R - base_radius);
        return max(EPS, y);
    }
    else if (tip_profile == 2) {
        // Secant ogive  
        float base_radius = bullet_diameter * 0.5;
        float secant_base_radius = base_radius * 0.9;
        float R = (ogive_length * ogive_length + secant_base_radius * secant_base_radius) / (2.0 * secant_base_radius) * ogive_radius_factor;
        float x = ogive_length * (1.0 - ogive_position);
        float radicand = R * R - (ogive_length - x) * (ogive_length - x);
        if (radicand < 0.0) return EPS;
        float y = sqrt(radicand) - (R - secant_base_radius);
        return max(EPS, y);
    }
    else if (tip_profile == 3) {
        // Elliptical
        float base_radius = bullet_diameter * 0.5;
        return base_radius * sqrt(max(EPS, 1.0 - ogive_position * ogive_position));
    }
    
    return EPS;
}

// ======================
// NORMAL CALCULATION
// ======================
vec3 calculate_surface_normal(float parameter_t, float angle, float overall_length) {
    // For gap regions, return radial normal
    if (is_in_gap_region(parameter_t)) {
        return normalize(vec3(cos(angle), 0.0, sin(angle)));
    }

    float t_forward = min(parameter_t + EPS, 1.0);
    float t_backward = max(parameter_t - EPS, 0.0);

    float radius_forward = calculate_radius(t_forward);
    float radius_backward = calculate_radius(t_backward);

    float y_forward = get_display_position(t_forward);
    float y_backward = get_display_position(t_backward);

    // Central differences for derivatives
    if (abs(t_forward - t_backward) < 2.0 * EPS) {
        return vec3(cos(angle), 0.0, sin(angle));
    }

    float dr_dt = (radius_forward - radius_backward) / (t_forward - t_backward);
    float dy_dt = (y_forward - y_backward) / (t_forward - t_backward);

    if (abs(dy_dt) < EPS) {
        return normalize(vec3(cos(angle), 0.0, sin(angle)));
    }

    float dr_dy = dr_dt / dy_dt;
    vec3 normal = vec3(cos(angle), -dr_dy, sin(angle));
    normal = normalize(normal);

    // Ensure normal points outward
    vec3 radial = vec3(cos(angle), 0.0, sin(angle));
    if (dot(normal, radial) < 0.0) {
        normal = -normal;
    }

    return normal;
}

// Calculate tracer visibility and intensity - FIXED VERSION
float calculate_tracer_intensity
(float parameter_t) {
    if (!tracer_enable) {
        return 0.0;
    }
    
    float extraction_distance = to_meters(bullet_extraction_mm);
    
    // Case position in world space (case doesn't move)
    float case_length = to_meters(case_length_mm);
    
    // Tracer starts at TS mm from the CASE (not world origin)
    float tracer_start_from_case = to_meters(tracer_start_mm) + case_length;
    float tracer_length = to_meters(tracer_length_mm);
    
    // Current vertex world position
    float world_position = get_display_position(parameter_t);
    
    // Tracer ignition point moves with bullet extraction
    float tracer_ignition_point = tracer_start_from_case;
    
    // Tracer extends backwards from ignition point
    float tracer_start_world = tracer_ignition_point;
    float tracer_end_world = tracer_ignition_point + tracer_length;
    
    // Only show tracer between start and end positions
    if (world_position >= tracer_start_world && world_position <= tracer_end_world) {
        // Calculate normalized position along tracer (0 at ignition, 1 at end)
        float tracer_normalized = (world_position - tracer_start_world) / tracer_length;
        
        // Apply power curve for falloff (fades out along the length)
        return pow(1.0 - tracer_normalized, tracer_power);
    }
    
    return 0.0;
}

// ======================
// SURFACE TYPE DETECTION
// ======================
int get_surface_type(float parameter_t) {
    // Tracer region - check if this position should show tracer
    if (is_in_gap_region(parameter_t)) {
        return SURFACE_TRACER;
    }

    float position = get_original_position(parameter_t);
    float case_length = to_meters(case_length_mm);
    float overall_length = to_meters(overall_length_mm);

    // --- CASE SECTIONS ---
    float primer_end = case_length * primer_percent;
    if (position < primer_end) return SURFACE_PRIMER;
    
    float rim_end = primer_end + case_length * rim_percent;
    if (position < rim_end) return SURFACE_RIM;
    
    float base_end = rim_end + case_length * base_percent;
    if (position < base_end) return SURFACE_CASE;
    
    if (position < case_length) return SURFACE_CASE;
    
    // --- BULLET SECTIONS ---
    float bullet_position = position - case_length;
    float bullet_section_length = overall_length - case_length;
    
    float base_section_length = bullet_section_length * bullet_base_color_percent;
    if (bullet_position < base_section_length) return SURFACE_BULLET_BASE;
    
    float tip_start = bullet_section_length * bullet_tip_color_percent;
    if (bullet_position > tip_start) return SURFACE_BULLET_TIP;
    
    return SURFACE_BULLET_BODY;
}

// ======================
// VERTEX SHADER
// ======================
void vertex() {
    float parameter_t = UV.x;
    float angle = UV.y * 2.0 * TAU;

    float radius = calculate_radius(parameter_t);
    float overall_length = to_meters(overall_length_mm);
    float bullet_extraction = to_meters(bullet_extraction_mm);
    
    // Calculate display position with center of mass adjustment
    float display_position = get_display_position(parameter_t);
    float total_display_length = overall_length + bullet_extraction;
    float center_offset = center_of_mass * total_display_length;
    float y_position = display_position - center_offset;

    // Base vertex position
    vec3 base_vertex = vec3(
        cos(angle) * radius,
        y_position,
        sin(angle) * radius
    );

    // --- SCALE-AWARE PHYSICS-BASED TRAJECTORY CALCULATIONS ---
    
    // Only apply trajectory to bullet and tracer regions
    float case_length = to_meters(case_length_mm);
    bool is_projectile = (get_original_position(parameter_t) > case_length) || is_in_gap_region(parameter_t);
    
    if (is_projectile && bullet_extraction > EPS) {
        // Calculate distance from case in SCALED meters
        float distance_from_case = display_position - case_length;
        
        if (distance_from_case > 0.0) {
            // Convert scaled distance back to real-world distance for physics
            float real_world_distance = distance_from_case / scale;
            
            // Calculate time of flight based on real-world distance and velocity
            float time_in_flight = real_world_distance / muzzle_velocity_ms;
            
            // Calculate bullet drop due to gravity (d = 0.5 * g * t²)
            float real_world_drop = 0.5 * bullet_drop_ms2 * time_in_flight * time_in_flight;
            
            // Calculate wind drift (d = wind_velocity * time)
            float real_world_wind_drift = wind_velocity_ms * time_in_flight;
            
            // Apply zeroing compensation (adjusts point of impact)
            float zeroing_time = zero_range_m / muzzle_velocity_ms;
            float zeroing_drop = 0.5 * bullet_drop_ms2 * zeroing_time * zeroing_time;
            float real_world_drop_compensation = real_world_drop - zeroing_drop * (real_world_distance / zero_range_m);
            
            // Convert real-world physics back to scaled coordinates
            float scaled_drop = real_world_drop_compensation * scale;
            float scaled_wind_drift = real_world_wind_drift * scale;
            
            // Apply trajectory adjustments in scaled coordinates
            base_vertex.z -= scaled_drop;
            base_vertex.x += scaled_wind_drift;
            
            // Optional: Add slight rotation to bullet based on trajectory
            if (!is_in_gap_region(parameter_t)) {
                float max_tip_tilt = 0.1; // radians
                float tilt_x = scaled_wind_drift * max_tip_tilt * 0.1;
                float tilt_z = scaled_drop * max_tip_tilt * 0.1;
                
                // Apply more tilt to the tip of the bullet
                float bullet_tip_factor = 0.0;
                float bullet_position = get_original_position(parameter_t) - case_length;
                float bullet_length = overall_length - case_length;
                if (bullet_position > 0.0) {
                    bullet_tip_factor = bullet_position / bullet_length;
                    bullet_tip_factor = pow(bullet_tip_factor, 2.0); // More tilt at tip
                }
                
                base_vertex.x += tilt_x * bullet_tip_factor;
                base_vertex.z += tilt_z * bullet_tip_factor;
            }
        }
    }

    VERTEX = base_vertex;
    NORMAL = calculate_surface_normal(parameter_t, angle, overall_length);
}

// ======================
// FRAGMENT SHADER
// ======================
void fragment() {
    float parameter_t = UV.x;
    vec2 detail_uv = vec2(UV.x * uv_scale_x, UV.y * uv_scale_y);
    int surface_type = get_surface_type(parameter_t);
    
    // Only discard if radius is zero (shouldn't happen with tracer)
    if (calculate_radius(parameter_t) < EPS) {
        discard;
    }

    if (surface_type == SURFACE_PRIMER) {
        vec3 texture_sample = texture(primer_texture, detail_uv).rgb;
        ALBEDO = primer_color.rgb * texture_sample;
        ALPHA = primer_color.a;
        METALLIC = primer_metallic;
        ROUGHNESS = primer_roughness + wear_amount * 0.4;
    }
    else if (surface_type == SURFACE_RIM) {
        vec3 texture_sample = texture(rim_texture, detail_uv).rgb;
        ALBEDO = rim_color.rgb * texture_sample;
        ALPHA = rim_color.a;
        METALLIC = rim_metallic;
        ROUGHNESS = rim_roughness + wear_amount * 0.2;
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
        if (bullet_tip_heat_enable) {
            float heat_with_distance = lerp(bullet_extraction_mm, 0.0, 2.0 * case_length_mm, 0.0, 1.0);
            float pulse = sin(TIME * tracer_pulse_speed + parameter_t * 10.0) * 0.5 + 0.5;
            EMISSION = tracer_color.rgb 
                     * tracer_emission_energy 
                     * (0.7 + 0.3 * pulse)
                     * heat_with_distance;
        }
        vec3 texture_sample = texture(bullet_texture, detail_uv).rgb;
        ALBEDO = bullet_tip_color.rgb * texture_sample;
        ALPHA = bullet_tip_color.a;
        METALLIC = bullet_metallic;
        ROUGHNESS = bullet_roughness;
    }
    else if (surface_type == SURFACE_TRACER) {
        float tracer_position = get_tracer_position(parameter_t);
        float pulse = sin(TIME * tracer_pulse_speed + tracer_position * 10.0) * 0.5 + 0.5;
        
        // Calculate tracer intensity based on world position
        float tracer_intensity = calculate_tracer_intensity(parameter_t);
        
        ALBEDO = tracer_color.rgb;
        ALPHA = tracer_color.a * tracer_intensity;
        EMISSION = tracer_color.rgb * tracer_emission_energy * (0.7 + 0.3 * pulse) * tracer_intensity;
        METALLIC = 0.0;
        ROUGHNESS = 0.1;
        
        // Add some noise/variation to the tracer
        ALBEDO *= (0.9 + 0.1 * sin(tracer_position * 20.0 + TIME * 2.0)) * tracer_intensity;
    }

    // Add subtle gradient along the length
    ALBEDO *= (0.8 + 0.2 * UV.x);
}

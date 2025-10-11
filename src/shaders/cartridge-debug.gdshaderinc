
// ======================
// ADVANCED DEBUG VISUALIZATION
// ======================
void get_debug_info(float parameter_t, out int segment_index, out int region_type, out vec3 region_color) {
    int subdivisions = max(2, mesh_segments_length);
    float f = clamp(parameter_t, 0.0, 1.0) * float(subdivisions - 1);
    segment_index = int(floor(f + 0.5));
    int primer_end, case_start, case_end, rim_end_local, head_end_local, shoulder_end_local, neck_end_local, mouth_start, mouth_end, gap_start, gap_end, bullet_start, last_index;
    compute_boundaries(primer_end, case_start, case_end, rim_end_local, head_end_local, shoulder_end_local, neck_end_local, mouth_start, mouth_end, gap_start, gap_end, bullet_start, last_index);
    // Determine exact region
    if (segment_index <= primer_end) {
        region_type = 0;
        region_color = vec3(0.0, 0.0, 1.0); // BLUE - Primer
    }
    else if (segment_index <= rim_end_local) {
        region_type = 1;
        region_color = vec3(0.0, 1.0, 1.0); // CYAN - Rim
    }
    else if (segment_index <= head_end_local) {
        region_type = 2;
        region_color = vec3(0.5, 0.5, 0.0); // DARK YELLOW - Head
    }
    else if (segment_index <= shoulder_end_local) {
        region_type = 3;
        region_color = vec3(1.0, 1.0, 0.0); // YELLOW - Shoulder
    }
    else if (segment_index <= neck_end_local) {
        region_type = 4;
        region_color = vec3(1.0, 0.5, 0.0); // ORANGE - Neck
    }
    else if (segment_index <= mouth_end) {
        region_type = 5;
        region_color = vec3(1.0, 0.0, 0.5); // PINK - Mouth
    }
    else if (segment_index <= gap_end) {
        region_type = 6;
        region_color = vec3(0.0, 1.0, 0.0); // GREEN - Gap/Tracer
    }
    else if (segment_index <= last_index) {
        // Bullet sub-regions
        int bullet_count = max(1, last_index - bullet_start + 1);
        float t = safe_div(float(segment_index - bullet_start), float(max(1, bullet_count - 1)));
        if (t < bullet_base_color_percent) {
            region_type = 7;
            region_color = vec3(0.1, 0.1, 0.1); // BLACK - Bullet Base
        } else if (t > bullet_tip_color_percent) {
            region_type = 9;
            region_color = vec3(1.0, 0.0, 1.0); // MAGENTA - Bullet Tip
        } else {
            region_type = 8;
            region_color = vec3(1.0, 0.0, 0.0); // RED - Bullet Body
        }
    }
    else {
        region_type = -1;
        region_color = vec3(1.0, 1.0, 1.0); // WHITE - Unknown
    }
}
// Replace fragment() with this advanced debug version:
void fragment() {
    float parameter_t = UV.x;
    int segment_index, region_type;
    vec3 region_color;
    get_debug_info(parameter_t, segment_index, region_type, region_color);
    ALBEDO = region_color;
    // Highlight segment boundaries
    int subdivisions = max(2, mesh_segments_length);
    float f = clamp(parameter_t, 0.0, 1.0) * float(subdivisions - 1);
    float segment_edge = abs(f - floor(f + 0.5)) * 2.0;
    if (segment_edge > 0.9) {
        ALBEDO = vec3(1.0, 1.0, 1.0); // Bright white at exact boundaries
    }
    // Add segment index as a pattern (optional)
    float pattern = mod(float(segment_index), 2.0);
    if (pattern < 0.1) {
        ALBEDO *= 0.7; // Darken every other segment for better visibility
    }
    ALPHA = 1.0;
    METALLIC = 0.0;
    ROUGHNESS = 1.0;
    EMISSION = vec3(0.0);
}

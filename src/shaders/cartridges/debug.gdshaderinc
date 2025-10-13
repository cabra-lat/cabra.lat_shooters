// ======================
// ADVANCED DEBUG VISUALIZATION
// ======================
void get_debug_info(vec2 uv, float parameter_t, CartridgeGeometry geo, out int segment_index, out int region_type, out vec3 region_color) {
    float f = clamp(parameter_t, 0.0, 1.0) * float(geo.total_rings - 1);
    segment_index = int(floor(f + 0.5));
    
    // Determine exact region using the precomputed geometry
    if (segment_index <= geo.primer_end) {
        region_type = 0;
        region_color = vec3(0.0, 0.0, 1.0); // BLUE - Primer
    }
    else if (segment_index <= geo.rim_end) {
        region_type = 1;
        region_color = vec3(0.0, 1.0, 1.0); // CYAN - Rim
    }
    else if (segment_index <= geo.head_end) {
        region_type = 2;
        region_color = vec3(0.5, 0.5, 0.0); // DARK YELLOW - Head
    }
    else if (segment_index <= geo.shoulder_end) {
        region_type = 3;
        region_color = vec3(1.0, 1.0, 0.0); // YELLOW - Shoulder
    }
    else if (segment_index <= geo.neck_end) {
        region_type = 4;
        region_color = vec3(1.0, 0.5, 0.0); // ORANGE - Neck
    }
    else if (segment_index <= geo.mouth_end) {
        region_type = 5;
        region_color = vec3(1.0, 0.0, 0.5); // PINK - Mouth
    }
    else if (segment_index <= geo.gap_end) {
        region_type = 6;
        region_color = vec3(0.0, 1.0, 0.0); // GREEN - Gap/Tracer
    }
    else if (segment_index <= geo.last_index) {
        // Bullet sub-regions
        int bullet_count = max(1, geo.last_index - geo.bullet_start + 1);
        float t = safe_div(float(segment_index - geo.bullet_start), float(max(1, bullet_count - 1)));
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
        region_color = vec3(1.0, 0.2, 0.8); // Magenta base (for stripes)
        // Stripe pattern based on UV.y angle around cylinder
        float stripe = step(0.5, fract(uv.y * 20.0)); // 20 stripes per turn
        region_color = mix(region_color, vec3(0.1), stripe); // alternate dark/light
    }
}

// Replace fragment() with this advanced debug version:
void fragment() {
    // Compute boundaries once (same as main fragment shader)
    CartridgeGeometry geo = compute_geometry_boundaries();
    
    float parameter_t = UV.x;
    int segment_index, region_type;
    vec3 region_color;
    get_debug_info(UV, parameter_t, geo, segment_index, region_type, region_color);
    
    ALBEDO = region_color;
    
    // Highlight segment boundaries
    float f = clamp(parameter_t, 0.0, 1.0) * float(geo.total_rings - 1);
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

group_uniforms Bevel_Settings;
uniform float primer_bevel_size : hint_range(0.0, 0.01) = 0.0002;
uniform float rim_bevel_size : hint_range(0.0, 0.01) = 0.0003;
uniform float bevel_smoothness : hint_range(0.0, 0.1) = 0.01;

group_uniforms Stamp_Settings;
uniform sampler2D stamp_font : source_color;
uniform int cells_per_row = 16;
uniform int cells_per_col = 16;
uniform int cells_width   = 32;
uniform int cells_height  = 32;
uniform int stamp_name[20];
uniform int stamp_characters = 20;
uniform int stamp_orientation : hint_enum("Outward","Inward") = 1;
uniform int stamp_style : hint_enum("Engraved","Embossed","Debossed") = 0; // ADDED THIS
uniform float stamp_depth = 0.0001;
uniform float stamp_size = 0.005;
uniform float stamp_ring_inner : hint_range(0.0, 1.0) = 0.00; // keep it 0 otherwise we can't see shit
uniform float stamp_ring_outer : hint_range(0.0, 1.0) = 0.95;
uniform float stamp_char_scale : hint_range(0.01, 2.0) = 0.50;
uniform float stamp_char_spacing : hint_range(0.5, 2.0) = 1.0;
uniform float stamp_radius_offset : hint_range(0.5, 1.0) = 0.825;
uniform float stamp_normal_strength : hint_range(0.0, 20.0) = 8.0;
uniform float stamp_start_angle : hint_range(-3.1415, 3.1415) = -3.1415;
uniform float stamp_normal_detail : hint_range(0.0, 2.0) = 0.5;

// Bumpy effect controls - ADDED THESE
uniform float stamp_bump_intensity : hint_range(0.0, 5.0) = 2.0;
uniform float stamp_bump_roughness : hint_range(0.0, 1.0) = 0.3;
uniform float stamp_edge_wear : hint_range(0.0, 1.0) = 0.1;
uniform float stamp_metal_scratch : hint_range(0.0, 1.0) = 0.2;

// SDF-specific uniforms
uniform float stamp_sdf_smoothness : hint_range(0.0, 0.1) = 0.02;
uniform float stamp_sdf_threshold : hint_range(0.3, 0.7) = 0.5;
uniform float stamp_sdf_outline : hint_range(0.0, 0.2) = 0.0;
uniform vec4 stamp_sdf_outline_color : source_color = vec4(0.1, 0.1, 0.1, 1.0);

// Ambient occlusion uniforms
uniform float stamp_ao_strength : hint_range(0.0, 2.0) = 1.0;
uniform float stamp_ao_radius : hint_range(0.0, 0.1) = 0.02;
uniform float stamp_ao_darkness : hint_range(0.0, 1.0) = 0.3;


// Simple edge-based ambient occlusion (more efficient)
float calculate_stamp_ao(vec2 char_uv, int style) {
    float edge = length(char_uv);
    float ao = 1.0;
    
    if (style == 0) { // Engraved - darken edges and center
        float edge_ao = smoothstep(0.0, 0.4, edge);
        float center_ao = 1.0 - smoothstep(0.0, 0.3, 1.0 - edge);
        ao -= (edge_ao * 0.7 + center_ao * 0.3) * stamp_ao_darkness;
    } 
    else if (style == 1) { // Embossed - darken around the base
        float base_ao = smoothstep(0.2, 0.4, edge);
        ao -= base_ao * stamp_ao_darkness * 0.5;
    } 
    else { // Debossed - darken edges
        float edge_ao = smoothstep(0.0, 0.4, edge);
        ao -= edge_ao * stamp_ao_darkness * 0.6;
    }
    
    return clamp(ao, 0.3, 1.0);
}

// Apply bevel effect to primer and rim
void apply_bevel(inout vec3 normal, vec3 world_pos, float max_radius, int surface_type) {
    float radius = length(world_pos.xz);
    
    if (surface_type == SURFACE_PRIMER) {
        // Primer bevel - create a slight slope at the edges
        float primer_radius = to_meters(primer_diameter_mm) * 0.5;
        float edge_distance = 1.0 - smoothstep(primer_radius - primer_bevel_size, primer_radius, radius);
        
        if (edge_distance > 0.0) {
            // Create bevel normal that slopes outward
            vec3 bevel_normal = normalize(vec3(world_pos.x, primer_bevel_size * 5.0, world_pos.z));
            normal = normalize(mix(normal, bevel_normal, edge_distance));
        }
    }
    else if (surface_type == SURFACE_RIM) {
        // Rim bevel - create slope at both inner and outer edges
        float rim_radius = to_meters(rim_diameter_mm) * 0.5;
        float head_radius = to_meters(primer_diameter_mm) * 0.5;
        
        // Outer edge bevel
        float outer_edge = 1.0 - smoothstep(rim_radius - rim_bevel_size, rim_radius, radius);
        // Inner edge bevel (where rim meets case head)
        float inner_edge = smoothstep(head_radius, head_radius + rim_bevel_size, radius);
        
        float bevel_strength = max(outer_edge, inner_edge);
        
        if (bevel_strength > 0.0) {
            // For outer edge, slope outward; for inner edge, slope inward
            vec3 bevel_normal;
            if (outer_edge > inner_edge) {
                bevel_normal = normalize(vec3(world_pos.x, rim_bevel_size * 3.0, world_pos.z));
            } else {
                bevel_normal = normalize(vec3(-world_pos.x, rim_bevel_size * 3.0, -world_pos.z));
            }
            normal = normalize(mix(normal, bevel_normal, bevel_strength));
        }
    }
}

// Updated apply_stamp function with bevel support
void apply_stamp(inout float roughness, inout vec3 albedo, inout vec3 normal, vec3 world_pos, float max_radius, int surface_type) {
    // Apply bevel to primer and rim surfaces
    if (surface_type == SURFACE_PRIMER || surface_type == SURFACE_RIM) {
        apply_bevel(normal, world_pos, max_radius, surface_type);
    }
    
    vec2 stamp_uv = world_pos.xz / max_radius;
    float angle = atan(stamp_uv.x, stamp_uv.y);
    float radius = length(stamp_uv);

    if (radius < stamp_ring_inner || radius > stamp_ring_outer) return;

    float chars_total = float(stamp_characters);
    float angle_per_char = TAU / chars_total * stamp_char_spacing;

    for (int i = 0; i < 20; i++) {
        if (i >= stamp_characters) break;
        
        // Handle character order and angle based on orientation
        int char_index = i;
        float char_angle = float(i) * angle_per_char + stamp_start_angle;
        
        if (stamp_orientation == 1) { // Inward
            char_index = stamp_characters - 1 - i;
            char_angle = - float(char_index) * angle_per_char + stamp_start_angle;
        }
        
        vec2 char_dir = vec2(cos(char_angle), sin(char_angle));
        vec2 char_center = char_dir * stamp_radius_offset;
        vec2 to_fragment = stamp_uv - char_center;

        // Calculate base alignment (outward facing)
        vec2 tangent = vec2(-char_dir.y, char_dir.x);
        vec2 aligned_uv = vec2(
            dot(to_fragment, tangent),
            dot(to_fragment, char_dir)
        );

        // Apply orientation transformations
        if (stamp_orientation == 1) { // Inward - flip both axes (180° rotation)
            aligned_uv = -aligned_uv;
        }

        vec2 char_uv = aligned_uv / stamp_char_scale;

        if (abs(char_uv.x) < 0.5 && abs(char_uv.y) < 0.5) {
            int char_code = stamp_name[char_index];
            int cell_x = char_code % cells_per_row;
            int cell_y = char_code / cells_per_row;

            vec2 cell_size = vec2(1.0) / vec2(float(cells_per_row), float(cells_per_col));
            vec2 cell_offset = vec2(float(cell_x), float(cell_y)) * cell_size;
            vec2 inner_uv = (char_uv + 0.5) * cell_size;
            vec2 atlas_uv = cell_offset + inner_uv;

            // SDF FONT SAMPLING
            float sdf_value = texture(stamp_font, atlas_uv).r;
            
            // Convert SDF to smooth alpha with anti-aliasing
            float char_alpha = smoothstep(
                stamp_sdf_threshold - stamp_sdf_smoothness,
                stamp_sdf_threshold + stamp_sdf_smoothness,
                sdf_value
            );
            
            // Optional outline effect
            float outline_alpha = 0.0;
            if (stamp_sdf_outline > 0.0) {
                outline_alpha = smoothstep(
                    stamp_sdf_threshold - stamp_sdf_outline - stamp_sdf_smoothness,
                    stamp_sdf_threshold - stamp_sdf_outline + stamp_sdf_smoothness,
                    sdf_value
                );
            }

            // Apply stamp with SDF rendering
            if (char_alpha > 0.01 || outline_alpha > 0.01) {
                // Calculate ambient occlusion
                float ao = calculate_stamp_ao(char_uv, stamp_style);
                
                // Apply outline first (if any)
                if (outline_alpha > 0.01) {
                    albedo = mix(albedo, stamp_sdf_outline_color.rgb, outline_alpha);
                }
                
                // Apply main text color with AO
                albedo = mix(albedo, albedo * ao, char_alpha);
                
                // CREATE BUMPY NORMAL BASED ON STAMP STYLE
                vec3 bump_normal = vec3(0.0);
                
                if (stamp_style == 0) { // ENGRAVED - depressed into surface
                    float depth = -stamp_depth;
                    bump_normal = vec3(
                        char_uv.x * stamp_normal_detail,
                        char_uv.y * stamp_normal_detail,
                        depth * stamp_normal_strength
                    );
                } 
                else if (stamp_style == 1) { // EMBOSSED - raised from surface
                    float height = stamp_depth;
                    bump_normal = vec3(
                        char_uv.x * stamp_normal_detail,
                        char_uv.y * stamp_normal_detail,
                        height * stamp_normal_strength
                    );
                } 
                else { // DEBOSSED - stamped/pressed (like coin)
                    float center_depth = -stamp_depth * 0.7;
                    float edge_height = smoothstep(0.3, 0.1, length(char_uv)) * stamp_depth * 0.3;
                    float total_height = center_depth + edge_height;
                    
                    bump_normal = vec3(
                        char_uv.x * stamp_normal_detail * 2.0,
                        char_uv.y * stamp_normal_detail * 2.0,
                        total_height * stamp_normal_strength
                    );
                }
                
                // Apply the bump normal
                normal = normalize(normal + bump_normal * char_alpha);
                
                // Adjust roughness for more realistic metal
                roughness = mix(roughness, roughness + 0.2, char_alpha * 0.3);
            }
        }
    }
}


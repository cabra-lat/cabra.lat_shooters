shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// --- Texture Uniforms ---
uniform sampler2D u_scope_texture;
uniform sampler2D u_reticle_texture;

// --- Color Uniforms ---
uniform vec4 u_reticle_tint : source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform vec4 u_bezel_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 u_front_tint_color : source_color = vec4(1.0, 0.58, 0.0, 0.757);
uniform vec4 u_rear_tint_color : source_color = vec4(0.0, 1.0, 1.0, 0.298);

// --- Lens Effect Uniforms ---
uniform float u_lens_curvature : hint_range(0.0, 1.0) = 0.3;
uniform float u_reflection_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float u_chromatic_aberration : hint_range(0.0, 0.02) = 0.005;
uniform float u_vignette_strength : hint_range(0.0, 1.0) = 0.3;
uniform float u_fresnel_power : hint_range(0.5, 5.0) = 2.0;

// --- UV Transform Uniforms ---
uniform vec2 u_front_lens_scale = vec2(0.5, 0.5);
uniform vec2 u_front_lens_offset = vec2(-0.25, 0.25);
uniform float u_front_lens_radius = 0.45;
uniform float u_front_lens_rotation = 0.0;

uniform vec2 u_rear_lens_scale = vec2(0.5, -0.5);
uniform vec2 u_rear_lens_offset = vec2(0.25, 0.25);
uniform float u_rear_lens_radius = 0.45;
uniform float u_rear_lens_rotation = 0.0;

// Rotation function
vec2 rotate_around_point(vec2 uv, vec2 center, float rotation) {
    vec2 centered_uv = uv - center;
    float cos_rot = cos(rotation);
    float sin_rot = sin(rotation);
    vec2 rotated_uv = vec2(
        centered_uv.x * cos_rot - centered_uv.y * sin_rot,
        centered_uv.x * sin_rot + centered_uv.y * cos_rot
    );
    return rotated_uv + center;
}

// Convert RGB to HSV
vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// Convert HSV to RGB
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Get complementary color
vec3 get_complementary_color(vec3 color) {
    vec3 hsv = rgb2hsv(color);
    hsv.x = fract(hsv.x + 0.5); // Shift hue by 180 degrees
    return hsv2rgb(hsv);
}

// Apply lens distortion (barrel distortion) - ONLY within circle
vec2 apply_lens_distortion(vec2 uv, vec2 center, float curvature, float radius) {
    vec2 offset = uv - center;
    float dist = length(offset);

    // Only apply distortion within the circle radius
    if (dist <= radius) {
        // Normalize distance for distortion calculation
        float normalized_dist = dist / radius;
        float distortion = 1.0 + curvature * normalized_dist * normalized_dist;
        return center + offset * distortion;
    }
    return uv; // Return original UV outside circle
}

// Apply chromatic aberration - ONLY within circle
vec3 apply_chromatic_aberration(sampler2D tex, vec2 uv, vec2 center, vec2 direction, float strength, float radius) {
    vec2 offset = uv - center;
    float dist = length(offset);

    if (dist <= radius) {
        float r = texture(tex, uv - direction * strength).r;
        float g = texture(tex, uv).g;
        float b = texture(tex, uv + direction * strength).b;
        return vec3(r, g, b);
    } else {
        return texture(tex, uv).rgb;
    }
}

// Generate lens reflection
float generate_lens_reflection(vec2 uv, vec2 center, float intensity, float radius) {
    vec2 to_center = center - uv;
    float dist = length(to_center);

    if (dist <= radius) {
        // Create a reflection highlight
        vec2 light_dir = normalize(vec2(0.3, 0.7)); // Light coming from top-right
        float reflection = dot(normalize(to_center), light_dir);
        reflection = max(0.0, reflection);
        reflection = pow(reflection, 8.0) * intensity;

        // Make reflection fade towards edges
        reflection *= (1.0 - dist/radius);

        return reflection;
    }
    return 0.0;
}

// Apply vignette effect
float apply_vignette(vec2 uv, vec2 center, float strength, float radius) {
    float dist = length(uv - center);
    if (dist <= radius) {
        float normalized_dist = dist / radius;
        return 1.0 - strength * normalized_dist * normalized_dist;
    }
    return 0.0;
}

// Enhanced scope color function
vec3 get_enhanced_scope_color(vec2 base_uv, vec2 scale, vec2 offset, float rotation, float radius,
                             vec4 tint_color, bool is_front_lens) {

    // Apply transformations
    vec2 offset_uv = base_uv - offset;
    vec2 scaled_uv = (offset_uv - vec2(0.5)) / scale + vec2(0.5);
    vec2 rotated_uv = rotate_around_point(scaled_uv, vec2(0.5), rotation);

    // Calculate distance from lens center for masking
    vec2 center_uv_modified = rotated_uv - vec2(0.5);
    float dist = length(center_uv_modified);

    if (dist <= radius) {
        // Apply lens distortion ONLY within the circle
        vec2 distorted_uv = apply_lens_distortion(rotated_uv, vec2(0.5), u_lens_curvature, radius);

        // Apply vignette
        float vignette = apply_vignette(rotated_uv, vec2(0.5), u_vignette_strength, radius);

        // Sample scope texture with chromatic aberration for front lens
        vec3 scope_color;
        if (is_front_lens && u_chromatic_aberration > 0.0) {
            vec2 dir = normalize(center_uv_modified);
            scope_color = apply_chromatic_aberration(u_scope_texture, distorted_uv, vec2(0.5), dir, u_chromatic_aberration, radius);
        } else {
            scope_color = texture(u_scope_texture, distorted_uv).rgb;
        }

        // Apply tint to scope color
        scope_color = mix(scope_color, scope_color * tint_color.rgb, tint_color.a);

        // Apply tint based on lens type
        vec4 reticle_sample;

        if (is_front_lens) {
            // Front lens: no reticle
            reticle_sample = vec4(0.0, 0.0, 0.0, 0.0);
        } else {
            // Rear lens: sample reticle
            reticle_sample = texture(u_reticle_texture, rotated_uv);
        }

        // Mix scope and reticle with proper tint handling
        vec3 final_color;
        // Rear lens: mix scope with tinted reticle
        vec3 tinted_reticle = reticle_sample.rgb * u_reticle_tint.rgb;
        float reticle_alpha = reticle_sample.a * u_reticle_tint.a;
        final_color = mix(scope_color, tinted_reticle, reticle_alpha);

        // Apply vignette
        final_color *= vignette;

        // Add lens reflection for front lens
        if (is_front_lens) {
            float reflection = generate_lens_reflection(rotated_uv, vec2(0.5), u_reflection_intensity, radius);
            final_color += reflection * tint_color.rgb;
        }

        // Add fresnel-like edge effect
        float edge = pow(1.0 - dist/radius, u_fresnel_power);
        final_color += edge * 0.1 * tint_color.rgb;

        return final_color;

    } else {
        // Outside the lens circle: Bezel color (blackout)
        return u_bezel_color.rgb;
    }
}

void fragment() {
    vec3 final_color = u_bezel_color.rgb;

    // For each lens, we need to check if the current UV is within its area

    // Front lens check
    vec2 offset_uv_front = UV - u_front_lens_offset;
    vec2 scaled_uv_front = (offset_uv_front - vec2(0.5)) / u_front_lens_scale + vec2(0.5);
    vec2 rotated_uv_front = rotate_around_point(scaled_uv_front, vec2(0.5), u_front_lens_rotation);
    float dist_front = length(rotated_uv_front - vec2(0.5));

    // Rear lens check
    vec2 offset_uv_rear = UV - u_rear_lens_offset;
    vec2 scaled_uv_rear = (offset_uv_rear - vec2(0.5)) / u_rear_lens_scale + vec2(0.5);
    vec2 rotated_uv_rear = rotate_around_point(scaled_uv_rear, vec2(0.5), u_rear_lens_rotation);
    float dist_rear = length(rotated_uv_rear - vec2(0.5));

    // Calculate both lens colors
    // Front lens (more reflective)
    vec3 color_front = get_enhanced_scope_color(UV, u_front_lens_scale, u_front_lens_offset, u_front_lens_rotation,
                                          u_front_lens_radius, u_front_tint_color, true);

    // Rear lens (with reticle)
    vec3 color_rear = get_enhanced_scope_color(UV, u_rear_lens_scale, u_rear_lens_offset, u_rear_lens_rotation,
                                          u_rear_lens_radius, u_rear_tint_color, false);

    // Apply lens colors where appropriate
    if (dist_front <= u_front_lens_radius) {
        final_color = color_front;
    }
    if (dist_rear <= u_rear_lens_radius) {
        final_color = color_rear;
    }

    ALBEDO = final_color;
    ALPHA = 1.0;
}
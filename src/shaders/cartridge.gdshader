shader_type spatial;
render_mode cull_front, vertex_lighting;
 
const float eps = 1e-9;

// --- GLOBAL SCALE (1.0 = real size in mm, 10 = 10x larger) ---
uniform float scale : hint_range(0.1, 5000.0, 0.1) = 1.0;
uniform float shift_y: hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float uv_x: hint_range(0.0, 100.0, 0.01) = 20.0;
uniform float uv_y: hint_range(0.0, 100.0, 0.01) = 20.0;

// --- Dimensions in MILLIMETERS (user-friendly) ---
uniform float bullet_diameter_mm : hint_range(0.0, 20.0, 0.1) = 5.70;
uniform float land_diameter_mm : hint_range(0.0, 20.0, 0.1) = 5.56;
uniform float neck_diameter_mm : hint_range(0.0, 20.0, 0.1) = 6.43;
uniform float neck_percent : hint_range(0.0, 1.0, 0.01) = 0.9;
uniform float shoulder_diameter_mm : hint_range(0.0, 20.0, 0.1) = 9.00;
uniform float shoulder_percent : hint_range(0.0, 1.0, 0.01) = 0.8;
uniform float base_diameter_mm : hint_range(0.0, 20.0, 0.1) = 9.58;
uniform float base_percent : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float rim_diameter_mm : hint_range(0.0, 20.0, 0.1) = 9.60;
uniform float rim_percent : hint_range(0.0, 1.0, 0.01) = 0.1;

uniform float case_length_mm : hint_range(0.0, 100.0, 0.1) = 44.70;
uniform float overall_length_mm : hint_range(0.0, 100.0, 0.1) = 57.40;

// --- Bullet base & extraction ---
uniform float bullet_extraction_mm : hint_range(0.0, 50.0, 0.1) = 0.0;
uniform float bullet_base_percent : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float bullet_tip_percent: hint_range(0.0, 1.0, 0.01) = 0.7;
// --- Bullet tip controls ---
uniform float ogive_radius_factor : hint_range(0.5, 5.0, 0.01) = 1.0;
uniform int tip_profile : hint_range(0, 3) = 1;

// --- Primer ---
uniform float primer_diameter_mm : hint_range(0.0, 5.0, 0.01) = 3.0;
uniform float primer_depth_mm : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform bool show_primer = true;

// --- Materials ---
uniform vec4 case_color : source_color = vec4(0.8, 0.6, 0.2, 1.0);
uniform vec4 bullet_color : source_color = vec4(0.7, 0.4, 0.2, 1.0);
uniform vec4 bullet_tip_color : source_color = vec4(0.9, 0.8, 0.7, 1.0);
uniform vec4 bullet_base_color : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform float case_metallic : hint_range(0,1) = 0.8;
uniform float case_roughness : hint_range(0,1) = 0.3;
uniform float bullet_metallic : hint_range(0,1) = 0.6;
uniform float bullet_roughness : hint_range(0,1) = 0.2;
uniform float primer_metallic : hint_range(0,1) = 0.3;
uniform float primer_roughness : hint_range(0,1) = 0.7;

// --- Textures ---
uniform sampler2D case_texture : source_color;
uniform sampler2D bullet_texture : source_color;
uniform sampler2D primer_texture : source_color;
uniform float wear_amount : hint_range(0,1) = 0.1;

// ======================
// INTERNAL: Convert mm → meters with scale
// ======================
float to_m(float mm) {
	return mm * 0.001 * scale;
}

// Linear interpolation between two radii over a segment
float linear_segment(float pos, float pos0, float pos1, float rad0, float rad1) {
    if (pos <= pos0) return rad0;
    if (pos >= pos1) return rad1;
    float t = (pos - pos0) / max(eps, pos1 - pos0);
    return mix(rad0, rad1, t);
}

// ======================
// CORRECTED OGIVE CALCULATION
// ======================
float get_radius(float t) {
    float bullet_ext = to_m(bullet_extraction_mm);
    float total_len = to_m(overall_length_mm) + bullet_ext;
    float pos = t * total_len;

    float bullet_diam = to_m(bullet_diameter_mm);
    float neck_diam = to_m(neck_diameter_mm);
    float shoulder_diam = to_m(shoulder_diameter_mm);
    float base_diam = to_m(base_diameter_mm);
    float rim_diam = to_m(rim_diameter_mm);
    float case_len = to_m(case_length_mm);
    float primer_diam = to_m(primer_diameter_mm);
    float primer_dep = to_m(primer_depth_mm);

    float ogive_start = case_len + bullet_ext;
    float ogive_length = total_len - ogive_start;

    // --- Rim (constant) ---
	if (pos < eps) return 0.0;
    else if (pos < rim_percent * case_len) {
        return rim_diam * 0.5;
    }
    // --- Base taper: rim → base ---
    else if (pos < base_percent * case_len) {
        return linear_segment(
            pos,
            rim_percent * case_len,
            base_percent * case_len,
            rim_diam * 0.5,
            base_diam * 0.5
        );
    }
    // --- Case body: base → shoulder (constant shoulder) ---
    else if (pos < shoulder_percent * case_len) {
        return shoulder_diam * 0.5;
    }
    // --- Shoulder taper: shoulder → neck ---
    else if (pos < neck_percent * case_len) {
        return linear_segment(
            pos,
            shoulder_percent * case_len,
            neck_percent * case_len,
            shoulder_diam * 0.5,
            neck_diam * 0.5
        );
    }
    // --- Neck (constant) ---
    else if (pos < case_len) {
        return neck_diam * 0.5;
    }
    // --- Gap during extraction ---
    else if (pos < ogive_start + eps) {
        return 0.0;
    }
    // --- BULLET SECTION ---
    else {
        float s = pos - ogive_start;

        // Bullet base (cylindrical shank)
        if (s < 0.0) {
            return bullet_diam * 0.5;
        }
        // Ogive tip
        else if (ogive_length <= eps) {
            return bullet_diam * 0.5;
        }
        else if (tip_profile == 0) {
            // Truncated cone ogive (not full cone!)
            float tip_length = ogive_length * ogive_radius_factor; // Only last 30% tapers
            if (s > ogive_length - tip_length) {
                float taper_s = s - (ogive_length - tip_length);
                return linear_segment(
                    taper_s,
                    0.0,
                    tip_length,
                    bullet_diam * 0.5,
                    0.0
                );
            } else {
                return bullet_diam * 0.5; // Cylindrical shank
            }
        }
        else if (tip_profile == 1) {
            // Tangent ogive (your existing logic is fine)
            float r0 = bullet_diam * 0.5;
            float L = ogive_length;
            float R = (L * L + r0 * r0) / (2.0 * r0) * ogive_radius_factor;
            float x = s;
            float y = R - sqrt(max(0.0, R * R - x * x));
            return max(0.0, r0 - y);
        }
        else if (tip_profile == 2) {
            // Secant ogive
            float r0 = bullet_diam * 0.5;
            float L = ogive_length;
            float base_radius = r0 * 0.9;
            float R = (L * L + base_radius * base_radius) / (2.0 * base_radius) * ogive_radius_factor;
            float x = s;
            float y = R - sqrt(max(0.0, R * R - x * x));
            return max(0.0, mix(r0, base_radius, 0.3) - y);
        }
        else {
            // Elliptical
            float r0 = bullet_diam * 0.5;
            float t_ellipse = s / ogive_length;
            return r0 * sqrt(max(0.0, 1.0 - t_ellipse * t_ellipse));
        }
    }
    return 0.0;
}

// ======================
// SIMPLIFIED BUT ROBUST NORMAL CALCULATION
// ======================
vec3 calculate_normal(float t, float angle, float total_len) {
    // Use central differences for position
    float delta = 0.001;
    // Current position
    float r_current = get_radius(t);
    float y_current = (t - shift_y) * total_len;
    
    // Neighboring positions
    float t_forward = min(t + delta, 1.0);
    float t_backward = max(t - delta, 0.0);
    
    float r_forward = get_radius(t_forward);
    float r_backward = get_radius(t_backward);
    
    float y_forward = (t_forward - shift_y) * total_len;
    float y_backward = (t_backward - shift_y) * total_len;
    
    // Central differences for derivatives
    float dr_dt = (r_forward - r_backward) / (t_forward - t_backward);
    float dy_dt = (y_forward - y_backward) / (t_forward - t_backward);
    
    // For a surface of revolution, the gradient is:
    // ∇f = (2x, 2y - 2R*dy/dx, 2z) but let's use a more direct approach
    
    // The surface point is: P = (r*cosθ, y, r*sinθ)
    // The normal can be computed as: N = (cosθ, -dr/dy, sinθ) normalized
    // But since we have dr/dt and dy/dt, we can use: dr/dy = (dr/dt) / (dy/dt)
    
    if (abs(dy_dt) < delta) {
        // Vertical surface - normal is purely horizontal
        return normalize(vec3(cos(angle), 0.0, sin(angle)));
    }
    
    float dr_dy = dr_dt / dy_dt;
    
    // The outward normal for a surface of revolution
    vec3 normal = vec3(cos(angle), -dr_dy, sin(angle));
    
    // Always normalize and ensure it points outward
    normal = normalize(normal);
    
    // For convex shapes (like bullets), the normal should point away from the central axis
    // We can verify by checking the dot product with the radial direction
    vec3 radial = vec3(cos(angle), 0.0, sin(angle));
    if (dot(normal, radial) < 0.0) {
        normal = abs(normal);
    }
    
    return normal;
}

// ======================
// MATERIAL: Surface Type
// ======================
int get_surface_type(float t) {
	float bullet_ext = to_m(bullet_extraction_mm);
	float total_len = to_m(overall_length_mm) + bullet_ext;

	float pos = t * total_len;
	float case_len = to_m(case_length_mm);
	float primer_d = to_m(primer_diameter_mm);
	float neck_d   = to_m(neck_diameter_mm);
	
	float radius = get_radius(t);
	if (radius < 0.0) return -1;
	if (pos < primer_d) return 0;
	if (pos < case_len * rim_percent) return 1;
	if (pos < case_len - eps) return 2;
	if (pos < case_len) return 0;
    if (pos < case_len + bullet_ext - eps) return -1;
	float ogive_start = case_len + bullet_ext;
	float base_start = ogive_start + (total_len - ogive_start) * bullet_base_percent;

	if (pos < base_start) return 3;

	float tip_start = ogive_start + (total_len - ogive_start) * bullet_tip_percent;
	return (pos > tip_start) ? 5 : 4;
}

// ======================
// VERTEX SHADER
// ======================
void vertex() {
	float t = UV.x;
	float angle = UV.y * 4.0 * PI;

	float radius = get_radius(t);
	float bullet_ext = to_m(bullet_extraction_mm);
	float total_len = to_m(overall_length_mm) + bullet_ext;

	float y = (t - shift_y) * total_len;

	VERTEX = vec3(
		cos(angle) * radius,
		y,
		sin(angle) * radius
	);

	// Try the simpler normal calculation first
	NORMAL = calculate_normal(t, angle, total_len);
}

// ======================
// FRAGMENT SHADER
// ======================
void fragment() {
	float t = UV.x;
	vec2 detail_uv = vec2(UV.x * uv_x, UV.y * uv_y);
	int surface = get_surface_type(t);
	if (surface == -1) {
		discard;
	}
	if (surface == 0) {
		vec3 tex = texture(primer_texture, detail_uv).rgb;
		ALBEDO = vec3(0.3, 0.3, 0.35) * tex;
		METALLIC = primer_metallic;
		ROUGHNESS = primer_roughness + wear_amount * 0.4;
	}
	else if (surface == 1) {
		vec3 tex = texture(case_texture, detail_uv).rgb;
		ALBEDO = case_color.rgb * tex * 1.1;
		METALLIC = case_metallic;
		ROUGHNESS = case_roughness + wear_amount * 0.2;
	}
	else if (surface == 2) {
		vec3 tex = texture(case_texture, detail_uv).rgb;
		ALBEDO = case_color.rgb * tex;
		ALPHA = bullet_base_color.a;
		METALLIC = case_metallic;
		ROUGHNESS = case_roughness + wear_amount * 0.3;
	}
	else if (surface == 3) {
		vec3 tex = texture(bullet_texture, detail_uv).rgb;
		ALBEDO = bullet_base_color.rgb;
		ALPHA = bullet_base_color.a;
		METALLIC = 0.1;
		ROUGHNESS = 0.8;
	}
	else if (surface == 4) {
		vec3 tex = texture(bullet_texture, detail_uv).rgb;
		ALBEDO = bullet_color.rgb * tex;
		METALLIC = bullet_metallic;
		ROUGHNESS = bullet_roughness + wear_amount * 0.2;
	}
	else {
		vec3 tex = texture(bullet_texture, detail_uv).rgb;
		ALBEDO = bullet_tip_color.rgb * tex;
		METALLIC = bullet_metallic * 0.5;
		ROUGHNESS = bullet_roughness * 0.8;
	}

	ALBEDO *= (0.8 + 0.2 * UV.x);
	
	// Debug normals - uncomment to check
	//ALBEDO = NORMAL * 0.5 + 0.5;
}
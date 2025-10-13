// circumferential coordinate: wrap around UV.y * circumference tiles
vec2 detail_uv_cylindrical(float u, float v, float  uv_scale_x, float uv_scale_y) {
  float u_circ = v * uv_scale_x;
  float v_axial = u * uv_scale_y;
  return vec2(u_circ, v_axial);
}

// NEW: Circular UV mapping for bottom surfaces (primer and rim) - using model space
varying vec3 model_space_position;

// Improved rim UV mapping that handles both bottom and sides
vec2 detail_uv_rim(vec2 uv, vec3 pos, float rim_diameter, float rim_thickness, float scale_x, float scale_y) {
    float max_radius = to_meters(rim_diameter) * 0.5;
    float rim_height = to_meters(rim_thickness);
    float radius = length(pos.xz);

    // Determine if we're on the bottom or side of the rim
    bool is_bottom = abs(pos.y) < EPS;
    bool is_side = !is_bottom && pos.y > 0.0 && pos.y < rim_height;

    if (is_bottom) {
        // Bottom surface - use circular mapping
        float normalized_radius = radius / max_radius;
        float angle = atan(pos.x, pos.z);

        vec2 circle_coord = vec2(cos(angle), sin(angle)) * normalized_radius;
        float u = circle_coord.x * 0.5;
        float v = circle_coord.y * 0.5;

        return vec2(u * scale_x - 0.5, v * scale_y - 0.5);
    }
    else if (is_side) {
        // Side surface - use cylindrical mapping but account for rim thickness
        float angle = atan(pos.x, pos.z);
        float height_ratio = pos.y / rim_height; // Normalize to rim thickness

        // Map to texture: U = angle around, V = height along rim side
        float u = (angle / (2.0 * PI)) * scale_x;
        float v = height_ratio * scale_y;

        return vec2(u, v);
    }
    else {
        // Fallback to cylindrical for other rim areas
        return detail_uv_cylindrical(uv.x, uv.y, scale_x, scale_y);
    }
}

// NEW: Corrected Circular UV mapping for bottom surfaces (primer and rim)
vec2 detail_uv_circular(vec2 uv, vec3 pos, float max_diameter, float scale_x, float scale_y) {
  float max_radius = to_meters(max_diameter) * 0.5;
  float radius = length(pos.xz);

  // For flat bottom surfaces, use circular mapping
  if (abs(pos.y) < uv.x) {
    // Map to unit circle, then scale to fit square texture
    float normalized_radius = radius / max_radius;
    float angle = atan(pos.x, pos.z);

    // Convert to circular coordinates (0,0 at center to 1,1 at edges)
    // This properly maps the circle to the square texture bounds
    vec2 circle_coord = vec2(cos(angle), sin(angle)) * normalized_radius;

    // Transform from [-1,1] range to [0,1] UV range
    // The entire circle fits within the square, diameter = 1.0
    float u = circle_coord.x * 0.5;
    float v = circle_coord.y * 0.5;

    return vec2(u * scale_x - 0.5, v * scale_y - 0.5);
  }
  // For cylindrical parts, fall back to cylindrical mapping
  else {
    return detail_uv_cylindrical(uv.x, uv.y, scale_x, scale_y);
  }
}

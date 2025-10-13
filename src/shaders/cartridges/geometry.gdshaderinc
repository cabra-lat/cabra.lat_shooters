// ======================
// GEOMETRY BOUNDARIES STRUCT
// ======================

struct CartridgeGeometry {
    // Main component boundaries
    int primer_start;
    int primer_end;
    int case_start;
    int case_end;
    int bullet_start;
    int last_index;
    
    // Case section boundaries
    int rim_end;
    int groove_end;
    int head_end;
    int shoulder_end;
    int neck_end;
    
    // Transition boundaries
    int mouth_start;
    int mouth_end;
    int gap_start;
    int gap_end;
    
    // Derived properties
    int total_rings;
    int case_rings;
    int bullet_rings;
    int primer_rings;
    int gap_rings;
};

// ======================
// BOUNDARY COMPUTATION WITH STRUCT
// ======================

CartridgeGeometry compute_geometry_boundaries() {
    CartridgeGeometry geo;
    
    // Total mesh configuration
    geo.total_rings = 2 + max(2, mesh_segments_length);
    geo.last_index = geo.total_rings - 1;
    
    // Component ring allocation
    geo.primer_rings = 2;
    int mouth_rings = 1;
    geo.gap_rings = (to_meters(bullet_extraction_mm) > EPS) ? max(1, gap_segments) : 0;
    
    // Calculate available rings
    int reserved_rings = geo.primer_rings + mouth_rings + geo.gap_rings;
    int available_rings = geo.total_rings - reserved_rings;
    
    // Ensure minimum rings for case and bullet
    if (available_rings < 8) {
        int needed_rings = 8 - available_rings;
        int reduce_gap = min(geo.gap_rings, needed_rings);
        geo.gap_rings -= reduce_gap;
        available_rings = geo.total_rings - (geo.primer_rings + mouth_rings + geo.gap_rings);
        
        if (available_rings < 8) {
            mouth_rings = max(1, mouth_rings - (8 - available_rings));
            available_rings = geo.total_rings - (geo.primer_rings + mouth_rings + geo.gap_rings);
        }
    }
    available_rings = max(8, available_rings);
    
    // Calculate component lengths
    float case_length = to_meters(case_length_mm);
    float overall_length = to_meters(overall_length_mm);
    float bullet_length = max(EPS, overall_length - case_length);
    float total_length = max(EPS, case_length + bullet_length);
    float case_ratio = safe_div(case_length, total_length);
    
    // Allocate rings to case and bullet
    geo.case_rings = int(max(4.0, floor(float(available_rings) * case_ratio + 0.5)));
    geo.bullet_rings = available_rings - geo.case_rings;
    geo.bullet_rings = max(4, geo.bullet_rings);
    
    // Set main boundaries
    geo.primer_start = 1;
    geo.primer_end = geo.primer_start + geo.primer_rings;
    geo.case_start = geo.primer_end + 1;
    geo.case_end = geo.case_start + geo.case_rings;
    geo.mouth_start = geo.case_end;
    geo.mouth_end = geo.mouth_start;
    geo.gap_start = geo.mouth_end;
    geo.gap_end = geo.gap_start + geo.gap_rings - 1;
    geo.bullet_start = geo.gap_end + 1;
    
    // Clamp boundaries to valid range
    if (geo.bullet_start > geo.last_index) {
        geo.gap_end = max(geo.gap_start, geo.last_index - 4);
        geo.bullet_start = geo.gap_end + 1;
    }
    
    geo.mouth_start = min(geo.mouth_start, geo.last_index);
    geo.mouth_end = min(geo.mouth_end, geo.last_index);
    geo.case_end = min(geo.case_end, max(geo.case_start, geo.mouth_start - 1));
    geo.gap_end = min(geo.gap_end, geo.last_index);
    geo.bullet_start = min(geo.bullet_start, geo.last_index);
    
    // Subdivide case into sections
    int total_case_rings = max(1, geo.case_end - geo.case_start + 1);
    int rim_rings = max(1, int(round(0.1 * float(total_case_rings))));
    int groove_rings = max(1, int(round(0.1 * float(total_case_rings))));
    int head_rings = max(1, int(round(0.1 * float(total_case_rings))));
    int shoulder_rings = max(1, int(round(0.1 * float(total_case_rings))));
    int neck_rings = max(1, total_case_rings - (rim_rings + groove_rings + head_rings + shoulder_rings));
    
    int current_idx = geo.case_start;
    geo.rim_end = min(geo.case_end, current_idx + rim_rings - 1); 
    current_idx = geo.rim_end + 1;
    geo.groove_end = min(geo.case_end, current_idx + groove_rings - 1); 
    current_idx = geo.groove_end + 1;
    geo.head_end = min(geo.case_end, current_idx + head_rings - 1); 
    current_idx = geo.head_end + 1;
    geo.shoulder_end = min(geo.case_end, current_idx + shoulder_rings - 1); 
    current_idx = geo.shoulder_end + 1;
    geo.neck_end = min(geo.case_end, current_idx + neck_rings - 1);
    
    return geo;
}

// Helper function for bullet tip calculation
float calculate_bullet_tip_radius(float base_radius, float ogive_progress, float ogive_length) {
    if (tip_profile == 0) { // Cone
        float tip_start = bullet_tip_percent;
        return (ogive_progress > tip_start) ? 
            my_lerp(base_radius, 0.0, (ogive_progress - tip_start) / (1.0 - tip_start)) : 
            base_radius;
    } 
    else if (tip_profile == 1 || tip_profile == 2) { // Tangent or Secant
        float R = (ogive_length * ogive_length + base_radius * base_radius)
                   / (2.0 * base_radius) * ogive_radius_factor;
        float x = (1.0 - ogive_progress) * ogive_length;
        float radicand = R * R - (ogive_length - x) * (ogive_length - x);
        return (radicand <= 0.0) ? 0.0 : max(0.0, sqrt(radicand) - (R - base_radius));
    } 
    else { // Elliptical
        return base_radius * sqrt(max(0.0, 1.0 - ogive_progress * ogive_progress));
    }
}

// ======================
// PER-RING DISPLAY PROFILE WITH STRUCT
// ======================
vec2 profile_display_for_ring(int idx, CartridgeGeometry geo) {
    float case_length = to_meters(case_length_mm);
    float overall_length = to_meters(overall_length_mm);
    float bullet_length = max(EPS, overall_length - case_length);
    float extraction = to_meters(bullet_extraction_mm);
    
    // Component dimensions
    float primer_radius = to_meters(primer_diameter_mm) * 0.5;
    float rim_radius = to_meters(rim_diameter_mm) * 0.5;
    float head_radius = to_meters(head_diameter_mm) * 0.5;
    float shoulder_radius = to_meters(shoulder_diameter_mm) * 0.5;
    float neck_radius = to_meters(neck_diameter_mm) * 0.5;
    float bullet_radius = to_meters(bullet_diameter_mm) * 0.5;
    float rim_thickness = to_meters(rim_thickness_mm);
    float wall_thickness = to_meters(case_wall_thickness_mm);

    // Primer region
    if (idx == geo.primer_end) return vec2(0.0, 0.0);
    if (idx == geo.primer_start) return vec2(0.0, primer_radius);
    
    // Case region
    if (idx >= geo.case_start && idx <= geo.case_end) {
        float case_progress = float(idx - geo.case_start) / float(max(1, geo.case_rings - 1));
        
        // Rim section
        if (idx <= geo.rim_end) {
            float rim_progress = float(idx - geo.case_start) / float(geo.rim_end - geo.case_start);
            float y = my_lerp(0.0, rim_thickness, rim_progress);
            float semicircle = sin(rim_progress * PI);
            float bulge = semicircle * (rim_thickness * 0.5) * ((rim_roundness - 0.5) * 2.0);
            float radius = rim_radius + bulge;
            return vec2(y, max(EPS, radius));
        }
        
        // Extractor groove section
        else if (idx <= geo.groove_end) {
            float groove_progress = float(idx - geo.rim_end) / float(geo.groove_end - geo.rim_end);
            float groove_radius = to_meters(extractor_groove_diameter_mm) * 0.5;
            float y0 = rim_thickness;
            float y1 = case_length * head_percent;
            float y = my_lerp(y0, y1, groove_progress);
            float radius = (groove_progress < 0.5)
                         ? my_lerp(rim_radius, groove_radius, groove_progress)
                         : my_lerp(groove_radius, head_radius, groove_progress);
            return vec2(y, max(EPS, radius));
        }
        
        // Head section
        else if (idx <= geo.head_end) {
            float head_progress = float(idx - geo.groove_end) / float(geo.head_end - geo.groove_end);
            float y0 = case_length * head_percent;
            float y1 = case_length * shoulder_percent;
            float y = my_lerp(y0, y1, head_progress);
            float radius = my_lerp(head_radius, shoulder_radius, head_progress);
            return vec2(y, max(EPS, radius));
        }
        
        // Shoulder section
        else if (idx <= geo.shoulder_end) {
            float shoulder_progress = float(idx - geo.head_end) / float(geo.shoulder_end - geo.head_end);
            float y0 = case_length * shoulder_percent;
            float y1 = case_length * neck_percent;
            float y = my_lerp(y0, y1, shoulder_progress);
            float radius = my_lerp(shoulder_radius, neck_radius, shoulder_progress);
            return vec2(y, max(EPS, radius));
        }
        
        // Neck section
        else {
            float neck_progress = float(idx - geo.shoulder_end) / float(geo.neck_end - geo.shoulder_end);
            float y0 = case_length * neck_percent;
            float y1 = case_length;
            float y = my_lerp(y0, y1, neck_progress);
            return vec2(y, max(EPS, neck_radius));
        }
    }
    
    // Case mouth transition
    float mouth_inner_radius = abs(neck_radius - wall_thickness);
    if (idx == geo.mouth_start) return vec2(case_length, mouth_inner_radius);
    if (idx == geo.mouth_end && extraction > EPS) return vec2(rim_thickness, bullet_radius);
    
    // Gap region (bullet extraction)
    if (idx >= geo.gap_start && idx <= geo.gap_end && extraction > EPS) {
        return vec2(rim_thickness, bullet_radius);
    }
    
    // Bullet region
    if (idx >= geo.bullet_start && idx <= geo.last_index) {
        float bullet_progress = float(idx - geo.bullet_start) / float(max(1, geo.bullet_rings - 1));
        float y = case_length + extraction + bullet_progress * bullet_length;
        
        // Calculate bullet radius based on profile
        float base_length = bullet_length * bullet_base_percent;
        float current_pos = bullet_progress * bullet_length;
        float radius = bullet_radius;
        
        if (current_pos >= base_length) {
            float ogive_length = bullet_length - base_length;
            float ogive_progress = (current_pos - base_length) / ogive_length;
            radius = calculate_bullet_tip_radius(radius, ogive_progress, ogive_length);
        }
        
        return vec2(y, radius);
    }
    
    return vec2(0.0, 0.0);
}

// Updated helper functions using the struct
vec2 sample_display_profile(float parameter_t, CartridgeGeometry geo) {
    float ring_float = clamp(parameter_t, 0.0, 1.0) * float(geo.total_rings - 1);
    int ring_a = int(floor(ring_float));
    int ring_b = min(geo.last_index, ring_a + 1);
    float blend = ring_float - float(ring_a);
    
    vec2 profile_a = profile_display_for_ring(ring_a, geo);
    vec2 profile_b = profile_display_for_ring(ring_b, geo);
    
    // Handle gap boundary transitions
    bool a_in_gap = (ring_a >= geo.gap_start && ring_a <= geo.gap_end);
    bool b_in_gap = (ring_b >= geo.gap_start && ring_b <= geo.gap_end);
    
    if (a_in_gap != b_in_gap) {
        return (blend < 0.5) ? profile_a : profile_b;
    }
    
    return mix(profile_a, profile_b, blend);
}

// wrappers
float get_display_position(float parameter_t, CartridgeGeometry geo) { return sample_display_profile(parameter_t, geo).x; }

// nearest ring index helper
int get_nearest_ring(float parameter_t, CartridgeGeometry geo) {
  float f = clamp(parameter_t, 0.0, 1.0) * float(geo.total_rings - 1);
  return int(floor(f + 0.5));
}

bool is_in_gap_region(float parameter_t, CartridgeGeometry geo) {
    if (to_meters(bullet_extraction_mm) < EPS) return false;
    
    int ring_index = get_nearest_ring(parameter_t, geo);
    
    return (ring_index >= geo.gap_start && ring_index <= geo.gap_end);
}

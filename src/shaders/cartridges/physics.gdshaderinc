group_uniforms Bullet.Physics;

uniform float muzzle_velocity_ms : hint_range(100.0, 2000.0, 1.0) = 800.0;
uniform float bullet_drop_ms2 : hint_range(0.0, 20.0, 0.1) = 9.81;
uniform float wind_velocity_ms : hint_range(-100.0, 100.0, 0.1) = 0.0;
uniform float zero_range_m : hint_range(0.0, 1000.0, 1.0) = 100.0;
uniform float ballistic_coefficient : hint_range(0.1, 1.0, 0.01) = 0.5;

// Improved physics with better precision and stability
void apply_bullet_physics(inout vec3 base_vertex, vec2 profile, float parameter_t, CartridgeGeometry geo) {
    float case_length = to_meters(case_length_mm);
    float overall_length = to_meters(overall_length_mm);
    float bullet_extraction = to_meters(bullet_extraction_mm);
    float display_position = profile.x;
    
    // Only apply to projectile regions with extraction
    bool is_projectile = (get_display_position(parameter_t, geo) > case_length);
    
    if (is_projectile && bullet_extraction > EPS) {
        float distance_from_case = display_position - case_length;
        
        if (distance_from_case > 0.0) {
            // Convert to real-world distance with better precision handling
            float real_world_distance = max(0.0, distance_from_case / scale);
            
            // Prevent extreme values that cause flickering
            real_world_distance = min(real_world_distance, 1000.0); // Max 1km
            
            // Improved time calculation with drag consideration
            float base_time = real_world_distance / muzzle_velocity_ms;
            
            // Simple drag approximation using ballistic coefficient
            float drag_factor = 1.0 - (ballistic_coefficient * 0.1);
            float adjusted_time = base_time * (1.0 + base_time * drag_factor);
            
            // Calculate physics effects
            float real_world_drop = 0.5 * bullet_drop_ms2 * adjusted_time * adjusted_time;
            float real_world_wind_drift = wind_velocity_ms * adjusted_time;
            
            // Zeroing compensation with better stability
            float real_world_drop_compensation = real_world_drop;
            if (zero_range_m > EPS) {
                float zeroing_time = zero_range_m / muzzle_velocity_ms;
                float zeroing_drop = 0.5 * bullet_drop_ms2 * zeroing_time * zeroing_time;
                real_world_drop_compensation -= zeroing_drop * min(real_world_distance / zero_range_m, 2.0);
            }
            
            // Convert back to scaled coordinates with clamping
            float scaled_drop = real_world_drop_compensation * scale;
            float scaled_wind_drift = real_world_wind_drift * scale;
            
            // Apply trajectory with smooth transitions
            base_vertex.z -= scaled_drop;
            base_vertex.x += scaled_wind_drift;
            
            // Improved bullet tilt - only apply to actual bullet, not gap
            if (distance_from_case > bullet_extraction) {
                float bullet_tip_factor = 0.0;
                float bullet_position = get_display_position(parameter_t, geo) - case_length;
                float bullet_length = overall_length - case_length;
                
                if (bullet_length > EPS) {
                    bullet_tip_factor = (bullet_position - bullet_extraction) / bullet_length;
                    bullet_tip_factor = clamp(bullet_tip_factor, 0.0, 1.0);
                    bullet_tip_factor = pow(bullet_tip_factor, 1.5);
                    
                    // Subtle tilt based on trajectory
                    float max_tip_tilt = 0.05;
                    float tilt_x = scaled_wind_drift * max_tip_tilt * 0.01 * bullet_tip_factor;
                    float tilt_z = scaled_drop * max_tip_tilt * 0.01 * bullet_tip_factor;
                    
                    base_vertex.x += tilt_x;
                    base_vertex.z += tilt_z;
                }
            }
        }
    }
}

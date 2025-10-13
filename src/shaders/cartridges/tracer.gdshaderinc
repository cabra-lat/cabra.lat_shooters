group_uniforms Bullet.Tracer;

uniform bool tracer_enable = true;
uniform vec4 tracer_color : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform float tracer_emission_energy : hint_range(0.0, 10.0, 0.1) = 1.0;
uniform float tracer_radius_percent : hint_range(0.0, 1.0, 0.1) = 0.5;
uniform float tracer_pulse_speed : hint_range(0.0, 10.0, 0.1) = 1.0;
uniform float tracer_start_mm : hint_range(0.0, 1000.0, 1.0) = 100.0;
uniform float tracer_length_mm : hint_range(0.0, 2000.0, 1.0) = 500.0;
uniform float tracer_power : hint_range(0.1, 3.0, 0.1) = 1.5;

// tracer positions and intensity — world-space based and smoothed
float get_tracer_position(float parameter_t, CartridgeGeometry geo) {
  // normalized 0..1 along gap using world positions
  float world_pos = get_display_position(parameter_t, geo);
  float case_length = to_meters(case_length_mm);
  float extraction = to_meters(bullet_extraction_mm);
  if (extraction < EPS) return 0.0;
  float gap_start_world = case_length;
  float gap_end_world = case_length + extraction;
  return clamp((world_pos - gap_start_world) / max(EPS, gap_end_world - gap_start_world), 0.0, 1.0);
}

float calculate_tracer_intensity(float parameter_t, CartridgeGeometry geo) {
  if (!tracer_enable) return 0.0;
  float extraction = to_meters(bullet_extraction_mm);
  if (extraction < EPS) return 0.0;
  if (!is_in_gap_region(parameter_t, geo)) return 0.0;

  float world_pos = get_display_position(parameter_t, geo);
  float case_length = to_meters(case_length_mm);
  float bullet_base_pos = case_length + extraction;
  float tracer_ignition_offset = to_meters(tracer_start_mm);
  float tracer_length = to_meters(tracer_length_mm);

  float tracer_ignition_point = bullet_base_pos - tracer_ignition_offset;
  float tracer_end_world = tracer_ignition_point - tracer_length;

  if (world_pos > tracer_ignition_point || world_pos < tracer_end_world) return 0.0;

  float tracer_normalized = clamp((tracer_ignition_point - world_pos) / max(EPS, tracer_length), 0.0, 1.0);
  float tracer_pos = get_tracer_position(parameter_t, geo);
  float pulse = 0.5 + 0.5 * sin(TIME * tracer_pulse_speed + tracer_pos * TAU);

  // smooth falloff
  float fall = pow(1.0 - tracer_normalized, tracer_power);
  return clamp((0.7 + 0.3 * pulse) * fall, 0.0, 1.0);
}

// ======================
// Heat helper (unchanged semantics, smoothed)
vec3 get_heat_with_distance(int surface_type, float parameter_t, CartridgeGeometry geo) {
  float overall_heat = clamp(bullet_extraction_mm / (bullet_heat_proportion * case_length_mm), 0.0, 1.0);

  float bullet_pos = 0.0;
  if (surface_type == SURFACE_BULLET_BASE) bullet_pos = 0.0;
  else if (surface_type == SURFACE_BULLET_BODY) {
    int nearest = get_nearest_ring(parameter_t, geo);
    int bullet_count = max(1, geo.last_index - geo.bullet_start + 1);
    float t = safe_div(float(nearest - geo.bullet_start), float(max(1, bullet_count - 1)));
    float body_start = bullet_base_color_percent;
    float body_end = bullet_tip_color_percent;
    if (t < body_start) bullet_pos = 0.0;
    else if (t > body_end) bullet_pos = 1.0;
    else bullet_pos = (t - body_start) / max(EPS, (body_end - body_start));
  } else if (surface_type == SURFACE_BULLET_TIP) bullet_pos = 1.0;

  float heat_threshold = 1.0 - overall_heat;
  if (bullet_pos <= heat_threshold) return vec3(0.0);
  float heat_depth = (bullet_pos - heat_threshold) / max(EPS, 1.0 - heat_threshold);
  heat_depth = clamp(heat_depth, 0.0, 1.0);
  float tracer_pos = get_tracer_position(parameter_t, geo);
  float pulse = 0.5 + 0.5 * sin(TIME * tracer_pulse_speed + tracer_pos * TAU);
  float heat_intensity = overall_heat * heat_depth;
  return tracer_color.rgb * tracer_emission_energy * (0.7 + 0.3 * pulse) * heat_intensity;
}

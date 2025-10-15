# res://src/core/utils/utils.gd
class_name Utils

static func bullet_energy(mass_g: float, speed_m_s: float) -> float:
  return 0.5 * (mass_g / 1000.0) * (speed_m_s * speed_m_s)

static func bullet_velocity(mass_g: float, energy_j: float) -> float:
  return sqrt((2 * energy_j) / (mass_g / 1000.0))

static func parse_caliber(cal: String) -> Dictionary:
  return CaliberParser.parse(cal)

static func is_same_caliber(cal1: String, cal2: String) -> bool:
  return parse_caliber(cal1) == parse_caliber(cal2)

static func to_mm(cm: float = 0.0) -> float:
  return cm * 0.1

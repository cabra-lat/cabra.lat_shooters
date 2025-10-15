# res://src/core/ballistics/ballistics_impact.gd
class_name BallisticsImpact
extends Resource

@export var ricochet: bool = false
@export var penetration_depth: float = 0.0      # mm
@export var fragments: int = 0
@export var mass: float = 0.0                   # grams
@export var hit_energy: float = 0.0             # Joules
@export var exit_energy: float = 0.0            # Joules
@export var thickness: float = 0.0              # mm
@export var angle: float = 0.0                  # degrees

var penetrated: bool:
  get: return penetration_depth >= thickness

var fragmented: bool:
  get: return fragments > 0

var exit_velocity: float:
  get: return Utils.bullet_velocity(mass, exit_energy)

var hit_velocity: float:
  get: return Utils.bullet_velocity(mass, hit_energy)

func _to_string() -> String:
  return "BallisticsImpact(" \
     + ", ".join([
      "angle: %.2f°" % angle,
      "thickness: %.2fmm" % thickness,
      "hit_energy: %.2fJ" % hit_energy,
      "exit_energy: %.2fJ" % exit_energy,
      "hit_velocity: %.2fm/s" % hit_velocity,
       "exit_velocity: %.2fm/s" % exit_velocity,
      "ricochet: %s" % ricochet,
       "fragmented: (%d frags)" % fragments if fragmented else "",
      "penetrated: (%.2fmm)" % penetration_depth if penetrated else ""
    ].filter(func(s): return s != "")) + ")"

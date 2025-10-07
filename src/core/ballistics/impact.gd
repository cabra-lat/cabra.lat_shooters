@tool
class_name BallisticsImpact extends Resource

var ricochet: bool = false
var penetration_depth: float = 0.0
var fragments: int = 0
var mass: float = 0.0
var hit_energy: float = 0.0
var exit_energy: float = 0.0
var thickness: float = 0.0
var angle: float = 0.0

var penetrated: bool:
	get: return penetration_depth >= thickness

var fragmented: bool:
	get: return fragments > 0

var exit_velocity:
	get: return Utils.bullet_velocity(mass, exit_energy)

var hit_velocity:
	get: return Utils.bullet_velocity(mass, hit_energy)

func _to_string() -> String:
	return "BallisticsImpact(" \
		 + ", ".join([
			"angle: %.2f °" % angle,
			"thickness: %.2f mm" % thickness,
			"hit_energy: %.2f J" % hit_energy,
			"exit_energy: %.2f J" % exit_energy,
			"hit_velocity: %.2f J" % hit_velocity,
		 	"exit_velocity: %.2f m/s" % exit_velocity,
			"ricochet: %s" % ricochet if ricochet else "",
		 	"fragmented: (%d fgmts)" % fragments if fragmented else "",
		 ("penetrated: (%.2f mm)" % penetration_depth if penetrated else "")
		].filter(func(s): return s != "")) + ")"

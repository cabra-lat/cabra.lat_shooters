# res://addons/cabra.lat_shooters/src/core/health/medical_item.gd
class_name MedicalItem
extends Item
## Consumable medical / provision item. Data mirror of the genre reference wiki (CC-BY-SA)
## infoboxes (use time / effects / weight).
##
## Applied by the player after `use_time` seconds; the effect lands through
## Health (wounds, pain, fractures, destroyed limbs) and PlayerSurvival
## (energy / hydration).

enum Kind {
	MEDKIT,       # heals HP, may stop bleeds
	BANDAGE,      # light bleeding
	TOURNIQUET,   # heavy bleeding (leaves a fresh wound)
	SPLINT,       # fracture
	PAINKILLER,   # pain relief over time
	SURGERY,      # restores a destroyed (blacked) part
	FOOD,         # energy
	DRINK,        # hydration
}

@export var kind: Kind = Kind.MEDKIT

@export_group("Use")
@export var use_time: float = 3.0 # s
@export var max_uses: int = 1
var uses_left: int = 1

@export_group("Effects")
@export var heals_hp: float = 0.0 # per use (Salewa 85, IFAK 50, AI-2 50, Grizzly 175)
@export var stops_light_bleeding: bool = false
@export var stops_heavy_bleeding: bool = false
@export var fixes_fracture: bool = false
@export var surgery: bool = false # restores one destroyed part
@export var surgery_hp_penalty_ratio: float = 0.35 # restored part comes back at 65% max
@export var pain_relief_seconds: float = 0.0
@export var energy: float = 0.0 # + for food, - allowed
@export var hydration: float = 0.0
@export var applies_fresh_wound: bool = false # tourniquets leave one

func _init() -> void:
	uses_left = max_uses

func can_use() -> bool:
	return uses_left > 0

## Does this item touch the body (HP / bleeds / fracture / surgery / pain)?
func needs_health() -> bool:
	return heals_hp > 0.0 or stops_light_bleeding or stops_heavy_bleeding \
		or fixes_fracture or surgery or pain_relief_seconds > 0.0 or applies_fresh_wound

## Apply to the player systems. `part` targets surgery / splint when given
## (BodyPart.Type.NONE = pick the worst applicable part automatically).
func apply(health: Health, survival: PlayerSurvival, part: int = BodyPart.Type.NONE) -> Dictionary:
	var result := {
		"healed": 0.0,
		"stopped_light": false,
		"stopped_heavy": false,
		"fixed_fracture": false,
		"surgery": false,
		"pain_seconds": 0.0,
		"energy": 0.0,
		"hydration": 0.0,
		"error": "",
	}
	if not can_use():
		result["error"] = "no uses left"
		return result
	# Food/drink need no body; only treatments do.
	if needs_health() and health == null:
		result["error"] = "no health"
		return result

	if health != null and stops_light_bleeding and health.stop_light_bleeding():
		result["stopped_light"] = true
	if health != null and stops_heavy_bleeding and health.stop_heavy_bleeding():
		result["stopped_heavy"] = true
	if health != null and fixes_fracture and health.splint_fracture(part):
		result["fixed_fracture"] = true
	if health != null and surgery:
		if health.apply_surgery(part, surgery_hp_penalty_ratio):
			result["surgery"] = true
		else:
			# Nothing to restore: refuse the use so a kit is not wasted.
			if not result["stopped_light"] and not result["stopped_heavy"] \
					and not result["fixed_fracture"]:
				result["error"] = "nothing to operate"
				return result
	if health != null and heals_hp > 0.0:
		result["healed"] = health.heal_hp(heals_hp)
	if health != null and pain_relief_seconds > 0.0:
		health.relieve_pain(pain_relief_seconds)
		result["pain_seconds"] = pain_relief_seconds
	if health != null and applies_fresh_wound:
		health.add_fresh_wound()
	if energy != 0.0 and survival != null:
		survival.add_energy(energy)
		result["energy"] = energy
	if hydration != 0.0 and survival != null:
		survival.add_hydration(hydration)
		result["hydration"] = hydration

	if _applied_anything(result):
		uses_left -= 1
	return result

func _applied_anything(result: Dictionary) -> bool:
	if result["healed"] > 0.0 or result["stopped_light"] or result["stopped_heavy"]:
		return true
	if result["fixed_fracture"] or result["surgery"] or result["pain_seconds"] > 0.0:
		return true
	if result["energy"] != 0.0 or result["hydration"] != 0.0:
		return true
	return false

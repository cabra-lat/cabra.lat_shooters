@tool
class_name AmmoFeed
extends Reservoir

signal incompatible_ammo(feed: AmmoFeed, ammo: Ammo)
signal inserted_ammo(feed: AmmoFeed, ammo: Ammo)
signal ejected_ammo(feed: AmmoFeed, ammo: Ammo)


## Feed/magazine types for weapons.
## 
## Used to determine how ammunition is loaded and fed into a weapon.
enum Type {
	INTERNAL,  ## Internal magazine (e.g., bolt-action rifles)
	EXTERNAL,  ## Detachable box magazine (e.g., AK-47, M4)
}

@export var viewmodel: PackedScene
@export var type: Type = Type.INTERNAL
@export var empty_mass: float = 0.0 ## mass when empty
@export var compatible_calibers: PackedStringArray = []
@export var bore_tolerance: float = 0.1  ## Bore difference tolerance in mm (Default: ±0.1mm)
@export var case_tolerance: float = 1.0  ## Case difference tolerance in mm (Default: ±1.0mm)
@export var strict_mode: bool = false ## Must be exact match with compatible calibers

var mass: float:
	get = get_mass

func get_mass():
	var total_mass = empty_mass
	for ammo in contents:
		total_mass += ammo.cartridge_mass
	return total_mass

func insert(ammo: Ammo) -> bool:
	if not is_compatible(ammo):
		incompatible_ammo.emit(self, ammo)
		return false
	inserted_ammo.emit(self, ammo)
	super.insert(ammo)
	return true

func eject() -> Ammo:
	var ammo = super.pop()
	ejected_ammo.emit(self, ammo)
	return ammo as Ammo

func is_compatible(ammo: Ammo) -> bool:
	# No restrictions → accept anything
	if compatible_calibers.is_empty():
		return true

	# Exact match always works
	if ammo.caliber in compatible_calibers:
		return true

	if strict_mode: return false
	
	# allow physical compatibility
	for allowed in compatible_calibers:
		if _is_physically_compatible(ammo.caliber, allowed):
			return true

	# INTERNAL feeds require exact match
	return false

# ─── PHYSICAL COMPATIBILITY ────────────────────────

func _is_physically_compatible(cal1: String, cal2: String) -> bool:
	var data1 = Utils.parse_caliber(cal1)
	var data2 = Utils.parse_caliber(cal2)

	# Rimmed vs rimless are NEVER compatible
	if data1.get("rimmed", false) != data2.get("rimmed", false):
		return false

	# Bore diameter must match within tolerance
	if abs(data1.get("bore_mm", 0) - data2.get("bore_mm", 0)) > bore_tolerance:
		return false

	# Case length must be similar (magazine constraint)
	var case_diff = abs(data1.get("case_mm", 0) - data2.get("case_mm", 0))
	if case_diff > case_tolerance:
		return false

	return true

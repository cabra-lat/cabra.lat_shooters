# res://src/core/ammo/ammo_feed.gd
class_name AmmoFeed
extends Reservoir

signal incompatible_ammo(feed: AmmoFeed, ammo: Ammo)
signal inserted_ammo(feed: AmmoFeed, ammo: Ammo)
signal ejected_ammo(feed: AmmoFeed, ammo: Ammo)

enum Type {
  INTERNAL,
  EXTERNAL,
}

@export_multiline var description: String = "This Ammofeed is the default one."
@export var type: Type = Type.INTERNAL
@export_custom(PROPERTY_HINT_NONE, "suffix:g") var empty_mass: float = 0.0
@export var compatible_calibers: PackedStringArray = []
@export_custom(PROPERTY_HINT_NONE, "suffix:mm") var bore_tolerance: float = 0.1
@export_custom(PROPERTY_HINT_NONE, "suffix:mm") var case_tolerance: float = 1.0
@export var strict_mode: bool = false

func get_mass() -> float:
  var total = empty_mass / 1000.0
  for ammo in contents:
    total += ammo.cartridge_mass / 1000.0
  return total

func insert(ammo: Resource) -> bool:
  if not is_compatible(ammo):
    incompatible_ammo.emit(self, ammo)
    return false
  inserted_ammo.emit(self, ammo)
  super.insert(ammo)
  return true

func eject() -> Ammo:
  var ammo = super.pop() as Ammo
  if ammo:
    ejected_ammo.emit(self, ammo)
  return ammo

func is_compatible(ammo: Ammo) -> bool:
  if compatible_calibers.is_empty():
    return true
  if ammo.caliber in compatible_calibers:
    return true
  if strict_mode:
    return false
  for allowed in compatible_calibers:
    if _is_physically_compatible(ammo.caliber, allowed):
      return true
  return false

func _is_physically_compatible(cal1: String, cal2: String) -> bool:
  var d1 = Utils.parse_caliber(cal1)
  var d2 = Utils.parse_caliber(cal2)
  if d1.get("rimmed", false) != d2.get("rimmed", false):
    return false
  if abs(d1.get("bore_mm", 0) - d2.get("bore_mm", 0)) > bore_tolerance:
    return false
  if abs(d1.get("case_mm", 0) - d2.get("case_mm", 0)) > case_tolerance:
    return false
  return true

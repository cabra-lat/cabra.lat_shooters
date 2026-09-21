# res://addons/cabra.lat_shooters/src/core/armor/plate.gd
class_name BallisticPlate
extends Resource

## A hard insert worn over a soft base armour (genre-typical "ballistic plate").
## It overrides protection class on the face it covers while intact.

@export var name: String = "Ballistic Plate"
@export var standard: Certification.Standard = Certification.Standard.GOST
@export_range(1, 14) var level: int = 4
@export var material: BallisticMaterial
@export_custom(PROPERTY_HINT_NONE, "suffix:0-1") var coverage: int = 1
@export var max_durability: int = 40:
  set(v):
    max_durability = maxi(v, 1)
    if current_durability <= 0 or current_durability > max_durability:
      current_durability = max_durability
var current_durability: int = 40

func is_intact() -> bool:
  return current_durability > 0

func take_wear(amount: float) -> float:
  var applied := maxf(amount, 1.0)
  current_durability = maxi(0, current_durability - int(round(applied)))
  return applied

# res://addons/cabra.lat_shooters/src/core/armor/repair_kit.gd
class_name RepairKit
extends Item

## Out-of-raid armour repair kit. Repair never restores full protection: it
## restores current durability toward the (now reduced) max, and the max itself
## shrinks per the material's repair loss curve.

@export_custom(PROPERTY_HINT_NONE, "suffix:0-1") var restore_ratio: float = 1.0
@export_custom(PROPERTY_HINT_NONE, "suffix:0-1") var loss_multiplier: float = 1.0

# src/ui/inventory/equipment_slot.gd
class_name EquipmentSlotUI
extends InventorySlotUI

@export var slot_type: String = ""
@export var allowed_categories: Array[String] = []

func _ready():
    super._ready()
    grid_position = Vector2i(-1, -1)
    is_equipment_slot = true

func _validate_drop(item: InventoryItem) -> bool:
    return _is_item_compatible(item)

func _is_item_compatible(item: InventoryItem) -> bool:
    match slot_type:
        "back":
            return item.extra is Backpack
        "primary", "secondary":
            return item.extra is Weapon
        "helmet":
            return item.extra is Armor and (item.extra as Armor).slot == "head"
        "vest":
            return item.extra is Armor and (item.extra as Armor).slot == "torso"
        _:
            return false

# Override drag data creation for equipment slots
func _create_drag_data() -> Dictionary:
    if associated_item and source_container:
        print("Starting drag from equipment slot: %s" % associated_item.name if associated_item else "Unknown")

        _hide_icon_during_drag()

        var preview = _create_drag_preview(associated_item)
        set_drag_preview(preview)

        return {
            "item": associated_item,
            "source": source_container
        }

    return {}

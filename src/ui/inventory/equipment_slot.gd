class_name EquipmentSlotUI
extends InventorySlotUI

@onready var slot_name: String = self.name
@export var display_name: String = self.name.capitalize()
@export var allowed_item_types: Array[String] = []
@export var allowed_categories: Array[String] = []

func _ready():
    super._ready()
    grid_position = Vector2i(-1, -1)
    is_equipment_slot = true

    # Add tooltip
    tooltip_text = display_name

func _validate_drop(item: InventoryItem) -> bool:
    return _is_item_compatible(item)

func _is_item_compatible(item: InventoryItem) -> bool:
    if not item or not item.content:
        return false

    # Check allowed types
    if allowed_item_types.size() > 0:
        var item_type = _get_item_type(item.content)
        if not allowed_item_types.has(item_type):
            return false

    # Check allowed categories
    if allowed_categories.size() > 0:
        var item_categories = _get_item_categories(item.content)
        for category in allowed_categories:
            if item_categories.has(category):
                return true
        return false

    return true

func _get_item_type(content: Resource) -> String:
    if content is Weapon:
        return "weapon"
    elif content is Armor:
        return "armor"
    elif content is Backpack:
        return "backpack"
    #elif content is Medical:
    #    return "medical"
    elif content is Ammo:
        return "ammo"
    return "misc"

func _get_item_categories(content: Resource) -> Array[String]:
    var categories: Array[String] = []

    if content is Weapon:
        categories.append("weapon")
        var weapon = content as Weapon
        if weapon.weapon_type:
            categories.append(weapon.weapon_type)
    elif content is Armor:
        categories.append("armor")
        var armor = content as Armor
        if armor.armor_slot:
            categories.append(armor.armor_slot)
    elif content is Backpack:
        categories.append("backpack")
        categories.append("storage")

    return categories

# Override drag data creation for equipment slots
func _create_drag_data() -> Dictionary:
    if associated_item and source_container:
        _hide_icon_during_drag()

        var preview = _create_drag_preview(associated_item)
        set_drag_preview(preview)

        return {
            "item": associated_item,
            "source": source_container
        }
    return {}

class_name ContainerConfig
extends Resource

@export_group("Container Settings")
@export var default_width: int = 5
@export var default_height: int = 5
@export var max_weight: float = 100.0
@export var allowed_item_types: Array[String] = []  # Empty = all types allowed
@export var category_restrictions: Array[String] = []  # Empty = no restrictions

@export_group("UI Settings")
@export var show_grid_labels: bool = true
@export var show_weight_info: bool = true
@export var auto_arrange_items: bool = false

func can_accept_item(item: InventoryItem) -> bool:
    if allowed_item_types.is_empty():
        return true

    var item_type = _get_item_type(item.content)
    return allowed_item_types.has(item_type)

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

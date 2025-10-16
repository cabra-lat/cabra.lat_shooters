# src/systems/inventory_system.gd
class_name InventorySystem
extends Resource

# Move item from source to target (no cloning)
static func transfer_item(source: Resource, target: Resource, item: InventoryItem) -> bool:
    if not target or not item:
        return false

    # Remove from source
    if source is InventoryContainer:
        if not source.items.has(item) or not source.remove_item(item):
            return false
    elif source is PlayerBody:
        var removed = false
        for slot in source.slots.values():
            if item in slot.items:
                removed = slot.remove_item(item)
                break
        if not removed:
            return false

    # Add to target
    if target is InventoryContainer:
        return target.add_item(item)
    elif target is PlayerBody:
        var slot_name = _infer_slot(item)
        if slot_name != "" and source != target:  # prevent self-equip
            return target.equip(item, slot_name)
    return false

static func _infer_slot(item: InventoryItem) -> String:
    if item.content is Weapon: return "primary"
    if item.content is Armor: return (item.content as Armor).slot
    if item.content is Backpack: return "back"
    return ""


static func create_inventory_item(content: Resource, stack_count: int = 1) -> InventoryItem:
    var item = InventoryItem.new()
    item.content = content
    item.max_stack = 30 if content is Ammo else 1
    item.stack_count = stack_count
    if content is Weapon:
        item.dimensions = Vector2i(3, 2)
    elif content is Armor:
        item.dimensions = Vector2i(2, 2)
    else:
        item.dimensions = Vector2i(1, 1)
    return item

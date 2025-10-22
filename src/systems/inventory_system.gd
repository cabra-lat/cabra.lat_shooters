# src/systems/inventory_system.gd
class_name InventorySystem
extends Resource

static func transfer_item(source: Resource, target: Resource, item: InventoryItem) -> bool:
    print("=== TRANSFER ITEM START ===")
    print("Transfer: %s -> %s" % [source, target])
    print("Item: %s (dimensions: %s)" % [item.name if item else "Unknown", item.dimensions])
    var result = transfer_item_to_position(source, target, item, Vector2i(-1, -1))
    print("Transfer result: %s" % result)
    print("=== TRANSFER ITEM END ===")
    return result

static func transfer_item_to_position(
    source: Resource,
    target: Resource,
    item: InventoryItem,
    position: Vector2i = Vector2i(-1, -1)
) -> bool:
    print("=== TRANSFER TO POSITION START ===")
    print("Source: %s" % source)
    print("Target: %s" % target)
    print("Item: %s" % item.name if item else "Unknown")
    print("Position: %s" % position)

    if not target or not item:
        print("ERROR: Invalid target or item")
        return false

    if not _is_compatible_with_target(item, target):
        print("ERROR: Item not compatible with target")
        return false

    # Store original position for rollback
    var original_position = item.position
    var original_container = null

    # Remove from source first
    var removed = false
    if source is InventoryContainer:
        original_container = source
        if item in source.items:
            print("Removing from container: %s" % source)
            removed = source.remove_item(item)
        else:
            print("ERROR: Item not found in source container")
    elif source is Equipment:
        original_container = source
        print("Removing from equipment")
        # Find which slot the item is in and remove it
        for slot_name in source.slots:
            var slot = source.slots[slot_name]
            if item in slot.items:
                removed = slot.remove_item(item)
                print("Removed from slot %s: %s" % [slot_name, removed])
                break
    else:
        removed = true

    if not removed:
        print("ERROR: Failed to remove from source")
        return false

    # Add to target
    var added = false
    if target is InventoryContainer:
        var target_pos = position
        if position != Vector2i(-1, -1):
            # Try exact position first
            print("Trying exact position: %s" % position)
            if target.grid.can_add_item(item, position):
                print("Exact position available")
                added = target.grid.add_item(item, position)
            else:
                print("Exact position not available, finding best position")
                # If exact position fails, find the best position
                target_pos = _find_best_position_for_item(item, position, target)
                if target_pos != Vector2i(-1, -1):
                    print("Found best position: %s" % target_pos)
                    added = target.grid.add_item(item, target_pos)
        else:
            # Find any free space
            print("Finding any free space")
            target_pos = target.grid.find_free_space_for_item(item)
            if target_pos != Vector2i(-1, -1):
                print("Found free space: %s" % target_pos)
                added = target.grid.add_item(item, target_pos)
    elif target is Equipment:
        var slot_name = _infer_slot(item)
        if slot_name != "":
            print("Equipping to slot: %s" % slot_name)
            added = target.equip(item, slot_name)
            print("Equip result: %s" % added)
        else:
            print("ERROR: Could not infer slot for item")

    if not added:
        print("ERROR: Failed to add to target, rolling back")
        # Rollback: put item back in original position
        if original_container is InventoryContainer:
            # Try to add back to original position
            if original_container.grid.can_add_item(item, original_position):
                original_container.grid.add_item(item, original_position)
            else:
                # If original position is taken, find any free space
                var free_pos = original_container.grid.find_free_space_for_item(item)
                if free_pos != Vector2i(-1, -1):
                    original_container.grid.add_item(item, free_pos)
        elif original_container is Equipment:
            # Try to re-equip in any compatible slot
            for slot_name in original_container.slots:
                var slot = original_container.slots[slot_name]
                if slot.can_add_item(item):
                    slot.add_item(item)
                    print("Rollback: re-equipped to slot %s" % slot_name)
                    break
        return false

    print("Transfer successful!")
    print("=== TRANSFER TO POSITION END ===")
    return true

static func _find_best_position_for_item(item: InventoryItem, preferred_position: Vector2i, target: InventoryContainer) -> Vector2i:
    print("Finding best position for %s around %s" % [item.dimensions, preferred_position])
    # Try positions around the preferred position
    var search_radius = 3
    var width = target.grid.width
    var height = target.grid.height

    # First, try the exact preferred position
    if target.grid.can_add_item(item, preferred_position):
        print("Exact position works: %s" % preferred_position)
        return preferred_position

    # Search in expanding squares around the preferred position
    for radius in range(1, search_radius + 1):
        for y_offset in range(-radius, radius + 1):
            for x_offset in range(-radius, radius + 1):
                # Skip the center if we already checked it
                if radius == 1 and x_offset == 0 and y_offset == 0:
                    continue

                var test_pos = Vector2i(
                    clamp(preferred_position.x + x_offset, 0, width - item.dimensions.x),
                    clamp(preferred_position.y + y_offset, 0, height - item.dimensions.y)
                )

                if target.grid.can_add_item(item, test_pos):
                    print("Found position at radius %d: %s" % [radius, test_pos])
                    return test_pos

    print("No suitable position found")
    return Vector2i(-1, -1)

static func _is_compatible_with_target(item: InventoryItem, target: Resource) -> bool:
    var compatible = false
    if target is Equipment:
        compatible = _is_equipment_compatible(item, target)
    else:
        compatible = target is InventoryContainer or target.is_type(Backpack)

    print("Compatibility check: %s -> %s = %s" % [item.name if item else "Unknown", target, compatible])
    return compatible

static func _is_equipment_compatible(item: InventoryItem, target: Equipment) -> bool:
    var slot_name = _infer_slot(item)
    if slot_name == "":
        print("No slot inferred for item")
        return false

    # Check if the equipment slot can accept this item
    if target.slots.has(slot_name):
        var slot = target.slots[slot_name]
        var can_add = slot.can_add_item(item)
        print("Equipment compatibility: %s -> %s = %s (slot type: %s)" % [item.name if item else "Unknown", slot_name, can_add, slot.slot_type])
        return can_add

    print("Slot %s not found in equipment" % slot_name)
    return false

static func _infer_slot(item: InventoryItem) -> String:
    var slot_name = ""
    if item.extra is Weapon:
        slot_name = "primary"
    elif item.extra is Armor:
        slot_name = (item.extra as Armor).slot
    elif item.extra is Backpack:
        slot_name = "back"

    print("Inferred slot for %s: %s" % [item.name if item else "Unknown", slot_name])
    return slot_name

# Keep this function as requested
static func create_inventory_item(content: Item, stack_count: int = 1) -> InventoryItem:
    var item := InventoryItem.new()
    print(content, content.name)
    item = InventoryItem.slurp(content as Item)
    item.max_stack = 30 if (content as Item) is Ammo else 1
    item.stack_count = stack_count
    if content is Weapon:
        item.dimensions = Vector2i(3, 2)
    elif content is Armor:
        item.dimensions = Vector2i(2, 2)
    else:
        item.dimensions = Vector2i(1, 1)
    return item

class_name Inventory
extends Resource

# Configuration
static var transfer_config: TransferConfig

# Debug settings
static var debug_transfers: bool = true

static func _static_init():
    transfer_config = TransferConfig.new() #load("res://src/core/inventory/config/transfer_config.tres")

static func transfer_item(source: Resource, target: Resource, item: InventoryItem, slot_name: String = "") -> bool:
    if debug_transfers:
        print("=== TRANSFER ITEM START ===")
        print("Transfer: %s -> %s" % [_get_resource_name(source), _get_resource_name(target)])
        print("Item: %s (dimensions: %s)" % [item.content.name if item.content else "Unknown", item.dimensions])
        print("Target Slot: %s" % slot_name)

    var result = false
    if slot_name != "":
        result = transfer_item_to_slot(source, target, item, slot_name)
    else:
        result = transfer_item_to_position(source, target, item, Vector2i(-1, -1))

    if debug_transfers:
        print("Transfer result: %s" % result)
        print("=== TRANSFER ITEM END ===")

    return result

static func transfer_item_to_position(
    source: Resource,
    target: Resource,
    item: InventoryItem,
    position: Vector2i = Vector2i(-1, -1)
) -> bool:
    if debug_transfers:
        print("=== TRANSFER TO POSITION START ===")
        print("Source: %s" % _get_resource_name(source))
        print("Target: %s" % _get_resource_name(target))
        print("Item: %s" % item.content.name if item.content else "Unknown")
        print("Position: %s" % position)

    # Validation
    if not _validate_transfer_parameters(target, item):
        return false

    if not _is_compatible_with_target(item, target):
        if debug_transfers:
            print("ERROR: Item not compatible with target")
        return false

    # Store original state for rollback
    var original_state = _store_original_state(source, item)

    # Remove from source first
    if not _remove_from_source(source, item, original_state):
        return false

    # Add to target
    var success = _add_to_target(target, item, position, original_state)

    if not success:
        _rollback_transfer(source, item, original_state)
        return false

    if debug_transfers:
        print("Transfer successful!")
        print("=== TRANSFER TO POSITION END ===")

    return true

static func transfer_item_to_slot(
    source: Resource,
    target: Resource,
    item: InventoryItem,
    slot_name: String
) -> bool:
    if debug_transfers:
        print("=== TRANSFER TO SLOT START ===")
        print("Source: %s" % _get_resource_name(source))
        print("Target: %s" % _get_resource_name(target))
        print("Item: %s" % item.content.name if item.content else "Unknown")
        print("Slot: %s" % slot_name)

    # Validation
    if not _validate_transfer_parameters(target, item):
        return false

    if not _is_compatible_with_slot(item, target, slot_name):
        if debug_transfers:
            print("ERROR: Item not compatible with slot %s" % slot_name)
        return false

    # Store original state for rollback
    var original_state = _store_original_state(source, item)

    # Remove from source first
    if not _remove_from_source(source, item, original_state):
        return false

    # Add to target slot
    var success = _add_to_slot(target, item, slot_name, original_state)

    if not success:
        _rollback_transfer(source, item, original_state)
        return false

    if debug_transfers:
        print("Transfer to slot successful!")
        print("=== TRANSFER TO SLOT END ===")

    return true

# Validation methods
static func _validate_transfer_parameters(target: Resource, item: InventoryItem) -> bool:
    if not target or not item:
        if debug_transfers:
            print("ERROR: Invalid target or item")
        return false

    if not item.content:
        if debug_transfers:
            print("ERROR: Item has no content")
        return false

    return true

static func _store_original_state(source: Resource, item: InventoryItem) -> Dictionary:
    return {
        "source": source,
        "original_position": item.position,
        "original_container": source,
        "slot_name": _find_item_slot_name(source, item) if source is Equipment else ""
    }

static func _find_item_slot_name(equipment: Equipment, item: InventoryItem) -> String:
    if not equipment or not item:
        return ""

    for slot_name in equipment.slots:
        var slot = equipment.slots[slot_name]
        if item in slot.items:
            return slot_name
    return ""

# Source removal methods
static func _remove_from_source(source: Resource, item: InventoryItem, original_state: Dictionary) -> bool:
    if not source:
        # No source (world item pickup)
        return true

    var removed = false

    if source is InventoryContainer:
        removed = source.remove_item(item)
        if debug_transfers:
            print("Removed from container: %s" % removed)
    elif source is Equipment:
        var slot_name = original_state.get("slot_name", "")
        if slot_name != "":
            removed = source.unequip(item, slot_name)
            if debug_transfers:
                print("Removed from equipment slot %s: %s" % [slot_name, removed])
        else:
            # Fallback: try to find and remove from any slot
            removed = _remove_from_equipment_anywhere(source, item)
    else:
        removed = true

    if not removed and debug_transfers:
        print("ERROR: Failed to remove from source")

    return removed

static func _remove_from_equipment_anywhere(equipment: Equipment, item: InventoryItem) -> bool:
    for slot_name in equipment.slots:
        if equipment.unequip(item, slot_name):
            if debug_transfers:
                print("Removed from equipment slot %s" % slot_name)
            return true
    return false

# Target addition methods
static func _add_to_target(target: Resource, item: InventoryItem, position: Vector2i, original_state: Dictionary) -> bool:
    var added = false

    if target is InventoryContainer:
        added = _add_to_container(target, item, position)
    elif target is Equipment:
        added = _add_to_equipment_auto(target, item)
    else:
        if debug_transfers:
            print("ERROR: Unknown target type")

    return added

static func _add_to_slot(target: Resource, item: InventoryItem, slot_name: String, original_state: Dictionary) -> bool:
    var added = false

    if target is Equipment:
        added = target.equip(item, slot_name)
        if debug_transfers:
            print("Equipped to slot %s: %s" % [slot_name, added])
    else:
        if debug_transfers:
            print("ERROR: Cannot add to slot on non-equipment target")

    return added

static func _add_to_container(target: InventoryContainer, item: InventoryItem, position: Vector2i) -> bool:
    var target_pos = position

    if position != Vector2i(-1, -1):
        # Try exact position first
        if target.grid.can_add_item(item, position):
            if debug_transfers:
                print("Exact position available: %s" % position)
            return target.grid.add_item(item, position)
        else:
            # Find best position around preferred
            target_pos = _find_best_position_for_item(item, position, target)
    else:
        # Find any free space
        target_pos = target.grid.find_free_space_for_item(item)

    if target_pos != Vector2i(-1, -1):
        if debug_transfers:
            print("Found position: %s" % target_pos)
        return target.grid.add_item(item, target_pos)

    if debug_transfers:
        print("ERROR: No suitable position found in container")
    return false

static func _add_to_equipment_auto(target: Equipment, item: InventoryItem) -> bool:
    var slot_name = _find_compatible_slot(item, target)
    if slot_name != "":
        if debug_transfers:
            print("Auto-equipping to slot: %s" % slot_name)
        return target.equip(item, slot_name)

    if debug_transfers:
        print("ERROR: No compatible slot found in equipment")
    return false

# Position finding methods
static func _find_best_position_for_item(item: InventoryItem, preferred_position: Vector2i, target: InventoryContainer) -> Vector2i:
    if debug_transfers:
        print("Finding best position for %s around %s" % [item.dimensions, preferred_position])

    var search_radius = transfer_config.position_search_radius
    var width = target.grid.width
    var height = target.grid.height

    # First, try the exact preferred position
    if target.grid.can_add_item(item, preferred_position):
        if debug_transfers:
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
                    if debug_transfers:
                        print("Found position at radius %d: %s" % [radius, test_pos])
                    return test_pos

    if debug_transfers:
        print("No suitable position found")
    return Vector2i(-1, -1)

# Compatibility checking
static func _is_compatible_with_target(item: InventoryItem, target: Resource) -> bool:
    var compatible = false

    if target is Equipment:
        compatible = _is_equipment_compatible(item, target)
    elif target is InventoryContainer:
        compatible = _is_container_compatible(item, target)
    else:
        compatible = false

    if debug_transfers:
        print("Compatibility check: %s -> %s = %s" % [
            item.content.name if item.content else "Unknown",
            _get_resource_name(target),
            compatible
        ])

    return compatible

static func _is_compatible_with_slot(item: InventoryItem, target: Resource, slot_name: String) -> bool:
    if not target is Equipment:
        return false

    var equipment = target as Equipment
    if not equipment.slots.has(slot_name):
        return false

    var slot = equipment.slots[slot_name]
    return slot.can_add_item(item)

static func _is_equipment_compatible(item: InventoryItem, target: Equipment) -> bool:
    var slot_name = _find_compatible_slot(item, target)
    return slot_name != ""

static func _is_container_compatible(item: InventoryItem, target: InventoryContainer) -> bool:
    # Check container-specific restrictions if they exist
    if target.has_method("can_accept_item"):
        return target.can_accept_item(item)

    # Default: all containers accept all items
    return true

static func _find_compatible_slot(item: InventoryItem, equipment: Equipment) -> String:
    if not equipment.equipment_config:
        # Fallback to old inference method
        return _infer_slot_fallback(item)

    # Use equipment config to find compatible slot
    for slot_def in equipment.equipment_config.slot_definitions:
        if slot_def.is_item_compatible(item):
            # Check if slot exists and has space
            if equipment.slots.has(slot_def.slot_name):
                var slot = equipment.slots[slot_def.slot_name]
                if slot.items.size() < slot.max_items:
                    return slot_def.slot_name

    return ""

static func _infer_slot_fallback(item: InventoryItem) -> String:
    if item.content is Weapon:
        return "primary"
    elif item.content is Armor:
        var armor = item.content as Armor
        return armor.armor_slot if armor.has("armor_slot") else "torso"
    elif item.content is Backpack:
        return "back"
    return ""

# Rollback methods
static func _rollback_transfer(source: Resource, item: InventoryItem, original_state: Dictionary):
    if debug_transfers:
        print("Rolling back transfer...")

    if source is InventoryContainer:
        var original_pos = original_state.get("original_position", Vector2i.ZERO)
        if source.grid.can_add_item(item, original_pos):
            source.grid.add_item(item, original_pos)
        else:
            var free_pos = source.grid.find_free_space_for_item(item)
            if free_pos != Vector2i(-1, -1):
                source.grid.add_item(item, free_pos)
    elif source is Equipment:
        var original_slot = original_state.get("slot_name", "")
        if original_slot != "":
            source.equip(item, original_slot)
        else:
            # Try to equip in any compatible slot
            _add_to_equipment_auto(source, item)

# Utility methods
static func _get_resource_name(resource: Resource) -> String:
    if not resource:
        return "None"
    elif resource is InventoryContainer:
        return "Container(%s)" % resource.name
    elif resource is Equipment:
        return "Equipment"
    else:
        return resource.resource_path.get_file() if resource.resource_path else "Unknown"

# Item creation with configuration support
static func create_inventory_item(content: Resource, stack_count: int = 1) -> InventoryItem:
    var item = InventoryItem.new()
    item.content = content
    item.stack_count = stack_count

    # Set dimensions based on item type using config
    _set_item_dimensions(item, content)

    # Set stack size based on item type
    if content is Ammo:
        item.max_stack = transfer_config.ammo_stack_size
    else:
        item.max_stack = 1

    return item

static func _set_item_dimensions(item: InventoryItem, content: Resource):
    if transfer_config and transfer_config.item_dimensions.has(content.get_class()):
        item.dimensions = transfer_config.item_dimensions[content.get_class()]
    else:
        # Fallback dimensions
        if content is Weapon:
            item.dimensions = Vector2i(3, 2)
        elif content is Armor:
            item.dimensions = Vector2i(2, 2)
        else:
            item.dimensions = Vector2i(1, 1)

# Batch operations
static func transfer_multiple_items(source: Resource, target: Resource, items: Array[InventoryItem]) -> bool:
    var success_count = 0

    for item in items:
        if transfer_item(source, target, item):
            success_count += 1

    return success_count == items.size()

# Weight checking
static func can_transfer_by_weight(source: Resource, target: Resource, item: InventoryItem) -> bool:
    if not target is InventoryContainer:
        return true

    var container = target as InventoryContainer
    var item_weight = item.content.mass * item.stack_count
    var new_total_weight = container.total_weight + item_weight

    return new_total_weight <= container.max_weight

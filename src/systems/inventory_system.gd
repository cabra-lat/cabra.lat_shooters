# src/systems/inventory_system.gd
class_name InventorySystem
extends Resource

static func transfer_item(source: Resource, target: Resource, item: InventoryItem) -> bool:
  if item == null:
    return false
  print("=== TRANSFER ITEM START ===")
  print("Transfer: %s -> %s" % [source, target])
  print("Item: %s (dimensions: %s)" % [item.name, item.dimensions])
  var result = transfer_item_to_position(source, target, item, Vector2i(-1, -1))
  print("Transfer result: %s" % result)
  print("=== TRANSFER ITEM END ===")
  return result

## Public half-transaction used by consumers that own a separate destination
## operation (for example, Gunsmith's timed weapon mount). The core still
## owns source lookup/removal, so callers never inspect container internals.
static func take_item(source: Resource, item: InventoryItem) -> bool:
  if source == null or item == null:
    return false
  return _remove_from_source(source, item)

## Public return path for a timed consumer. It shares the same insertion and
## rollback helpers as transfer_item_to_position; preferred_position is honored
## when free, with the same fallback behavior as a normal container return.
static func return_item(source: Resource, item: InventoryItem, preferred_position: Vector2i = Vector2i(-1, -1)) -> bool:
  if source == null or item == null:
    return false
  return _insert_into_destination(source, item, preferred_position, false, true, true)

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

    # A container item must never be dropped into itself or a descendant.
  if target is InventoryContainer and not (target as InventoryContainer).accepts_item(item):
    print("ERROR: refusing to drop a container into itself/descendant")
    return false

    # Store original source and position for rollback
  var original_position = item.position
  var original_source: Resource = source

  # Remove from source first. Null is the existing quick-equip/return path:
  # there is no source to remove from, so the target insertion owns the result.
  var removed := source == null or _remove_from_source(source, item)
  if not removed:
    print("ERROR: Failed to remove from source")
    return false

  # Add to target through the same insertion helper used by return_item().
  var added := _insert_into_destination(target, item, position, true, false, true)
  if not added:
    print("ERROR: Failed to add to target, rolling back")
    if original_source != null:
      _restore_to_source(original_source, item, original_position)
    return false

  print("Transfer successful!")
  print("=== TRANSFER TO POSITION END ===")
  return true

static func _remove_from_source(source: Resource, item: InventoryItem) -> bool:
  if source is InventoryContainer:
    var container := source as InventoryContainer
    if item in container.items:
      print("Removing from container: %s" % source)
      return container.remove_item(item)
    print("ERROR: Item not found in source container")
    return false
  if source is Equipment:
    print("Removing from equipment")
    for slot_name in source.slots:
      var slot := source.slots[slot_name] as EquipmentSlot
      if slot != null and item in slot.items:
        var removed := slot.remove_item(item)
        print("Removed from slot %s: %s" % [slot_name, removed])
        return removed
    return false
  if source.has_method("remove_item"):
    return bool(source.call("remove_item", item))
  return false


## Shared insertion boundary for normal transfers, timed returns, and rollback.
## search_near=true preserves transfer_item_to_position()'s radius search;
## use_container_api/use_equipment_equip preserve the existing caller-specific
## signal and validation behavior while keeping the branch in one place.
static func _insert_into_destination(
  destination: Resource,
  item: InventoryItem,
  preferred_position: Vector2i,
  search_near: bool,
  use_container_api: bool,
  use_equipment_equip: bool
) -> bool:
  if destination is InventoryContainer:
    var container := destination as InventoryContainer
    if container.grid == null:
      return false
    var target_pos := Vector2i(-1, -1)
    if preferred_position != Vector2i(-1, -1) and search_near:
      target_pos = _find_best_position_for_item(item, preferred_position, container)
    elif preferred_position != Vector2i(-1, -1) and container.grid.is_area_free(preferred_position, item.dimensions):
      target_pos = preferred_position
    else:
      target_pos = container.grid.find_free_space_for_item(item)
    if target_pos == Vector2i(-1, -1):
      return false
    if use_container_api:
      return container.add_item(item, target_pos)
    return container.grid.add_item(item, target_pos)
  if destination is Equipment:
    var equipment := destination as Equipment
    if use_equipment_equip:
      var slot_name := _infer_slot(item)
      if slot_name == "" or not equipment.slots.has(slot_name):
        return false
      return equipment.equip(item, slot_name)
    for slot_name in equipment.slots:
      var slot := equipment.slots[slot_name] as EquipmentSlot
      if slot != null and slot.can_add_item(item):
        return slot.add_item(item)
    return false
  if destination.has_method("add_item"):
    return bool(destination.call("add_item", item))
  return false


static func _restore_to_source(source: Resource, item: InventoryItem, original_position: Vector2i) -> bool:
  # Rollback must be able to restore a just-removed item even when normal
  # container rules would reject the add, so use the direct grid/equipment
  # insertion modes here.
  return _insert_into_destination(source, item, original_position, false, false, false)


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
  elif content is Backpack:
    item.dimensions = Vector2i(2, 2)
  elif content is AmmoFeed:
    item.dimensions = Vector2i(1, 2)
  else:
    item.dimensions = Vector2i(1, 1)
  return item

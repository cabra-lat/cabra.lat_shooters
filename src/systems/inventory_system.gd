# res://src/systems/inventory_system.gd
class_name InventorySystem
extends Resource

# Transfers an item from source to target container
# Returns true if successful, false otherwise
static func transfer_item(
  source: Resource,
  target: Resource,
  item: InventoryItem
) -> bool:
  # Step 1: Validate inputs
  if not source or not target or not item:
    return false

    # Handle WorldItem as source
    if source is WorldItem:
        # WorldItem always contains the item
        pass
    elif source is InventoryContainer:
        if not source.items.has(item):
            return false
    elif source is AmmoFeed:
        return false  # Cannot transfer FROM AmmoFeed
    else:
        return false

  # Step 2: Check if source contains the item (only for InventoryContainer)
  if source is InventoryContainer:
    if not source.items.has(item):
      return false
  elif source is AmmoFeed:
    # Cannot transfer FROM AmmoFeed in this design
    return false

  # Step 3: Validate compatibility
  if not _is_compatible_with_target(item, target):
    return false

  # Step 4: Remove from source
  if source is InventoryContainer:
    if not source.remove_item(item):
      return false

  # Step 5: Add to target
  var cloned_item = item.duplicate(true)
  if target is InventoryContainer:
    if not target.add_item(cloned_item):
      # Rollback
      if source is InventoryContainer:
        source.add_item(item)
      return false
  elif target is AmmoFeed:
    # Special handling for AmmoFeed
    if not (cloned_item.content is Ammo):
      # Rollback
      if source is InventoryContainer:
        source.add_item(item)
      return false
    var ammo = cloned_item.content as Ammo
    # Insert each round individually based on stack_count
    for i in range(cloned_item.stack_count):
      if not target.insert(ammo):
        # Rollback partially inserted rounds
        for j in range(i):
          target.eject()
        # Rollback source
        if source is InventoryContainer:
          source.add_item(item)
        return false
  else:
    # Rollback
    if source is InventoryContainer:
      source.add_item(item)
    return false

  return true

# Checks if an item is compatible with a target container
static func _is_compatible_with_target(item: InventoryItem, target: Resource) -> bool:
  if target is AmmoFeed:
    if not (item.content is Ammo):
      return false
    return target.is_compatible(item.content as Ammo)
  elif target is InventoryContainer:
    return true
  elif target is PlayerBody:
    return true
  return false

# Equips an item from a container to the player's body
static func equip_item(
  source: InventoryContainer,
  player_body: PlayerBody,
  item: InventoryItem,
  slot_name: String
) -> bool:
  if not source or not player_body or not item:
    return false
  if not source.items.has(item):
    return false

  # Remove from source first
  if not source.remove_item(item):
    return false

  # Attempt to equip
  var cloned_item = item.duplicate(true)
  if not player_body.equip(cloned_item, slot_name):
    # Rollback: return item to source
    source.add_item(item)
    return false

  return true

# Unequips an item from player's body to a container
static func unequip_item(
  player_body: PlayerBody,
  target: InventoryContainer,
  item: InventoryItem,
  slot_name: String
) -> bool:
  if not player_body or not target or not item:
    return false

  # Remove from body
  if not player_body.unequip(item, slot_name):
    return false

  # Add to target
  var cloned_item = item.duplicate(true)
  if not target.add_item(cloned_item):
    # Rollback: re-equip item
    player_body.equip(item, slot_name)
    return false

  return true

# Creates an InventoryItem from a content resource
static func create_inventory_item(content: Resource, stack_count: int = 1) -> InventoryItem:
  var item = InventoryItem.new()
  item.content = content
  # Set max_stack FIRST
  if content is Ammo:
    item.max_stack = 30
  else:
    item.max_stack = 1
  # THEN set stack_count (so clamp works)
  item.stack_count = stack_count
  # Set dimensions
  if content is Weapon:
    item.dimensions = Vector2i(3, 2)
  elif content is Armor:
    item.dimensions = Vector2i(2, 2)
  elif content is Attachment:
    item.dimensions = Vector2i(1, 1)
  elif content is Ammo:
    item.dimensions = Vector2i(1, 1)
  else:
    item.dimensions = Vector2i(1, 1)
  return item

# In src/systems/inventory_system.gd
static func transfer_item_from_world(target: InventoryContainer, world_item: WorldItem) -> bool:
  if not target or not world_item or not world_item.inventory_item:
    return false
  # Transfer the item
  var success = transfer_item(world_item, target, world_item.inventory_item)
  if success:
    world_item.is_pickable = false
  return success

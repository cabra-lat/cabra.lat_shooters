# src/systems/inventory_system.gd (UPDATED)
class_name InventorySystem
extends Resource

static func transfer_item(source: Resource, target: Resource, item: InventoryItem) -> bool:
	return transfer_item_to_position(source, target, item, Vector2i(-1, -1))

static func transfer_item_to_position(
	source: Resource,
	target: Resource,
	item: InventoryItem,
	position: Vector2i = Vector2i(-1, -1)
) -> bool:
	if not target or not item:
		return false

	if not _is_compatible_with_target(item, target):
		return false

	# Remove from source
	var removed = false
	if source is InventoryContainer:
		if item in source.items:
			removed = source.remove_item(item)
	elif source is PlayerBody:
		for slot in source.slots.values():
			if item in slot.items:
				removed = slot.remove_item(item)
				break
	else:
		removed = true

	if not removed:
		return false

	# Add to target
	var added = false
	if target is InventoryContainer:
		if position != Vector2i(-1, -1):
			# Try exact position first
			if target.grid.can_add_item(item, position):
				added = target.grid.add_item(item, position)
			else:
				# If exact position fails, try to find any free space
				added = target.add_item(item)
		else:
			# Find any free space
			added = target.add_item(item)
	elif target is PlayerBody:
		var slot_name = _infer_slot(item)
		if slot_name != "":
			added = target.equip(item, slot_name)

	if not added:
		_rollback(source, item)
		return false

	return true

static func _is_compatible_with_target(item: InventoryItem, target: Resource) -> bool:
	return target is PlayerBody or target is InventoryContainer or target is Backpack

static func _infer_slot(item: InventoryItem) -> String:
	if item.content is Weapon:
		return "primary"
	elif item.content is Armor:
		return (item.content as Armor).slot
	elif item.content is Backpack:
		return "back"
	return ""

static func _rollback(source: Resource, original_item: InventoryItem):
	if source is InventoryContainer:
		source.add_item(original_item)
	elif source is PlayerBody:
		for slot in source.slots.values():
			if slot.can_add_item(original_item):
				slot.add_item(original_item)
				break

# Keep this function as requested
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

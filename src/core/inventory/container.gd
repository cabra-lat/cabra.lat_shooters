# res://src/core/inventory/container.gd
class_name InventoryContainer
extends Item 

@export var grid_width: int = 5
@export var grid_height: int = 5
@export var max_weight: float = 100.0  # kg
@export var is_open: bool = true

var grid: InventoryGrid
var items: Array[InventoryItem]:
	get: return grid.items if grid else []

var total_weight: float:
	get:
		var weight = 0.0
		for item in items:
			weight += item.content.mass * item.stack_count
		return weight

func _init():
	grid = InventoryGrid.new()
	grid.width = grid_width
	grid.height = grid_height

func can_add_item(item: InventoryItem) -> bool:
	if not is_open:
		return false
	if total_weight + (item.content.mass * item.stack_count) > max_weight:
		return false
	return true

func add_item(item: InventoryItem, position: Vector2i = Vector2i.ZERO) -> bool:
	if not can_add_item(item):
		return false
	return grid.add_item(item, position)

func remove_item(item: InventoryItem) -> bool:
	return grid.remove_item(item)

func find_item_by_content(content: Resource) -> InventoryItem:
	for item in items:
		if item.content == content:
			return item
	return null

func get_free_space() -> int:
	return grid.get_free_area()

func get_used_space() -> int:
	return grid.get_used_area()

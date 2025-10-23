# src/core/inventory/container.gd
class_name InventoryContainer
extends Item

signal item_added(item: InventoryItem, position: Vector2i)
signal item_removed(item: InventoryItem)
signal item_moved(item: InventoryItem, from_pos: Vector2i, to_pos: Vector2i)
signal container_changed

@export var grid_width: int = 999
@export var grid_height: int = 999
@export var max_weight: float = 100.0
@export var is_open: bool = true

var grid: InventoryGrid
var items: Array[InventoryItem] = []:
    get:
        if grid:
            return grid.items
        else:
            push_error("Grid is null in container!")
            return []

var total_weight: float:
    get:
        var weight = 0.0
        for item in items:
            weight += item.mass * item.stack_count
        return weight

func _init():
    print("DEBUG: Initializing container with grid: ", grid_width, "x", grid_height)
    grid = InventoryGrid.new()
    grid.width = grid_width
    grid.height = grid_height
    # Force grid initialization
    grid._reset_grid()

func can_add_item(item: InventoryItem) -> bool:
    if not is_open:
        return false
    if total_weight + (item.mass * item.stack_count) > max_weight:
        return false
    return true

func add_item(item: InventoryItem, position: Vector2i = Vector2i.ZERO) -> bool:
    if not can_add_item(item):
        return false

    var success = grid.add_item(item, position)
    if success:
        item_added.emit(item, position)
        container_changed.emit()
    return success

func remove_item(item: InventoryItem) -> bool:
    var old_pos = item.position
    var success = grid.remove_item(item)
    if success:
        item_removed.emit(item)
        container_changed.emit()
    return success

func move_item(item: InventoryItem, new_position: Vector2i) -> bool:
    var old_pos = item.position
    var success = grid.move_item(item, new_position)
    if success:
        item_moved.emit(item, old_pos, new_position)
        container_changed.emit()
    return success

func find_item_by_content(content: Resource) -> InventoryItem:
    for item in items:
        if item == content:
            return item
    return null

func get_free_space() -> int:
    if grid:
        return grid.get_free_area()
    return 0

func get_used_space() -> int:
    if grid:
        return grid.get_used_area()
    return 0

func get_item_at(position: Vector2i) -> InventoryItem:
    if grid:
        return grid.get_item_at(position)
    return null

# src/core/inventory/container.gd
class_name InventoryContainer
extends Item

signal item_added(item: InventoryItem, position: Vector2i)
signal item_removed(item: InventoryItem)
signal item_moved(item: InventoryItem, from_pos: Vector2i, to_pos: Vector2i)
signal container_changed

# Dimensions rebuild the grid when assigned. A .tres with non-default size is
# deserialized AFTER _init(), so building the grid only in _init() left every
# loaded container at the 15x15 default (QA-009).
@export var grid_width: int = 15:
    set(value):
        grid_width = value
        _rebuild_grid()
@export var grid_height: int = 15:
    set(value):
        grid_height = value
        _rebuild_grid()
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

# Wrapped items (InventoryItem.slurp does not copy `mass`) report 0 through
# `mass`; use get_mass() so the max_weight gate sees wrapped weapon/armour mass
# and agrees with get_total_mass() (QA-005).
var total_weight: float:
    get:
        var weight = 0.0
        for item in items:
            weight += item.get_mass() * item.stack_count
        return weight

## Recursive carried mass: contents + nested containers (rig inside a pack).
func get_total_mass() -> float:
    var total := 0.0
    for item in items:
        total += item.get_mass() * item.stack_count
        var nested = item.extra
        if nested is InventoryContainer:
            total += (nested as InventoryContainer).get_total_mass()
    return total

func _rebuild_grid() -> void:
    if grid == null:
        grid = InventoryGrid.new()
    grid.width = grid_width
    grid.height = grid_height
    grid._reset_grid()

func _init():
    _rebuild_grid()

func can_add_item(item: InventoryItem) -> bool:
    if not is_open:
        return false
    if total_weight + (item.get_mass() * item.stack_count) > max_weight:
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

## Rotate an item 90° (swap `dimensions`) in place, or relocate it to the first
## free spot of the rotated size. Tetris-inventory rotation.
func rotate_item(item: InventoryItem) -> bool:
    if grid == null or item == null or not (item in items):
        return false
    var old_pos = item.position
    if not grid.rotate_item(item):
        return false
    item_moved.emit(item, old_pos, item.position)
    container_changed.emit()
    return true

## Swap two items already in this container (drag A onto B's cells).
func swap_items(a: InventoryItem, b: InventoryItem) -> bool:
    if grid == null or a == null or b == null or a == b or not (a in items) or not (b in items):
        return false
    var a_pos = a.position
    var b_pos = b.position
    if not grid.swap_items(a, b):
        return false
    item_moved.emit(a, a_pos, a.position)
    item_moved.emit(b, b_pos, b.position)
    container_changed.emit()
    return true

## True when the item under `position` can be swapped with `item`.
func can_swap_at(item: InventoryItem, position: Vector2i) -> bool:
    if grid == null or item == null:
        return false
    var other := grid.get_item_at(position)
    if other == null or other == item:
        return false
    return grid.can_swap_items(item, other)

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

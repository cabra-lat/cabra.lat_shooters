# src/core/inventory/inventory_grid.gd (COMPLETELY REWRITTEN)
class_name InventoryGrid
extends Resource

@export var width: int = 5
@export var height: int = 5

var items: Array[InventoryItem] = []
var _occupancy_grid: Array[Array] = [] # -1 = free, item_index = occupied

func _init():
    _reset_grid()

func _reset_grid():
    _occupancy_grid.clear()
    for y in range(height):
        var row: Array[int] = []
        row.resize(width)
        for x in range(width):
            row[x] = -1
        _occupancy_grid.append(row)

func is_area_free(position: Vector2i, size: Vector2i) -> bool:
    # Check bounds
    if position.x < 0 or position.y < 0:
        return false
    if position.x + size.x > width or position.y + size.y > height:
        return false
    
    # Check occupancy
    for y in range(size.y):
        for x in range(size.x):
            if _occupancy_grid[position.y + y][position.x + x] != -1:
                return false
    return true

func occupy_area(position: Vector2i, size: Vector2i, item_index: int):
    for y in range(size.y):
        for x in range(size.x):
            _occupancy_grid[position.y + y][position.x + x] = item_index

func free_area(position: Vector2i, size: Vector2i):
    for y in range(size.y):
        for x in range(size.x):
            _occupancy_grid[position.y + y][position.x + x] = -1

func find_free_space_for_item(item: InventoryItem) -> Vector2i:
    for y in range(height - item.dimensions.y + 1):
        for x in range(width - item.dimensions.x + 1):
            if is_area_free(Vector2i(x, y), item.dimensions):
                return Vector2i(x, y)
    return Vector2i(-1, -1)

func can_add_item(item: InventoryItem, position: Vector2i = Vector2i(-1, -1)) -> bool:
    var target_pos = position
    if position == Vector2i(-1, -1):
        target_pos = find_free_space_for_item(item)
        return target_pos != Vector2i(-1, -1)
    else:
        return is_area_free(target_pos, item.dimensions)

func add_item(item: InventoryItem, position: Vector2i = Vector2i(-1, -1)) -> bool:
    var target_pos = position
    if position == Vector2i(-1, -1):
        target_pos = find_free_space_for_item(item)
        if target_pos == Vector2i(-1, -1):
            return false
    
    if not is_area_free(target_pos, item.dimensions):
        return false
    
    # Handle stacking
    for existing_item in items:
        if existing_item.can_stack_with(item):
            var remaining = existing_item.merge(item)
            if remaining <= 0:
                return true
            item.stack_count = remaining
    
    # Add as new item
    item.position = target_pos
    items.append(item)
    occupy_area(target_pos, item.dimensions, items.size() - 1)
    return true

func remove_item(item: InventoryItem) -> bool:
    var index = items.find(item)
    if index != -1:
        free_area(item.position, item.dimensions)
        items.remove_at(index)
        # Rebuild occupancy grid
        _reset_grid()
        for i in range(items.size()):
            occupy_area(items[i].position, items[i].dimensions, i)
        return true
    return false

func move_item(item: InventoryItem, new_position: Vector2i) -> bool:
    if not is_area_free(new_position, item.dimensions):
        return false
    
    var index = items.find(item)
    if index == -1:
        return false
    
    free_area(item.position, item.dimensions)
    item.position = new_position
    occupy_area(new_position, item.dimensions, index)
    return true

func get_item_at(position: Vector2i) -> InventoryItem:
    if position.x < 0 or position.x >= width or position.y < 0 or position.y >= height:
        return null
    
    var item_index = _occupancy_grid[position.y][position.x]
    if item_index >= 0 and item_index < items.size():
        return items[item_index]
    return null

func get_used_area() -> int:
    var count = 0
    for y in range(height):
        for x in range(width):
            if _occupancy_grid[y][x] != -1:
                count += 1
    return count

func get_free_area() -> int:
    return width * height - get_used_area()

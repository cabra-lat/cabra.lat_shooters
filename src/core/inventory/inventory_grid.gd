# src/core/inventory/inventory_grid.gd
class_name InventoryGrid
extends Resource

@export var width: int = 5
@export var height: int = 5

var items: Array[InventoryItem] = []
var _grid: Array[bool] = []

func _init():
    _resize_grid()

func _resize_grid():
    _grid.resize(width * height)
    for i in _grid.size():
        _grid[i] = false

func get_cell(x: int, y: int) -> bool:
    if x < 0 or x >= width or y < 0 or y >= height:
        return true
    return _grid[y * width + x]

func set_cell(x: int, y: int, occupied: bool):
    if x >= 0 and x < width and y >= 0 and y < height:
        _grid[y * width + x] = occupied

func is_area_free(position: Vector2i, size: Vector2i) -> bool:
    for dy in range(size.y):
        for dx in range(size.x):
            if get_cell(position.x + dx, position.y + dy):
                return false
    return true

func occupy_area(position: Vector2i, size: Vector2i):
    for dy in range(size.y):
        for dx in range(size.x):
            set_cell(position.x + dx, position.y + dy, true)

func free_area(position: Vector2i, size: Vector2i):
    for dy in range(size.y):
        for dx in range(size.x):
            set_cell(position.x + dx, position.y + dy, false)

func add_item(item: InventoryItem, position: Vector2i = Vector2i.ZERO) -> bool:
    if position == Vector2i.ZERO:
        position = _find_fit(item.dimensions)
        if position == Vector2i(-1, -1):
            return false
    elif not is_area_free(position, item.dimensions):
        return false

    for existing in items:
        if existing.position == position and existing.dimensions == item.dimensions:
            if existing.merge(item):
                return true

    item.position = position
    items.append(item)
    occupy_area(position, item.dimensions)
    return true

func remove_item(item: InventoryItem) -> bool:
    if item in items:
        free_area(item.position, item.dimensions)
        items.erase(item)
        return true
    return false

func clear():
    for item in items:
        free_area(item.position, item.dimensions)
    items.clear()

func _find_fit(size: Vector2i) -> Vector2i:
    for y in range(height):
        for x in range(width):
            if x + size.x <= width and y + size.y <= height:
                if is_area_free(Vector2i(x, y), size):
                    return Vector2i(x, y)
    return Vector2i(-1, -1)

func get_used_area() -> int:
    var count = 0
    for cell in _grid:
        if cell:
            count += 1
    return count

func get_free_area() -> int:
    return width * height - get_used_area()

# ✅ Critical: get item at grid position
func get_item_at(position: Vector2i) -> InventoryItem:
    if position.x < 0 or position.x >= width or position.y < 0 or position.y >= height:
        return null
    for item in items:
        var right = item.position.x + item.dimensions.x
        var bottom = item.position.y + item.dimensions.y
        if position.x >= item.position.x and position.x < right and \
           position.y >= item.position.y and position.y < bottom:
            return item
    return null

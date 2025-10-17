# src/core/inventory/grid.gd
class_name InventoryGrid
extends Resource

@export var width: int = 5
@export var height: int = 5

var items: Array[InventoryItem] = []
var _occupancy_grid: Array[Array] = [] # -1 = free, item_index = occupied
var _temp_ignored_item: InventoryItem = null  # NEW: Item being dragged

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

# NEW: Set item to temporarily ignore during drag
func set_temp_ignored_item(item: InventoryItem):
    _temp_ignored_item = item

# NEW: Clear temporary ignored item
func clear_temp_ignored_item():
    _temp_ignored_item = null

func is_area_free(position: Vector2i, size: Vector2i) -> bool:
    # Check bounds more carefully
    if position.x < 0 or position.y < 0:
        print("DEBUG: Position out of bounds (negative): ", position)
        return false
    if position.x + size.x > width or position.y + size.y > height:
        print("DEBUG: Position out of bounds (exceeds grid): ", position, " size: ", size, " grid: ", width, "x", height)
        return false
    
    # Check occupancy - with proper bounds checking
    for y in range(size.y):
        for x in range(size.x):
            var check_y = position.y + y
            var check_x = position.x + x
            
            # Double-check bounds
            if check_y >= _occupancy_grid.size():
                print("DEBUG: Grid row out of bounds: ", check_y, " >= ", _occupancy_grid.size())
                return false
            if check_x >= _occupancy_grid[check_y].size():
                print("DEBUG: Grid column out of bounds: ", check_x, " >= ", _occupancy_grid[check_y].size())
                return false
                
            var cell_value = _occupancy_grid[check_y][check_x]
            
            # MODIFIED: Ignore cells occupied by the temporary ignored item
            if cell_value != -1:
                # Check if this cell is occupied by the ignored item
                var item_index = cell_value
                if item_index >= 0 and item_index < items.size():
                    var occupying_item = items[item_index]
                    if occupying_item == _temp_ignored_item:
                        # This is the item we're dragging, so treat it as free
                        continue
                    else:
                        # This is a different item, so the cell is occupied
                        print("DEBUG: Cell occupied at: ", Vector2i(check_x, check_y), " by different item")
                        return false
    return true

# Rest of the functions remain the same...
func occupy_area(position: Vector2i, size: Vector2i, item_index: int):
    print("DEBUG: Occupying area at ", position, " size ", size, " for item ", item_index)
    for y in range(size.y):
        for x in range(size.x):
            var occ_y = position.y + y
            var occ_x = position.x + x
            
            # Bounds check
            if occ_y < _occupancy_grid.size() and occ_x < _occupancy_grid[occ_y].size():
                _occupancy_grid[occ_y][occ_x] = item_index
            else:
                print("ERROR: Attempted to occupy out-of-bounds cell: ", Vector2i(occ_x, occ_y))

func free_area(position: Vector2i, size: Vector2i):
    print("DEBUG: Freeing area at ", position, " size ", size)
    for y in range(size.y):
        for x in range(size.x):
            var free_y = position.y + y
            var free_x = position.x + x
            
            # Bounds check
            if free_y < _occupancy_grid.size() and free_x < _occupancy_grid[free_y].size():
                _occupancy_grid[free_y][free_x] = -1
            else:
                print("ERROR: Attempted to free out-of-bounds cell: ", Vector2i(free_x, free_y))

func can_add_item(item: InventoryItem, position: Vector2i = Vector2i(-1, -1)) -> bool:
    var target_pos = position
    if position == Vector2i(-1, -1):
        target_pos = find_free_space_for_item(item)
        return target_pos != Vector2i(-1, -1)
    else:
        return is_area_free(target_pos, item.dimensions)

func find_free_space_for_item(item: InventoryItem) -> Vector2i:
    print("DEBUG: Finding free space for item dimensions: ", item.dimensions)
    for y in range(height - item.dimensions.y + 1):
        for x in range(width - item.dimensions.x + 1):
            if is_area_free(Vector2i(x, y), item.dimensions):
                print("DEBUG: Found free space at: ", Vector2i(x, y))
                return Vector2i(x, y)
    print("DEBUG: No free space found for item")
    return Vector2i(-1, -1)

func add_item(item: InventoryItem, position: Vector2i = Vector2i(-1, -1)) -> bool:
    print("DEBUG: Adding item to grid at position: ", position)
    var target_pos = position
    if position == Vector2i(-1, -1):
        target_pos = find_free_space_for_item(item)
        if target_pos == Vector2i(-1, -1):
            print("DEBUG: No space found for item")
            return false
    
    if not is_area_free(target_pos, item.dimensions):
        print("DEBUG: Area not free at target position: ", target_pos)
        return false
    
    # Handle stacking
    for existing_item in items:
        if existing_item.can_stack_with(item):
            var remaining = existing_item.merge(item)
            if remaining <= 0:
                print("DEBUG: Item stacked with existing")
                return true
            item.stack_count = remaining
    
    # Add as new item
    item.position = target_pos
    items.append(item)
    occupy_area(target_pos, item.dimensions, items.size() - 1)
    print("DEBUG: Item added successfully at: ", target_pos)
    return true

func remove_item(item: InventoryItem) -> bool:
    print("DEBUG: Removing item from grid: ", item.content.name if item.content else "Unknown")
    var index = items.find(item)
    if index != -1:
        free_area(item.position, item.dimensions)
        items.remove_at(index)
        # Rebuild occupancy grid for remaining items
        _reset_grid()
        for i in range(items.size()):
            occupy_area(items[i].position, items[i].dimensions, i)
        print("DEBUG: Item removed successfully")
        return true
    print("DEBUG: Item not found in grid")
    return false

func move_item(item: InventoryItem, new_position: Vector2i) -> bool:
    print("DEBUG: Moving item to new position: ", new_position)
    if not is_area_free(new_position, item.dimensions):
        print("DEBUG: Cannot move item - area not free")
        return false
    
    var index = items.find(item)
    if index == -1:
        print("DEBUG: Cannot move item - not found")
        return false
    
    free_area(item.position, item.dimensions)
    item.position = new_position
    occupy_area(new_position, item.dimensions, index)
    print("DEBUG: Item moved successfully")
    return true

func get_item_at(position: Vector2i) -> InventoryItem:
    if position.x < 0 or position.x >= width or position.y < 0 or position.y >= height:
        return null
    
    # Bounds check for occupancy grid
    if position.y >= _occupancy_grid.size() or position.x >= _occupancy_grid[position.y].size():
        print("ERROR: get_item_at out of bounds: ", position, " grid size: ", _occupancy_grid.size(), "x", (_occupancy_grid[0].size() if _occupancy_grid.size() > 0 else 0))
        return null
    
    var item_index = _occupancy_grid[position.y][position.x]
    if item_index >= 0 and item_index < items.size():
        return items[item_index]
    return null

func get_used_area() -> int:
    var count = 0
    # Use the actual grid dimensions to avoid out-of-bounds
    var grid_height = _occupancy_grid.size()
    if grid_height == 0:
        return 0
    
    for y in range(grid_height):
        var row = _occupancy_grid[y]
        for x in range(row.size()):
            if row[x] != -1:
                count += 1
    print("DEBUG: Used area: ", count, "/", width * height)
    return count

func get_free_area() -> int:
    var free = width * height - get_used_area()
    print("DEBUG: Free area: ", free, "/", width * height)
    return free

# Add to inventory_grid.gd
func debug_print_grid():
    print("=== GRID STATE ===")
    for y in range(height):
        var row = ""
        for x in range(width):
            if _occupancy_grid[y][x] == -1:
                row += "[ ]"
            else:
                row += "[X]"
        print(row)
    print("=================")

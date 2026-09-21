# src/core/inventory/grid.gd
class_name InventoryGrid
extends Resource

@export var width: int = 5
@export var height: int = 5

var items: Array[InventoryItem] = []
var _occupancy_grid: Array[Array] = [] # -1 = free, item_index = occupied
var _temp_ignored_item: InventoryItem = null

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

# NEW: Check if a position is occupied by the ignored item
func _is_position_ignored(position: Vector2i) -> bool:
  if not _temp_ignored_item:
    return false

    # Check if this position falls within the ignored item's area
  var item_pos = _temp_ignored_item.position
  var item_size = _temp_ignored_item.dimensions

  return (position.x >= item_pos.x and
    position.y >= item_pos.y and
    position.x < item_pos.x + item_size.x and
    position.y < item_pos.y + item_size.y)

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

            # MODIFIED: Also ignore cells that are part of the ignored item's area
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
        else:
          print("DEBUG: Invalid item index: ", item_index)
            # NEW: Also check if this position is part of the ignored item's original area
      elif _is_position_ignored(Vector2i(check_x, check_y)):
                # This position is currently occupied by the ignored item, treat as free
        continue

  return true

# Rest of your existing functions remain the same...
func set_temp_ignored_item(item: InventoryItem):
  _temp_ignored_item = item
  print("DEBUG: Temporarily ignoring item at position: ", item.position if item else "null")

func clear_temp_ignored_item():
  _temp_ignored_item = null

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

    # Handle stacking. `merge()` is a whole-stack merge (returns bool); the
    # old code treated it as a remaining-count and compared a bool to 0, which
    # errored at runtime. Move what fits, keep the overflow as a new slot.
  for existing_item in items:
    if existing_item == item:
      continue
    if existing_item.can_stack_with(item):
      var room := existing_item.max_stack - existing_item.stack_count
      if room > 0:
        var want := item.stack_count
        var moved := mini(room, want)
        existing_item.stack_count += moved
        if moved >= want:
          # Fully absorbed. stack_count cannot hold 0 (the setter clamps to 1),
          # so signal success here instead of testing for 0.
          item.stack_count = 1
          return true
        item.stack_count = want - moved

    # Add as new item
  item.position = target_pos
  items.append(item)
  occupy_area(target_pos, item.dimensions, items.size() - 1)
  print("DEBUG: Item added successfully at: ", target_pos)
  return true

func remove_item(item: InventoryItem) -> bool:
  print("DEBUG: Removing item from grid: ", item.name if item else "Unknown")
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

# ─── TETRIS UX (rotation / swap) ────────────────────
# Free-space search for an arbitrary size, optionally ignoring one item's own
# cells (used by rotation so the rotated footprint can overlap the original).
func find_free_space_for_dims(dims: Vector2i, ignore: InventoryItem = null) -> Vector2i:
  var prev = _temp_ignored_item
  _temp_ignored_item = ignore
  var found := Vector2i(-1, -1)
  for y in range(height - dims.y + 1):
    for x in range(width - dims.x + 1):
      if is_area_free(Vector2i(x, y), dims):
        found = Vector2i(x, y)
        break
    if found != Vector2i(-1, -1):
      break
  _temp_ignored_item = prev
  return found

## Bounds + occupancy only (no temp-ignore). Used by swap.
func _raw_free(position: Vector2i, size: Vector2i) -> bool:
  if position.x < 0 or position.y < 0 or position.x + size.x > width or position.y + size.y > height:
    return false
  for y in range(size.y):
    for x in range(size.x):
      if _occupancy_grid[position.y + y][position.x + x] != -1:
        return false
  return true

## Rotate 90° in place when the swapped `dimensions` still fit, else relocate to
## the first free spot of the rotated size. Returns false and leaves the item
## untouched when neither is possible. Square items are a no-op.
func rotate_item(item: InventoryItem) -> bool:
  var index = items.find(item)
  if index == -1:
    return false
  var rotated := Vector2i(item.dimensions.y, item.dimensions.x)
  if rotated == item.dimensions:
    return false
  _temp_ignored_item = item
  var in_place := is_area_free(item.position, rotated)
  _temp_ignored_item = null
  if in_place:
    free_area(item.position, item.dimensions)
    item.dimensions = rotated
    occupy_area(item.position, rotated, index)
    return true
  var spot := find_free_space_for_dims(rotated, item)
  if spot == Vector2i(-1, -1):
    return false
  free_area(item.position, item.dimensions)
  item.dimensions = rotated
  item.position = spot
  occupy_area(spot, rotated, index)
  return true

## Swap two items inside this grid (drop item A onto item B's footprint).
## Rolls back completely if either item does not fit in the other's place.
func swap_items(a: InventoryItem, b: InventoryItem) -> bool:
  var ai = items.find(a)
  var bi = items.find(b)
  if ai == -1 or bi == -1 or a == b:
    return false
  var a_pos = a.position
  var b_pos = b.position
  var a_dims = a.dimensions
  var b_dims = b.dimensions
  free_area(a_pos, a_dims)
  free_area(b_pos, b_dims)
  if not _raw_free(b_pos, a_dims) or not _raw_free(a_pos, b_dims):
    occupy_area(a_pos, a_dims, ai)
    occupy_area(b_pos, b_dims, bi)
    return false
  occupy_area(b_pos, a_dims, ai)
  if not _raw_free(a_pos, b_dims):
    free_area(b_pos, a_dims)
    occupy_area(a_pos, a_dims, ai)
    occupy_area(b_pos, b_dims, bi)
    return false
  occupy_area(a_pos, b_dims, bi)
  a.position = b_pos
  b.position = a_pos
  return true

## Dry-run a swap: performs it and undoes it, so callers can validate a drop.
func can_swap_items(a: InventoryItem, b: InventoryItem) -> bool:
  if not swap_items(a, b):
    return false
  swap_items(a, b)
  return true

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

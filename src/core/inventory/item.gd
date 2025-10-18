# res://src/core/inventory/inventory_item.gd
class_name InventoryItem
extends Item

# What this item represents (Ammo, Weapon, Armor, etc.)
@export var content: Item

# Stacking
@export var max_stack: int = 1  # 1 = not stackable, >1 = stackable
@export var stack_count: int = 1:
  set(value):
    stack_count = clamp(value, 1, max_stack)

# Grid placement
@export var dimensions: Vector2i = Vector2i.ONE  # width x height in grid cells
@export var position: Vector2i = Vector2i.ZERO  # top-left grid position

# Computed
var occupied_cells: Array[Vector2i]:
  get:
    var cells: Array[Vector2i] = []
    for y in range(dimensions.y):
      for x in range(dimensions.x):
        cells.append(position + Vector2i(x, y))
    return cells

func can_stack_with(other: InventoryItem) -> bool:
  if not content or not other.content:
    return false
  if max_stack <= 1 or other.max_stack <= 1:
    return false
  return content.resource_path == other.content.resource_path

func merge(other: InventoryItem) -> bool:
  if not can_stack_with(other):
    return false
  var new_count = stack_count + other.stack_count
  if new_count <= max_stack:
    stack_count = new_count
    return true
  return false

func duplicate(deep: bool = false) -> InventoryItem:
  var copy = InventoryItem.new()
  copy.content = content.duplicate() if (deep and content) else content
  copy.max_stack = max_stack
  copy.stack_count = stack_count
  copy.dimensions = dimensions
  copy.position = position
  return copy

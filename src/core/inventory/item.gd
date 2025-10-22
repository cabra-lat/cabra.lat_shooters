# src/core/inventory/item.gd
class_name InventoryItem
extends Item

@export var extra: Item = null

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
  if not other:
    return false
  if max_stack <= 1 or other.max_stack <= 1:
    return false
  return resource_path == other.resource_path

func merge(other: InventoryItem) -> bool:
  if not can_stack_with(other):
    return false
  var new_count = stack_count + other.stack_count
  if new_count <= max_stack:
    stack_count = new_count
    return true
  return false

func duplicate(deep: bool = false) -> InventoryItem:
  return self.duplicate() if deep else self

static func slurp(item: Item) -> InventoryItem:
    var new = InventoryItem.new()
    new.icon = item.icon
    new.name = item.name
    new.view_model = item.view_model
    new.equip_sound = item.equip_sound
    new.extra = item
    return new

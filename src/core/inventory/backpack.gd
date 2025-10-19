class_name Backpack
extends InventoryContainer

func _init():
    name = "Backpack"
    grid_width = 6
    grid_height = 10
    max_weight = 25.0
    super._init()  # calls parent _init()

func get_quick_access_items() -> Array[InventoryItem]:
    return items.filter(func(i): return i.content is Weapon)

# Override to ensure proper initialization
func add_item(item: InventoryItem, position: Vector2i = Vector2i.ZERO) -> bool:
    if not grid:
        grid = InventoryGrid.new()
        grid.width = grid_width
        grid.height = grid_height
        grid._reset_grid()

    return super.add_item(item, position)

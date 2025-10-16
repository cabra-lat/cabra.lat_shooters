# src/ui/inventory/container_ui.gd
class_name ContainerUI
extends Container

@export var data_container: InventoryContainer = null
@onready var grid_container: GridContainer = %Panel/GridContainer

func open_container(container: InventoryContainer = null) -> void:
    data_container = container
    _setup_grid()
    _update_ui()

func _clear_grid() -> bool:
    if not self.grid_container: return false
    for slot in self.grid_container.get_children():
        (slot as InventoryUISlot).clear()
    return true

func _setup_grid():
    if not _clear_grid(): return
    grid_container.columns = data_container.grid_width
    for y in range(data_container.grid_height):
        for x in range(data_container.grid_width):
            var slot = preload("inventory_ui_slot.tscn").instantiate()
            slot.name = "Slot%d_%d" % [x, y]
            grid_container.add_child(slot)

func _update_ui():
    if not _clear_grid(): return
    for item in data_container.items:
        var idx = item.position.y * data_container.grid_width + item.position.x
        if idx < grid_container.get_child_count():
            var slot = grid_container.get_child(idx)
            if slot is InventoryUISlot:
                slot.associated_item = item
                slot.source_container = self
                slot.item_icon = item.content.icon

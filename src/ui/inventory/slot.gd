# src/ui/inventory/slot.gd
class_name InventorySlotUI
extends BaseSlotUI

@export var grid_position: Vector2i = Vector2i(-1,-1)

var container_ui: InventoryContainerUI = null
var is_equipment_slot: bool = false

func _ready():
    super._ready()
    is_equipment_slot = (grid_position == Vector2i(-1, -1))
    if is_equipment_slot:
        icon = TextureRect.new()
        icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        icon.custom_minimum_size = size

func _create_drag_data() -> Dictionary:
    var dragged_item = null
    var source = null

    if associated_item and source_container:
        # Equipment slot drag
        dragged_item = associated_item
        source = source_container
        _hide_icon_during_drag()
    elif container_ui and container_ui.current_inventory_source:
        # Container slot drag
        var container = container_ui.current_inventory_source as InventoryContainer
        var item_at_slot = container.get_item_at(grid_position)
        if item_at_slot:
            dragged_item = item_at_slot
            source = container
            # Tell container to hide the original item
            container_ui._on_drag_started(item_at_slot)

    if dragged_item:
        var preview = _create_drag_preview(dragged_item)
        set_drag_preview(preview)
        return {"item": dragged_item, "source": source}

    return {}

func _validate_drop(item: InventoryItem) -> bool:
    if is_equipment_slot:
        return true  # Equipment slots handle their own validation

    if container_ui and container_ui.current_inventory_source:
        var container = container_ui.current_inventory_source as InventoryContainer
        # Temporarily ignore the dragged item for collision detection
        container.grid.set_temp_ignored_item(item)
        var can_place = container.grid.can_add_item(item, grid_position)
        _show_drop_preview(item.dimensions, can_place)
        return can_place

    return false

func _hide_icon_during_drag():
    if icon:
        icon.visible = false

func _show_icon_after_drag():
    if icon:
        icon.visible = true

func _show_drop_preview(dimensions: Vector2i, valid: bool):
    if container_ui and container_ui.has_method("show_drop_preview"):
        var preview_color = Color(0, 1, 0, 0.3) if valid else Color(1, 0, 0, 0.3)
        container_ui.show_drop_preview(grid_position, dimensions, preview_color)

func _hide_drop_preview():
    if container_ui and container_ui.has_method("hide_drop_preview"):
        container_ui.hide_drop_preview()

func _drop_data(at_position: Vector2, data: Variant) -> void:
    if data is Dictionary and data.has("item"):
        print("Drop accepted at slot %s (equipment: %s)" % [grid_position, is_equipment_slot])

        # Hide drop preview
        _hide_drop_preview()

        # Clear temporary ignores
        if container_ui and container_ui.current_inventory_source:
            var container = container_ui.current_inventory_source as InventoryContainer
            container.grid.clear_temp_ignored_item()
        if data["source"] is InventoryContainer:
            data["source"].grid.clear_temp_ignored_item()

        slot_dropped.emit(data, self)

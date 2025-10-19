class_name InventoryContainerUI
extends BaseInventoryUI

signal container_closed()
signal container_resized(size: Vector2)

@onready var foldable_panel: FoldableContainer = $Panel
@onready var grid_background: Control = $Panel/GridBackground
@onready var items_container: Control = $Panel/ItemsContainer
@onready var close_button: Button = %CloseButton
@onready var grid_size_label: Label = %GridSizeLabel  # Optional: for displaying grid info

# Drop preview
var drop_preview: ColorRect
var current_hovered_slot: InventorySlotUI = null
var dragged_item: InventoryItem = null
var container_config: ContainerConfig

func _ready():
    super._ready()
    close_button.pressed.connect(_on_close_button_pressed)
    _create_drop_preview()
    _apply_container_theme()

func _apply_container_theme():
    if theme:
        # Apply container-specific theming
        if foldable_panel:
            foldable_panel.add_theme_stylebox_override("panel", theme.get_stylebox("container_panel", "Inventory"))

func open_container(container: InventoryContainer):
    setup_inventory(container)
    show()

func setup_inventory(container: Resource):
    if not container is InventoryContainer:
        push_error("InventoryContainerUI requires an InventoryContainer resource")
        return

    current_inventory_source = container
    foldable_panel.title = container.name
    _setup_slots()
    _update_ui()

    # Update grid size label if available
    if grid_size_label:
        grid_size_label.text = "%dx%d" % [container.grid_width, container.grid_height]

func _setup_slots():
    _clear_existing_slots()
    _setup_grid_size()
    _create_grid_slots()

func _clear_existing_slots():
    for child in grid_background.get_children():
        if child != drop_preview:
            grid_background.remove_child(child)
            child.queue_free()
    slot_displays.clear()

func _setup_grid_size():
    var container = current_inventory_source as InventoryContainer
    if not container:
        return

    var grid_size = theme.slot_size * Vector2(
        container.grid_width,
        container.grid_height
    )
    grid_background.custom_minimum_size = grid_size
    grid_background.size = grid_size
    items_container.custom_minimum_size = grid_size
    items_container.size = grid_size

    # Emit signal for container resize if needed
    container_resized.emit(grid_size)

func _create_grid_slots():
    var container = current_inventory_source as InventoryContainer
    if not container:
        return

    for y in range(container.grid_height):
        for x in range(container.grid_width):
            var slot: InventorySlotUI = preload("res://addons/cabra.lat_shooters/src/ui/inventory/slot.tscn").instantiate()
            _setup_grid_slot(slot, Vector2i(x, y))
            grid_background.add_child(slot)
            slot_displays.append(slot)

func _setup_grid_slot(slot: InventorySlotUI, position: Vector2i):
    slot.grid_position = position
    slot.name = "Slot[%d,%d]" % [position.x, position.y]
    slot.size = theme.slot_size
    slot.position = theme.slot_size * Vector2(position)

    # Set container reference for slot context
    slot.container_ui = self

    # Connect signals with theme-integrated handlers
    if not slot.drag_started.is_connected(_on_drag_started):
        slot.drag_started.connect(_on_drag_started)
    if not slot.drag_ended.is_connected(_on_drag_ended):
        slot.drag_ended.connect(_on_drag_ended)
    if not slot.slot_hovered.is_connected(_on_slot_hovered):
        slot.slot_hovered.connect(_on_slot_hovered)
    if not slot.slot_exited.is_connected(_on_slot_exited):
        slot.slot_exited.connect(_on_slot_exited)
    if not slot.slot_dropped.is_connected(_on_slot_dropped):
        slot.slot_dropped.connect(_on_slot_dropped)

func _get_display_items() -> Array[InventoryItem]:
    var container = current_inventory_source as InventoryContainer
    return container.items if container else []

func _add_item_display_to_scene(display: InventoryItemUI):
    items_container.add_child(display)
    display.z_index = 1

func _position_item_display(display: InventoryItemUI, item: InventoryItem):
    display.position = theme.slot_size * Vector2(item.position) + Vector2(theme.item_margin, theme.item_margin)

func _update_slot_states():
    # Clear all slots first
    for slot in slot_displays:
        slot.set_occupied(false)

    # Mark occupied slots from items
    for item in _get_display_items():
        _mark_item_occupancy(item)

func _mark_item_occupancy(item: InventoryItem):
    for y in range(item.dimensions.y):
        for x in range(item.dimensions.x):
            var slot_pos = Vector2i(item.position.x + x, item.position.y + y)
            var slot = get_slot_at_position(slot_pos)
            if slot:
                slot.set_occupied(true)

# Enhanced drop preview methods with theme integration
func _create_drop_preview():
    drop_preview = ColorRect.new()
    drop_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
    drop_preview.visible = false
    drop_preview.z_index = 2  # Above slots but below items
    grid_background.add_child(drop_preview)

func show_drop_preview(position: Vector2i, dimensions: Vector2i, valid: bool):
    if not drop_preview:
        return

    drop_preview.position = theme.slot_size * Vector2(position)
    drop_preview.size = theme.slot_size * Vector2(dimensions)
    drop_preview.color = theme.slot_valid_drop_color if valid else theme.slot_invalid_drop_color
    drop_preview.visible = true

func hide_drop_preview():
    if drop_preview:
        drop_preview.visible = false

# Enhanced slot interaction with theme colors
func _on_slot_hovered(slot: InventorySlotUI):
    current_hovered_slot = slot

    # Show drop preview if dragging
    if dragged_item:
        var can_drop = _can_drop_at_slot(slot, dragged_item)
        show_drop_preview(slot.grid_position, dragged_item.dimensions, can_drop)

    # Apply hover effect using theme
    var hover_style = StyleBoxFlat.new()
    hover_style.bg_color = theme.slot_hover_color
    slot.add_theme_stylebox_override("panel", hover_style)

func _on_slot_exited(slot: InventorySlotUI):
    if current_hovered_slot == slot:
        current_hovered_slot = null
        hide_drop_preview()

    # Restore normal style
    slot.remove_theme_stylebox_override("panel")

func _can_drop_at_slot(slot: InventorySlotUI, item: InventoryItem) -> bool:
    if not current_inventory_source is InventoryContainer:
        return false

    var container = current_inventory_source as InventoryContainer
    container.grid.set_temp_ignored_item(item)
    var can_place = container.grid.can_add_item(item, slot.grid_position)
    container.grid.clear_temp_ignored_item()

    return can_place

# Enhanced drag handling
func _on_drag_started(item: InventoryItem):
    dragged_item = item
    # Hide the original item being dragged
    for display in item_displays:
        if display.inventory_item == item:
            display.visible = false
            break

    # Apply drag effects to all items
    for display in item_displays:
        display.modulate = Color(1, 1, 1, 0.5)  # Semi-transparent during drag

func _on_drag_ended():
    dragged_item = null
    # Restore all items
    for display in item_displays:
        display.visible = true
        display.modulate = Color(1, 1, 1, 1)  # Full opacity

    hide_drop_preview()
    current_hovered_slot = null

func _on_close_button_pressed():
    container_closed.emit()
    hide()

# Enhanced input handling for better UX
func _input(event):
    if event is InputEventMouseMotion:
        var mouse_pos = get_global_mouse_position()
        highlight_items_under_cursor(mouse_pos)

        # Update drop preview position if dragging
        if dragged_item and current_hovered_slot:
            var can_drop = _can_drop_at_slot(current_hovered_slot, dragged_item)
            show_drop_preview(current_hovered_slot.grid_position, dragged_item.dimensions, can_drop)

# Utility methods
func get_container() -> InventoryContainer:
    return current_inventory_source as InventoryContainer

func get_grid_dimensions() -> Vector2i:
    var container = get_container()
    if container:
        return Vector2i(container.grid_width, container.grid_height)
    return Vector2i.ZERO

func is_position_valid(position: Vector2i) -> bool:
    var dimensions = get_grid_dimensions()
    return position.x >= 0 and position.y >= 0 and position.x < dimensions.x and position.y < dimensions.y

# Cleanup method
func cleanup():
    if is_instance_valid(drop_preview):
        drop_preview.queue_free()

    for slot in slot_displays:
        if is_instance_valid(slot):
            slot.queue_free()

    slot_displays.clear()
    item_displays.clear()

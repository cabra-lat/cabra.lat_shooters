# src/ui/inventory/container.gd
class_name InventoryContainerUI
extends BaseInventoryUI

signal container_closed()

@onready var foldable_panel: FoldableContainer = $Panel
@onready var grid_background: Control = $Panel/GridBackground
@onready var items_container: Control = $Panel/ItemsContainer
@onready var close_button: Button = %CloseButton

# Drop preview
var drop_preview: ColorRect
var current_hovered_slot: InventorySlotUI = null
var dragged_item: InventoryItem = null  # Track currently dragged item

func _ready():
    super._ready()
    close_button.pressed.connect(_on_close_button_pressed)
    _create_drop_preview()

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

    var grid_size = Vector2(
        container.grid_width * slot_size,
        container.grid_height * slot_size
    )
    grid_background.size = grid_size
    items_container.size = grid_size

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
    slot.size = Vector2(slot_size, slot_size)
    slot.position = Vector2(position.x * slot_size, position.y * slot_size)
    slot.setup(self)

    # Connect signals
    if not slot.drag_started.is_connected(_on_drag_started):
        slot.drag_started.connect(_on_drag_started)
    if not slot.drag_ended.is_connected(_on_drag_ended):
        slot.drag_ended.connect(_on_drag_ended)
    if not slot.mouse_entered.is_connected(_on_slot_mouse_entered.bind(slot)):
        slot.mouse_entered.connect(_on_slot_mouse_entered.bind(slot))
    if not slot.mouse_exited.is_connected(_on_slot_mouse_exited.bind(slot)):
        slot.mouse_exited.connect(_on_slot_mouse_exited.bind(slot))
    if not slot.slot_dropped.is_connected(_on_slot_dropped):
        slot.slot_dropped.connect(_on_slot_dropped)

func _get_display_items() -> Array[InventoryItem]:
    var container = current_inventory_source as InventoryContainer
    return container.items if container else []

func _add_item_display_to_scene(display: InventoryItemUI):
    items_container.add_child(display)
    display.z_index = 1

func _position_item_display(display: InventoryItemUI, item: InventoryItem):
    display.position = Vector2(item.position.x * slot_size, item.position.y * slot_size)

func _update_slot_states():
    # Clear all slots first
    for slot in slot_displays:
        slot.set_occupied(false)

    # Mark occupied slots from items
    for item in _get_display_items():
        for y in range(item.dimensions.y):
            for x in range(item.dimensions.x):
                var slot_pos = Vector2i(item.position.x + x, item.position.y + y)
                var slot = get_slot_at_position(slot_pos)
                if slot:
                    slot.set_occupied(true)

# Drop preview methods
func _create_drop_preview():
    drop_preview = ColorRect.new()
    drop_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
    drop_preview.visible = false
    drop_preview.z_index = -1
    grid_background.add_child(drop_preview)

func show_drop_preview(position: Vector2i, dimensions: Vector2i, color: Color):
    if current_hovered_slot:
        drop_preview.position = Vector2(position.x * slot_size, position.y * slot_size)
        drop_preview.size = Vector2(dimensions.x * slot_size, dimensions.y * slot_size)
        drop_preview.color = color
        drop_preview.visible = true

func hide_drop_preview():
    drop_preview.visible = false

func _on_slot_mouse_entered(slot: InventorySlotUI):
    current_hovered_slot = slot
    if slot.is_occupied:
        slot.modulate = Color(1.0, 0.5, 0.5, 0.522)
    else:
        slot.modulate = Color(0.5, 1.0, 0.5, 0.553)

func _on_slot_mouse_exited(slot: InventorySlotUI):
    if current_hovered_slot == slot:
        current_hovered_slot = null
        hide_drop_preview()
    slot.modulate = Color(1, 1, 1, 1)

# Handle drag start - hide the original item
func _on_drag_started(item: InventoryItem):
    dragged_item = item
    for display in item_displays:
        if display.inventory_item == item:
            display.visible = false
            break

# Handle drag end - restore all items
func _on_drag_ended():
    dragged_item = null
    for display in item_displays:
        display.visible = true
    hide_drop_preview()
    current_hovered_slot = null

func _on_close_button_pressed():
    container_closed.emit()
    hide()

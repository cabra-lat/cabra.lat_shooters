# src/ui/inventory/container.gd
class_name InventoryContainerUI
extends BaseInventoryUI

signal container_closed()
signal quick_equip_requested(item: InventoryItem, source: InventoryContainer)
# Double-clicking a nested rig/pack asks the main UI to open it (pack inside
# backpack inside stash).
signal container_open_requested(item: InventoryItem)

const CONTEXT_ROTATE := 401

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
    # ItemsContainer is a full-grid Control layered ABOVE the slots; with the
    # default MOUSE_FILTER_STOP it swallowed every click, so the slots (and thus
    # the right-click context menu) never received input. It only draws the
    # floating item icons (themselves IGNORE), so it must be pass-through.
    items_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
    _update_stats()

## Weight + free-space feedback lives in the foldable title: no extra layout
## node, always visible, consistent with the shared HUD style.
func _update_stats() -> void:
    var container = current_inventory_source as InventoryContainer
    if not container or foldable_panel == null:
        return
    foldable_panel.title = "%s   %.1f/%.0f kg   %d cells free" % [
        container.name, container.total_weight, container.max_weight,
        container.get_free_space()]

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
    if not slot.gui_input.is_connected(_on_slot_gui_input.bind(slot)):
        slot.gui_input.connect(_on_slot_gui_input.bind(slot))

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
        slot.associated_item = null
        slot.tooltip_text = ""

    # Mark occupied slots from items (topmost item wins the tooltip).
    # NOTE: match on the slot's GRID position — get_slot_at_position() works
    # in pixels, so feeding it grid cells collapsed every item onto slot 0.
    for item in _get_display_items():
        for y in range(item.dimensions.y):
            for x in range(item.dimensions.x):
                var slot_pos = Vector2i(item.position.x + x, item.position.y + y)
                var slot := get_slot_by_grid_position(slot_pos)
                if slot:
                    slot.set_occupied(true)
                    slot.associated_item = item
                    slot.tooltip_text = InventoryTooltip.text_for(item)


## Slot at a grid cell (see _update_slot_states).
func get_slot_by_grid_position(cell: Vector2i) -> InventorySlotUI:
    for slot in slot_displays:
        if slot.grid_position == cell:
            return slot
    return null

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
    # Don't hide the item display during drag - let the signals handle updates

# Handle drag end - restore all items
func _on_drag_ended():
    dragged_item = null
    hide_drop_preview()
    current_hovered_slot = null

# Double-click a filled slot:
#   * a nested container (rig/pack)  -> open it
#   * anything else                 -> quick-equip into a free slot
# A quick-move that is a no-op (no compatible/free equipment slot) is reported
# by the main UI; the item is never silently dropped.
func _on_slot_gui_input(event: InputEvent, slot: InventorySlotUI) -> void:
    if event is InputEventMouseButton:
        var mb := event as InputEventMouseButton
        if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and mb.double_click:
            if slot.associated_item != null and current_inventory_source is InventoryContainer:
                if slot.associated_item.extra is InventoryContainer:
                    container_open_requested.emit(slot.associated_item)
                else:
                    quick_equip_requested.emit(
                        slot.associated_item,
                        current_inventory_source as InventoryContainer)
                get_viewport().set_input_as_handled()
            return
        # Right-click is handled by the base context menu. Left single click
        # selects nothing (drag & drop is the interaction).

# R rotates the item under the cursor (tetris rotation). Only when the
# inventory UI is up, so the in-game bind cannot be stolen.
func _unhandled_input(event: InputEvent) -> void:
    if not is_visible_in_tree():
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
        if current_hovered_slot != null and current_hovered_slot.associated_item != null:
            if _rotate(current_hovered_slot.associated_item):
                get_viewport().set_input_as_handled()

func _rotate(item: InventoryItem) -> bool:
    var container = current_inventory_source as InventoryContainer
    if container == null or item == null:
        return false
    if item.dimensions.x == item.dimensions.y:
        return false  # square: rotation is a no-op
    if container.rotate_item(item):
        _update_ui()
        return true
    return false

## Add a Rotate action to the base right-click menu for non-square items.
func show_context_menu(slot: InventorySlotUI) -> void:
    super.show_context_menu(slot)
    if context_menu == null or slot == null or slot.associated_item == null:
        return
    var item := slot.associated_item as InventoryItem
    if item.dimensions.x == item.dimensions.y:
        return
    context_menu.add_item("Rotate (R)  %dx%d" % [item.dimensions.y, item.dimensions.x], CONTEXT_ROTATE)

func _on_context_menu_selected(id: int) -> void:
    if id == CONTEXT_ROTATE and currently_hovered_slot != null:
        _rotate(currently_hovered_slot.associated_item)
        currently_hovered_slot = null
        return
    super._on_context_menu_selected(id)

func _on_close_button_pressed():
    container_closed.emit()
    hide()

## Re-add the stats line whenever the grid changes.
func _on_container_changed():
    _update_stats()
    super._on_container_changed()

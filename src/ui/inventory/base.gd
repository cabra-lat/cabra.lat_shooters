class_name BaseInventoryUI
extends PanelContainer

signal slot_dropped(data: Dictionary, target_slot: InventorySlotUI)
signal drag_started(item: InventoryItem)
signal drag_ended()
signal inventory_updated()

var item_displays: Array[InventoryItemUI] = []
var slot_displays: Array[InventorySlotUI] = []
var current_inventory_source: Resource = null

func _ready():
    theme = InventoryTheme.get_theme()
    _setup_common_connections()
    _apply_theme()

func _apply_theme():
    # Base theming - can be overridden by subclasses
    pass

func _setup_common_connections():
    # Common signal connections will be set up by subclasses
    pass

func setup_inventory(source: Resource):
    current_inventory_source = source
    _setup_slots()
    _update_ui()

func _setup_slots():
    # To be implemented by subclasses
    push_error("_setup_slots must be implemented by subclass")

func _update_ui():
    _clear_item_displays()
    _create_item_displays()
    _update_slot_states()
    inventory_updated.emit()

func _clear_item_displays():
    for display in item_displays:
        if is_instance_valid(display):
            display.queue_free()
    item_displays.clear()

func _create_item_displays():
    var items = _get_display_items()
    for item in items:
        _create_item_display(item)

func _get_display_items() -> Array[InventoryItem]:
    # To be implemented by subclasses
    push_error("_get_display_items must be implemented by subclass")
    return []

func _create_item_display(item: InventoryItem):
    var display = InventoryItemUI.new()
    display.setup(item, self)
    _add_item_display_to_scene(display)
    item_displays.append(display)
    _position_item_display(display, item)

func _add_item_display_to_scene(display: InventoryItemUI):
    # To be implemented by subclasses
    push_error("_add_item_display_to_scene must be implemented by subclass")

func _position_item_display(display: InventoryItemUI, item: InventoryItem):
    # To be implemented by subclasses
    push_error("_position_item_display must be implemented by subclass")

func _update_slot_states():
    # To be implemented by subclasses
    push_error("_update_slot_states must be implemented by subclass")

# Common drag/drop handlers
func _on_drag_started(item: InventoryItem):
    drag_started.emit(item)

func _on_drag_ended():
    drag_ended.emit()

func _on_slot_dropped(data: Dictionary, target_slot: InventorySlotUI):
    slot_dropped.emit(data, target_slot)

# Common utility methods
func get_slot_at_position(position: Vector2i) -> InventorySlotUI:
    for slot in slot_displays:
        if slot.grid_position == position:
            return slot
    return null

func create_item_ui(item: InventoryItem) -> InventoryItemUI:
    var item_ui = InventoryItemUI.new()
    item_ui.setup(item, self)
    return item_ui

func get_item_ui_at_position(position: Vector2) -> InventoryItemUI:
    for item_ui in item_displays:
        if item_ui.get_global_rect().has_point(position):
            return item_ui
    return null

func highlight_items_under_cursor(cursor_position: Vector2):
    for item_ui in item_displays:
        var is_under_cursor = item_ui.get_global_rect().has_point(cursor_position)
        item_ui.set_highlighted(is_under_cursor)

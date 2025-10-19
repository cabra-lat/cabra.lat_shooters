# src/ui/inventory/base_slot.gd
class_name BaseSlotUI
extends Panel

const SLOT_SIZE_PX = Vector2(50, 50)

signal slot_dropped(data: Dictionary, target_slot: BaseSlotUI)
signal drag_started(item: InventoryItem)
signal drag_ended()

@onready var icon: TextureRect = $Icon
@onready var label: Label = $Label

var associated_item: InventoryItem = null
var source_container: Resource = null
var is_occupied: bool = false
var parent_ui: BaseInventoryUI = null

func _ready():
    custom_minimum_size = SLOT_SIZE_PX
    size_flags_horizontal = Control.SIZE_FILL
    size_flags_vertical = Control.SIZE_FILL
    mouse_filter = Control.MOUSE_FILTER_STOP

func setup(parent: BaseInventoryUI):
    parent_ui = parent

func clear():
    if icon:
        icon.texture = null
        _reset_icon_size()
    if label:
        label.text = ""
    associated_item = null
    source_container = null
    is_occupied = false
    modulate = Color(1, 1, 1, 1)

func _reset_icon_size():
    if icon:
        icon.custom_minimum_size = SLOT_SIZE_PX

func set_occupied(occupied: bool):
    is_occupied = occupied
    if occupied:
        self_modulate = Color(0.7, 0.7, 0.7, 0.3)
    else:
        self_modulate = Color(1, 1, 1, 1)

# Common drag/drop implementation
func _get_drag_data(at_position: Vector2) -> Variant:
    var drag_data = _create_drag_data()
    if drag_data:
        _on_drag_start(drag_data["item"])
        return drag_data
    return null

func _create_drag_data() -> Dictionary:
    # To be implemented by subclasses
    push_error("_create_drag_data must be implemented by subclass")
    return {}

func _on_drag_start(item: InventoryItem):
    # Hide icon during drag for equipment slots
    if has_method("_hide_icon_during_drag"):
        _hide_icon_during_drag()
    drag_started.emit(item)

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
    if not data is Dictionary or not data.has("item"):
        return false
    return _validate_drop(data["item"])

func _validate_drop(item: InventoryItem) -> bool:
    # To be implemented by subclasses
    push_error("_validate_drop must be implemented by subclass")
    return true

func _drop_data(at_position: Vector2, data: Variant) -> void:
    if data is Dictionary and data.has("item"):
        _on_drop_accepted(data)

func _on_drop_accepted(data: Dictionary):
    slot_dropped.emit(data, self)

func _notification(what):
    if what == NOTIFICATION_DRAG_END:
        _on_drag_end()

func _on_drag_end():
    # Restore icon visibility
    if has_method("_show_icon_after_drag"):
        _show_icon_after_drag()
    drag_ended.emit()

func _hide_icon_during_drag():
    # To be overridden by subclasses
    pass

func _show_icon_after_drag():
    # To be overridden by subclasses
    pass

func _create_drag_preview(item: InventoryItem) -> Control:
    var preview = TextureRect.new()
    preview.texture = item.content.icon
    preview.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
    preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    preview.size = SLOT_SIZE_PX * Vector2(item.dimensions)

    var control = Control.new()
    control.add_child(preview)
    control.custom_minimum_size = preview.size
    control.size = preview.size
    preview.position = -0.25 * preview.size

    return control

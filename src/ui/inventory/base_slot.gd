class_name BaseSlotUI
extends Panel

signal slot_dropped(data: Dictionary, target_slot: BaseSlotUI)
signal drag_started(item: InventoryItem)
signal drag_ended()
signal slot_hovered(slot: BaseSlotUI)
signal slot_exited(slot: BaseSlotUI)

@onready var icon: TextureRect = $Icon
@onready var label: Label = $Label
@onready var rarity_overlay: ColorRect = $RarityOverlay

var associated_item: InventoryItem = null
var source_container: Resource = null
var is_occupied: bool = false
var slot_size: int

func _ready():
    theme = InventoryTheme.get_theme()
    slot_size = (theme as InventoryTheme).slot_size
    custom_minimum_size = slot_size * Vector2.ONE
    size_flags_horizontal = Control.SIZE_FILL
    size_flags_vertical = Control.SIZE_FILL
    mouse_filter = Control.MOUSE_FILTER_STOP
    _apply_theme_styles()

func _apply_theme_styles():
    var style_box = StyleBoxFlat.new()
    style_box.bg_color = theme.slot_bg_color
    style_box.border_color = theme.slot_border_color
    style_box.border_width_left = 1
    style_box.border_width_top = 1
    style_box.border_width_right = 1
    style_box.border_width_bottom = 1
    add_theme_stylebox_override("panel", style_box)

func clear():
    if icon:
        icon.texture = null
        _reset_icon_size()
    if label:
        label.text = ""
    if rarity_overlay:
        rarity_overlay.visible = false
    associated_item = null
    source_container = null
    is_occupied = false
    modulate = Color(1, 1, 1, 1)

func _reset_icon_size():
    if icon:
        icon.custom_minimum_size = slot_size * Vector2.ONE

func set_occupied(occupied: bool):
    is_occupied = occupied
    if occupied:
        self_modulate = theme.slot_occupied_color
    else:
        self_modulate = Color(1, 1, 1, 1)

func set_rarity(rarity: String):
    if rarity_overlay and theme.rarity_colors.has(rarity):
        rarity_overlay.color = theme.rarity_colors[rarity]
        rarity_overlay.visible = true

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
    preview.size = slot_size * Vector2(item.dimensions)

    var control = Control.new()
    control.add_child(preview)
    control.custom_minimum_size = preview.size
    control.size = preview.size
    preview.position = -0.25 * preview.size

    return control

func _on_mouse_entered():
    slot_hovered.emit(self)

func _on_mouse_exited():
    slot_exited.emit(self)

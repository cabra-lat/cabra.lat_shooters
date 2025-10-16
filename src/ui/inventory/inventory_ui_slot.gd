# src/ui/inventory/inventory_ui_slot.gd
class_name InventoryUISlot
extends Panel

signal drag_started(item: InventoryItem, source: InventoryContainer)
signal dropped_here(item: InventoryItem, source: InventoryContainer)

@onready var icon: TextureRect = %Icon

var associated_item: InventoryItem = null
var source_container: InventoryContainer = null

@export var item_icon: Texture2D:
    set(value):
        item_icon = value
        if icon: icon.texture = value

func _get_drag_data(at_position: Vector2) -> Variant:
    if not associated_item:
        return null
    var preview = TextureRect.new()
    preview.texture = icon.texture
    preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    preview.expand_mode = TextureRect.EXPAND_FIT_HEIGHT
    preview.custom_minimum_size = size
    set_drag_preview(preview)
    drag_started.emit(associated_item, source_container)
    return {"item": associated_item, "source": source_container}

func _drop_data(at_position: Vector2,  data: Variant) -> void:
    if data is Dictionary and data.has("item"):
        dropped_here.emit(data["item"], data["source"])

func clear():
    associated_item = null

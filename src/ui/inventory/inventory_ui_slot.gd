# ui/inventory/inventory_ui_slot.gd
class_name InventoryUISlot
extends Panel

@onready var icon: TextureRect = %Icon
@onready var label: Label = %Label

# Public properties
@export var item_icon: Texture2D:
    set(value):
        item_icon = value
        if icon: icon.texture = value
@export var slot_name: String:
    set(value):
        slot_name = value
        if label: label.text = value
        name = value

func clear():
    if icon: icon.texture = null
    if label: label.text = ""

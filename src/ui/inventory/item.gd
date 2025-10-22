# src/ui/inventory/item.gd
class_name InventoryItemUI
extends Control

@export var slot_size: int = 50
var inventory_item: InventoryItem
var container_ui: BaseInventoryUI
var debug_label: Label

func _ready():
    # CRITICAL: Let ALL mouse events pass through
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup(item: InventoryItem, container: BaseInventoryUI):
    inventory_item = item
    container_ui = container

    # Create the visual representation
    var texture_rect = TextureRect.new()
    texture_rect.texture = item.icon
    texture_rect.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
    texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

    # CRITICAL: Make the texture rect also ignore mouse events
    texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

    # Set the correct size for multi-slot items
    var display_size = Vector2(slot_size, slot_size) * Vector2(item.dimensions)
    texture_rect.custom_minimum_size = display_size
    texture_rect.size = display_size

    add_child(texture_rect)

    # Position to cover all occupied slots
    position = Vector2(item.position.x * slot_size, item.position.y * slot_size)
    size = display_size

    # CRITICAL: Ensure this control doesn't process input at all
    mouse_filter = Control.MOUSE_FILTER_IGNORE

# Remove ALL drag/drop functionality from items
func _get_drag_data(at_position: Vector2):
    return null

func _can_drop_data(at_position: Vector2, data):
    return false

func _drop_data(at_position: Vector2, data):
    pass

# Also ignore gui_input
func _gui_input(event):
    # Let the event pass through to underlying slots
    pass

# src/ui/inventory/item.gd
class_name InventoryItemUI
extends Control

@export var slot_size: int = 50
var inventory_item: InventoryItem
var container_ui: ContainerUI
var debug_label: Label

func _ready():
    mouse_filter = Control.MOUSE_FILTER_PASS

func setup(item: InventoryItem, container: ContainerUI):
    inventory_item = item
    container_ui = container
    
    # Create the visual representation
    var texture_rect = TextureRect.new()
    texture_rect.texture = item.content.icon if item.content and item.content.icon else \
        preload("../../../assets/ui/inventory/placeholder.png")
    texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    
    # Set the correct size for multi-slot items
    var display_size = Vector2(slot_size, slot_size) * Vector2(item.dimensions)
    texture_rect.custom_minimum_size = display_size
    texture_rect.size = display_size
    
    add_child(texture_rect)
    
    # Position to cover all occupied slots
    position = Vector2(item.position.x * slot_size, item.position.y * slot_size)
    size = display_size
    
    # Create debug overlay
    _create_debug_overlay(item)
    
    # Make it draggable from any part
    mouse_filter = Control.MOUSE_FILTER_STOP

func _create_debug_overlay(item: InventoryItem):
    var debug_panel = Panel.new()
    debug_panel.modulate = Color(0, 0, 0, 0.3)
    debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    debug_panel.size = size
    
    debug_label = Label.new()
    debug_label.modulate = Color.WHITE
    debug_label.add_theme_font_size_override("font_size", 10)
    debug_label.text = "%s\n%s" % [item.content.name if item.content else "Unknown", item.dimensions]
    debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    debug_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    debug_label.size = size
    debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    
    add_child(debug_panel)
    add_child(debug_label)

func _get_drag_data(at_position: Vector2):
    print("Starting drag from container: %s (dimensions: %s)" % [inventory_item.content.name if inventory_item.content else "Unknown", inventory_item.dimensions])
    
    var preview = TextureRect.new()
    preview.texture = get_child(0).texture
    preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    
    # Use a fixed size for drag preview to avoid huge images
    var max_preview_size = 100
    var preview_scale = min(1.0, max_preview_size / max(size.x, size.y))
    var preview_size = size * preview_scale
    
    preview.custom_minimum_size = preview_size
    preview.size = preview_size
    preview.modulate = Color(1, 1, 1, 0.7)
    
    var control = Control.new()
    control.add_child(preview)
    control.size = preview_size
    preview.position = -0.5 * preview_size
    
    set_drag_preview(control)
    
    return {
        "item": inventory_item,
        "source": container_ui.current_container,
        "display": self
    }

func _can_drop_data(at_position: Vector2, data):
    return false  # Item displays don't accept drops

func _drop_data(at_position: Vector2, data):
    pass  # Item displays don't accept drops

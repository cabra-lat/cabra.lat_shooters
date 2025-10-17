# src/ui/inventory/slot.gd (UPDATED)
class_name InventorySlotUI
extends Panel

signal slot_dropped(data: Dictionary, target_slot: InventorySlotUI)

@onready var icon: TextureRect = %Icon
@onready var label: Label = %Label
@export var grid_position: Vector2i = Vector2i(-1,-1)

var associated_item: InventoryItem = null
var source_container: Resource = null
var is_main_slot: bool = false
var is_occupied: bool = false
var item_dimensions: Vector2i = Vector2i.ONE
var debug_label: Label

func _ready():
    custom_minimum_size = Vector2(50, 50)
    size_flags_horizontal = Control.SIZE_FILL
    size_flags_vertical = Control.SIZE_FILL
    _create_debug_label()

func _create_debug_label():
    debug_label = Label.new()
    debug_label.name = "DebugLabel"
    debug_label.modulate = Color.YELLOW
    debug_label.add_theme_font_size_override("font_size", 8)
    debug_label.text = str(grid_position)
    debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    debug_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(debug_label)

func clear():
    if icon: 
        icon.texture = null
        call_deferred("_reset_icon_size")
    if label: 
        label.text = ""
    associated_item = null
    source_container = null
    is_main_slot = false
    is_occupied = false
    item_dimensions = Vector2i.ONE
    modulate = Color(1, 1, 1, 1)
    
    # Update debug info
    if debug_label:
        debug_label.text = str(grid_position)

func _reset_icon_size():
    if icon:
        icon.custom_minimum_size = Vector2(50, 50)
        icon.size = Vector2(50, 50)

func set_occupied(occupied: bool):
    is_occupied = occupied
    if occupied:
        self_modulate = Color(0.7, 0.7, 0.7, 0.3)
        if debug_label:
            debug_label.text = "%s\nOCCUPIED" % grid_position
    else:
        self_modulate = Color(1, 1, 1, 1)
        if debug_label:
            debug_label.text = str(grid_position)

func _get_drag_data(at_position: Vector2) -> Variant:
    # Allow dragging from equipment slots (they don't have InventoryItemUI)
    if associated_item and source_container:
        print("Starting drag from equipment: %s (dimensions: %s)" % [associated_item.content.name if associated_item.content else "Unknown", associated_item.dimensions])
        
        var preview = TextureRect.new()
        preview.texture = icon.texture if icon.texture else \
            preload("../../../assets/ui/inventory/placeholder.png")
        preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
        preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        
        # Scale preview to match item dimensions - use fixed size to avoid huge previews
        var max_preview_size = 100
        var preview_size_base = Vector2(50, 50) * Vector2(associated_item.dimensions)
        var preview_scale = min(1.0, max_preview_size / max(preview_size_base.x, preview_size_base.y))
        var preview_size = preview_size_base * preview_scale
        
        preview.custom_minimum_size = preview_size
        preview.size = preview_size
        preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
        
        var control = Control.new()
        control.add_child(preview)
        control.size = preview_size
        preview.position = -0.5 * preview_size
        
        set_drag_preview(control)
        
        return {
            "item": associated_item,
            "source": source_container
        }
    
    return null

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
    if not data is Dictionary or not data.has("item"):
        print("Drop rejected: Invalid data")
        return false
    
    # Don't allow dropping on occupied slots
    if is_occupied:
        print("Drop rejected: Slot %s is occupied" % grid_position)
        return false
    
    # Check if the item can be placed here - FIXED: Get container from scene tree
    var container_ui = _get_parent_container()
    if container_ui and container_ui.current_container:
        var item = data["item"]
        var can_place = container_ui.current_container.grid.can_add_item(item, grid_position)
        print("Drop check at %s: %s (item: %s, dimensions: %s)" % [grid_position, "CAN PLACE" if can_place else "CANNOT PLACE", item.content.name if item.content else "Unknown", item.dimensions])
        return can_place
    
    print("Drop rejected: No container found for slot %s" % grid_position)
    return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
    if data is Dictionary and data.has("item"):
        print("Drop accepted at slot %s" % grid_position)
        slot_dropped.emit(data, self)

# FIXED: Better container detection
func _get_parent_container() -> ContainerUI:
    # First try the direct parent approach
    var parent = get_parent()
    while parent and not parent is ContainerUI:
        parent = parent.get_parent()
    
    if parent is ContainerUI:
        return parent as ContainerUI
    
    # If that fails, try to find any ContainerUI in the scene
    var scene_root = get_tree().current_scene
    if scene_root:
        return _find_container_in_children(scene_root)
    
    return null

func _find_container_in_children(node: Node) -> ContainerUI:
    if node is ContainerUI:
        return node as ContainerUI
    
    for child in node.get_children():
        var result = _find_container_in_children(child)
        if result:
            return result
    
    return null

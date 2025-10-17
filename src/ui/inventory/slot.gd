# src/ui/inventory/slot.gd
class_name InventorySlotUI
extends Panel

signal slot_dropped(data: Dictionary, target_slot: InventorySlotUI)
signal drag_started(item: InventoryItem)  # NEW: Signal for drag start
signal drag_ended()  # NEW: Signal for drag end

@onready var icon: TextureRect = $Icon
@onready var label: Label = $Label

@export var grid_position: Vector2i = Vector2i(-1,-1)

var associated_item: InventoryItem = null
var source_container: Resource = null
var is_main_slot: bool = false
var is_occupied: bool = false
var item_dimensions: Vector2i = Vector2i.ONE
var container_ui: ContainerUI = null
var debug_label: Label
var is_equipment_slot: bool = false

func _ready():
    custom_minimum_size = Vector2(50, 50)
    size_flags_horizontal = Control.SIZE_FILL
    size_flags_vertical = Control.SIZE_FILL
    mouse_filter = Control.MOUSE_FILTER_STOP
    is_equipment_slot = (grid_position == Vector2i(-1, -1))

func _get_drag_data(at_position: Vector2) -> Variant:
    print("Slot _get_drag_data called at position: ", grid_position)
    
    var dragged_item = null
    var source = null
    
    # Handle equipment slots
    if associated_item and source_container:
        print("Starting drag from equipment: %s (dimensions: %s)" % [associated_item.content.name if associated_item.content else "Unknown", associated_item.dimensions])
        dragged_item = associated_item
        source = source_container
        
        # NEW: Dim the equipment slot icon
        icon.modulate = Color(1, 1, 1, 0.3)
        
        # NEW: Tell the source container's grid to ignore this item
        if source is InventoryContainer:
            source.grid.set_temp_ignored_item(associated_item)
    
    # Handle container slots
    elif container_ui and container_ui.current_container:
        var item_at_slot = container_ui.current_container.get_item_at(grid_position)
        if item_at_slot:
            print("Starting drag from container: %s at %s (dimensions: %s)" % [item_at_slot.content.name if item_at_slot.content else "Unknown", grid_position, item_at_slot.dimensions])
            dragged_item = item_at_slot
            source = container_ui.current_container
            
            # NEW: Tell the container's grid to ignore this item
            container_ui.current_container.grid.set_temp_ignored_item(item_at_slot)
            
            # NEW: Emit signal to dim the original item
            drag_started.emit(item_at_slot)
    
    if dragged_item:
        var preview = _create_drag_preview(dragged_item)
        set_drag_preview(preview)
        
        return {
            "item": dragged_item,
            "source": source
        }
    
    return null

# NEW: Enhanced drag end handling
func _notification(what):
    if what == NOTIFICATION_DRAG_END:
        print("Drag ended, cleaning up...")
        
        # NEW: Restore equipment slot appearance
        if associated_item and source_container:
            icon.modulate = Color(1, 1, 1, 1)
        
        # NEW: Emit signal to restore original items
        drag_ended.emit()
        
        # Clear temporary ignored items from all relevant containers
        if container_ui and container_ui.current_container:
            container_ui.current_container.grid.clear_temp_ignored_item()
        if associated_item and source_container is InventoryContainer:
            source_container.grid.clear_temp_ignored_item()

func _create_drag_preview(item: InventoryItem) -> Control:
    var preview = TextureRect.new()
    preview.texture = item.content.icon if item.content and item.content.icon else \
        preload("../../../assets/ui/inventory/placeholder.png")
    preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    
    # Scale preview to match item dimensions
    var max_preview_size = 100
    var preview_size_base = Vector2(50, 50) * Vector2(item.dimensions)
    var preview_scale = min(1.0, max_preview_size / max(preview_size_base.x, preview_size_base.y))
    var preview_size = preview_size_base * preview_scale
    
    preview.custom_minimum_size = preview_size
    preview.size = preview_size
    preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
    
    var control = Control.new()
    control.add_child(preview)
    control.size = preview_size
    preview.position = -0.5 * preview_size
    
    return control

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
    if not data is Dictionary or not data.has("item"):
        print("Drop rejected: Invalid data")
        return false
    
    var item = data["item"]
    
    # Prevent containers from being placed in themselves
    if container_ui and container_ui.current_container and item.content == container_ui.current_container:
        print("Drop rejected: Cannot place container in itself")
        return false
    
    # Handle equipment slots differently
    if is_equipment_slot:
        print("Equipment slot drop check for %s" % name)
        return true
    
    # Handle container slots
    else:
        print("Container slot drop check")
        if not container_ui or not container_ui.current_container:
            print("Drop rejected: No container reference for slot %s" % grid_position)
            return false
        
        # NEW: Also tell the target container to temporarily ignore the dragged item
        # This allows dropping on positions that overlap with the item's original position
        container_ui.current_container.grid.set_temp_ignored_item(item)
        
        var can_place = container_ui.current_container.grid.can_add_item(item, grid_position)
        print("Container drop check at %s: %s (item: %s, dimensions: %s)" % [grid_position, "CAN PLACE" if can_place else "CANNOT PLACE", item.content.name if item.content else "Unknown", item.dimensions])
        
        # NEW: Show visual feedback for the drop area
        _show_drop_preview(item.dimensions, can_place)
        
        return can_place

func _drop_data(at_position: Vector2, data: Variant) -> void:
    if data is Dictionary and data.has("item"):
        print("Drop accepted at slot %s (equipment: %s)" % [grid_position, is_equipment_slot])
        
        # NEW: Hide drop preview
        _hide_drop_preview()
        
        # NEW: Clear temporary ignores
        if container_ui and container_ui.current_container:
            container_ui.current_container.grid.clear_temp_ignored_item()
        if data["source"] is InventoryContainer:
            data["source"].grid.clear_temp_ignored_item()
        
        slot_dropped.emit(data, self)

# NEW: Visual feedback for drop area
func _show_drop_preview(dimensions: Vector2i, valid: bool):
    if not container_ui:
        return
        
    # Create or update a preview that spans multiple slots
    var preview_color = Color(0, 1, 0, 0.3) if valid else Color(1, 0, 0, 0.3)
    
    # This will be handled by the container UI
    if container_ui.has_method("show_drop_preview"):
        container_ui.show_drop_preview(grid_position, dimensions, preview_color)

func _hide_drop_preview():
    if container_ui and container_ui.has_method("hide_drop_preview"):
        container_ui.hide_drop_preview()

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

func _reset_icon_size():
    if icon:
        icon.custom_minimum_size = Vector2(50, 50)
        icon.size = Vector2(50, 50)

# Set container reference directly (for container slots only)
func set_container_ui(container: ContainerUI):
    if not is_equipment_slot:  # Only set for container slots
        container_ui = container
        print("Set container_ui for slot %s" % grid_position)

func get_parent_container() -> ContainerUI:
    return container_ui

func set_occupied(occupied: bool):
    is_occupied = occupied
    if occupied:
        self_modulate = Color(0.7, 0.7, 0.7, 0.3)
    else:
        self_modulate = Color(1, 1, 1, 1)

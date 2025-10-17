# slot.gd - UPDATED
class_name InventorySlotUI
extends Panel

signal slot_dropped(data: Dictionary, target_slot: InventorySlotUI)

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
var is_equipment_slot: bool = false  # NEW: Track if this is equipment

func _ready():
    custom_minimum_size = Vector2(50, 50)
    size_flags_horizontal = Control.SIZE_FILL
    size_flags_vertical = Control.SIZE_FILL
    mouse_filter = Control.MOUSE_FILTER_STOP
    is_equipment_slot = (grid_position == Vector2i(-1, -1))

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

func _get_drag_data(at_position: Vector2) -> Variant:
    print("Slot _get_drag_data called at position: ", grid_position)
    
    # Handle equipment slots
    if associated_item and source_container:
        print("Starting drag from equipment: %s (dimensions: %s)" % [associated_item.content.name if associated_item.content else "Unknown", associated_item.dimensions])
        
        # NEW: Tell the grid to temporarily ignore this item
        if source_container is InventoryContainer:
            source_container.grid.set_temp_ignored_item(associated_item)
        
        var preview = _create_drag_preview(associated_item)
        set_drag_preview(preview)
        
        return {
            "item": associated_item,
            "source": source_container
        }
    
    # Handle container slots
    if container_ui and container_ui.current_container:
        var item_at_slot = container_ui.current_container.get_item_at(grid_position)
        if item_at_slot:
            print("Starting drag from container: %s at %s (dimensions: %s)" % [item_at_slot.content.name if item_at_slot.content else "Unknown", grid_position, item_at_slot.dimensions])
            
            # NEW: Tell the grid to temporarily ignore this item
            container_ui.current_container.grid.set_temp_ignored_item(item_at_slot)
            
            var preview = _create_drag_preview(item_at_slot)
            set_drag_preview(preview)
            
            return {
                "item": item_at_slot,
                "source": container_ui.current_container
            }
    
    return null

# NEW: Handle drag ending to clear the temporary ignore
func _notification(what):
    if what == NOTIFICATION_DRAG_END:
        # Clear temporary ignored item when drag ends (whether successful or not)
        if container_ui and container_ui.current_container:
            container_ui.current_container.grid.clear_temp_ignored_item()
        elif source_container is InventoryContainer:
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
    
    # Don't allow dropping on occupied slots
    if is_occupied:
        print("Drop rejected: Slot is occupied")
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
        
        var can_place = container_ui.current_container.grid.can_add_item(item, grid_position)
        print("Container drop check at %s: %s (item: %s, dimensions: %s)" % [grid_position, "CAN PLACE" if can_place else "CANNOT PLACE", item.content.name if item.content else "Unknown", item.dimensions])
        return can_place

func _drop_data(at_position: Vector2, data: Variant) -> void:
    if data is Dictionary and data.has("item"):
        print("Drop accepted at slot %s (equipment: %s)" % [grid_position, is_equipment_slot])
        
        # NEW: Clear the temporary ignore when drop is completed
        if container_ui and container_ui.current_container:
            container_ui.current_container.grid.clear_temp_ignored_item()
        elif data["source"] is InventoryContainer:
            data["source"].grid.clear_temp_ignored_item()
        
        slot_dropped.emit(data, self)

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

# src/ui/inventory/container.gd (UPDATED POSITIONING)
class_name ContainerUI
extends Container

signal slot_dropped(data: Dictionary, target_slot: InventorySlotUI)
signal container_closed()

@onready var foldable_panel: FoldableContainer = $Panel
@onready var grid_container: GridContainer = $Panel/Items
@onready var close_button: Button = %CloseButton

var current_container: InventoryContainer = null
var slot_size: int = 50
var item_displays: Array[InventoryItemUI] = []
var debug_label: Label
var error_label: Label

func _ready():
    close_button.pressed.connect(_on_close_button_pressed)
    _create_debug_labels()

func _create_debug_labels():
    debug_label = Label.new()
    debug_label.name = "DebugLabel"
    debug_label.modulate = Color.YELLOW
    debug_label.add_theme_font_size_override("font_size", 12)
    add_child(debug_label)
    
    error_label = Label.new()
    error_label.name = "ErrorLabel"
    error_label.modulate = Color.RED
    error_label.add_theme_font_size_override("font_size", 12)
    error_label.position = Vector2(0, 150)
    add_child(error_label)

func open_container(container: InventoryContainer):
    current_container = container
    foldable_panel.title = container.name
    _setup_grid()
    _update_ui()
    show()

func _setup_grid():
    # Clear existing
    for child in grid_container.get_children():
        if child is InventorySlotUI:
            grid_container.remove_child(child)
            child.queue_free()
    
    for child in get_children():
        if child is InventoryItemUI:
            remove_child(child)
            child.queue_free()
    
    item_displays.clear()
    
    # Setup grid slots
    grid_container.columns = current_container.grid_width
    grid_container.custom_minimum_size = Vector2(
        current_container.grid_width * slot_size,
        current_container.grid_height * slot_size
    )
    
    for y in range(current_container.grid_height):
        for x in range(current_container.grid_width):
            var slot = preload("slot.tscn").instantiate()
            slot.grid_position = Vector2i(x, y)
            slot.name = "Slot[%d,%d]" % [x, y]
            slot.custom_minimum_size = Vector2(slot_size, slot_size)
            slot.mouse_entered.connect(_on_slot_mouse_entered.bind(slot))
            slot.mouse_exited.connect(_on_slot_mouse_exited.bind(slot))
            grid_container.add_child(slot)

func _update_ui():
    if not current_container:
        return
    
    call_deferred("_deferred_update_ui")

func _deferred_update_ui():
    # Clear all slots
    for slot in grid_container.get_children():
        if slot is InventorySlotUI:
            slot.clear()
            slot.set_occupied(false)
    
    # Remove old item displays
    for display in item_displays:
        if is_instance_valid(display):
            remove_child(display)
            display.queue_free()
    item_displays.clear()
    
    # Update debug info with error handling
    _update_debug_info()
    
    # Create item displays for each item
    for item in current_container.items:
        _create_item_display(item)

func _update_debug_info():
    if debug_label and current_container:
        var debug_text = "Container: %s\n" % current_container.name
        debug_text += "Grid: %dx%d\n" % [current_container.grid_width, current_container.grid_height]
        debug_text += "Items: %d\n" % current_container.items.size()
        
        # Safe area calculation
        var used_area = 0
        var free_area = 0
        if current_container.grid:
            used_area = current_container.grid.get_used_area()
            free_area = current_container.grid.get_free_area()
        
        debug_text += "Used area: %d\n" % used_area
        debug_text += "Free area: %d\n" % free_area
        
        # Show item positions
        var i = 0
        for item in current_container.items:
            debug_text += "Item %d: %s at %s\n" % [i, item.content.name if item.content else "Unknown", item.position]
            i += 1
        debug_label.text = debug_text
        
        # Update error label if there are issues
        if current_container.items.size() > 0 and used_area == 0:
            error_label.text = "WARNING: Items exist but grid shows no used area!"
        else:
            error_label.text = ""

func _create_item_display(item: InventoryItem):
    var display = InventoryItemUI.new()
    display.slot_size = slot_size
    display.setup(item, self)
    add_child(display)
    display.z_index = 1  # Make sure items appear above slots
    item_displays.append(display)
    
    # Debug: print item info
    print("Created item display: %s at %s (dimensions: %s)" % [item.content.name if item.content else "Unknown", item.position, item.dimensions])
    
    # Mark occupied slots with bounds checking
    for y in range(item.dimensions.y):
        for x in range(item.dimensions.x):
            var slot_pos = Vector2i(item.position.x + x, item.position.y + y)
            var slot_index = slot_pos.y * current_container.grid_width + slot_pos.x
            if slot_index < grid_container.get_child_count():
                var slot = grid_container.get_child(slot_index)
                if slot is InventorySlotUI:
                    slot.set_occupied(true)
            else:
                print("ERROR: Slot index out of bounds: ", slot_index, " >= ", grid_container.get_child_count())

func _on_slot_mouse_entered(slot: InventorySlotUI):
    # Visual feedback for drag operations
    if slot.is_occupied:
        slot.modulate = Color(1, 0.5, 0.5, 1)  # Red tint for occupied
    else:
        slot.modulate = Color(0.5, 1, 0.5, 1)  # Green tint for free

func _on_slot_mouse_exited(slot: InventorySlotUI):
    # Reset visual feedback
    slot.modulate = Color(1, 1, 1, 1)

func _on_slot_dropped(data: Dictionary, target_slot: InventorySlotUI):
    print("ContainerUI: Slot dropped: %s -> %s" % [data["item"].content.name if data["item"].content else "Unknown", target_slot.grid_position])
    slot_dropped.emit(data, target_slot)

func _on_close_button_pressed():
    container_closed.emit()
    hide()

# container.gd - FIXED
class_name ContainerUI
extends PanelContainer

signal slot_dropped(data: Dictionary, target_slot: InventorySlotUI)
signal container_closed()

@onready var foldable_panel: FoldableContainer = $Panel
@onready var grid_background: Control = $Panel/GridBackground
@onready var items_container: Control = $Panel/ItemsContainer
@onready var close_button: Button = %CloseButton

var current_container: InventoryContainer = null
var slot_size: int = 50
var item_displays: Array[InventoryItemUI] = []
var slot_displays: Array[InventorySlotUI] = []
var debug_label: Label
var error_label: Label

func _ready():
    close_button.pressed.connect(_on_close_button_pressed)

func open_container(container: InventoryContainer):
    current_container = container
    foldable_panel.title = container.name
    _setup_grid()
    _update_ui()
    show()

func _setup_grid():
    # Clear existing slots and items
    for child in grid_background.get_children():
        grid_background.remove_child(child)
        child.queue_free()
    
    for child in items_container.get_children():
        items_container.remove_child(child)
        child.queue_free()
    
    item_displays.clear()
    slot_displays.clear()
    
    # Set container size - FIXED: Use size instead of custom_minimum_size
    var grid_size = Vector2(
        current_container.grid_width * slot_size,
        current_container.grid_height * slot_size
    )
    
    grid_background.size = grid_size
    items_container.size = grid_size
    
    print("Setting up container grid: %dx%d, slot_size: %d" % [current_container.grid_width, current_container.grid_height, slot_size])
    print("Grid background size: %s" % grid_size)
    
    # Create grid slots - REMOVED visual debugging styles
    for y in range(current_container.grid_height):
        for x in range(current_container.grid_width):
            var slot: InventorySlotUI = preload("res://addons/cabra.lat_shooters/src/ui/inventory/slot.tscn").instantiate()
            slot.grid_position = Vector2i(x, y)
            slot.name = "Slot[%d,%d]" % [x, y]
            slot.size = Vector2(slot_size, slot_size)
            slot.position = Vector2(x * slot_size, y * slot_size)
            
            # Set container reference directly
            slot.set_container_ui(self)
            
            slot.mouse_entered.connect(_on_slot_mouse_entered.bind(slot))
            slot.mouse_exited.connect(_on_slot_mouse_exited.bind(slot))
            slot.slot_dropped.connect(_on_slot_dropped)
            grid_background.add_child(slot)
            slot_displays.append(slot)
    
    print("Total slots created: %d" % slot_displays.size())

func _update_ui():
    if not current_container:
        return
    
    call_deferred("_deferred_update_ui")

func _deferred_update_ui():
    # Clear all slots
    for slot in slot_displays:
        slot.clear()
        slot.set_occupied(false)
    
    # Remove old item displays
    for display in item_displays:
        if is_instance_valid(display):
            items_container.remove_child(display)
            display.queue_free()
    item_displays.clear()
    
    # Create item displays for each item
    for item in current_container.items:
        _create_item_display(item)

func _create_item_display(item: InventoryItem):
    var display = InventoryItemUI.new()
    display.slot_size = slot_size
    display.setup(item, self)
    items_container.add_child(display)
    display.z_index = 1
    item_displays.append(display)
    
    # Position the item correctly
    display.position = Vector2(item.position.x * slot_size, item.position.y * slot_size)
    
    print("Created item display: %s at %s (dimensions: %s)" % [item.content.name if item.content else "Unknown", item.position, item.dimensions])
    
    # Mark occupied slots
    for y in range(item.dimensions.y):
        for x in range(item.dimensions.x):
            var slot_pos = Vector2i(item.position.x + x, item.position.y + y)
            var slot = _get_slot_at_position(slot_pos)
            if slot:
                slot.set_occupied(true)

func _get_slot_at_position(position: Vector2i) -> InventorySlotUI:
    for slot in slot_displays:
        if slot.grid_position == position:
            return slot
    return null

func _on_slot_mouse_entered(slot: InventorySlotUI):
    # Visual feedback for drag operations
    if slot.is_occupied:
        slot.modulate = Color(1, 0.5, 0.5, 1)
    else:
        slot.modulate = Color(0.5, 1, 0.5, 1)

func _on_slot_mouse_exited(slot: InventorySlotUI):
    # Reset visual feedback
    slot.modulate = Color(1, 1, 1, 1)

func _on_slot_dropped(data: Dictionary, target_slot: InventorySlotUI):
    print("ContainerUI: Slot dropped: %s -> %s" % [data["item"].content.name if data["item"].content else "Unknown", target_slot.grid_position])
    slot_dropped.emit(data, target_slot)

func _on_close_button_pressed():
    container_closed.emit()
    hide()

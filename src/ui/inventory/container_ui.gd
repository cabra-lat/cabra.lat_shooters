# ui/inventory/container_ui.gd
class_name ContainerUI
extends Container

signal item_drag_started(item: InventoryItem, source: InventoryContainer)
signal slot_clicked(container: InventoryContainer, position: Vector2i)
signal container_closed()

@onready var foldable_panel: FoldableContainer = %Panel
@onready var grid_container: GridContainer = %GridContainer
@onready var close_button: Button = %CloseButton

var current_container: InventoryContainer = null

func _ready():
    close_button.pressed.connect(_on_close_button_pressed)

func open_container(container: InventoryContainer):
    current_container = container
    foldable_panel.title = container.name
    _setup_grid()
    _update_ui()
    show()

func _setup_grid():
    # Clear old slots
    for child in grid_container.get_children():
        grid_container.remove_child(child)
        child.queue_free()

    # Create new slots
    grid_container.columns = current_container.grid_width
    for y in range(current_container.grid_height):
        for x in range(current_container.grid_width):
            var slot = preload("inventory_ui_slot.tscn").instantiate()
            slot.slot_name = "Slot%d_%d" % [x, y]
            slot.gui_input.connect(_on_slot_gui_input.bind(slot, Vector2i(x, y)))
            grid_container.add_child(slot)

func _update_ui():
    if not current_container:
        return

    # Clear all icons
    for slot_node in grid_container.get_children():
        slot_node.clear()

    # Populate items
    for item in current_container.items:
        var index = item.position.y * current_container.grid_width + item.position.x
        if index < grid_container.get_child_count():
            var slot = grid_container.get_child(index)
            slot.item_icon = item.content.icon if item.content.icon else \
                preload("../../../assets/ui/inventory/placeholder.png")

func _on_slot_gui_input(event: InputEvent, slot: InventoryUISlot, position: Vector2i):
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if current_container:
            slot_clicked.emit(current_container, position)

func _on_close_button_pressed():
    container_closed.emit()
    hide()

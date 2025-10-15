# ui/inventory/container_ui.gd
class_name ContainerUI
extends PanelContainer

signal item_drag_started(item: InventoryItem, source_container: InventoryContainer)
signal slot_clicked(container: InventoryContainer, position: Vector2i)
signal container_closed()

@onready var grid_container: GridContainer = %GridContainer
@onready var foldable_panel: FoldableContainer = %Control
@onready var close_button: Button = %CloseButton

var current_container: InventoryContainer = null
var is_folded: bool = false

func _ready():
  close_button.pressed.connect(_on_close_button_pressed)

# Open UI for ANY container
func open_container(container: InventoryContainer):
  current_container = container
  foldable_panel.title = container.name
  _setup_grid()
  _update_ui()
  show()

func _setup_grid():
  # Clear existing children
  for child in grid_container.get_children():
    grid_container.remove_child(child)
    child.queue_free()

  # Create slots based on container size
  for y in range(current_container.grid_height):
    for x in range(current_container.grid_width):
      var slot = Panel.new()
      slot.name = "Slot%d_%d" % [x, y]
      slot.mouse_filter = Control.MOUSE_FILTER_STOP
      slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
      slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
      slot.gui_input.connect(_on_slot_gui_input.bind(slot, Vector2i(x, y)))
      grid_container.add_child(slot)

  grid_container.columns = current_container.grid_width

func _update_ui():
  if not current_container:
    return

  # Clear item icons
  for slot in grid_container.get_children():
    if slot.get_child_count() > 0:
      var icon = slot.get_child(0)
      slot.remove_child(icon)
      icon.queue_free()

  # Populate items
  for item in current_container.items:
    var icon = _create_item_icon(item)
    var slot_index = item.position.y * current_container.grid_width + item.position.x
    if slot_index < grid_container.get_child_count():
      grid_container.get_child(slot_index).add_child(icon)

func _create_item_icon(item: InventoryItem) -> TextureRect:
  var icon = TextureRect.new()
  icon.texture = item.content.icon if item.content.icon else preload("../../../assets/ui/inventory/placeholder.png")
  icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  icon.custom_minimum_size = Vector2(48, 48)
  icon.mouse_filter = Control.MOUSE_FILTER_STOP
  icon.gui_input.connect(_on_item_icon_gui_input.bind(icon, item))
  return icon

func _on_item_icon_gui_input(event: InputEvent, icon: TextureRect, item: InventoryItem):
  if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
    # Start drag (handled by PlayerController)
    item_drag_started.emit(item, current_container)
    icon.hide()

func _on_slot_gui_input(event: InputEvent, slot: Panel, position: Vector2i):
  if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
    slot_clicked.emit(current_container, position)

func _on_close_button_pressed():
  container_closed.emit()
  hide()

# src/ui/inventory/container_ui.gd (UPDATED)
class_name ContainerUI
extends Container

signal slot_dropped(data: Dictionary, target_slot: InventoryUISlot)
signal container_closed()

@onready var foldable_panel: FoldableContainer = $Panel
@onready var grid_container: GridContainer = $Panel/Items
@onready var close_button: Button = %CloseButton

var current_container: InventoryContainer = null
var drag_preview: Control = null
var invalid_drop_positions: Array[Vector2i] = []

func _ready():
	close_button.pressed.connect(_on_close_button_pressed)

func open_container(container: InventoryContainer):
	current_container = container
	foldable_panel.title = container.name
	_setup_grid()
	_update_ui()
	show()

func _setup_grid():
	for child in grid_container.get_children():
		grid_container.remove_child(child)
		child.queue_free()
	
	grid_container.columns = current_container.grid_width
	for y in range(current_container.grid_height):
		for x in range(current_container.grid_width):
			var slot = preload("slot.tscn").instantiate()
			slot.grid_position = Vector2i(x, y)
			slot.name = "Slot[%d,%d]" % [x, y]
			slot.mouse_entered.connect(_on_slot_mouse_entered.bind(slot))
			slot.mouse_exited.connect(_on_slot_mouse_exited.bind(slot))
			grid_container.add_child(slot)

func _update_ui():
	if not current_container:
		return
	
	# Clear all slots first
	for slot in grid_container.get_children():
		if slot is InventoryUISlot:
			slot.clear()
			slot.set_occupied(false)
	
	# Mark occupied slots and set main item slots
	for item in current_container.items:
		# Set the main slot (top-left corner)
		var main_slot_index = item.position.y * current_container.grid_width + item.position.x
		if main_slot_index < grid_container.get_child_count():
			var main_slot = grid_container.get_child(main_slot_index)
			if main_slot is InventoryUISlot:
				main_slot.icon.texture = item.content.icon if item.content and item.content.icon else \
					preload("../../../assets/ui/inventory/placeholder.png")
				main_slot.associated_item = item
				main_slot.source_container = current_container
				main_slot.is_main_slot = true
				main_slot.item_dimensions = item.dimensions
				main_slot.connect("slot_dropped", _on_slot_dropped)
		
		# Mark all occupied slots
		for y in range(item.dimensions.y):
			for x in range(item.dimensions.x):
				var slot_pos = Vector2i(item.position.x + x, item.position.y + y)
				var slot_index = slot_pos.y * current_container.grid_width + slot_pos.x
				if slot_index < grid_container.get_child_count():
					var slot = grid_container.get_child(slot_index)
					if slot is InventoryUISlot:
						slot.set_occupied(true)
						if slot_pos != item.position: # Not the main slot
							slot.modulate = Color(1, 1, 1, 0.3) # Visual indication of occupied but not main

func _on_slot_mouse_entered(slot: InventoryUISlot):
	if drag_preview and drag_preview.visible:
		# Check if item can be placed here
		var drag_data = drag_preview.get_meta("drag_data")
		if drag_data and drag_data.has("item"):
			var item = drag_data["item"]
			var can_place = current_container.grid.can_add_item(item, slot.grid_position)
			
			if can_place:
				drag_preview.modulate = Color(1, 1, 1, 0.7) # Valid drop
			else:
				drag_preview.modulate = Color(1, 0, 0, 0.7) # Invalid drop (red)

func _on_slot_mouse_exited(slot: InventoryUISlot):
	if drag_preview:
		drag_preview.modulate = Color(1, 1, 1, 0.7)

func _create_drag_preview(item: InventoryItem) -> Control:
	var preview = Control.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var texture_rect = TextureRect.new()
	texture_rect.texture = item.content.icon if item.content and item.content.icon else \
		preload("../../../assets/ui/inventory/placeholder.png")
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.size = Vector2(50, 50) * Vector2(item.dimensions)
	texture_rect.modulate = Color(1, 1, 1, 0.7)
	
	preview.add_child(texture_rect)
	preview.size = texture_rect.size
	preview.set_meta("drag_data", {"item": item, "source": current_container})
	
	return preview

func _on_slot_dropped(data: Dictionary, target_slot: InventoryUISlot):
	slot_dropped.emit(data, target_slot)

func _on_close_button_pressed():
	container_closed.emit()
	hide()

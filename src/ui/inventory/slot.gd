# src/ui/inventory/inventory_ui_slot.gd (UPDATED)
class_name InventoryUISlot
extends Panel

signal slot_dropped(data: Dictionary, target_slot: InventoryUISlot)

@onready var icon: TextureRect = %Icon
@onready var label: Label = %Label
@export var grid_position: Vector2i = Vector2i(-1,-1)

var associated_item: InventoryItem = null
var source_container: Resource = null
var is_main_slot: bool = false
var is_occupied: bool = false
var item_dimensions: Vector2i = Vector2i.ONE

func _ready():
	custom_minimum_size = Vector2(50, 50)

func clear():
	if icon: 
		icon.texture = null
		icon.custom_minimum_size = Vector2(50, 50)
		icon.size = Vector2(50, 50)
	if label: 
		label.text = ""
	associated_item = null
	source_container = null
	is_main_slot = false
	is_occupied = false
	item_dimensions = Vector2i.ONE
	modulate = Color(1, 1, 1, 1)

func set_occupied(occupied: bool):
	is_occupied = occupied
	if occupied and not is_main_slot:
		# Visual styling for occupied (but not main) slots
		self_modulate = Color(0.5, 0.5, 0.5, 0.5)
	else:
		self_modulate = Color(1, 1, 1, 1)

func _get_drag_data(at_position: Vector2) -> Variant:
	if not associated_item or not is_main_slot:
		return null
	
	var preview = TextureRect.new()
	preview.texture = icon.texture if icon.texture else \
		preload("../../../assets/ui/inventory/placeholder.png")
	preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Scale preview to match item dimensions
	var slot_size = 50
	preview.custom_minimum_size = Vector2(slot_size, slot_size) * Vector2(associated_item.dimensions)
	preview.size = Vector2(slot_size, slot_size) * Vector2(associated_item.dimensions)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var control = Control.new()
	control.add_child(preview)
	control.size = preview.size
	preview.position = -0.5 * preview.size
	
	set_drag_preview(control)
	
	return {
		"item": associated_item,
		"source": source_container
	}

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not data.has("item"):
		return false
	
	# Don't allow dropping on occupied slots (unless it's the same item's main slot)
	if is_occupied:
		if is_main_slot and associated_item == data["item"]:
			return true # Allow reordering the same item
		return false
	
	return true

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.has("item"):
		slot_dropped.emit(data, self)

func get_parent_container() -> ContainerUI:
	var parent = get_parent()
	while parent and not parent is ContainerUI:
		parent = parent.get_parent()
	return parent as ContainerUI

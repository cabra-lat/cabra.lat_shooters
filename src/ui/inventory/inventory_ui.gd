# ui/inventory/inventory_ui.gd
class_name InventoryUI
extends PanelContainer

# ─── NODE REFERENCES ───────────────────────────────
@onready var equipment_panel: FoldableContainer = %EquipmentPanel
@onready var helmet_slot: Panel = %HelmetSlot
@onready var vest_slot: Panel = %VestSlot
@onready var primary_weapon_slot: Panel = %PrimaryWeaponSlot
@onready var secondary_weapon_slot: Panel = %SecondaryWeaponSlot

@onready var container_panel: FoldableContainer = %ContainerPanel
@onready var item_grid: GridContainer = %ItemGrid

@onready var close_button: Button = %CloseButton

# ─── STATE ─────────────────────────────────────────
var player_controller: PlayerController
var current_container: InventoryContainer = null
var current_drag_item: InventoryItem = null
var drag_source: Resource = null  # PlayerBody or InventoryContainer

# ─── INIT ──────────────────────────────────────────
func _ready():
  close_button.pressed.connect(_on_close_button_pressed)
  _setup_equipment_slots()

# ─── PUBLIC METHODS ────────────────────────────────
func open_inventory(player: PlayerController, container: InventoryContainer = null):
  player_controller = player
  current_container = container
  _update_ui()
  show()

func close_inventory():
  hide()

# ─── UI SETUP ──────────────────────────────────────
func _setup_equipment_slots():
  helmet_slot.gui_input.connect(_on_equipment_slot_input.bind(helmet_slot, "head"))
  vest_slot.gui_input.connect(_on_equipment_slot_input.bind(vest_slot, "torso"))
  primary_weapon_slot.gui_input.connect(_on_equipment_slot_input.bind(primary_weapon_slot, "primary"))
  secondary_weapon_slot.gui_input.connect(_on_equipment_slot_input.bind(secondary_weapon_slot, "secondary"))

func _setup_container_grid():
  # Clear existing children
  for child in item_grid.get_children():
    item_grid.remove_child(child)
    child.queue_free()

  if not current_container:
    container_panel.hide()
    return

  container_panel.show()
  container_panel.title = current_container.name
  item_grid.columns = current_container.grid_width

  # Create slots
  for y in range(current_container.grid_height):
    for x in range(current_container.grid_width):
      var slot = Panel.new()
      slot.mouse_filter = Control.MOUSE_FILTER_STOP
      slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
      slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
      slot.gui_input.connect(_on_container_slot_input.bind(slot, Vector2i(x, y)))
      item_grid.add_child(slot)

# ─── UPDATE UI ─────────────────────────────────────
func _update_ui():
  _setup_container_grid()
  _update_equipment_slots()
  _update_container_items()

func _update_equipment_slots():
  _update_equipment_slot(helmet_slot, "head")
  _update_equipment_slot(vest_slot, "torso")
  _update_equipment_slot(primary_weapon_slot, "primary")
  _update_equipment_slot(secondary_weapon_slot, "secondary")

func _update_equipment_slot(panel: Panel, slot_name: String):
  # Clear existing icon
  if panel.get_child_count() > 0:
    panel.get_child(0).queue_free()

  # Add new icon
  var equipped = player_controller.player_body.get_equipped(slot_name)
  if not equipped.is_empty():
    var icon = _create_item_icon(equipped[0])
    panel.add_child(icon)

func _update_container_items():
  if not current_container:
    return

  # Clear item icons (keep slots)
  for slot in item_grid.get_children():
    if slot.get_child_count() > 0:
      slot.get_child(0).queue_free()

  # Add items
  for item in current_container.items:
    var icon = _create_item_icon(item)
    var index = item.position.y * current_container.grid_width + item.position.x
    if index < item_grid.get_child_count():
      item_grid.get_child(index).add_child(icon)

# ─── ITEM ICON ─────────────────────────────────────
func _create_item_icon(item: InventoryItem) -> TextureRect:
  var icon = TextureRect.new()
  icon.texture = item.content.icon if item.content.icon else preload("../../../assets/ui/inventory/placeholder.png")
  icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  icon.custom_minimum_size = Vector2(48, 48)
  icon.mouse_filter = Control.MOUSE_FILTER_STOP
  icon.gui_input.connect(_on_item_icon_input.bind(icon, item))
  return icon

# ─── DRAG & DROP ───────────────────────────────────
func _on_item_icon_input(event: InputEvent, icon: TextureRect, item: InventoryItem):
  if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
    # Determine source
    if player_controller.player_body.get_equipped("head").has(item) or \
       player_controller.player_body.get_equipped("torso").has(item) or \
       player_controller.player_body.get_equipped("primary").has(item) or \
       player_controller.player_body.get_equipped("secondary").has(item):
      drag_source = player_controller.player_body
    else:
      drag_source = current_container
    current_drag_item = item
    icon.hide()

func _on_equipment_slot_input(event: InputEvent, slot: Panel, slot_name: String):
  if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
    if current_drag_item:
      _handle_equip_drop(current_drag_item, slot_name)
      current_drag_item = null

func _on_container_slot_input(event: InputEvent, slot: Panel, position: Vector2i):
  if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
    if current_drag_item:
      _handle_container_drop(current_drag_item, position)
      current_drag_item = null

# ─── DROP HANDLERS ─────────────────────────────────
func _handle_equip_drop(item: InventoryItem, slot_name: String):
  if drag_source is PlayerBody:
    # Unequip from old slot → equip to new slot
    pass  # Simplified: assume same slot
  else:
    # Transfer from container to body
    if InventorySystem.equip_item(drag_source, player_controller.player_body, item, slot_name):
      _update_ui()

func _handle_container_drop(item: InventoryItem, position: Vector2i):
  if drag_source is PlayerBody:
    # Unequip from body → put in container
    var old_slot = _get_body_slot_for_item(item)
    if old_slot:
      if InventorySystem.unequip_item(player_controller.player_body, current_container, item, old_slot):
        _update_ui()
  else:
    # Move within container or from another container
    if InventorySystem.transfer_item(drag_source, current_container, item):
      _update_ui()

# ─── HELPERS ───────────────────────────────────────
func _get_body_slot_for_item(item: InventoryItem) -> String:
  for slot_name in ["head", "torso", "primary", "secondary"]:
    if player_controller.player_body.get_equipped(slot_name).has(item):
      return slot_name
  return ""

func _on_close_button_pressed():
  close_inventory()

class_name EquipmentUI
extends BaseInventoryUI

signal equipment_updated()
signal equipment_slot_dropped(data: Dictionary, target_slot: EquipmentSlotUI)

@onready var tab_container: TabContainer = $Equipment/TabContainer

var player_controller: PlayerController
var equipment_config: EquipmentConfig
var slot_ui_map: Dictionary = {}  # slot_name -> EquipmentSlotUI
var layer_ui_map: Dictionary = {}  # layer_name -> Control

func _ready():
    super._ready()
    _setup_common_connections()

func _setup_common_connections():
    # We'll set up connections when we map the existing slots
    pass

func setup_player(player: PlayerController):
    player_controller = player
    if player and player.equipment:
        # Use the player's equipment config
        equipment_config = player.equipment.equipment_config
        current_inventory_source = player.equipment

        # Map existing slots from the scene
        _map_existing_slots()
        _update_ui()

func _map_existing_slots():
    slot_displays = []
    slot_ui_map = {}

    if not equipment_config:
        push_error("EquipmentUI: No equipment config available")
        return

    # Clear any dynamically created slots first
    _clear_dynamic_slots()

    # Map slots from each layer in the tab container
    for tab_index in tab_container.get_tab_count():
        var layer_control = tab_container.get_tab_control(tab_index)
        var layer_name = tab_container.get_tab_title(tab_index).to_lower()

        if layer_control:
            _map_slots_in_layer(layer_control, layer_name)

func _clear_dynamic_slots():
    # Remove any dynamically created slots (from previous runs)
    for slot in slot_displays:
        if slot and slot.get_parent() and "GridContainer" in slot.get_parent().name:
            slot.get_parent().remove_child(slot)
            slot.queue_free()

    slot_displays.clear()
    slot_ui_map.clear()

func _map_slots_in_layer(layer_control: Control, layer_name: String):
    # Find all EquipmentSlotUI nodes in this layer
    var slots = _find_equipment_slots(layer_control)

    for slot_ui in slots:
        var slot_name = slot_ui.name.to_lower()
        var slot_def = equipment_config.get_slot_definition(slot_name)

        if slot_def:
            _configure_existing_slot(slot_ui, slot_def)
            slot_ui_map[slot_name] = slot_ui
            slot_displays.append(slot_ui)

            # Connect signals if not already connected
            if not slot_ui.slot_dropped.is_connected(_on_equipment_slot_dropped):
                slot_ui.slot_dropped.connect(_on_equipment_slot_dropped)
            if not slot_ui.drag_started.is_connected(_on_drag_started):
                slot_ui.drag_started.connect(_on_drag_started)
            if not slot_ui.drag_ended.is_connected(_on_drag_ended):
                slot_ui.drag_ended.connect(_on_drag_ended)
        else:
            push_warning("EquipmentUI: No slot definition found for '%s'" % slot_name)

func _find_equipment_slots(node: Node) -> Array[EquipmentSlotUI]:
    var slots: Array[EquipmentSlotUI] = []

    # Check if this node is an EquipmentSlotUI
    if node is EquipmentSlotUI:
        slots.append(node)

    # Recursively check children
    for child in node.get_children():
        slots.append_array(_find_equipment_slots(child))

    return slots

func _configure_existing_slot(slot_ui: EquipmentSlotUI, slot_def: EquipmentSlotDefinition):
    # Configure the existing slot with definition data
    slot_ui.slot_name = slot_def.slot_name
    slot_ui.display_name = slot_def.display_name
    slot_ui.allowed_item_types = slot_def.allowed_item_types
    slot_ui.allowed_categories = slot_def.allowed_categories

    # Set tooltip
    slot_ui.tooltip_text = slot_def.display_name

    # Apply size from theme if available
    if theme and theme.equipment_slot_sizes.has(slot_def.slot_size):
        var size = theme.equipment_slot_sizes[slot_def.slot_size]
        slot_ui.custom_minimum_size = size

func _get_display_items() -> Array[InventoryItem]:
    var items: Array[InventoryItem] = []
    if player_controller and player_controller.equipment:
        items = player_controller.equipment.get_all_equipped_items()
    return items

func _add_item_display_to_scene(display: InventoryItemUI):
    # Equipment doesn't use floating item displays
    display.queue_free()

func _position_item_display(display: InventoryItemUI, item: InventoryItem):
    # Not used for equipment
    pass

func _update_slot_states():
    # Update all equipment slots based on current equipment
    for slot_name in slot_ui_map:
        _update_equipment_slot(slot_ui_map[slot_name], slot_name)

func _update_equipment_slot(slot: EquipmentSlotUI, slot_name: String):
    if not slot:
        return

    slot.clear()
    if player_controller and player_controller.equipment:
        var equipped = player_controller.equipment.get_equipped(slot_name)
        if not equipped.is_empty():
            var item = equipped[0]
            if slot.icon:
                slot.icon.texture = item.content.icon
                slot.icon.visible = true
            slot.associated_item = item
            slot.source_container = player_controller.equipment

            # Set rarity if applicable
            if item.content.has_method("get_rarity"):
                slot.set_rarity(item.content.get_rarity())

func _on_equipment_slot_dropped(data: Dictionary, target_slot: EquipmentSlotUI):
    equipment_slot_dropped.emit(data, target_slot)

func handle_equipment_drop(data: Dictionary, target_slot: EquipmentSlotUI) -> bool:
    var slot_name = target_slot.slot_name
    var item = data["item"]
    var source = data["source"]

    var success = false

    if target_slot._is_item_compatible(item):
        if Inventory.transfer_item(source, player_controller.equipment, item, slot_name):
            success = true

    if success:
        _update_ui()
        equipment_updated.emit()

    return success

# Utility method to get a slot by name
func get_slot_by_name(slot_name: String) -> EquipmentSlotUI:
    return slot_ui_map.get(slot_name)

# Method to show/hide specific layers
func set_layer_visible(layer_name: String, visible: bool):
    for tab_index in tab_container.get_tab_count():
        var tab_title = tab_container.get_tab_title(tab_index).to_lower()
        if tab_title == layer_name.to_lower():
            tab_container.set_tab_hidden(tab_index, not visible)
            break

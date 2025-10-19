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
    # Don't create empty config here - wait for player setup
    _setup_common_connections()

func setup_player(player: PlayerController):
    player_controller = player
    if player and player.equipment:
        # Use the player's equipment config
        equipment_config = player.equipment.equipment_config
        current_inventory_source = player.equipment
        _initialize_layers()
        _setup_slots()
        _update_ui()

func _initialize_layers():
    if not equipment_config:
        push_error("EquipmentUI: No equipment config available")
        return

    # Sort layers by order
    var sorted_layers = equipment_config.layer_definitions.duplicate()
    sorted_layers.sort_custom(func(a, b): return a.layer_order < b.layer_order)

    # Clear existing tabs
    for child in tab_container.get_children():
        tab_container.remove_child(child)
        child.queue_free()
    layer_ui_map.clear()

    # Create tabs for each layer
    for layer_def in sorted_layers:
        var layer_ui = _create_layer_ui(layer_def)
        tab_container.add_child(layer_ui)
        layer_ui_map[layer_def.layer_name] = layer_ui
        tab_container.set_tab_title(tab_container.get_tab_count() - 1, layer_def.display_name)

func _create_layer_ui(layer_def: EquipmentLayerDefinition) -> Control:
    var layer_container = ScrollContainer.new()
    layer_container.name = layer_def.layer_name.capitalize()

    var grid_container = GridContainer.new()
    grid_container.columns = 3
    grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    layer_container.add_child(grid_container)

    return layer_container

func _setup_slots():
    slot_displays = []
    slot_ui_map = {}

    if not equipment_config:
        push_error("EquipmentUI: No equipment config available for slot setup")
        return

    # Create slots based on configuration
    for slot_def in equipment_config.slot_definitions:
        var slot_ui = _create_equipment_slot(slot_def)
        if slot_ui:
            slot_ui_map[slot_def.slot_name] = slot_ui
            slot_displays.append(slot_ui)

            # Add to appropriate layer
            var layer_ui = layer_ui_map.get(slot_def.layer)
            if layer_ui and layer_ui.get_child(0) is GridContainer:
                layer_ui.get_child(0).add_child(slot_ui)

func _create_equipment_slot(slot_def: EquipmentSlotDefinition) -> EquipmentSlotUI:
    var slot_scene = load("res://addons/cabra.lat_shooters/src/ui/inventory/equipment_slot.tscn")
    var slot_ui = slot_scene.instantiate() as EquipmentSlotUI

    slot_ui.slot_name = slot_def.slot_name
    slot_ui.display_name = slot_def.display_name
    slot_ui.allowed_item_types = slot_def.allowed_item_types
    slot_ui.allowed_categories = slot_def.allowed_categories

    # Set size based on configuration
    var size_key = slot_def.slot_size
    if theme.equipment_slot_sizes.has(size_key):
        slot_ui.custom_minimum_size = theme.equipment_slot_sizes[size_key]

    # Connect signals
    if not slot_ui.slot_dropped.is_connected(_on_equipment_slot_dropped):
        slot_ui.slot_dropped.connect(_on_equipment_slot_dropped)
    if not slot_ui.drag_started.is_connected(_on_drag_started):
        slot_ui.drag_started.connect(_on_drag_started)
    if not slot_ui.drag_ended.is_connected(_on_drag_ended):
        slot_ui.drag_ended.connect(_on_drag_ended)

    return slot_ui

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
    # Update all equipment slots
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
            slot.icon.texture = item.content.icon
            slot.associated_item = item
            slot.source_container = player_controller.equipment
            slot.icon.visible = true

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

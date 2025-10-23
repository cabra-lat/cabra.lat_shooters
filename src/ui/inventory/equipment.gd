# src/ui/inventory/equipment.gd
# src/ui/inventory/equipment.gd
class_name EquipmentUI
extends BaseInventoryUI

signal equipment_updated()
signal equipment_slot_dropped(data: Dictionary, target_slot: EquipmentSlotUI)

@onready var slots_container: Control = $Equipment/TabContainer

var player_controller: PlayerController
var slots: Dictionary = {}

func setup_player(player: PlayerController):
    # Disconnect from previous equipment
    if player_controller and player_controller.equipment:
        player_controller.equipment.equipped.disconnect(_on_equipment_changed)
        player_controller.equipment.unequiped.disconnect(_on_equipment_changed)
        player_controller.equipment.container_changed.disconnect(_update_ui)

    player_controller = player
    if player and player.equipment:
        current_inventory_source = player.equipment

        # Connect to equipment signals
        player.equipment.equipped.connect(_on_equipment_changed)
        player.equipment.unequiped.connect(_on_equipment_changed)
        player.equipment.container_changed.connect(_update_ui)
        _update_ui()

func _on_equipment_changed(item: InventoryItem, slot_name: String):
    print("Equipment changed: %s in %s" % [item.name if item else "None", slot_name])
    _update_equipment_slot(slot_name)

func _update_ui():
    # Still do full update initially, but incremental updates will use signals
    for slot_name in slots:
        _update_equipment_slot(slot_name)

func _ready():
    super._ready()
    _initialize_slots_dict()
    _setup_slots()

func _initialize_slots_dict():
    slots["helmet"] = slots_container.get_node("Front/helmet") as EquipmentSlotUI
    slots["vest"] = slots_container.get_node("Front/vest") as EquipmentSlotUI
    slots["back"] = slots_container.get_node("Back/back") as EquipmentSlotUI
    slots["primary"] = slots_container.get_node("Loadout/primary") as EquipmentSlotUI
    slots["secondary"] = slots_container.get_node("Loadout/secondary") as EquipmentSlotUI

    # Set slot types
    for slot_name in slots:
        if slots[slot_name]:
            slots[slot_name].slot_type = slot_name

func _setup_slots():
    # Equipment slots are pre-defined in the scene
    slot_displays = []
    for slot_name in slots:
        if slots[slot_name]:
            slot_displays.append(slots[slot_name])
            slots[slot_name].setup(self)

            # Connect signals
            if not slots[slot_name].slot_dropped.is_connected(_on_equipment_slot_dropped):
                slots[slot_name].slot_dropped.connect(_on_equipment_slot_dropped)
            if not slots[slot_name].drag_started.is_connected(_on_drag_started):
                slots[slot_name].drag_started.connect(_on_drag_started)
            if not slots[slot_name].drag_ended.is_connected(_on_drag_ended):
                slots[slot_name].drag_ended.connect(_on_drag_ended)

func _get_display_items() -> Array[InventoryItem]:
    var items: Array[InventoryItem] = []
    if player_controller and player_controller.equipment:
        for slot_name in slots:
            var equipped = player_controller.equipment.get_equipped(slot_name)
            if not equipped.is_empty():
                items.append(equipped[0])
    return items

func _add_item_display_to_scene(display: InventoryItemUI):
    # Equipment doesn't use floating item displays - items are shown in slot icons
    # Just queue_free since we don't need it
    display.queue_free()

func _position_item_display(display: InventoryItemUI, item: InventoryItem):
    # Not used for equipment
    pass

func _update_slot_states():
    # Update slot icons and associated items
    for slot_name in slots:
        _update_equipment_slot(slot_name)

func _update_equipment_slot(slot_name: String):
    var slot = slots.get(slot_name)
    if not slot: return
    slot.clear()
    if player_controller and player_controller.equipment:
        var equipped = player_controller.equipment.get_equipped(slot_name)
        if not equipped.is_empty():
            slot.icon.texture = equipped[0].icon
            slot.associated_item = equipped[0]
            slot.source_container = player_controller.equipment
            slot.icon.visible = true

func _on_equipment_slot_dropped(data: Dictionary, target_slot: EquipmentSlotUI):
    print("EquipmentUI: Slot dropped: %s -> %s" % [
        data["item"].name if data["item"] else "Unknown",
        target_slot.slot_type
    ])
    equipment_slot_dropped.emit(data, target_slot)

func handle_equipment_drop(data: Dictionary, target_slot: EquipmentSlotUI) -> bool:
    var slot_name = target_slot.slot_type
    var item = data["item"]
    var source = data["source"]

    print("Equipment drop attempt: %s -> %s" % [
        item.name if item else "Unknown",
        slot_name
    ])

    var success = false

    if target_slot._is_item_compatible(item):
        print("Attempting to equip item in %s" % slot_name)
        if InventorySystem.transfer_item(source, player_controller.equipment, item):
            print("Item equipped successfully")
            success = true
        else:
            print("Failed to equip item")
    else:
        print("Item not compatible with equipment slot")

    if success:
        _update_ui()
        equipment_updated.emit()

    return success

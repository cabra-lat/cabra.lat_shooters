# src/ui/inventory/inventory_ui.gd
class_name InventoryUI
extends PanelContainer

@onready var equipment_slots: Array[InventoryUISlot] = [
    %Equipment/helmet, %Equipment/vest, %Equipment/back, %Equipment/primary, %Equipment/secondary
]
@onready var containers_vbox: VBoxContainer = %VBoxContainer

var player_controller: PlayerController
var open_containers: Array[ContainerUI] = []

func open_inventory(player: PlayerController, container: InventoryContainer = null):
    player_controller = player
    _update_equipment()
    var backpack = _get_backpack()
    if backpack: _open_container_once(backpack)
    if container: _open_container_once(container)
    show()

func _update_equipment():
    for slot in equipment_slots:
        _update_slot(slot)

func _update_slot(slot: InventoryUISlot):
    var equipped = player_controller.player_body.get_equipped(slot.name)
    slot.associated_item = equipped[0] if not equipped.is_empty() else null
    slot.source_container = player_controller.player_body
    slot.item_icon = equipped[0].content.icon if not equipped.is_empty() else null

func _get_backpack() -> Backpack:
    var equipped = player_controller.player_body.get_equipped("back")
    return equipped[0].content as Backpack if not equipped.is_empty() else null

func _open_container_once(container: InventoryContainer):
    for ui in open_containers:
        if ui.current_container == container:
            return
    var container_ui = preload("container_ui.tscn").instantiate()
    containers_vbox.add_child(container_ui)
    open_containers.append(container_ui)
    container_ui.open_container(container)

# ─── DROP HANDLER ──────────────────────────────────

func _on_item_dropped(data: Dictionary, target_slot: InventoryUISlot, target_container: InventoryContainer):
    var parent = target_slot.get_parent()
    var success = false

    # Equipment slot
    if parent == %EquipmentPanel.find_child("PanelContainer"):
        var slot_name = target_slot.name
        if slot_name == "back" and data["item"].content is Backpack:
            success = InventorySystem.transfer_item(data["source"], player_controller.player_body, data["item"])
            if success:
                var backpack = _get_backpack()
                if backpack: _open_container_once(backpack)
        elif slot_name == "back":
            var backpack = _get_backpack()
            if backpack:
                success = InventorySystem.transfer_item(data["source"], backpack, data["item"])
        else:
            success = InventorySystem.transfer_item(data["source"], player_controller.player_body, data["item"])

    # Grid container
    else:
        success = InventorySystem.transfer_item(data["source"], target_container, data["item"])

    if success:
        _update_equipment()
        for ui in open_containers:
            ui._update_ui()

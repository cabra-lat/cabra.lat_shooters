# src/ui/inventory/inventory_ui.gd (UPDATED)
class_name InventoryUI
extends PanelContainer

@onready var equipment_panel: FoldableContainer = $InventoryUi/HB/EquipmentPanel
@onready var slots: Array[InventoryUISlot] = [
     equipment_panel.get_node("Equipment/helmet"),
     equipment_panel.get_node("Equipment/vest"),
     equipment_panel.get_node("Equipment/back"),
     equipment_panel.get_node("Equipment/primary"),
     equipment_panel.get_node("Equipment/secondary")
]
@onready var containers_vbox: VBoxContainer = $InventoryUi/HB/ScrollContainer/VB
@onready var close_button: Button = %CloseButton

var player_controller: PlayerController
var open_containers: Array[ContainerUI] = []

func _ready():
    _setup_equipment_slots()
    close_button.pressed.connect(_on_close_button_pressed)

func _setup_equipment_slots():
    for slot in slots:
        slot.connect("slot_dropped", _on_slot_dropped)

func open_inventory(player: PlayerController, container: InventoryContainer = null):
    player_controller = player
    _update_equipment()
    var equipped = player.player_body.get_equipped("back")
    var backpack = equipped[0].content as Backpack if not equipped.is_empty() else null
    if backpack:
        _open_container_once(backpack)
    if container:
        _open_container_once(container)
    show()

func _open_container_once(container: InventoryContainer):
    for ui in open_containers:
        if ui.current_container == container:
            return
    var container_ui = preload("container.tscn").instantiate()
    container_ui.connect("slot_dropped", _on_slot_dropped)
    container_ui.container_closed.connect(_on_container_closed.bind(container_ui))
    containers_vbox.add_child(container_ui)
    open_containers.append(container_ui)
    container_ui.open_container(container)

func _update_equipment():
     for slot in slots:
        _update_equipment_slot(slot, slot.name)

func _update_equipment_slot(slot: InventoryUISlot, slot_name: String):
    slot.clear()
    var equipped = player_controller.player_body.get_equipped(slot_name)
    if not equipped.is_empty():
        slot.icon.texture = equipped[0].content.icon if equipped[0].content and equipped[0].content.icon else \
            preload("../../../assets/ui/inventory/placeholder.png")
        slot.associated_item = equipped[0]
        slot.source_container = player_controller.player_body
        slot.is_main_slot = true
    else:
        slot.label.text = slot_name

func _on_slot_dropped(data: Dictionary, target_slot: InventoryUISlot):
    var parent = target_slot.get_parent()
    
    if target_slot in slots:
        # Equipment slot handling
        _handle_equipment_drop(data, target_slot)
    else:
        # Container slot handling
        _handle_container_drop(data, target_slot)

func _handle_equipment_drop(data: Dictionary, target_slot: InventoryUISlot):
    var slot_name = target_slot.name
    var item = data["item"]
    var source = data["source"]
    
    if slot_name == "back" and item.content is Backpack:
        if InventorySystem.transfer_item(source, player_controller.player_body, item):
            _update_equipment()
            _refresh_open_containers()
    elif slot_name == "back":
        var equipped = player_controller.player_body.get_equipped("back")
        if not equipped.is_empty():
            var backpack = equipped[0].content as Backpack
            if backpack and InventorySystem.transfer_item(source, backpack, item):
                _update_equipment()
                _refresh_open_containers()
    else:
        if InventorySystem.transfer_item(source, player_controller.player_body, item):
            _update_equipment()
            _refresh_open_containers()

func _handle_container_drop(data: Dictionary, target_slot: InventoryUISlot):
    var container_ui = target_slot.get_parent_container()
    if container_ui and container_ui.current_container:
        var pos = target_slot.grid_position
        if pos != Vector2i(-1, -1):
            # Try exact position first, then find any free space
            if InventorySystem.transfer_item_to_position(data["source"], container_ui.current_container, data["item"], pos) or \
               InventorySystem.transfer_item(data["source"], container_ui.current_container, data["item"]):
                _update_equipment()
                _refresh_open_containers()

func _refresh_open_containers():
    for ui in open_containers:
        ui._update_ui()

func _on_container_closed(container_ui: ContainerUI):
    if container_ui in open_containers:
        open_containers.erase(container_ui)
        containers_vbox.remove_child(container_ui)
        container_ui.queue_free()

func _on_close_button_pressed():
    hide()
    for ui in open_containers:
        ui.queue_free()
    open_containers.clear()
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

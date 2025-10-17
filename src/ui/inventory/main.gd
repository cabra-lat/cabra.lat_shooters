# src/ui/inventory/main.gd
class_name InventoryUI
extends PanelContainer

@onready var equipment_panel: FoldableContainer = $InventoryUi/HB/EquipmentPanel
@onready var slots: Array[InventorySlotUI] = [
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
var debug_label: Label

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

func _update_equipment_slot(slot: InventorySlotUI, slot_name: String):
    slot.clear()
    var equipped = player_controller.player_body.get_equipped(slot_name)
    if not equipped.is_empty():
        slot.icon.texture = equipped[0].content.icon if equipped[0].content and equipped[0].content.icon else \
            preload("../../../assets/ui/inventory/placeholder.png")
        slot.associated_item = equipped[0]
        slot.source_container = player_controller.player_body
        print("Equipment slot %s: %s" % [slot_name, equipped[0].content.name if equipped[0].content else "Unknown"])

# main.gd - UPDATED _on_slot_dropped method
func _on_slot_dropped(data: Dictionary, target_slot: InventorySlotUI):
    print("=== DROP EVENT START ===")
    print("Drop data: %s -> %s" % [data["item"].content.name if data["item"].content else "Unknown", target_slot.name])
    print("Source: %s" % data["source"])
    print("Target slot type: %s" % ("EQUIPMENT" if target_slot.grid_position == Vector2i(-1, -1) else "CONTAINER"))
    print("Target slot position: %s" % target_slot.grid_position)  # ADD THIS
    
    var parent = target_slot.get_parent()
    
    # Handle equipment slots (grid_position == (-1, -1))
    if target_slot.grid_position == Vector2i(-1, -1):
        print("Target is equipment slot: %s" % target_slot.name)
        _handle_equipment_drop(data, target_slot)
    else:
        print("Target is container slot: %s" % target_slot.grid_position)
        _handle_container_drop(data, target_slot)
    
    print("=== DROP EVENT END ===")

func _handle_equipment_drop(data: Dictionary, target_slot: InventorySlotUI):
    var slot_name = target_slot.name
    var item = data["item"]
    var source = data["source"]
    
    print("Equipment drop: %s -> %s" % [item.content.name if item.content else "Unknown", slot_name])
    
    # Special handling for backpack
    if slot_name == "back" and item.content is Backpack:
        print("Attempting to equip backpack")
        if InventorySystem.transfer_item(source, player_controller.player_body, item):
            print("Backpack equipped successfully")
            _update_equipment()
            _refresh_open_containers()
        else:
            print("Failed to equip backpack")
    elif slot_name == "back":
        # Try to put item in backpack
        var equipped = player_controller.player_body.get_equipped("back")
        if not equipped.is_empty():
            var backpack = equipped[0].content as Backpack
            if backpack and InventorySystem.transfer_item(source, backpack, item):
                print("Item transferred to backpack")
                _update_equipment()
                _refresh_open_containers()
            else:
                print("Failed to transfer item to backpack")
        else:
            print("No backpack equipped")
    else:
        # Regular equipment transfer
        print("Attempting to equip item in %s" % slot_name)
        if InventorySystem.transfer_item(source, player_controller.player_body, item):
            print("Item equipped successfully")
            _update_equipment()
            _refresh_open_containers()
        else:
            print("Failed to equip item")

# main.gd - UPDATE _handle_container_drop function
func _handle_container_drop(data: Dictionary, target_slot: InventorySlotUI):
    # FIXED: Use the direct container_ui reference instead of get_parent_container()
    var container_ui = target_slot.container_ui
    if container_ui and container_ui.current_container:
        var pos = target_slot.grid_position
        if pos != Vector2i(-1, -1):
            print("Attempting to transfer to container %s at position %s" % [container_ui.current_container.name, pos])
            if InventorySystem.transfer_item_to_position(data["source"], container_ui.current_container, data["item"], pos):
                print("Transfer successful")
                _update_equipment()
                _refresh_open_containers()
            else:
                print("Transfer failed")
        else:
            print("Invalid position")
    else:
        print("No container found for slot %s" % target_slot.grid_position)

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

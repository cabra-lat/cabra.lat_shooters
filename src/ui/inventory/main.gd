# src/ui/inventory/main.gd
class_name InventoryUI
extends Control

@onready var equipment_ui: EquipmentUI = $InventoryUi/HB/RS/VB/Equipment
@onready var world_drop_zone: WorldDropZone = $WorldDropZone
@onready var containers_vbox: VBoxContainer = $InventoryUi/HB/LS/VB
@onready var close_button: Button = %CloseButton

var player_controller: PlayerController
var open_containers: Array[InventoryContainerUI] = []
var current_drag_data: Dictionary = {}

func _ready():
    if equipment_ui:
        equipment_ui.equipment_slot_dropped.connect(_on_equipment_slot_dropped)
    close_button.pressed.connect(_on_close_button_pressed)
    if world_drop_zone:
        world_drop_zone.item_dropped.connect(_on_world_drop)

func open_inventory(player: PlayerController, container: InventoryContainer = null):
    player_controller = player
    if equipment_ui:
        equipment_ui.setup_player(player)

    # Open backpack if equipped
    var equipped = player.equipment.get_equipped("back")
    var backpack = equipped[0].extra as Backpack if not equipped.is_empty() else null
    if backpack:
        _open_container_once(backpack)

    # Open additional container if provided
    if container:
        _open_container_once(container)

    show()

func _handle_container_drop(data: Dictionary, target_slot: InventorySlotUI):
    var container_ui = target_slot.container_ui
    if container_ui and container_ui.current_inventory_source:
        var container = container_ui.current_inventory_source as InventoryContainer
        var pos = target_slot.grid_position

        # Let the core system handle the transfer and emit signals
        # The UI will update automatically via signal connections
        if InventorySystem.transfer_item_to_position(data["source"], container, data["item"], pos):
            print("Transfer successful")
            # Update ALL open containers, not just the target
            _update_all_open_containers()
        else:
            print("Transfer failed - both UIs should remain unchanged")

func _handle_equipment_drop(data: Dictionary, target_slot: EquipmentSlotUI):
    var slot_name = target_slot.slot_type
    var item = data["item"]
    var source = data["source"]

    print("Equipment drop attempt: %s -> %s" % [
        item.name if item else "Unknown",
        slot_name
    ])

    if target_slot._is_item_compatible(item):
        print("Attempting to equip item in %s" % slot_name)
        if InventorySystem.transfer_item(source, player_controller.equipment, item):
            print("Item equipped successfully")
            # Update all containers when equipment changes
            _update_all_open_containers()
        else:
            print("Failed to equip item")
    else:
        print("Item not compatible with equipment slot")

func _handle_world_drop(data: Dictionary):
    var item = data["item"]
    var source = data["source"]
    var removed = false

    if source is InventoryContainer:
        removed = source.remove_item(item)
    elif source is Equipment:
        for slot_name in source.slots:
            var slot = source.slots[slot_name]
            if item in slot.items:
                removed = slot.remove_item(item)
                break

    if removed:
        _create_world_item(item)
        # Update all containers when world drop happens
        _update_all_open_containers()

func _open_container_once(container: InventoryContainer):
    for ui in open_containers:
        if ui.current_inventory_source == container:
            return

    var container_ui_scene = preload("res://addons/cabra.lat_shooters/src/ui/inventory/container.tscn")
    var container_ui = container_ui_scene.instantiate() as InventoryContainerUI

    # Connect to the container's signals
    if container.has_signal("container_changed"):
        container.container_changed.connect(container_ui._update_ui)

    container_ui.slot_dropped.connect(_on_slot_dropped)
    container_ui.container_closed.connect(_on_container_closed.bind(container_ui))
    containers_vbox.add_child(container_ui)
    open_containers.append(container_ui)
    container_ui.open_container(container)

func _update_all_open_containers():
    # Update all open container UIs
    for container_ui in open_containers:
        container_ui._update_ui()

    # Update equipment UI
    if equipment_ui:
        equipment_ui._update_ui()

func _on_container_closed(container_ui: InventoryContainerUI):
    if container_ui in open_containers:
        # Disconnect from container signals
        if container_ui.current_inventory_source and container_ui.current_inventory_source.has_signal("container_changed"):
            container_ui.current_inventory_source.container_changed.disconnect(container_ui._update_ui)

        open_containers.erase(container_ui)
        containers_vbox.remove_child(container_ui)
        container_ui.queue_free()

func _on_equipment_slot_dropped(data: Dictionary, target_slot: EquipmentSlotUI):
    print("Main UI: Equipment slot drop received")
    _handle_equipment_drop(data, target_slot)

func _on_slot_dropped(data: Dictionary, target_slot: InventorySlotUI):
    print("=== DROP EVENT START ===")
    print("Drop data: %s -> %s" % [data["item"].name if data["item"] else "Unknown",
          target_slot.grid_position if target_slot.grid_position != Vector2i(-1, -1) else target_slot.name])
    print("Source: %s" % data["source"])

    # Store source for world drops
    if current_drag_data and current_drag_data.has("item"):
        current_drag_data["source"] = data["source"]

    # Equipment slots are now handled by EquipmentUI via separate signal
    if target_slot.grid_position == Vector2i(-1, -1):
        print("Target is equipment slot, handled by EquipmentUI")
    else:
        print("Target is container slot: %s" % target_slot.grid_position)
        _handle_container_drop(data, target_slot)

    print("=== DROP EVENT END ===")

func _on_world_drop(data: Dictionary):
    if data and data.has("item") and data.has("source"):
        _handle_world_drop(data)

func _on_drag_started(item: InventoryItem):
    current_drag_data = {"item": item}
    print("World drop zone activated")

func _on_drag_ended():
    current_drag_data = {}
    print("World drop zone deactivated")

func _create_world_item(item: InventoryItem):
    var world_item = WorldItem.spawn(player_controller, item)
    print("Created world item at position: %s" % world_item.global_position)

# World drop zone drag handling
func _get_drag_data_at_position(at_position: Vector2) -> Variant:
    # Forward drag data from the current drag
    if current_drag_data and current_drag_data.has("item"):
        return current_drag_data
    return null

func _on_close_button_pressed():
    hide()
    for ui in open_containers:
        ui.queue_free()
    open_containers.clear()
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

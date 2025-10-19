# src/ui/inventory/main.gd
class_name InventoryUI
extends Control

@onready var equipment_ui:    EquipmentUI   = $InventoryUi/HB/RS/VB/Equipment
@onready var world_drop_zone: WorldDropZone = $WorldDropZone
@onready var containers_vbox: VBoxContainer = $InventoryUi/HB/LS/VB
@onready var close_button: Button = %CloseButton

var player_controller: PlayerController
var open_containers: Array[InventoryContainerUI] = []
var current_drag_data: Dictionary = {}

func _ready():
    if equipment_ui:
        equipment_ui.equipment_slot_dropped.connect(_on_equipment_slot_dropped)
        equipment_ui.equipment_updated.connect(_refresh_open_containers)
    close_button.pressed.connect(_on_close_button_pressed)
    if world_drop_zone:
        world_drop_zone.item_dropped.connect(_on_world_drop)

func _on_equipment_slot_dropped(data: Dictionary, target_slot: EquipmentSlotUI):
    print("Main UI: Equipment slot drop received")
    if equipment_ui:
        equipment_ui.handle_equipment_drop(data, target_slot)

func open_inventory(player: PlayerController, container: InventoryContainer = null):
    player_controller = player
    if equipment_ui:
        equipment_ui.setup_player(player)

    # Open backpack if equipped
    var equipped = player.equipment.get_equipped("back")
    var backpack = equipped[0].content as Backpack if not equipped.is_empty() else null
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
        if pos != Vector2i(-1, -1):
            print("Attempting to transfer to container %s at position %s" % [container.name, pos])
            if InventorySystem.transfer_item_to_position(data["source"], container, data["item"], pos):
                print("Transfer successful")
                _refresh_open_containers()
            else:
                print("Transfer failed")
        else:
            print("Invalid position")
    else:
        print("No container found for slot %s" % target_slot.grid_position)

func _on_slot_dropped(data: Dictionary, target_slot: InventorySlotUI):
    print("=== DROP EVENT START ===")
    print("Drop data: %s -> %s" % [data["item"].content.name if data["item"].content else "Unknown",
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

func _handle_world_drop(data: Dictionary):
    print("=== WORLD DROP START ===")
    print("Dropping item in world: %s" % data["item"].content.name if data["item"].content else "Unknown")

    var item = data["item"]
    var source = data["source"]
    var removed = false

    if source is InventoryContainer:
        removed = source.remove_item(item)
        print("Removed from container: %s" % removed)
    elif source is Equipment:
        # Find which slot the item is in and remove it
        for slot_name in source.slots:
            var slot = source.slots[slot_name]
            if item in slot.items:
                removed = slot.remove_item(item)
                print("Removed from equipment slot %s: %s" % [slot_name, removed])
                break

    if removed:
        # Create world item - Use the original item, don't duplicate
        _create_world_item(item)
        print("World item created successfully")

        # Update UI
        if equipment_ui:
            equipment_ui._update_ui()
        _refresh_open_containers()
    else:
        print("Failed to remove item from source")

    print("=== WORLD DROP END ===")

func _create_world_item(item: InventoryItem):
    var world_item_scene = preload("res://addons/cabra.lat_shooters/src/gameplay/world_item.tscn")
    var world_item = world_item_scene.instantiate() as WorldItem
    # Set up the world item - Use the original item, don't duplicate
    world_item.inventory_item = item
    # Reset the item's position for the world - THIS IS THE CRITICAL FIX
    item.position = Vector2i.ZERO
    # Position the item in front of the player
    if player_controller and player_controller.equipment:
        var player_pos = player_controller.global_position
        var player_forward = -player_controller.global_transform.basis.z
        var drop_pos = player_pos + player_forward * 2.0 + Vector3(0, 1, 0)  # 2m in front, 1m up
        world_item.global_position = drop_pos
        # Add some random rotation
        world_item.rotate_y(randf() * PI * 2)
    # Add to scene
    get_tree().current_scene.add_child(world_item)
    print("Created world item at position: %s" % world_item.global_position)

# World drop zone drag handling
func _get_drag_data_at_position(at_position: Vector2) -> Variant:
    # Forward drag data from the current drag
    if current_drag_data and current_drag_data.has("item"):
        return current_drag_data
    return null

func _can_drop_data_at_position(at_position: Vector2, data: Variant) -> bool:
    # Always allow dropping in world when dragging outside inventory
    return data is Dictionary and data.has("item")

func _drop_data_at_position(at_position: Vector2, data: Variant) -> void:
    if data is Dictionary and data.has("item") and data.has("source"):
        print("=== WORLD DROP START ===")
        print("Dropping item in world: %s" % data["item"].content.name if data["item"].content else "Unknown")

        # Remove item from source
        var item = data["item"]
        var source = data["source"]
        var removed = false

        if source is InventoryContainer:
            removed = source.remove_item(item)
            print("Removed from container: %s" % removed)
        elif source is Equipment:
            # Find which slot the item is in and remove it
            for slot_name in source.slots:
                var slot = source.slots[slot_name]
                if item in slot.items:
                    removed = slot.remove_item(item)
                    print("Removed from equipment slot %s: %s" % [slot_name, removed])
                    break

        if removed:
            # Create world item - Use the original item reference
            _create_world_item(item)
            print("World item created successfully")

            # Update UI
            if equipment_ui:
                equipment_ui._update_ui()
            _refresh_open_containers()
        else:
            print("Failed to remove item from source")

        print("=== WORLD DROP END ===")

func _open_container_once(container: InventoryContainer):
    for ui in open_containers:
        if ui.current_inventory_source == container:
            return
    var container_ui_scene = preload("res://addons/cabra.lat_shooters/src/ui/inventory/container.tscn")
    var container_ui = container_ui_scene.instantiate() as InventoryContainerUI
    container_ui.slot_dropped.connect(_on_slot_dropped)
    container_ui.container_closed.connect(_on_container_closed.bind(container_ui))
    containers_vbox.add_child(container_ui)
    open_containers.append(container_ui)
    container_ui.open_container(container)

func _refresh_open_containers():
    for ui in open_containers:
        ui._update_ui()

func _on_container_closed(container_ui: InventoryContainerUI):
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

# src/ui/inventory/main.gd
class_name InventoryUI
extends Control

@onready var equipment_panel: FoldableContainer = $InventoryUi/HB/EquipmentPanel
@onready var slots: Array[InventorySlotUI] = [
     equipment_panel.get_node("Equipment/helmet"),
     equipment_panel.get_node("Equipment/vest"),
     equipment_panel.get_node("Equipment/back"),
     equipment_panel.get_node("Equipment/primary"),
     equipment_panel.get_node("Equipment/secondary")
]

@onready var world_drop_zone: WorldDropZone = $WorldDropZone
@onready var containers_vbox: VBoxContainer = $InventoryUi/HB/ScrollContainer/VB
@onready var close_button: Button = %CloseButton

# NEW: Proper world drop zone setup
var player_controller: PlayerController
var open_containers: Array[ContainerUI] = []
var debug_label: Label
var current_drag_data: Dictionary = {}

func _ready():
    _setup_equipment_slots()
    close_button.pressed.connect(_on_close_button_pressed)
    world_drop_zone.item_dropped.connect(_on_world_drop)

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
    elif source is PlayerBody:
        # Find which slot the item is in and remove it
        for slot_name in source.slots:
            var slot = source.slots[slot_name]
            if item in slot.items:
                removed = slot.remove_item(item)
                print("Removed from equipment slot %s: %s" % [slot_name, removed])
                break

    if removed:
        # Create world item
        _create_world_item(item)
        print("World item created successfully")

        # Update UI
        _update_equipment()
        _refresh_open_containers()
    else:
        print("Failed to remove item from source")

    print("=== WORLD DROP END ===")

func _create_world_item(item: InventoryItem):
    var world_item_scene = preload("../../gameplay/world_item.tscn")
    var world_item = world_item_scene.instantiate() as WorldItem

    # Set up the world item
    world_item.inventory_item = item.duplicate(true)

    # Position the item in front of the player
    if player_controller and player_controller.player_body:
        var player_pos = player_controller.global_position
        var player_forward = -player_controller.global_transform.basis.z
        var drop_pos = player_pos + player_forward * 2.0 + Vector3(0, 1, 0)  # 2m in front, 1m up

        world_item.global_position = drop_pos

        # Add some random rotation
        world_item.rotate_y(randf() * PI * 2)

    # Add to scene
    get_tree().current_scene.add_child(world_item)
    print("Created world item at position: %s" % world_item.global_position)

# UPDATED: Store source when drag starts
func _on_slot_dropped(data: Dictionary, target_slot: InventorySlotUI):
    print("=== DROP EVENT START ===")
    print("Drop data: %s -> %s" % [data["item"].content.name if data["item"].content else "Unknown", target_slot.name])
    print("Source: %s" % data["source"])

    # UPDATE: Store the source in current drag data for world drops
    if current_drag_data and current_drag_data.has("item"):
        current_drag_data["source"] = data["source"]

    # Rest of your existing drop handling code...
    var parent = target_slot.get_parent()

    if target_slot.grid_position == Vector2i(-1, -1):
        print("Target is equipment slot: %s" % target_slot.name)
        _handle_equipment_drop(data, target_slot)
    else:
        print("Target is container slot: %s" % target_slot.grid_position)
        _handle_container_drop(data, target_slot)

    print("=== DROP EVENT END ===")

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

func _setup_equipment_slots():
    for slot in slots:
        slot.connect("slot_dropped", _on_slot_dropped)
        # NEW: Connect drag signals
        slot.connect("drag_started", _on_drag_started)
        slot.connect("drag_ended", _on_drag_ended)

# NEW: World drop zone drag handling
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
        elif source is PlayerBody:
            # Find which slot the item is in and remove it
            for slot_name in source.slots:
                var slot = source.slots[slot_name]
                if item in slot.items:
                    removed = slot.remove_item(item)
                    print("Removed from equipment slot %s: %s" % [slot_name, removed])
                    break

        if removed:
            # Create world item
            _create_world_item(item)
            print("World item created successfully")

            # Update UI
            _update_equipment()
            _refresh_open_containers()
        else:
            print("Failed to remove item from source")

        print("=== WORLD DROP END ===")

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
        slot.icon.texture = equipped[0].content.icon
        slot.associated_item = equipped[0]
        slot.source_container = player_controller.player_body
        print("Equipment slot %s: %s" % [slot_name, equipped[0].content.name if equipped[0].content else "Unknown"])

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

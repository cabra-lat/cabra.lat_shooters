class_name TestPlayerScene
extends Node

# Configuration
var test_config: TestSceneConfig

# Debug/Test resources
@onready var test_ammo: Ammo = preload("res://addons/cabra.lat_shooters/src/resources/ammo/7_62_39mm_PS_GOST_BR4.tres")
@onready var test_weapon: Weapon = preload("res://addons/cabra.lat_shooters/src/resources/weapons/AK_47.tres")
@onready var test_backpack_icon: Texture2D = preload("res://addons/cabra.lat_shooters/assets/ui/inventory/backpack.png")
@onready var test_magazine_icon: Texture2D = preload("res://addons/cabra.lat_shooters/assets/ui/inventory/icon_stock_mag.png")

# Scene references
@onready var player: PlayerController = $Player
@onready var hud: Control = $HUD
@onready var world_item: WorldItem = %WorldItem

func _ready():
    # Load test configuration
    test_config = TestSceneConfig.new()

    _setup_player_equipment()
    _setup_world_item()
    _connect_player_signals()

    if test_config and test_config.debug_mode:
        print("Test scene initialized")

func _setup_player_equipment():
    # First, ensure player has equipment with proper config
    if not player.equipment:
        player.equipment = Equipment.new()
        player.equipment.equipment_config = _create_equipment_config()

    # Equip primary weapon
    var weapon_item = Inventory.create_inventory_item(test_weapon)
    weapon_item.dimensions = Vector2i(3, 2)  # Set dimensions before adding
    var equipped = player.equipment.equip(weapon_item, "primary")
    if not equipped:
        push_error("Could not equip primary")
        return

    # Create and equip magazine
    var magazine = _create_test_magazine()
    var magazine_item = Inventory.create_inventory_item(magazine)
    magazine_item.dimensions = Vector2i(1, 2)  # Set dimensions before adding

    # Create backpack and add magazine
    var backpack = _create_test_backpack()
    var backpack_item = Inventory.create_inventory_item(backpack)
    backpack_item.dimensions = Vector2i(2, 3)  # Set dimensions before equipping

    # Add magazine to backpack first
    var magazine_added = backpack.add_item(magazine_item)
    if not magazine_added:
        push_error("Could not add magazine to backpack")
        # Try to find why it failed
        print("Backpack free space: ", backpack.get_free_space())
        print("Magazine dimensions: ", magazine_item.dimensions)
        print("Backpack grid: ", backpack.grid_width, "x", backpack.grid_height)
        return

    # Now equip backpack
    var backpack_equipped = player.equipment.equip(backpack_item, "back")
    if not backpack_equipped:
        push_error("Could not equip backpack")
        return

    if test_config and test_config.debug_mode:
        print("Player equipment setup complete")

func _create_equipment_config() -> EquipmentConfig:
    var config = EquipmentConfig.new()

    # Define basic slot definitions
    var primary_slot = EquipmentSlotDefinition.new()
    primary_slot.slot_name = "primary"
    primary_slot.display_name = "Primary Weapon"
    primary_slot.allowed_item_types = ["weapon"]
    primary_slot.allowed_categories = ["primary"]
    primary_slot.max_items = 1
    primary_slot.layer = "gear"
    primary_slot.slot_size = "large"

    var back_slot = EquipmentSlotDefinition.new()
    back_slot.slot_name = "back"
    back_slot.display_name = "Backpack"
    back_slot.allowed_item_types = ["backpack"]
    back_slot.allowed_categories = ["back", "storage"]
    back_slot.max_items = 1
    back_slot.layer = "storage"
    back_slot.slot_size = "medium"

    var torso_slot = EquipmentSlotDefinition.new()
    torso_slot.slot_name = "torso"
    torso_slot.display_name = "Torso Armor"
    torso_slot.allowed_item_types = ["armor"]
    torso_slot.allowed_categories = ["torso"]
    torso_slot.max_items = 1
    torso_slot.layer = "armor"
    torso_slot.slot_size = "medium"

    config.slot_definitions = [primary_slot, back_slot, torso_slot]

    # Define layers
    var gear_layer = EquipmentLayerDefinition.new()
    gear_layer.layer_name = "gear"
    gear_layer.display_name = "Gear"
    gear_layer.layer_order = 0
    gear_layer.slots = ["primary", "secondary"]
    gear_layer.visible_by_default = true

    var storage_layer = EquipmentLayerDefinition.new()
    storage_layer.layer_name = "storage"
    storage_layer.display_name = "Storage"
    storage_layer.layer_order = 1
    storage_layer.slots = ["back"]
    storage_layer.visible_by_default = true

    var armor_layer = EquipmentLayerDefinition.new()
    armor_layer.layer_name = "armor"
    armor_layer.display_name = "Armor"
    armor_layer.layer_order = 2
    armor_layer.slots = ["torso", "head", "arms", "legs"]
    armor_layer.visible_by_default = true

    config.layer_definitions = [gear_layer, storage_layer, armor_layer]

    return config

func _create_test_magazine() -> AmmoFeed:
    var magazine = AmmoFeed.new()
    magazine.name = "AK-47 Magazine"
    magazine.compatible_calibers.append(test_ammo.caliber)
    magazine.type = AmmoFeed.Type.EXTERNAL
    magazine.icon = test_magazine_icon
    magazine.max_capacity = 30

    # Fill magazine with test ammo
    for i in range(magazine.max_capacity):
        magazine.insert(test_ammo)

    return magazine

func _create_test_backpack() -> Backpack:
    var backpack = Backpack.new()
    backpack.name = "Test Backpack"
    backpack.icon = test_backpack_icon
    return backpack

func _setup_world_item():
    if world_item:
        var ammo_item = Inventory.create_inventory_item(test_ammo, 30)
        world_item.inventory_item = ammo_item

        # Apply test config settings
        if test_config:
            world_item.auto_rotate = test_config.world_item_auto_rotate
            world_item.rotation_speed = test_config.world_item_rotation_speed
            world_item.pickup_radius = test_config.world_item_pickup_radius

        if test_config and test_config.debug_mode:
            print("World item setup complete")

func _connect_player_signals():
    if not player:
        return

    # Connect all player signals to our handlers
    var signals_to_connect = [
        "trigger_locked", "cartridge_fired", "trigger_released",
        "firemode_changed", "ammofeed_empty", "ammofeed_missing",
        "ammofeed_changed", "ammofeed_incompatible", "player_debug",
        "player_landed"
    ]

    for signal_name in signals_to_connect:
        if player.has_signal(signal_name):
            var error = player.connect(signal_name, Callable(self, "_on_player_" + signal_name))
            if error != OK and test_config and test_config.debug_mode:
                print("Failed to connect signal: ", signal_name)

# ─── PLAYER SIGNAL HANDLERS ────────────────────────
func _on_player_trigger_locked():
    hud.show_popup("[can't pull the trigger]")

func _on_player_cartridge_fired(ejected):
    var string = ""
    if player.weapon and player.weapon.ammofeed:
        for chambered in ejected:
            string += "Pow! (%d) %s\n" % [
                player.weapon.ammofeed.max_capacity - player.weapon.ammofeed.remaining,
                chambered.caliber
            ]
    else:
        string = "Weapon not properly equipped"

    hud.show_popup(string)

func _on_player_trigger_released():
    hud.show_popup("Released trigger")

func _on_player_firemode_changed(new):
    hud.show_popup("Changed firemode: %s" % new)

func _on_player_ammofeed_empty():
    hud.show_popup("Click!")

func _on_player_ammofeed_missing():
    hud.show_popup('Click!')

func _on_player_ammofeed_changed(old, new):
    var old_remaining = old.remaining if old else 0
    var old_capacity = old.max_capacity if old else 0
    var new_remaining = new.remaining if new else 0
    var new_capacity = new.max_capacity if new else 0

    hud.show_popup("Changed mag %d/%d to %d/%d" % [
        old_remaining, old_capacity, new_remaining, new_capacity
    ])

func _on_player_ammofeed_incompatible():
    hud.show_popup("- This doesn't fit here")

func _on_player_player_debug(_player: PlayerController, text: String) -> void:
    hud.update_debug(text)

func _on_player_player_landed(_player: PlayerController, max_velocity: float, delta: float) -> void:
    var lethal_g = player.config.letal_acceleration
    var a = abs(max_velocity - player.velocity.length()) / (2.0 * delta)
    var g = a / player.config.gravity
    var lethality_ratio = g / lethal_g

    var message = ""
    if lethality_ratio > 1:
        message = "Lethal fall damage (%.2f g)" % g
    elif lethality_ratio > 0.5:
        message = "Minor fall damage (%.2f g)" % g
    else:
        message = "Safely landed (%.2f g)" % g

    hud.show_popup(message)

# ─── INPUT HANDLING ────────────────────────────────
func _input(event):
    if event.is_action_pressed("interact") and world_item and world_item.is_highlighted:
        if world_item.pick_up(player):
            if test_config and test_config.debug_mode:
                print("World item picked up via interaction")

    # Debug controls
    if test_config and test_config.enable_debug_controls:
        _handle_debug_input(event)

func _handle_debug_input(event):
    if event.is_action_pressed("debug_spawn_item"):
        _spawn_debug_item()
    elif event.is_action_pressed("debug_clear_items"):
        _clear_debug_items()

func _spawn_debug_item():
    var new_world_item = world_item.duplicate()
    var spawn_pos = player.global_position + -player.global_transform.basis.z * 2.0
    new_world_item.global_position = spawn_pos
    add_child(new_world_item)

    if test_config and test_config.debug_mode:
        print("Spawned debug world item")

func _clear_debug_items():
    for child in get_children():
        if child is WorldItem and child != world_item:
            child.queue_free()

    if test_config and test_config.debug_mode:
        print("Cleared debug world items")

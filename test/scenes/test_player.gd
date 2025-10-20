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
    print("=== COMPREHENSIVE EQUIPMENT DEBUG ===")

    # 1. Check player and equipment existence
    if not player:
        push_error("Player controller is null")
        return

    if not player.equipment:
        push_error("Player equipment is null")
        return

    print("1. Player equipment exists: ", player.equipment != null)

    # 2. Check equipment slots
    print("2. Equipment slots: ", player.equipment.slots.keys())

    # 3. Check if 'primary' slot exists
    var has_primary_slot = player.equipment.slots.has("primary")
    print("3. Has 'primary' slot: ", has_primary_slot)

    if not has_primary_slot:
        push_error("Primary slot not found in equipment")
        print("Available slots: ", player.equipment.slots.keys())
        return

    # 4. Check equipment config
    var equipment_config = player.equipment.equipment_config
    print("4. Equipment config exists: ", equipment_config != null)

    if equipment_config:
        print("5. Slot definitions count: ", equipment_config.slot_definitions.size())

        # 5. Check primary slot definition
        var primary_def = equipment_config.get_slot_definition("primary")
        print("6. Primary slot definition exists: ", primary_def != null)

        if primary_def:
            print("7. Primary slot definition:")
            print("   - Slot name: ", primary_def.slot_name)
            print("   - Display name: ", primary_def.display_name)
            print("   - Allowed types: ", primary_def.allowed_item_types)
            print("   - Allowed categories: ", primary_def.allowed_categories)
            print("   - Max items: ", primary_def.max_items)
            print("   - Layer: ", primary_def.layer)

    # 6. Create test weapon and check its properties
    var weapon = test_weapon
    var weapon_item = Inventory.create_inventory_item(weapon)

    print("8. Test weapon created:")
    print("   - Weapon name: ", weapon.name)
    print("   - Weapon type: ", weapon.weapon_type if "weapon_type" in weapon else "NO WEAPON_TYPE PROPERTY")
    print("   - Weapon class: ", weapon.get_class())
    print("   - Weapon mass: ", weapon.mass)

    # 7. Check inventory item
    print("9. Inventory item:")
    print("   - Item content: ", weapon_item.content != null)
    print("   - Item dimensions: ", weapon_item.dimensions)
    print("   - Item stack count: ", weapon_item.stack_count)

    # 8. Test direct slot access
    var primary_slot = player.equipment.slots["primary"]
    print("10. Primary slot details:")
    print("   - Slot class: ", primary_slot.get_class())
    print("   - Slot items: ", primary_slot.items.size())
    print("   - Slot max items: ", primary_slot.max_items)

    # 9. Test can_add_item directly on the slot
    var can_add = primary_slot.can_add_item(weapon_item)
    print("11. Primary slot can_add_item: ", can_add)

    if not can_add:
        print("12. Slot can_add_item failed - checking why:")
        print("   - Items size: ", primary_slot.items.size())
        print("   - Max items: ", primary_slot.max_items)

        # Check if it's a compatibility issue
        if primary_slot is EquipmentSlot:
            var equipment_slot = primary_slot as EquipmentSlot
            print("   - Slot type: ", equipment_slot.slot_type)
            print("   - Slot name: ", equipment_slot.slot_name)

    # 10. Test the actual equip method with detailed debugging
    print("13. Attempting to equip weapon...")
    var success = player.equipment.equip(weapon_item, "primary")
    print("14. Equip result: ", success)

    if not success:
        push_error("Could not equip primary - see detailed debug above")
    else:
        print("SUCCESS: Weapon equipped to primary slot!")
        print("Primary slot now has: ", primary_slot.items.size(), " items")

    # After equipping the weapon, equip a backpack
    print("15. Attempting to equip backpack...")
    var backpack = _create_test_backpack()
    var backpack_item = Inventory.create_inventory_item(backpack)

    # Check if back slot exists
    var has_back_slot = player.equipment.slots.has("back")
    print("16. Has 'back' slot: ", has_back_slot)

    if has_back_slot:
        var back_slot = player.equipment.slots["back"]
        print("17. Back slot details:")
        print("   - Slot type: ", back_slot.slot_type)
        print("   - Slot items: ", back_slot.items.size())
        print("   - Slot max items: ", back_slot.max_items)

        var backpack_success = player.equipment.equip(backpack_item, "back")
        print("18. Backpack equip result: ", backpack_success)

        if backpack_success:
            print("SUCCESS: Backpack equipped!")
            print("Back slot now has: ", back_slot.items.size(), " items")

            # Test adding items to the backpack
            _test_backpack_storage(backpack)
        else:
            push_error("Could not equip backpack")
    else:
        push_error("No 'back' slot found for backpack")
        print("Available slots: ", player.equipment.slots.keys())

    print("=== END COMPREHENSIVE DEBUG ===")

# Enhanced test weapon creation
func _create_test_weapon() -> Weapon:
    var weapon = Weapon.new()
    weapon.name = "Test Assault Rifle"

    # Set weapon_type property directly
    weapon.set("weapon_type", "assault_rifle")
    weapon.mass = 3.5

    # Debug weapon properties
    print("Weapon properties:")
    for property in weapon.get_property_list():
        var name = property["name"]
        if name == "weapon_type" or name == "weaponType" or "weapon" in name.to_lower():
            print("   - ", name, ": ", weapon.get(name))

    return weapon

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
    backpack.grid_width = 6
    backpack.grid_height = 10
    backpack.max_weight = 25.0

    # Make sure the backpack is properly initialized
    if not backpack.grid:
        backpack.grid = InventoryGrid.new()
        backpack.grid.width = backpack.grid_width
        backpack.grid.height = backpack.grid_height
        backpack.grid._reset_grid()

    # Add some test items to the backpack
    _add_test_items_to_backpack(backpack)

    return backpack

func _add_test_items_to_backpack(backpack: Backpack):
    # Add some ammo to the backpack
    var ammo_item1 = Inventory.create_inventory_item(test_ammo, 30)
    if backpack.add_item(ammo_item1, Vector2i(0, 0)):
        print("Added ammo to backpack at position (0, 0)")

    # Add another ammo stack
    var ammo_item2 = Inventory.create_inventory_item(test_ammo, 20)
    if backpack.add_item(ammo_item2, Vector2i(1, 0)):
        print("Added ammo to backpack at position (1, 0)")

    # Add a magazine
    var magazine = _create_test_magazine()
    var magazine_item = Inventory.create_inventory_item(magazine)
    if backpack.add_item(magazine_item, Vector2i(3, 0)):
        print("Added magazine to backpack at position (3, 0)")

func _test_backpack_storage(backpack: Backpack):
    print("=== BACKPACK STORAGE TEST ===")
    print("Backpack name: ", backpack.name)
    print("Backpack dimensions: ", backpack.grid_width, "x", backpack.grid_height)
    print("Backpack max weight: ", backpack.max_weight)
    print("Backpack current weight: ", backpack.total_weight)
    print("Backpack items count: ", backpack.items.size())
    print("Backpack used space: ", backpack.get_used_space())
    print("Backpack free space: ", backpack.get_free_space())

    # List all items in backpack
    for i in range(backpack.items.size()):
        var item = backpack.items[i]
        print("Item ", i, ": ", item.content.name, " at position ", item.position)

    print("=== END BACKPACK TEST ===")

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
        print("=== ITEM PICKUP ATTEMPT ===")
        print("World item: ", world_item.inventory_item.content.name if world_item.inventory_item and world_item.inventory_item.content else "No item")
        print("World item position: ", world_item.global_position)
        print("Player position: ", player.global_position)
        print("Distance: ", world_item.global_position.distance_to(player.global_position))

        if world_item.pick_up(player):
            if test_config and test_config.debug_mode:
                print("World item picked up via interaction")
        else:
            print("Pickup failed - possible reasons:")
            print("  - No suitable container found")
            print("  - Item not compatible with any container")
            print("  - Containers are full")

        print("=== END PICKUP DEBUG ===")

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

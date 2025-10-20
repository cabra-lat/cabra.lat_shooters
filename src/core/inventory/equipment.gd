class_name Equipment
extends Resource

@export var equipment_config: EquipmentConfig
var slots: Dictionary = {}

func _init():
    # Create default config if none provided
    if not equipment_config:
        equipment_config = EquipmentConfig.new()
    _initialize_slots()

func _initialize_slots():
    if not equipment_config:
        push_error("Equipment: No equipment config available")
        return

    for slot_definition in equipment_config.slot_definitions:
        var slot = EquipmentSlot.new()
        slot.slot_name = slot_definition.slot_name
        slot.max_items = slot_definition.max_items

        # CRITICAL FIX: Set the correct slot_type based on slot name
        slot.slot_type = _get_slot_type_from_name(slot_definition.slot_name)

        slots[slot_definition.slot_name] = slot
        print("Initialized equipment slot: ", slot_definition.slot_name, " with type: ", slot.slot_type)

func _get_slot_type_from_name(slot_name: String) -> int:
    match slot_name:
        "head":
            return EquipmentSlot.Type.HEAD
        "torso", "lower_torso", "hips":
            return EquipmentSlot.Type.TORSO
        "left_upper_arm", "left_lower_arm", "left_hand", "right_upper_arm", "right_lower_arm", "right_hand":
            return EquipmentSlot.Type.ARMS
        "left_upper_leg", "left_knee", "left_lower_leg", "left_foot", "right_upper_leg", "right_knee", "right_lower_leg", "right_foot":
            return EquipmentSlot.Type.LEGS
        "primary":
            return EquipmentSlot.Type.PRIMARY_WEAPON
        "secondary", "utility":
            return EquipmentSlot.Type.SECONDARY_WEAPON
        "back", "backpack":  # Add this if you have a backpack slot
            return EquipmentSlot.Type.BACK
        _:
            return EquipmentSlot.Type.HEAD  # Default fallback

func equip(item: InventoryItem, slot_name: String) -> bool:
    print("Equipment.equip called - Slot: ", slot_name, " | Item: ", item.content.name if item.content else "No content")

    if not slots.has(slot_name):
        push_error("Equipment slot '%s' not found. Available slots: %s" % [slot_name, slots.keys()])
        return false

    var slot_definition = equipment_config.get_slot_definition(slot_name)
    if not slot_definition:
        push_error("No slot definition found for '%s'" % slot_name)
        return false

    # Enhanced compatibility check with debugging
    if not slot_definition.is_item_compatible(item):
        print("Item not compatible with slot '%s'" % slot_name)
        print("  Item type: ", _get_item_type_for_debug(item.content))
        print("  Item categories: ", _get_item_categories_for_debug(item.content))
        print("  Allowed types: ", slot_definition.allowed_item_types)
        print("  Allowed categories: ", slot_definition.allowed_categories)
        return false

    var success = slots[slot_name].add_item(item)
    print("Slot add_item result: ", success)
    return success

func _get_item_type_for_debug(content: Resource) -> String:
    if content is Weapon:
        return "weapon"
    elif content is Armor:
        return "armor"
    elif content is Backpack:
        return "backpack"
    elif content is Ammo:
        return "ammo"
    return "misc"

func _get_item_categories_for_debug(content: Resource) -> Array[String]:
    var categories = []

    if content is Weapon:
        categories.append("weapon")
        var weapon = content as Weapon
        if weapon.weapon_type:
            categories.append(weapon.weapon_type)
    elif content is Armor:
        categories.append("armor")
        var armor = content as Armor
        if armor.armor_slot:
            categories.append(armor.armor_slot)
    elif content is Backpack:
        categories.append("backpack")
        categories.append("storage")

    return categories

func unequip(item: InventoryItem, slot_name: String) -> bool:
    if not slots.has(slot_name):
        return false
    return slots[slot_name].remove_item(item)

func get_equipped(slot_name: String) -> Array[InventoryItem]:
    if slots.has(slot_name):
        return slots[slot_name].items
    return []

func get_slot_by_item(item: InventoryItem) -> String:
    for slot_name in slots:
        if item in slots[slot_name].items:
            return slot_name
    return ""

func get_total_mass() -> float:
    var total = 0.0
    for slot in slots.values():
        total += slot.get_total_mass()
    return total

# Get all equipped items
func get_all_equipped_items() -> Array[InventoryItem]:
    var items: Array[InventoryItem] = []
    for slot in slots.values():
        items.append_array(slot.items)
    return items

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
        slots[slot_definition.slot_name] = slot

func equip(item: InventoryItem, slot_name: String) -> bool:
    if not slots.has(slot_name):
        push_error("Equipment slot '%s' not found" % slot_name)
        return false

    var slot_definition = equipment_config.get_slot_definition(slot_name)
    if not slot_definition:
        push_error("No slot definition found for '%s'" % slot_name)
        return false

    if not slot_definition.is_item_compatible(item):
        push_error("Item not compatible with slot '%s'" % slot_name)
        return false

    return slots[slot_name].add_item(item)

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

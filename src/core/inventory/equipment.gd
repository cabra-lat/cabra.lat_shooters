class_name Equipment
extends Resource

@export var equipment_config: EquipmentConfig
var slots: Dictionary = {}

func _init():
    if equipment_config:
        _initialize_slots()

func _initialize_slots():
    for slot_definition in equipment_config.slot_definitions:
        var slot = EquipmentSlot.new()
        slot.slot_name = slot_definition.slot_name
        slot.max_items = slot_definition.max_items
        slots[slot_definition.slot_name] = slot

func equip(item: InventoryItem, slot_name: String) -> bool:
    if not slots.has(slot_name):
        return false

    var slot_definition = equipment_config.get_slot_definition(slot_name)
    if not slot_definition or not slot_definition.is_item_compatible(item):
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

# res://src/core/inventory/player_body.gd
class_name PlayerBody
extends Resource

# Body zones with slot types
var slots: Dictionary = {
	"head": EquipmentSlot.new(),
	"torso": EquipmentSlot.new(),
	"arms": EquipmentSlot.new(),
	"legs": EquipmentSlot.new(),
	"primary": EquipmentSlot.new(),
	"secondary": EquipmentSlot.new(),
	"utility": EquipmentSlot.new()
}

func _init():
	# Configure slots
	slots["head"].slot_type = EquipmentSlot.SlotType.HEAD
	slots["torso"].slot_type = EquipmentSlot.SlotType.TORSO
	slots["arms"].slot_type = EquipmentSlot.SlotType.ARMS
	slots["legs"].slot_type = EquipmentSlot.SlotType.LEGS
	slots["primary"].slot_type = EquipmentSlot.SlotType.PRIMARY_WEAPON
	slots["secondary"].slot_type = EquipmentSlot.SlotType.SECONDARY_WEAPON
	slots["utility"].slot_type = EquipmentSlot.SlotType.UTILITY

	# Weapon slots: only 1 item
	slots["primary"].max_items = 1
	slots["secondary"].max_items = 1

	# Clothing/armor slots: allow layering (optional)
	slots["torso"].max_items = 3  # base layer + clothing + armor
	slots["head"].max_items = 2   # cap + helmet

func equip(item: InventoryItem, slot_name: String) -> bool:
	if not slots.has(slot_name):
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

func get_total_mass() -> float:
	var total = 0.0
	for slot in slots.values():
		total += slot.get_total_mass()
	return total

# Temperature system hooks (future)
func get_insulation_rating() -> float:
	var rating = 0.0
	for slot in ["torso", "legs", "head"]:
		for item in slots[slot].items:
			if item.content.has_method("get_insulation"):
				rating += item.content.get_insulation()
	return rating

# Encumbrance hooks
func get_movement_penalty() -> float:
	var penalty = 0.0
	for slot in slots.values():
		penalty += slot.get_total_mass() * 0.01
	return min(penalty, 0.5)  # Max 50% penalty

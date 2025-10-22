# res://src/core/inventory/equipment.gd
class_name Equipment
extends Resource

signal equipped(item: InventoryItem, slot_name: String)
signal unequiped(item: InventoryItem, slot_name: String)

# Body zones with slot types
var slots: Dictionary = {
  "head": EquipmentSlot.new(),
  "torso": EquipmentSlot.new(),
  "arms": EquipmentSlot.new(),
  "legs": EquipmentSlot.new(),
  "primary": EquipmentSlot.new(),
  "secondary": EquipmentSlot.new(),
  "back": EquipmentSlot.new()
}

func _init():
  # Configure slots
  slots["head"].slot_type = EquipmentSlot.Type.HEAD
  slots["torso"].slot_type = EquipmentSlot.Type.TORSO
  slots["arms"].slot_type = EquipmentSlot.Type.ARMS
  slots["legs"].slot_type = EquipmentSlot.Type.LEGS
  slots["primary"].slot_type = EquipmentSlot.Type.PRIMARY_WEAPON
  slots["secondary"].slot_type = EquipmentSlot.Type.SECONDARY_WEAPON
  slots["back"].slot_type = EquipmentSlot.Type.BACK

func equip(item: InventoryItem, slot_name: String) -> bool:
  if not slots.has(slot_name):
    return false
  var success = slots[slot_name].add_item(item)
  if success: equipped.emit(item, slot_name)
  return success

func unequip(item: InventoryItem, slot_name: String) -> bool:
  if not slots.has(slot_name):
    return false
  var success = slots[slot_name].remove_item(item)  # Must return true if removed
  if success: unequiped.emit(item, slot_name)
  return success

func get_equipped(slot_name: String) -> Array[InventoryItem]:
  if slots.has(slot_name):
    return slots[slot_name].items
  return []

func is_equipped(slot_name: String) -> bool:
  return slots.has(slot_name) and slots[slot_name].items.size() > 0

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
      if item.has_method("get_insulation"):
        rating += item.get_insulation()
  return rating

# Encumbrance hooks
func get_movement_penalty() -> float:
  var penalty = 0.0
  for slot in slots.values():
    penalty += slot.get_total_mass() * 0.01
  return min(penalty, 0.5)  # Max 50% penalty

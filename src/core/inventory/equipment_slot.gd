# res://src/core/inventory/equipment_slot.gd
class_name EquipmentSlot
extends Resource

enum SlotType {
  HEAD,
  TORSO,
  ARMS,
  LEGS,
  PRIMARY_WEAPON,
  SECONDARY_WEAPON,
  UTILITY
}

@export var slot_type: SlotType
@export var max_items: int = 1  # 1 for weapons, >1 for layered clothing
var items: Array[InventoryItem] = []
@export var mass: float: get = get_total_mass

func can_add(item: InventoryItem) -> bool:
  if items.size() >= max_items:
    return false
  # Add compatibility logic here (e.g., only helmets in HEAD)
  return true

func add_item(item: InventoryItem) -> bool:
  if not can_add(item):
    return false
  items.append(item)
  return true

func remove_item(item: InventoryItem) -> bool:
  if item in items:
    items.erase(item)
    return true
  return false

func get_total_mass() -> float:
  var total = 0.0
  for item in items:
    total += item.content.mass * item.stack_count
  return total

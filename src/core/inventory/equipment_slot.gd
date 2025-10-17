# res://src/core/inventory/equipment_slot.gd
class_name EquipmentSlot
extends InventoryContainer

enum SlotType {
  HEAD,
  TORSO,
  ARMS,
  LEGS,
  PRIMARY_WEAPON,
  SECONDARY_WEAPON,
  BACK
}

@export var slot_type: SlotType
@export var max_items: int = 1  # 1 for weapons, >1 for layered clothing

func can_add_item(item: InventoryItem) -> bool:
  if items.size() >= max_items:
    return false
  # Add compatibility logic here (e.g., only helmets in HEAD)
  return true

func get_total_mass() -> float:
  var total = 0.0
  for item in items:
    total += item.content.mass * item.stack_count
  return total

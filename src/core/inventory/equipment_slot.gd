# res://src/core/inventory/equipment_slot.gd (UPDATED)
class_name EquipmentSlot
extends InventoryContainer

enum Type {
  HEAD,
  TORSO,
  ARMS,
  LEGS,
  PRIMARY_WEAPON,
  SECONDARY_WEAPON,
  BACK
}

@export var slot_type: Type
@export var max_items: int = 1  # 1 for weapons, >1 for layered clothing

func can_add_item(item: InventoryItem) -> bool:
  print("EquipmentSlot.can_add_item: checking %s in slot type %s (current items: %d/%d)" % [
      item.content.name if item.content else "Unknown",
      slot_type,
      items.size(),
      max_items
  ])

  if items.size() >= max_items:
    print("  -> REJECTED: Slot full")
    return false

  # Add compatibility logic here
  var compatible = false
  match slot_type:
    Type.HEAD:
      compatible = true  # Allow any head item for now
    Type.TORSO:
      compatible = true  # Allow any torso item for now
    Type.ARMS:
      compatible = true  # Allow any arms item for now
    Type.LEGS:
      compatible = true  # Allow any legs item for now
    Type.PRIMARY_WEAPON:
      compatible = item.content is Weapon
    Type.SECONDARY_WEAPON:
      compatible = item.content is Weapon
    Type.BACK:
      compatible = item.content is Backpack

  print("  -> %s: %s" % ["COMPATIBLE" if compatible else "INCOMPATIBLE", item.content.name if item.content else "Unknown"])
  return compatible

func get_total_mass() -> float:
  var total = 0.0
  for item in items:
    total += item.content.mass * item.stack_count
  return total

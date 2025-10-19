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
@export var slot_name: String = ""
@export var max_items: int = 1  # 1 for weapons, >1 for layered clothing

func can_add_item(item: InventoryItem) -> bool:
    if items.size() >= max_items:
        return false

    # Add compatibility logic here
    var compatible = false
    match slot_type:
        Type.HEAD:
            compatible = item.content is Armor
        Type.TORSO:
            compatible = item.content is Armor
        Type.ARMS:
            compatible = item.content is Armor
        Type.LEGS:
            compatible = item.content is Armor
        Type.PRIMARY_WEAPON:
            compatible = item.content is Weapon
        Type.SECONDARY_WEAPON:
            compatible = item.content is Weapon
        Type.BACK:
            compatible = item.content is Backpack

    return compatible

func get_total_mass() -> float:
    var total = 0.0
    for item in items:
        total += item.content.mass * item.stack_count
    return total

# src/core/inventory/equipment_slot.gd
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

func can_add_item(item: InventoryItem) -> bool:
  print("EquipmentSlot.can_add_item: checking %s in slot type %s (current items: %d/%d)" % [
      item.name if item else "Unknown",
      Type.get(slot_type),
      items.size(),
      1
  ])
  if items.size() > 0: return false

  return _is_category_compatible(item)

## Validity of an item ALREADY in this slot, as opposed to can_add_item(), which
## answers "may I drop this in" and therefore refuses any occupied slot.
##
## WHY THIS EXISTS ALONGSIDE can_add_item AND NOT INSTEAD OF IT. A loadout screen
## has to say WHICH ITEM makes a kit illegal, and building that on can_add_item
## condemns every worn slot: it returns false the moment the slot holds anything,
## so a full and perfectly legal kit reports violations and the screen tells a
## player their rifle is illegal. The two questions are genuinely different, so
## both exist; they share ONE compatibility implementation below, because a second
## copy of that match is exactly how the two drift and a kit becomes legal in the
## screen and illegal in the game.
##
## Note what this does NOT decide: whether the item FITS, which is the grid's
## question and is asked of the container, not of the slot.
func is_legal_while_equipped(item: InventoryItem) -> bool:
  if item == null:
    return false
  return _is_category_compatible(item)

## The one place the slot's category rules live. Both entry points route here.
func _is_category_compatible(item: InventoryItem) -> bool:
  var compatible := false
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
      compatible = item.extra is Weapon
    Type.SECONDARY_WEAPON:
      compatible = item.extra is Weapon
    Type.BACK:
      compatible = item.extra is Backpack
  return compatible

## Backpack contents, for a screen that reports what a rig holds.
func get_items() -> Array:
  return items.duplicate()


func get_total_mass() -> float:
  var total = 0.0
  for item in items:
    total += item.mass * item.stack_count
  return total

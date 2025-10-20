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

func _init():
    # Ensure grid is initialized for equipment slots
    if not grid:
        grid = InventoryGrid.new()
        grid.width = 1
        grid.height = 1
        grid._reset_grid()

func can_add_item(item: InventoryItem) -> bool:
    print("EquipmentSlot.can_add_item - Slot: ", slot_name, " | Item: ", item.content.name if item.content else "No content")

    if items.size() >= max_items:
        print("  - Failed: Slot full (", items.size(), "/", max_items, ")")
        return false

    # Enhanced compatibility logic with better debugging
    var compatible = false
    match slot_type:
        Type.HEAD:
            compatible = item.content is Armor
            print("  - HEAD slot compatibility: ", compatible, " | Is Armor: ", item.content is Armor)
        Type.TORSO:
            compatible = item.content is Armor
            print("  - TORSO slot compatibility: ", compatible, " | Is Armor: ", item.content is Armor)
        Type.ARMS:
            compatible = item.content is Armor
            print("  - ARMS slot compatibility: ", compatible, " | Is Armor: ", item.content is Armor)
        Type.LEGS:
            compatible = item.content is Armor
            print("  - LEGS slot compatibility: ", compatible, " | Is Armor: ", item.content is Armor)
        Type.PRIMARY_WEAPON:
            compatible = item.content is Weapon
            print("  - PRIMARY_WEAPON slot compatibility: ", compatible, " | Is Weapon: ", item.content is Weapon)
        Type.SECONDARY_WEAPON:
            compatible = item.content is Weapon
            print("  - SECONDARY_WEAPON slot compatibility: ", compatible, " | Is Weapon: ", item.content is Weapon)
        Type.BACK:
            compatible = item.content is Backpack
            print("  - BACK slot compatibility: ", compatible, " | Is Backpack: ", item.content is Backpack)

    print("  - Final compatibility: ", compatible)
    return compatible

func get_total_mass() -> float:
    var total = 0.0
    for item in items:
        total += item.content.mass * item.stack_count
    return total

# Override add_item to ensure it works for equipment
func add_item(item: InventoryItem, position: Vector2i = Vector2i.ZERO) -> bool:
    print("EquipmentSlot.add_item - Slot: ", slot_name, " | Item: ", item.content.name)

    if not can_add_item(item):
        print("  - Failed: Cannot add item to slot")
        return false

    # For equipment slots, we don't use grid positioning
    items.append(item)
    print("  - Success: Item added to slot. Total items: ", items.size())
    return true

# Override remove_item for equipment
func remove_item(item: InventoryItem) -> bool:
    var index = items.find(item)
    if index != -1:
        items.remove_at(index)
        return true
    return false

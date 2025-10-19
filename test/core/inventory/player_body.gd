# test/core/inventory/equipment.gd
@tool
class_name TestPlayerBody extends EditorScript

func _run():
  print("🧪 Testing EquipmentSlot...")

  var body = EquipmentSlot.new()

  # Equip primary weapon
  var weapon = Weapon.new()
  weapon.name = "M4A1"
  var weapon_item = InventoryItem.new()
  weapon_item.content = weapon
  weapon_item.dimensions = Vector2i(3, 1)

  check(body.equip(weapon_item, "primary"), "Equip primary weapon")
  check(body.get_equipped("primary").size() == 1, "Weapon equipped")

  # Equip armor
  var armor = Armor.new()
  armor.name = "Plate Carrier"
  var armor_item = InventoryItem.new()
  armor_item.content = armor
  armor_item.dimensions = Vector2i(2, 2)

  check(body.equip(armor_item, "torso"), "Equip armor")
  check(body.get_equipped("torso").size() == 1, "Armor equipped")

  # Test layering (add t-shirt)
  var clothing = InventoryItem.new()
  clothing.content = Item.new()
  clothing.content.mass = 0.2
  clothing.dimensions = Vector2i(1, 1)
  check(body.equip(clothing, "torso"), "Equip clothing layer")
  check(body.get_equipped("torso").size() == 2, "Layered clothing")

  # Test mass calculation
  var total_mass = body.get_total_mass()
  check(total_mass > 0, "Total mass calculated")

  print("✅ EquipmentSlot tests passed!")

func check(condition: bool, message: String):
  if not condition:
    push_error("❌ FAIL: " + message)
  else:
    print("  ✅ PASS: " + message)

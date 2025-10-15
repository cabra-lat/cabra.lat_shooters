# res://test/core/inventory/backpack.gd
@tool
class_name TestBackpack extends EditorScript

func _run():
  print("🧪 Testing Backpack...")

  var backpack = Backpack.new()
  check(backpack.grid_width == 6, "Backpack width correct")
  check(backpack.grid_height == 10, "Backpack height correct")
  check(backpack.max_weight == 25.0, "Backpack weight limit correct")

  # Add weapon
  var weapon = Weapon.new()
  weapon.name = "Test Rifle"
  var weapon_item = InventoryItem.new()
  weapon_item.content = weapon
  weapon_item.dimensions = Vector2i(3, 2)

  check(backpack.add_item(weapon_item), "Add weapon to backpack")
  check(backpack.items.size() == 1, "Weapon in backpack")

  print("✅ Backpack tests passed!")

func check(condition: bool, message: String):
  if not condition:
    push_error("❌ FAIL: " + message)
  else:
    print("  ✅ PASS: " + message)

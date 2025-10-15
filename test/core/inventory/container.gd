# res://test/core/inventory/container.gd
@tool
class_name TestInventoryContainer extends EditorScript

func _run():
  print("🧪 Testing InventoryContainer...")

  var container = InventoryContainer.new()
  container.grid_width = 3
  container.grid_height = 3
  container.max_weight = 10.0

  # Create test ammo item
  var ammo = Ammo.create_test_ammo()
  var item = InventoryItem.new()
  item.content = ammo
  item.max_stack = 30
  item.stack_count = 10
  item.dimensions = Vector2i(2, 1)

  # Test add
  check(container.add_item(item), "Add item to container")
  check(container.items.size() == 1, "Item count correct")
  check(container.total_weight > 0, "Weight calculated")

  # Test remove
  check(container.remove_item(item), "Remove item")
  check(container.items.is_empty(), "InventoryContainer empty after removal")

  print("✅ InventoryContainer tests passed!")

func check(condition: bool, message: String):
  if not condition:
    push_error("❌ FAIL: " + message)
  else:
    print("  ✅ PASS: " + message)

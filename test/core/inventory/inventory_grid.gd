# res://test/core/inventory/inventory_grid.gd
@tool
class_name TestInventoryGrid extends EditorScript

func _run():
  print("🧪 Testing InventoryGrid...")

  var grid = InventoryGrid.new()
  grid.width = 3
  grid.height = 3

  # Add 1x1 item
  var item1 = InventoryItem.new()
  item1.dimensions = Vector2i(1, 1)
  check(grid.add_item(item1), "Add 1x1 item")
  check(grid.get_used_area() == 1, "Used area = 1")

  # Add 2x2 item
  var item2 = InventoryItem.new()
  item2.dimensions = Vector2i(2, 2)
  check(grid.add_item(item2), "Add 2x2 item")
  check(grid.get_used_area() == 5, "Used area = 5")

  # Try to add 2x2 again → should fail
  var item3 = InventoryItem.new()
  item3.dimensions = Vector2i(2, 2)
  check(not grid.add_item(item3), "Cannot add overlapping 2x2")

  # Remove item
  check(grid.remove_item(item2), "Remove 2x2 item")
  check(grid.get_used_area() == 1, "Used area back to 1")

  print("✅ InventoryGrid tests passed!")

func check(condition: bool, message: String):
  if not condition:
    push_error("❌ FAIL: " + message)
  else:
    print("  ✅ PASS: " + message)

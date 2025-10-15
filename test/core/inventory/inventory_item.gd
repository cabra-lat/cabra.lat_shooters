# res://test/core/inventory/inventory_item.gd
@tool
class_name TestInventoryItem extends EditorScript

func _run():
	print("🧪 Testing InventoryItem...")

	var item = InventoryItem.new()
	item.dimensions = Vector2i(2, 1)
	item.position = Vector2i(1, 2)
	check(item.occupied_cells.size() == 2, "Occupied cells count")
	check(Vector2i(1, 2) in item.occupied_cells, "Cell (1,2) occupied")
	check(Vector2i(2, 2) in item.occupied_cells, "Cell (2,2) occupied")

	# Test stacking
	var ammo1 = InventoryItem.new()
	ammo1.content = Ammo.create_test_ammo()
	ammo1.max_stack = 30
	ammo1.stack_count = 10

	var ammo2 = InventoryItem.new()
	ammo2.content = Ammo.create_test_ammo()
	ammo2.max_stack = 30
	ammo2.stack_count = 15

	check(ammo1.can_stack_with(ammo2), "Can stack same ammo")
	check(ammo1.merge(ammo2), "Merge succeeds")
	check(ammo1.stack_count == 25, "Stack count updated")

	print("✅ InventoryItem tests passed!")

func check(condition: bool, message: String):
	if not condition:
		push_error("❌ FAIL: " + message)
	else:
		print("  ✅ PASS: " + message)

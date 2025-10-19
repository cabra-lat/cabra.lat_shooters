# test/gameplay/world_item.gd
@tool
class_name TestWorldItem extends EditorScript

func _run():
  print("🧪 Testing WorldItem...")

  # Create world item
  var world_item = WorldItem.new()
  var ammo = Ammo.create_test_ammo()
  var inventory_item = Inventory.create_inventory_item(ammo, 5)
  world_item.inventory_item = inventory_item

  # Create player mock
  var player = _create_mock_player()

  # Test pickup
  var success = world_item.pick_up(player)
  check(success, "Should pick up item from world")
  check(player.backpack.items.size() == 1, "Backpack should contain item")

  print("✅ WorldItem tests passed!")

func _create_mock_player() -> PlayerController:
  var player = PlayerController.new()
  player.backpack = Backpack.new()
  player.inventory_system = Inventory.new()
  return player

func check(condition: bool, message: String):
  if not condition:
    push_error("❌ FAIL: " + message)
  else:
    print("  ✅ PASS: " + message)

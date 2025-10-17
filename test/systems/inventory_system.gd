# res://test/systems/inventory_system.gd
@tool
class_name TestInventorySystem extends EditorScript

func _run():
  print("🧪 Testing InventorySystem...")

  # Test 1: Transfer ammo between backpacks
  _test_backpack_to_backpack()

  # Test 2: Transfer ammo to AmmoFeed (magazine)
  _test_ammo_to_magazine()

  # Test 3: Equip weapon to player body
  _test_equip_weapon()

  # Test 4: Incompatible ammo rejection
  _test_incompatible_ammo()

  print("✅ InventorySystem tests passed!")

# Test transferring items between generic containers
func _test_backpack_to_backpack():
  var source_backpack = Backpack.new()
  var target_backpack = Backpack.new()

  # Create ammo item
  var ammo = Ammo.create_test_ammo()
  var item = InventorySystem.create_inventory_item(ammo, 10)
  source_backpack.add_item(item)

  # Transfer
  var success = InventorySystem.transfer_item(source_backpack, target_backpack, item)
  check(success, "Should transfer ammo between backpacks")
  check(target_backpack.items.size() == 1, "Target should have 1 item")
  check(source_backpack.items.is_empty(), "Source should be empty")

# Test transferring ammo to a magazine
func _test_ammo_to_magazine():
  var backpack = Backpack.new()

  # Create compatible ammo
  var ammo = Ammo.create_test_ammo()  # 9mm
  var item = InventorySystem.create_inventory_item(ammo, 5)
  backpack.add_item(item)

  var magazine = AmmoFeed.new()
  magazine.compatible_calibers = ["9x19mm"]
  magazine.type = AmmoFeed.Type.EXTERNAL

  # Transfer
  var success = InventorySystem.transfer_item(backpack, magazine, item)
  print("Magazine contents after transfer: ", magazine.contents.size())
  check(success, "Should transfer compatible ammo to magazine")
  check(magazine.capacity == 5, "Magazine should contain 5 rounds")

# Test equipping a weapon
func _test_equip_weapon():
  var backpack = Backpack.new()
  var player_body = PlayerBody.new()

  # Create weapon
  var weapon = Weapon.new()
  weapon.name = "M4A1"
  var item = InventorySystem.create_inventory_item(weapon)
  backpack.add_item(item)

  # Equip
  var success = InventorySystem.transfer_item(backpack, player_body, item)
  check(success, "Should equip weapon to primary slot")
  check(player_body.get_equipped("primary").size() == 1, "Primary slot should have weapon")
  check(backpack.items.is_empty(), "Backpack should be empty")

# Test incompatible ammo rejection
func _test_incompatible_ammo():
  var backpack = Backpack.new()
  var ak_magazine = AmmoFeed.new()
  ak_magazine.compatible_calibers = ["7.62x39mm"]
  ak_magazine.type = AmmoFeed.Type.EXTERNAL

  # Create 9mm ammo (incompatible with AK)
  var nine_mm = Ammo.create_test_ammo()  # 9mm
  var item = InventorySystem.create_inventory_item(nine_mm, 1)
  backpack.add_item(item)

  # Attempt transfer
  var success = InventorySystem.transfer_item(backpack, ak_magazine, item)
  check(not success, "Should reject incompatible ammo")
  check(backpack.items.size() == 1, "Backpack should still have item")
  check(ak_magazine.is_empty(), "Magazine should be empty")

# Assertion helper (renamed from assert to check)
func check(condition: bool, message: String):
  if not condition:
    push_error("❌ FAIL: " + message)
  else:
    print("  ✅ PASS: " + message)

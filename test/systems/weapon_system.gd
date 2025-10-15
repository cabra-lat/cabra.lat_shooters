# res://test/systems/weapon_system.gd
@tool
class_name TestWeaponSystem extends EditorScript

func _run():
  print("🧪 Testing WeaponSystem...")

  var weapon = Weapon.new()
  weapon.name = "Test Rifle"
  weapon.firemodes = Firemode.SEMI | Firemode.AUTO
  weapon.feed_type = AmmoFeed.Type.EXTERNAL

  # Load ammo — INSERT TWO ROUNDS
  var feed = AmmoFeed.new()
  feed.compatible_calibers = ["5.56x45mm"]
  var ammo = Ammo.new()
  ammo.caliber = "5.56x45mm"
  ammo.cartridge_mass = 0.012
  feed.insert(ammo)
  feed.insert(ammo)  # ← SECOND ROUND
  weapon.ammofeed = feed

  # Chamber first round
  weapon.chambered_round = weapon.ammofeed.eject()

  # Test firing
  var fired = WeaponSystem.pull_trigger(weapon)
  check(fired, "Should fire successfully")
  check(weapon.semi_control, "Semi control should be active")

  # Test second shot blocked
  fired = WeaponSystem.pull_trigger(weapon)
  check(not fired, "Second shot should be blocked")

  # Release trigger and fire again
  WeaponSystem.release_trigger(weapon)
  # Re-chamber from remaining ammo
  if weapon.ammofeed and not weapon.ammofeed.is_empty():
    weapon.chambered_round = weapon.ammofeed.eject()
  fired = WeaponSystem.pull_trigger(weapon)
  check(fired, "Should fire after release")

  # Test firemode cycling
  WeaponSystem.cycle_firemode(weapon)
  check(weapon.firemode == Firemode.AUTO, "Should cycle to AUTO")

  print("✅ WeaponSystem tests passed!")

func check(condition: bool, message: String):
  if not condition:
    push_error("❌ FAIL: " + message)
  else:
    print("  ✅ PASS: " + message)

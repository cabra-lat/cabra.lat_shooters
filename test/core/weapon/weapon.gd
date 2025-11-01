# res://test/core/weapon/weapon.gd
@tool
class_name TestWeapon extends EditorScript

func _run():
  print("🧪 Testing Weapon...")

  # Create weapon
  var weapon = Weapon.new()
  weapon.name = "Test Rifle"
  weapon.firemodes = Firemode.SEMI | Firemode.AUTO
  weapon.feed_type = AmmoFeed.Type.EXTERNAL

  # Test firemode init
  check(weapon.firemode == Firemode.SEMI, "Defaults to SEMI")

  # Test cycling
  weapon.cycle_firemode()
  check(weapon.firemode == Firemode.AUTO, "Cycles to AUTO")
  weapon.cycle_firemode()
  check(weapon.firemode == Firemode.SEMI, "Wraps to SEMI")

  # Test ammo feed
  var feed = AmmoFeed.new()
  feed.compatible_calibers = ["5.56x45mm"]
  var ammo = Ammo.new()
  ammo.caliber = "5.56x45mm"
  ammo.cartridge_mass = 0.012
  feed.insert(ammo)
  weapon.ammo_feed = feed
  check(weapon.can_fire, "Can fire with ammo")

  # Test mass
  weapon.base_mass = 3.0
  check(abs(weapon.mass - (3.0 + 0.012)) < 0.001, "Mass includes ammo")

  # Test attachments
  weapon.attach_points = Weapon.AttachmentPoint.TOP_RAIL
  var att = Attachment.new()
  att.attachment_point = Weapon.AttachmentPoint.TOP_RAIL
  att.mass = 0.2
  att.accuracy_modifier = 0.8
  weapon.attach_attachment(Weapon.AttachmentPoint.TOP_RAIL, att)
  check(weapon.accuracy == weapon.base_accuracy * 0.8, "Accuracy modified")
  check(abs(weapon.mass - (3.0 + 0.012 + 0.2)) < 0.001, "Mass includes attachment")

  print("✅ Weapon tests passed!")

func check(condition: bool, message: String):
  if not condition:
    push_error("❌ FAIL: " + message)
  else:
    print("  ✅ PASS: " + message)

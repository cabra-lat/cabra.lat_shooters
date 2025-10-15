# res://test/core/attachment/attachment.gd
@tool
class_name TestAttachment extends EditorScript

func _run():
  print("🧪 Testing Attachment...")

  # Create weapon with top rail
  var weapon: Weapon = Weapon.new()
  weapon.name = "Test Rifle"
  weapon.attach_points = Weapon.AttachmentPoint.TOP_RAIL | Weapon.AttachmentPoint.MUZZLE

  # Create compatible scope
  var scope: Attachment = Attachment.new()
  scope.name = "Red Dot"
  scope.type = Attachment.AttachmentType.OPTICS
  scope.attachment_point = Weapon.AttachmentPoint.TOP_RAIL
  scope.accuracy_modifier = 0.8
  scope.mass = 0.15

  # Test compatibility
  check(scope._is_compatible(weapon), "Scope should be compatible with top rail")

  # Test attachment
  var attached = weapon.attach_attachment(Weapon.AttachmentPoint.TOP_RAIL, scope)
  check(attached, "Should attach successfully")
  check(weapon.get_attachment(Weapon.AttachmentPoint.TOP_RAIL) == scope, "Scope should be on weapon")

  # Test stat modification
  var base_acc = weapon.base_accuracy
  check(abs(weapon.accuracy - (base_acc * 0.8)) < 0.001, "Accuracy modified by scope")

  # Test mass
  check(abs(weapon.mass - (weapon.base_mass + 0.15)) < 0.001, "Mass includes attachment")

  # Test detachment
  var detached = weapon.detach_attachment(Weapon.AttachmentPoint.TOP_RAIL)
  check(detached, "Should detach successfully")
  check(weapon.get_attachment(Weapon.AttachmentPoint.TOP_RAIL) == null, "Scope should be removed")

  # Test incompatible attachment
  var laser: Attachment = Attachment.new()
  laser.attachment_point = Weapon.AttachmentPoint.LEFT_RAIL  # Not on weapon
  check(not laser._is_compatible(weapon), "Laser should be incompatible")

  print("✅ Attachment tests passed!")

func check(condition: bool, message: String):
  if not condition:
    push_error("❌ FAIL: " + message)
  else:
    print("  ✅ PASS: " + message)

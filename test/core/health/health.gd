# test/core/health/health.gd
@tool
class_name TestHealth extends EditorScript

func _run():
  print("🧪 Testing Health...")

  var health = Health.new()
  check(health.body_parts.size() == 16, "16 body parts created")

  # Test head destruction = death
  var head = health.body_parts[BodyPart.Type.HEAD]
  var impact = BallisticsImpact.new()
  impact.hit_energy = 5000.0  # Lethal energy
  health.take_ballistic_damage(impact, BodyPart.Type.HEAD)

  check(head.is_destroyed, "Head destroyed")
  check(not health.is_alive, "Player died from head destruction")

  # Test armor equip
  var vest = Armor.new()
  vest.protection_zones = Armor.BodyParts.THORAX
  health.equip_armor(vest)
  check(health.body_parts[BodyPart.Type.UPPER_CHEST].equipped_armor == vest, "Armor equipped")

  # Test healing
  health = Health.new()
  var chest = health.body_parts[BodyPart.Type.UPPER_CHEST]
  chest.take_damage(20.0)
  health.apply_healing(10.0, BodyPart.Type.UPPER_CHEST)
  check(chest.current_health == 60.0, "Healing applied")

  print("✅ Health tests passed!")

func check(condition: bool, message: String):
  if not condition:
    push_error("❌ FAIL: " + message)
  else:
    print("  ✅ PASS: " + message)

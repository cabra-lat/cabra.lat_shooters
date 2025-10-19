# test/core/weapon/firemode.gd
@tool
class_name TestFiremode extends EditorScript

func _run():
	print("🧪 Testing Firemode...")

	check(Firemode.get_name(Firemode.SEMI) == "SEMI", "SEMI name correct")
	check(Firemode.get_name(Firemode.BURST) == "BURST", "BURST name correct")
	check(Firemode.get_name(999) == "UNKNOWN", "Unknown mode handled")

	check(Firemode.is_automatic(Firemode.AUTO), "AUTO is automatic")
	check(Firemode.is_automatic(Firemode.BURST), "BURST is automatic")
	check(not Firemode.is_automatic(Firemode.SEMI), "SEMI is not automatic")

	var order = Firemode.get_priority_order()
	check(order.size() == 5, "Priority order has 5 modes")
	check(order[0] == Firemode.AUTO, "AUTO first in priority")

	print("✅ Firemode tests passed!")

func check(condition: bool, message: String):
	if not condition:
		push_error("❌ FAIL: " + message)
	else:
		print("  ✅ PASS: " + message)

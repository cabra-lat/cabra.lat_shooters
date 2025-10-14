# res://test/core/ammo/reservoir.gd
@tool
class_name TestReservoir extends EditorScript

func _run():
	print("🧪 Testing Reservoir...")
	
	var reservoir = Reservoir.new()
	reservoir.max_capacity = 3
	
	# Test initial state
	check(reservoir.is_empty(), "Should start empty")
	check(not reservoir.is_full(), "Should not be full")
	check(reservoir.capacity == 0, "Capacity should be 0")
	
	# Insert items
	var item1 = Resource.new()
	var item2 = Resource.new()
	
	check(reservoir.insert(item1), "Should insert first item")
	check(reservoir.insert(item2), "Should insert second item")
	check(reservoir.capacity == 2, "Capacity should be 2")
	
	# Fill to max
	check(reservoir.insert(Resource.new()), "Should insert third item")
	check(reservoir.is_full(), "Should be full")
	check(not reservoir.insert(Resource.new()), "Should reject fourth item")
	
	# Pop items
	var popped = reservoir.pop()
	check(popped != null, "Should pop an item")
	check(reservoir.capacity == 2, "Capacity should decrease")
	
	popped = reservoir.pop()
	popped = reservoir.pop()
	check(reservoir.is_empty(), "Should be empty after popping all")
	
	print("✅ Reservoir tests passed!")

func check(condition: bool, message: String):
	if not condition:
		push_error("❌ FAIL: " + message)
	else:
		print("  ✅ PASS: " + message)

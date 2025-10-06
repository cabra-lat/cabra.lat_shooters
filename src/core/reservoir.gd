@tool
class_name Reservoir extends Resource

@export var max_capacity: int = 30
@export var contents: Array[Resource] = [] 
var capacity : get = get_capacity

func get_capacity() -> int:
	return len(contents)

func is_empty() -> int:
	return len(contents) == 0

func is_full() -> bool:
	return len(contents) == max_capacity

func insert(thing) -> bool:
	if not is_full(): contents.push_back(thing.duplicate())
	return not is_full()

func pop() -> Resource:
	if not is_empty(): return contents.pop_back()
	return null

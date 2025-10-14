# res://src/core/ammo/reservoir.gd
class_name Reservoir
extends Resource

@export var max_capacity: int = 30
@export var contents: Array[Resource] = []

var capacity: int:
	get: return len(contents)

func is_empty() -> bool:
	return len(contents) == 0

func is_full() -> bool:
	return len(contents) == max_capacity

func insert(thing: Resource) -> bool:
	if is_full():
		return false
	contents.push_back(thing.duplicate())
	return true

func pop() -> Resource:
	if is_empty():
		return null
	return contents.pop_back()

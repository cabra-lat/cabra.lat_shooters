class_name Reservoir
extends Resource

@export var max_capacity: int = 30
@export var contents: Array[Resource] = [] 
var remaining : get = get_remaining

func get_remaining():
	return len(contents)

func is_empty():
	return len(contents) == 0

func full():
	return len(contents) == max_capacity

func insert(thing):
	if not full(): contents.push_back(thing.duplicate())

func eject():
	if not is_empty(): return contents.pop_back()

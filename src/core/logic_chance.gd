@tool
class_name LogicChance
extends Resource

static func succeed(chance):
	randomize()
	var normal = randf_range(0, 1)
	return chance < normal

static func failed(chance):
	return not succeed(chance)

class_name AmmoFeed
extends Reservoir

@export var viewmodel: Resource
@export var type: enums.FeedType
@export var empty_mass: float

var mass : get = get_mass

func get_mass():
	var total_mass = empty_mass
	for ammo in contents:
		total_mass += ammo.mass
	return total_mass

func insert(ammo: Ammo):
	super.insert(ammo)

func eject():
	return super.eject()

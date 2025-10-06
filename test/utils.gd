@tool
class_name TestUtils extends EditorScript

const AMMO_PATH = "res://addons/cabra.lat_shooters/src/resources/ammo/"
const WEAPONS_PATH = "res://addons/cabra.lat_shooters/src/resources/weapons/"

static func load_all_ammo() -> Array[Ammo]:
	var list: Array[Ammo]
	for ammo in load_all_resources(AMMO_PATH):
		list.append(ammo as Ammo)
	return list

static func load_all_weapons() -> Array[Weapon]:
	var list: Array[Weapon]
	for ammo in load_all_resources(WEAPONS_PATH):
		list.append(ammo as Weapon)
	return list

static func load_all_resources(PATH: String) -> Array[Resource]:
	var list: Array[Resource] = []
	if not DirAccess.dir_exists_absolute(PATH):
		return list
	var dir = DirAccess.open(PATH)
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if file.ends_with(".tres"):
			var path = PATH + file
			if ResourceLoader.exists(path):
				var res: Resource = ResourceLoader.load(path)
				list.append(res)
		file = dir.get_next()
	return list

# res://addons/cabra.lat_shooters/src/player/medical_kit.gd
class_name MedicalKit
extends RefCounted
## Locating and picking the right medical/consumable item for the current
## condition, plus the starter kit so a player can actually reach a bandage
## and a splint without a console (arena and range alike).
##
## Pure helpers: unit-testable headless and free of scene ownership.

const PATHS := {
	"bandage": "res://resources/medical/army_bandage.tres",
	"tourniquet": "res://resources/medical/cat_hemostatic_tourniquet.tres",
	"splint": "res://resources/medical/aluminium_splint.tres",
	"painkiller": "res://resources/medical/analgin_painkillers.tres",
	"surgery": "res://resources/medical/cms_surgical_kit.tres",
	"medkit": "res://resources/medical/salewa_first_aid_kit.tres",
	"small_medkit": "res://resources/medical/ai2_medkit.tres",
	"food": "res://resources/medical/can_of_condensed_milk.tres",
	"water": "res://resources/medical/bottle_of_water.tres",
}

## Loadout for testing: covers both bleed types, a fracture and hydration.
const STARTER := ["bandage", "splint", "tourniquet", "water"]

static func make(key: String) -> InventoryItem:
	var path: String = PATHS.get(key, "")
	if path == "":
		return null
	var item := InventoryItem.slurp(load(path) as Item)
	if key == "bandage":
		item.dimensions = Vector2i(1, 1)
	return item


## Priority list of kit keys that would help right now, best first.
static func wanted_keys(health: Health, survival: PlayerSurvival) -> Array[String]:
	var out: Array[String] = []
	if health != null:
		if health.has_heavy_bleeding():
			out.append("tourniquet")
			out.append("medkit")
		elif health.has_light_bleeding():
			out.append("bandage")
			out.append("medkit")
		if health.has_fracture():
			out.append("splint")
		if not health.get_blacked_parts().is_empty():
			out.append("surgery")
		if health.effective_pain() > 0.25:
			out.append("painkiller")
		# Hurt enough to warrant healing (leave minor scratches alone).
		if health.health_percentage < 0.85:
			out.append("medkit")
			out.append("small_medkit")
	if survival != null:
		if survival.energy_ratio() < 0.4:
			out.append("food")
		if survival.hydration_ratio() < 0.4:
			out.append("water")
	return out


## Best usable item from anything the player carries (equipment + backpack).
static func find_usable(player: Node) -> InventoryItem:
	if player == null or player.equipment == null:
		return null
	var carried := carried_medical(player)
	if carried.is_empty():
		return null
	for key in wanted_keys(player.health, player.survival):
		for item in carried:
			var med = item.extra
			if med is MedicalItem and (med as MedicalItem).can_use() \
					and _item_key(item) == key:
				return item
	return null


## All medical items the player carries, de-duplicated (the equipped backpack
## is reachable both through its equipment slot and through
## get_equipped_backpack(), so walking blindly would double-count).
static func carried_medical(player: Node) -> Array:
	var out: Array = []
	var seen := {}
	if player == null or player.equipment == null:
		return out
	for slot_name in player.equipment.slots:
		var slot = player.equipment.slots[slot_name]
		if slot == null:
			continue
		for item in slot.items:
			_collect(item, out, seen)
	var pack = player.get_equipped_backpack() if player.has_method("get_equipped_backpack") else null
	if pack != null:
		for item in pack.items:
			_collect(item, out, seen)
	return out


static func _collect(item, out: Array, seen: Dictionary) -> void:
	if item == null:
		return
	var id: int = item.get_instance_id()
	if seen.has(id):
		return
	seen[id] = true
	if item.extra is MedicalItem:
		out.append(item)
	var nested = item.extra
	if nested is InventoryContainer:
		for inner in (nested as InventoryContainer).items:
			_collect(inner, out, seen)


static func _item_key(item: InventoryItem) -> String:
	var med = item.extra
	if not (med is MedicalItem):
		return ""
	var path := (med as MedicalItem).resource_path
	if path != "":
		for key in PATHS:
			if PATHS[key] == path:
				return key
	return ""

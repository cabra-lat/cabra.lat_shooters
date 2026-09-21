# src/ui/inventory/tooltip.gd
class_name InventoryTooltip
extends RefCounted
## Pure-logic item tooltip text (name + kind + stats). No scene deps,
## so headless harnesses can cover it directly.


static func text_for(item: InventoryItem) -> String:
	if item == null:
		return ""
	var lines: Array[String] = [item.name]
	lines.append(_kind_line(item))
	var stat := _stat_line(item)
	if stat != "":
		lines.append(stat)
	# Wrapper resources rarely carry mass (see InventoryItem.slurp):
	# show the wrapped item's mass (weapon incl. attachments/mag).
	var m: float = item.extra.get_mass() if item.extra != null else item.mass
	lines.append("Size %dx%d   Mass %.2f kg" % [
		item.dimensions.x, item.dimensions.y, m * maxf(item.stack_count, 1)])
	if item.max_stack > 1:
		lines.append("Stack %d/%d" % [item.stack_count, item.max_stack])
	return "\n".join(lines)


static func _kind_line(item: InventoryItem) -> String:
	var extra: Item = item.extra
	if extra is Weapon:
		return "Weapon"
	if extra is AmmoFeed:
		return "Magazine"
	if extra is Ammo:
		return "Ammo"
	if extra is Armor:
		return "Armor"
	if extra is Backpack:
		return "Backpack"
	return "Item"


static func _stat_line(item: InventoryItem) -> String:
	var extra: Item = item.extra
	if extra is Weapon:
		var w := extra as Weapon
		return "%d rpm   %s" % [int(w.firerate), _weapon_modes(w)]
	if extra is AmmoFeed:
		var feed := extra as AmmoFeed
		var cals := ", ".join(feed.compatible_calibers)
		return "Rounds %d/%d%s" % [feed.capacity, feed.max_capacity,
			("   " + cals) if cals != "" else ""]
	if extra is Ammo:
		var ammo := extra as Ammo
		return "%s   %.0f J" % [ammo.caliber, ammo.get_energy()]
	if extra is Armor:
		var armor := extra as Armor
		return "%s   Level %d   %d%%" % [
			_armor_type_name(armor), armor.level, armor.current_durability]
	if extra is Backpack:
		var pack := extra as Backpack
		return "Grid %dx%d" % [pack.grid_width, pack.grid_height]
	return ""


static func _weapon_modes(w: Weapon) -> String:
	var modes: Array[String] = []
	for m in [Firemode.AUTO, Firemode.SEMI, Firemode.BURST, Firemode.PUMP, Firemode.BOLT]:
		if w.is_firemode_available(m):
			modes.append(Firemode.get_mode(m))
	if modes.is_empty():
		return "SAFE"
	return "/".join(modes)


static func _armor_type_name(armor: Armor) -> String:
	match armor.type:
		Armor.ArmorType.HELMET:
			return "Helmet"
		Armor.ArmorType.VEST:
			return "Vest"
	return "Armor"

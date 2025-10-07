# generate_armor.gd
@tool
extends EditorScript

const OUTPUT_PATH = "res://addons/cabra.lat_shooters/src/resources/armor/"

func _run():
	var armor_list = []
	
	# ─── VPAM ARMORS ──────────────────────────────────
	armor_list.append(_create_armor("VPAM_PM1", "VPAM PM1 Armor", Armor.Standard.VPAM, 1, 
		"Stops .22 LR and similar low-energy rounds", 1.5, 80, 0.95))
	armor_list.append(_create_armor("VPAM_PM2", "VPAM PM2 Armor", Armor.Standard.VPAM, 2, 
		"Stops 9mm FMJ at 360 m/s", 2.0, 120, 0.92))
	armor_list.append(_create_armor("VPAM_PM3", "VPAM PM3 Armor", Armor.Standard.VPAM, 3, 
		"Stops 9mm FMJ at 415 m/s", 2.5, 150, 0.90))
	armor_list.append(_create_armor("VPAM_PM4", "VPAM PM4 Armor", Armor.Standard.VPAM, 4, 
		"Stops .357 Magnum and .44 Magnum", 3.0, 180, 0.88))
	armor_list.append(_create_armor("VPAM_PM5", "VPAM PM5 Armor", Armor.Standard.VPAM, 5, 
		"Stops .357 Magnum FMJ at 580 m/s", 3.5, 200, 0.85))
	armor_list.append(_create_armor("VPAM_PM6", "VPAM PM6 Armor", Armor.Standard.VPAM, 6, 
		"Stops 7.62x39mm PS steel core", 8.0, 300, 0.75))
	armor_list.append(_create_armor("VPAM_PM7", "VPAM PM7 Armor", Armor.Standard.VPAM, 7, 
		"Stops 5.56mm SS109 and 7.62x51mm DM111", 10.0, 350, 0.70))
	armor_list.append(_create_armor("VPAM_PM8", "VPAM PM8 Armor", Armor.Standard.VPAM, 8, 
		"Stops 7.62x39mm BZ API", 12.0, 400, 0.65))
	armor_list.append(_create_armor("VPAM_PM9", "VPAM PM9 Armor", Armor.Standard.VPAM, 9, 
		"Stops 7.62x51mm P80 AP", 15.0, 450, 0.60))
	
	# ─── NIJ ARMORS ───────────────────────────────────
	armor_list.append(_create_armor("NIJ_IIA", "NIJ Level IIA", Armor.Standard.NIJ, 2, 
		"Stops 9mm, .40 S&W, .45 ACP", 2.0, 100, 0.90))
	armor_list.append(_create_armor("NIJ_II", "NIJ Level II", Armor.Standard.NIJ, 3, 
		"Stops 9mm +P and .357 Magnum", 3.0, 150, 0.85))
	armor_list.append(_create_armor("NIJ_IIIA", "NIJ Level IIIA", Armor.Standard.NIJ, 6, 
		"Stops .357 SIG and .44 Magnum", 4.0, 200, 0.80))
	armor_list.append(_create_armor("NIJ_III", "NIJ Level III", Armor.Standard.NIJ, 7, 
		"Stops 7.62x51mm M80", 8.0, 300, 0.70))
	armor_list.append(_create_armor("NIJ_IV", "NIJ Level IV", Armor.Standard.NIJ, 9, 
		"Stops .30-06 M2 AP", 12.0, 400, 0.60))
	armor_list.append(_create_armor("NIJ_RF2", "NIJ RF2", Armor.Standard.NIJ, 8, 
		"Stops M855 green tip", 10.0, 350, 0.65))
	
	# ─── GOST ARMORS ──────────────────────────────────
	armor_list.append(_create_armor("GOST_BR1", "GOST BR1", Armor.Standard.GOST, 1, 
		"Stops 9x18mm Makarov", 2.0, 120, 0.92))
	armor_list.append(_create_armor("GOST_BR2", "GOST BR2", Armor.Standard.GOST, 2, 
		"Stops 9x21mm Gyurza", 3.0, 150, 0.88))
	armor_list.append(_create_armor("GOST_BR3", "GOST BR3", Armor.Standard.GOST, 3, 
		"Stops 9x19mm 7N21", 4.0, 180, 0.85))
	armor_list.append(_create_armor("GOST_BR4", "GOST BR4", Armor.Standard.GOST, 4, 
		"Stops 5.45mm and 7.62x39mm", 7.0, 250, 0.75))
	armor_list.append(_create_armor("GOST_BR5", "GOST BR5", Armor.Standard.GOST, 5, 
		"Stops 7.62x54mmR 7N13", 9.0, 300, 0.70))
	armor_list.append(_create_armor("GOST_BR6", "GOST BR6", Armor.Standard.GOST, 6, 
		"Stops 12.7mm B32 API", 15.0, 450, 0.55))
	
	# ─── MILITARY ARMORS ──────────────────────────────
	armor_list.append(_create_armor("SAPI", "Military SAPI", Armor.Standard.MILITARY, 1, 
		"Stops M855 and 7.62x51mm", 8.0, 350, 0.72))
	armor_list.append(_create_armor("ESAPI", "Military ESAPI", Armor.Standard.MILITARY, 2, 
		"Stops M995 AP and .30-06 AP", 12.0, 400, 0.62))
	
	# Save all armors
	for armor in armor_list:
		var safe_name = armor.name.replace(" ", "_").replace(".", "_")
		var path = OUTPUT_PATH + safe_name + ".tres"
		
		var error = ResourceSaver.save(armor, path)
		if error != OK:
			push_error("Failed to save armor %s: error %d" % [armor.name, error])
		else:
			print("Saved: %s" % path)
	
	print("Generated %d armor resources in %s" % [armor_list.size(), OUTPUT_PATH])

func _create_armor(name: String, display_name: String, standard: int, level: int, 
				  description: String, weight_kg: float, durability: int, 
				  armor_effectiveness: float) -> Armor:
	
	var armor = Armor.new()
	armor.name = display_name
	armor.description = description
	armor.standard = standard
	armor.level = level
	
	# Set material properties
	armor.material = BallisticMaterial.new()
	armor.material.armor_effectiveness = armor_effectiveness
	armor.material.hardness = _get_hardness_for_level(level)
	armor.material.toughness = _get_toughness_for_level(level)
	armor.material.density = _get_density_for_level(level)
	
	# Set durability
	armor.max_durability = durability
	armor.current_durability = durability
	
	# Set protection zones based on armor type
	_set_protection_zones(armor, standard, level)
	
	# Set penalties based on weight
	_set_movement_penalties(armor, weight_kg)
	
	return armor

func _get_hardness_for_level(level: int) -> float:
	# Higher level = harder materials (ceramics, steel)
	return 0.3 + (level * 0.05)

func _get_toughness_for_level(level: int) -> float:
	# Higher level = more toughness (composite materials)
	return 0.4 + (level * 0.04)

func _get_density_for_level(level: int) -> float:
	# Higher level = denser materials
	return 2.0 + (level * 0.3)

func _set_protection_zones(armor: Armor, standard: int, level: int):
	match standard:
		Armor.Standard.VPAM, Armor.Standard.NIJ, Armor.Standard.MILITARY:
			if level <= 3:  # Soft armor
				armor.protection_zones = Armor.BodyParts.THORAX | Armor.BodyParts.STOMACH
			else:  # Hard armor plates
				armor.protection_zones = Armor.BodyParts.THORAX
		Armor.Standard.GOST:
			# GOST typically covers more areas
			armor.protection_zones = Armor.BodyParts.THORAX | Armor.BodyParts.STOMACH | Armor.BodyParts.HEAD

func _set_movement_penalties(armor: Armor, weight_kg: float):
	# Heavier armor = more penalties
	var penalty_factor = weight_kg / 15.0  # Normalize to 15kg reference
	
	armor.turn_speed_penalty = -0.1 * penalty_factor
	armor.move_speed_penalty = -0.15 * penalty_factor
	armor.sound_reduction = -0.2 * penalty_factor

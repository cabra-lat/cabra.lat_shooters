# generate_projectiles.gd
# Run this as a tool script or from an EditorPlugin to generate ammo resources
@tool
extends EditorScript

const OUTPUT_PATH = "res://addons/cabra.lat_shooters/src/resources/ammo/"

func _run():
	var ammo_list = []

	# ─── VPAM ───────────────────────────────────────
	ammo_list.append(_create_enhanced_ammo("22_LR_VPAM_PM1", ".22 LR", 2.6, 360, Ammo.Type.FMJ, "VPAM PM1", 0.125, 40.0, 0.9, 1.0))
	ammo_list.append(_create_enhanced_ammo("9mm_VPAM_PM2", "9x19mm", 8.0, 360, Ammo.Type.FMJ, "VPAM PM2", 0.145, 45.0, 1.0, 1.0))
	ammo_list.append(_create_enhanced_ammo("9mm_VPAM_PM3", "9x19mm", 8.0, 415, Ammo.Type.FMJ, "VPAM PM3", 0.145, 52.0, 1.0, 1.0))
	ammo_list.append(_create_enhanced_ammo("357Mag_VPAM_PM4", ".357 Magnum", 10.2, 430, Ammo.Type.JSP, "VPAM PM4", 0.165, 65.0, 0.8, 1.2))
	ammo_list.append(_create_enhanced_ammo("44Mag_VPAM_PM4", ".44 Magnum", 15.6, 440, Ammo.Type.JSP, "VPAM PM4", 0.210, 85.0, 0.8, 1.2))
	ammo_list.append(_create_enhanced_ammo("357Mag_FMs_VPAM_PM5", ".357 Magnum FMs", 7.1, 580, Ammo.Type.FMJ, "VPAM PM5", 0.165, 70.0, 1.0, 1.0))
	ammo_list.append(_create_enhanced_ammo("762x39_PS_VPAM_PM6", "7.62x39mm PS", 8.0, 720, Ammo.Type.STEEL_CORE, "VPAM PM6", 0.275, 55.0, 1.2, 1.0))
	ammo_list.append(_create_enhanced_ammo("556_SS109_VPAM_PM7", "5.56x45mm SS109", 4.0, 950, Ammo.Type.GREEN_TIP, "VPAM PM7", 0.151, 42.0, 1.3, 0.9))
	ammo_list.append(_create_enhanced_ammo("762x51_DM111_VPAM_PM7", "7.62x51mm DM111", 9.55, 830, Ammo.Type.STEEL_CORE, "VPAM PM7", 0.405, 65.0, 1.2, 1.0))
	ammo_list.append(_create_enhanced_ammo("762x39_BZ_API_VPAM_PM8", "7.62x39mm BZ API", 7.7, 740, Ammo.Type.API, "VPAM PM8", 0.275, 60.0, 1.5, 0.8))
	ammo_list.append(_create_enhanced_ammo("762x51_P80_VPAM_PM9", "7.62x51mm P80 AP", 9.7, 820, Ammo.Type.AP, "VPAM PM9", 0.405, 70.0, 1.8, 0.8))
	ammo_list.append(_create_enhanced_ammo("762x54R_B32_VPAM_PM10", "7.62x54mmR B32 API", 10.4, 860, Ammo.Type.API, "VPAM PM10", 0.410, 85.0, 1.6, 0.8))
	ammo_list.append(_create_enhanced_ammo("762x51_M993_VPAM_PM11", "7.62x51mm M993 AP", 8.4, 930, Ammo.Type.AP, "VPAM PM11", 0.405, 75.0, 2.0, 0.7))
	ammo_list.append(_create_enhanced_ammo("762x51_SWISS_P_VPAM_PM12", "7.62x51mm Swiss P AP", 12.7, 810, Ammo.Type.AP, "VPAM PM12", 0.405, 90.0, 2.2, 0.7))
	ammo_list.append(_create_enhanced_ammo("127x99_SWISS_P_VPAM_PM13", "12.7x99mm Swiss P", 43.5, 930, Ammo.Type.AP, "VPAM PM13", 0.670, 150.0, 2.5, 0.6))
	ammo_list.append(_create_enhanced_ammo("145x114_B32_VPAM_PM14", "14.5x114mm B32 API", 63.4, 911, Ammo.Type.API, "VPAM PM14", 0.720, 200.0, 2.8, 0.6))

	# ─── NIJ (0101.06 + 0123.00) ────────────────────
	ammo_list.append(_create_enhanced_ammo("22_LR_NIJ_I", "22 LR", 2.6, 329, Ammo.Type.FMJ, "NIJ I", 0.125, 35.0, 0.9, 1.0))
	ammo_list.append(_create_enhanced_ammo("380_ACP_NIJ_I", ".380 ACP", 6.2, 322, Ammo.Type.FMJ, "NIJ I", 0.145, 40.0, 1.0, 1.0))
	ammo_list.append(_create_enhanced_ammo("9mm_NIJ_IIA", "9x19mm", 8.0, 373, Ammo.Type.FMJ, "NIJ IIA", 0.145, 45.0, 1.0, 1.0))
	ammo_list.append(_create_enhanced_ammo("40SW_NIJ_IIA", ".40 S&W", 11.7, 352, Ammo.Type.FMJ, "NIJ IIA", 0.165, 50.0, 1.0, 1.0))
	ammo_list.append(_create_enhanced_ammo("45ACP_NIJ_IIA", ".45 ACP", 14.9, 275, Ammo.Type.FMJ, "NIJ IIA", 0.230, 55.0, 1.0, 1.0))
	ammo_list.append(_create_enhanced_ammo("9mm_p_NIJ_II", "9mm +P", 8.0, 398, Ammo.Type.FMJ, "NIJ II", 0.145, 48.0, 1.0, 1.0))
	ammo_list.append(_create_enhanced_ammo("357Mag_NIJ_II", ".357 Magnum", 10.2, 436, Ammo.Type.JSP, "NIJ II", 0.165, 60.0, 0.8, 1.2))
	ammo_list.append(_create_enhanced_ammo("357SIG_NIJ_IIIA", ".357 SIG", 8.1, 448, Ammo.Type.FMJ, "NIJ IIIA", 0.145, 50.0, 1.0, 1.0))
	ammo_list.append(_create_enhanced_ammo("44Mag_NIJ_IIIA", ".44 Magnum", 15.6, 436, Ammo.Type.JHP, "NIJ IIIA", 0.210, 80.0, 0.6, 1.4))
	ammo_list.append(_create_enhanced_ammo("762x51_M80_NIJ_III", "7.62x51mm M80", 9.6, 847, Ammo.Type.FMJ, "NIJ III", 0.405, 65.0, 1.0, 1.0))
	ammo_list.append(_create_enhanced_ammo("3006_M2_AP_NIJ_IV", ".30-06 M2 AP", 10.8, 878, Ammo.Type.AP, "NIJ IV", 0.409, 75.0, 1.8, 0.8))
	# NIJ 0123.00
	ammo_list.append(_create_enhanced_ammo("556_M193_NIJ_RF1", "5.56x45mm M193", 3.56, 990, Ammo.Type.FMJ, "NIJ RF1", 0.151, 40.0, 1.0, 1.0))
	ammo_list.append(_create_enhanced_ammo("556_M855_NIJ_RF2", "5.56x45mm M855", 4.0, 950, Ammo.Type.GREEN_TIP, "NIJ RF2", 0.151, 42.0, 1.3, 0.9))

	# ─── GOST (2017) ────────────────────────────────
	ammo_list.append(_create_enhanced_ammo("9x18_Makarov_GOST_BR1", "9x18mm Makarov", 5.9, 335, Ammo.Type.STEEL_CORE, "GOST BR1", 0.130, 45.0, 1.2, 1.0))
	ammo_list.append(_create_enhanced_ammo("9x21_Gyurza_GOST_BR2", "9x21mm Gyurza", 7.93, 390, Ammo.Type.FMJ, "GOST BR2", 0.145, 50.0, 1.0, 1.0))
	ammo_list.append(_create_enhanced_ammo("9x19_7N21_GOST_BR3", "9x19mm 7N21", 5.2, 455, Ammo.Type.STEEL_CORE, "GOST BR3", 0.145, 48.0, 1.3, 0.9))
	ammo_list.append(_create_enhanced_ammo("545x39_7N10_GOST_BR4", "5.45x39mm 7N10", 3.4, 895, Ammo.Type.STEEL_CORE, "GOST BR4", 0.168, 38.0, 1.2, 1.0))
	ammo_list.append(_create_enhanced_ammo("762x39_PS_GOST_BR4", "7.62x39mm PS", 7.9, 720, Ammo.Type.STEEL_CORE, "GOST BR4", 0.275, 55.0, 1.2, 1.0))
	ammo_list.append(_create_enhanced_ammo("762x54R_7N13_GOST_BR5", "7.62x54mmR 7N13", 9.4, 830, Ammo.Type.STEEL_CORE, "GOST BR5", 0.410, 70.0, 1.3, 1.0))
	ammo_list.append(_create_enhanced_ammo("1270x108R_B32_GOST_BR6", "12.7×108mm 57-BZ-542 API", 48.2, 830, Ammo.Type.API, "GOST BR6", 0.410, 85.0, 1.6, 0.8))

	# ─── US MILITARY ────────────────────────────────
	ammo_list.append(_create_enhanced_ammo("556_M855_SAPI", "5.56x45mm M855", 4.0, 990, Ammo.Type.GREEN_TIP, "MIL SAPI", 0.151, 42.0, 1.3, 0.9))
	ammo_list.append(_create_enhanced_ammo("762x39_BZ_API_ISAPI", "7.62x39mm BZ API", 7.4, 730, Ammo.Type.API, "MIL ISAPI", 0.275, 58.0, 1.5, 0.8))
	ammo_list.append(_create_enhanced_ammo("3006_M2_AP_ESAPI", ".30-06 M2 AP", 10.8, 870, Ammo.Type.AP, "MIL ESAPI Rev G", 0.409, 75.0, 1.8, 0.8))
	ammo_list.append(_create_enhanced_ammo("556_M995_ESAPI", "5.56x45mm M995 AP", 3.6, 1020, Ammo.Type.M995, "MIL ESAPI Rev G", 0.151, 45.0, 2.2, 0.7))
	ammo_list.append(_create_enhanced_ammo("762x54R_7N1_ESAPI", "7.62x54mmR 7N1", 9.8, 820, Ammo.Type.STEEL_CORE, "MIL ESAPI Rev G", 0.410, 72.0, 1.3, 1.0))

	# ─── FRAGMENT SIMULATORS (FSP) ──────────────────
	ammo_list.append(_create_enhanced_ammo("FSP_2gr", "2gr FSP", 0.13, 830, Ammo.Type.FSP, "MIL FSP", 0.080, 8.0, 0.3, 1.2))
	ammo_list.append(_create_enhanced_ammo("FSP_4gr", "4gr FSP", 0.26, 730, Ammo.Type.FSP, "MIL FSP", 0.100, 12.0, 0.4, 1.2))
	ammo_list.append(_create_enhanced_ammo("FSP_16gr", "16gr FSP", 1.0, 620, Ammo.Type.FSP, "MIL FSP", 0.150, 25.0, 0.5, 1.2))
	ammo_list.append(_create_enhanced_ammo("FSP_64gr", "64gr FSP", 4.1, 510, Ammo.Type.FSP, "MIL FSP", 0.200, 35.0, 0.6, 1.2))

	# Save all
	for info in ammo_list:
		var ammo = info[0]
		var standard_ref = info[1]
		var safe_name = ammo.caliber.replace(".", "_").replace(" ", "_").replace("x", "_") + "_" + standard_ref.replace(" ", "_")
		var path = OUTPUT_PATH + safe_name + ".tres"
		
		# Set additional type-specific properties
		_set_type_specific_properties(ammo)
		
		var error = ResourceSaver.save(ammo, path)
		if error != OK:
			push_error("Failed to save ammo %s: error %d" % [ammo.name, error])
		else:
			print("Saved: %s" % path)
	
	print("Generated %d enhanced ammo resources in %s" % [ammo_list.size(), OUTPUT_PATH])

func _create_enhanced_ammo(name: String, caliber: String, 
				  mass_g: float, velocity_mps: float,
				  type: Ammo.Type, standard_ref: String,
				  ballistic_coefficient: float, base_damage: float,
				  armor_modifier: float, flesh_modifier: float) -> Array:
	
	var ammo = Ammo.new(mass_g, velocity_mps, type)
	ammo.name = name
	ammo.caliber = caliber
	ammo.description = "%s (%s)" % [caliber, standard_ref]
	
	# Set enhanced ballistic properties
	ammo.ballistic_coefficient = ballistic_coefficient
	ammo.base_damage = base_damage
	ammo.armor_modifier = armor_modifier
	ammo.flesh_modifier = flesh_modifier
	
	# Set bullet dimensions based on caliber
	_set_bullet_dimensions(ammo, caliber)
	
	# Set cartridge mass (typically 1.5-2x bullet mass)
	ammo.cartridge_mass = mass_g * _get_cartridge_multiplier(caliber)
	
	# Set penetration value based on type and modifiers
	ammo.penetration_value = _calculate_penetration_value(type, armor_modifier, mass_g, velocity_mps)
	
	# Set special properties based on ammo type
	_set_special_properties(ammo, type)
	
	return [ammo, standard_ref]

func _set_bullet_dimensions(ammo: Ammo, caliber: String):
	# Set bullet diameter and length based on caliber
	var dimensions = _get_caliber_dimensions(caliber)
	ammo.bullet_diameter = dimensions.diameter
	ammo.bullet_length = dimensions.length
	ammo.sectional_density = (ammo.bullet_mass / 1000.0) / (PI * pow(ammo.bullet_diameter / 2000.0, 2))

func _get_caliber_dimensions(caliber: String) -> Dictionary:
	var res = Utils.parse_caliber(caliber)
	return { "diameter": res["bore_mm"], "length": res["case_mm"] }

func _get_cartridge_multiplier(caliber: String) -> float:
	# Cartridge mass multiplier based on caliber type
	var multipliers = {
		"22 LR": 1.8,
		"9x19mm": 1.7,
		".357 Magnum": 1.6,
		".45 ACP": 1.5,
		"5.56x45mm": 1.9,
		"7.62x39mm": 1.8,
		"7.62x51mm": 1.7,
		"12.7x99mm": 1.6,
		"14.5x114mm": 1.5
	}
	return multipliers.get(caliber, 1.7)

func _calculate_penetration_value(type: Ammo.Type, armor_modifier: float, mass_g: float, velocity: float) -> float:
	# Base penetration calculation based on type and kinetic energy
	var base_energy = 0.5 * (mass_g / 1000.0) * pow(velocity, 2)
	var energy_factor = base_energy / 1000.0  # Normalize to ~1.0 for rifle rounds
	
	var type_base = {
		Ammo.Type.FMJ: 1.0,
		Ammo.Type.JSP: 1.1,
		Ammo.Type.JHP: 0.7,
		Ammo.Type.AP: 1.8,
		Ammo.Type.API: 1.6,
		Ammo.Type.STEEL_CORE: 1.3,
		Ammo.Type.GREEN_TIP: 1.4,
		Ammo.Type.M995: 2.0,
		Ammo.Type.FSP: 0.5
	}
	
	return type_base.get(type, 1.0) * armor_modifier * energy_factor

func _set_special_properties(ammo: Ammo, type: Ammo.Type):
	# Set type-specific special properties
	match type:
		Ammo.Type.API, Ammo.Type.INCENDIARY:
			ammo.incendiary_chance = 0.8
			ammo.ricochet_chance = 0.2
		Ammo.Type.JHP, Ammo.Type.HOLLOW_POINT:
			ammo.bleeding_chance = 0.6
			ammo.fragment_chance = 0.4
			ammo.ricochet_chance = 0.1
		Ammo.Type.AP, Ammo.Type.M995:
			ammo.armor_damage = 0.8
			ammo.ricochet_chance = 0.3
		Ammo.Type.FSP:
			ammo.fragmentation_chance = 1.0
			ammo.ricochet_chance = 0.1
		Ammo.Type.TRACER:
			ammo.tracer_duration = 2.5
		Ammo.Type.FMJ:
			ammo.ricochet_chance = 0.2
			ammo.armor_damage = 0.3

func _set_type_specific_properties(ammo: Ammo):
	# Set additional gameplay properties based on type
	var type_props = ammo.get_type_modifiers()
	
	# Apply type-specific accuracy modifiers
	var accuracy_modifiers = {
		Ammo.Type.FMJ: 1.0,
		Ammo.Type.JHP: 1.1,
		Ammo.Type.AP: 0.9,
		Ammo.Type.STEEL_CORE: 1.0,
		Ammo.Type.GREEN_TIP: 1.0,
		Ammo.Type.FSP: 0.7
	}
	ammo.accuracy *= accuracy_modifiers.get(ammo.type, 1.0)
	
	# Set ricochet angles based on bullet type
	var ricochet_angles = {
		Ammo.Type.FMJ: 25.0,
		Ammo.Type.JHP: 20.0,
		Ammo.Type.AP: 30.0,
		Ammo.Type.STEEL_CORE: 28.0,
		Ammo.Type.GREEN_TIP: 27.0,
		Ammo.Type.FSP: 15.0
	}
	ammo.ricochet_angle = ricochet_angles.get(ammo.type, 25.0)

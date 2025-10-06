# generate_projectiles.gd
# Run this as a tool script or from an EditorPlugin to generate ammo resources
@tool
extends EditorScript

const OUTPUT_PATH = "res://addons/cabra.lat_shooters/src/resources/ammo/"

func _run():
	var ammo_list = []

	# ─── VPAM ───────────────────────────────────────
	ammo_list.append(_create_ammo("22_LR_VPAM_PM1", "22 LR", 2.6, 360, Ammo.Type.FMJ, "VPAM PM1"))
	ammo_list.append(_create_ammo("9mm_VPAM_PM2", "9x19mm", 8.0, 360, Ammo.Type.FMJ, "VPAM PM2"))
	ammo_list.append(_create_ammo("9mm_VPAM_PM3", "9x19mm", 8.0, 415, Ammo.Type.FMJ, "VPAM PM3"))
	ammo_list.append(_create_ammo("357Mag_VPAM_PM4", ".357 Magnum", 10.2, 430, Ammo.Type.JSP, "VPAM PM4"))
	ammo_list.append(_create_ammo("44Mag_VPAM_PM4", ".44 Magnum", 15.6, 440, Ammo.Type.JSP, "VPAM PM4"))
	ammo_list.append(_create_ammo("357Mag_FMs_VPAM_PM5", ".357 Magnum FMs", 7.1, 580, Ammo.Type.FMJ, "VPAM PM5"))
	ammo_list.append(_create_ammo("762x39_PS_VPAM_PM6", "7.62x39mm PS", 8.0, 720, Ammo.Type.STEEL_CORE, "VPAM PM6"))
	ammo_list.append(_create_ammo("556_SS109_VPAM_PM7", "5.56x45mm SS109", 4.0, 950, Ammo.Type.GREEN_TIP, "VPAM PM7"))
	ammo_list.append(_create_ammo("762x51_DM111_VPAM_PM7", "7.62x51mm DM111", 9.55, 830, Ammo.Type.STEEL_CORE, "VPAM PM7"))
	ammo_list.append(_create_ammo("762x39_BZ_API_VPAM_PM8", "7.62x39mm BZ API", 7.7, 740, Ammo.Type.API, "VPAM PM8"))
	ammo_list.append(_create_ammo("762x51_P80_VPAM_PM9", "7.62x51mm P80 AP", 9.7, 820, Ammo.Type.AP, "VPAM PM9"))
	ammo_list.append(_create_ammo("762x54R_B32_VPAM_PM10", "7.62x54mmR B32 API", 10.4, 860, Ammo.Type.API, "VPAM PM10"))
	ammo_list.append(_create_ammo("762x51_M993_VPAM_PM11", "7.62x51mm M993 AP", 8.4, 930, Ammo.Type.AP, "VPAM PM11"))
	ammo_list.append(_create_ammo("762x51_SWISS_P_VPAM_PM12", "7.62x51mm Swiss P AP", 12.7, 810, Ammo.Type.AP, "VPAM PM12"))
	ammo_list.append(_create_ammo("127x99_SWISS_P_VPAM_PM13", "12.7x99mm Swiss P", 43.5, 930, Ammo.Type.AP, "VPAM PM13"))
	ammo_list.append(_create_ammo("145x114_B32_VPAM_PM14", "14.5x114mm B32 API", 63.4, 911, Ammo.Type.API, "VPAM PM14"))

	# ─── NIJ (0101.06 + 0123.00) ────────────────────
	ammo_list.append(_create_ammo("22_LR_NIJ_I", "22 LR", 2.6, 329, Ammo.Type.FMJ, "NIJ I"))
	ammo_list.append(_create_ammo("380_ACP_NIJ_I", ".380 ACP", 6.2, 322, Ammo.Type.FMJ, "NIJ I"))
	ammo_list.append(_create_ammo("9mm_NIJ_IIA", "9x19mm", 8.0, 373, Ammo.Type.FMJ, "NIJ IIA"))
	ammo_list.append(_create_ammo("40SW_NIJ_IIA", ".40 S&W", 11.7, 352, Ammo.Type.FMJ, "NIJ IIA"))
	ammo_list.append(_create_ammo("45ACP_NIJ_IIA", ".45 ACP", 14.9, 275, Ammo.Type.FMJ, "NIJ IIA"))
	ammo_list.append(_create_ammo("9mm_p_NIJ_II", "9mm +P", 8.0, 398, Ammo.Type.FMJ, "NIJ II"))
	ammo_list.append(_create_ammo("357Mag_NIJ_II", ".357 Magnum", 10.2, 436, Ammo.Type.JSP, "NIJ II"))
	ammo_list.append(_create_ammo("357SIG_NIJ_IIIA", ".357 SIG", 8.1, 448, Ammo.Type.FMJ, "NIJ IIIA"))
	ammo_list.append(_create_ammo("44Mag_NIJ_IIIA", ".44 Magnum", 15.6, 436, Ammo.Type.JHP, "NIJ IIIA"))
	ammo_list.append(_create_ammo("762x51_M80_NIJ_III", "7.62x51mm M80", 9.6, 847, Ammo.Type.FMJ, "NIJ III"))
	ammo_list.append(_create_ammo("3006_M2_AP_NIJ_IV", ".30-06 M2 AP", 10.8, 878, Ammo.Type.AP, "NIJ IV"))
	# NIJ 0123.00
	ammo_list.append(_create_ammo("556_M193_NIJ_RF1", "5.56x45mm M193", 56/15.432, 990, Ammo.Type.FMJ, "NIJ RF1"))  # 56gr → g
	ammo_list.append(_create_ammo("556_M855_NIJ_RF2", "5.56x45mm M855", 62/15.432, 950, Ammo.Type.GREEN_TIP, "NIJ RF2"))  # 62gr

	# ─── GOST (2017) ────────────────────────────────
	ammo_list.append(_create_ammo("9x18_Makarov_GOST_BR1", "9x18mm Makarov", 5.9, 335, Ammo.Type.STEEL_CORE, "GOST BR1"))
	ammo_list.append(_create_ammo("9x21_Gyurza_GOST_BR2", "9x21mm Gyurza", 7.93, 390, Ammo.Type.FMJ, "GOST BR2"))
	ammo_list.append(_create_ammo("9x19_7N21_GOST_BR3", "9x19mm 7N21", 5.2, 455, Ammo.Type.STEEL_CORE, "GOST BR3"))
	ammo_list.append(_create_ammo("545x39_7N10_GOST_BR4", "5.45x39mm 7N10", 3.4, 895, Ammo.Type.STEEL_CORE, "GOST BR4"))
	ammo_list.append(_create_ammo("762x39_PS_GOST_BR4", "7.62x39mm PS", 7.9, 720, Ammo.Type.STEEL_CORE, "GOST BR4"))
	ammo_list.append(_create_ammo("762x54R_7N13_GOST_BR5", "7.62x54mmR 7N13", 9.4, 830, Ammo.Type.STEEL_CORE, "GOST BR5"))
	ammo_list.append(_create_ammo("762x54R_B32_GOST_BR6", "7.62x54mmR B32 API", 48.2, 830, Ammo.Type.API, "GOST BR6"))

	# ─── US MILITARY ────────────────────────────────
	ammo_list.append(_create_ammo("556_M855_SAPI", "5.56x45mm M855", 4.0, 990, Ammo.Type.GREEN_TIP, "MIL SAPI"))
	ammo_list.append(_create_ammo("762x39_BZ_API_ISAPI", "7.62x39mm BZ API", 7.4, 730, Ammo.Type.API, "MIL ISAPI"))
	ammo_list.append(_create_ammo("3006_M2_AP_ESAPI", ".30-06 M2 AP", 10.8, 870, Ammo.Type.AP, "MIL ESAPI Rev G"))
	ammo_list.append(_create_ammo("556_M995_ESAPI", "5.56x45mm M995 AP", 3.6, 1020, Ammo.Type.M995, "MIL ESAPI Rev G"))
	ammo_list.append(_create_ammo("762x54R_7N1_ESAPI", "7.62x54mmR 7N1", 9.8, 820, Ammo.Type.STEEL_CORE, "MIL ESAPI Rev G"))

	# ─── FRAGMENT SIMULATORS (FSP) ──────────────────
	ammo_list.append(_create_ammo("FSP_2gr", "2gr FSP", 0.13, 830, Ammo.Type.FSP, "MIL FSP"))
	ammo_list.append(_create_ammo("FSP_4gr", "4gr FSP", 0.26, 730, Ammo.Type.FSP, "MIL FSP"))
	ammo_list.append(_create_ammo("FSP_16gr", "16gr FSP", 1.0, 620, Ammo.Type.FSP, "MIL FSP"))
	ammo_list.append(_create_ammo("FSP_64gr", "64gr FSP", 4.1, 510, Ammo.Type.FSP, "MIL FSP"))

	# Save all
	for ammo in ammo_list:
		var safe_name = ammo.caliber.replace(".", "_").replace(" ", "_").replace("x", "_") + "_" + ammo.standard_ref.replace(" ", "_")
		var path = OUTPUT_PATH + safe_name + ".tres"
		ResourceSaver.save(ammo, path)
	
	print("Generated %d ammo resources in %s" % [ammo_list.size(), OUTPUT_PATH])

func _create_ammo(name: String, caliber: String, mass_g: float, velocity_mps: float, type: Ammo.Type, standard_ref: String) -> Ammo:
	var ammo = Ammo.new(mass_g, velocity_mps, type)
	ammo.caliber = caliber
	ammo.standard_ref = standard_ref
	ammo.description = "%s (%s)" % [caliber, standard_ref]
	return ammo

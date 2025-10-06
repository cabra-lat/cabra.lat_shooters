# generate_attachments.gd
@tool
extends EditorScript

const OUTPUT_PATH = "res://addons/cabra.lat_shooters/src/resources/attachments/"

func _run():
	var attachments = []

	# ─── OPTICS ──────────────────────────────────────
	attachments.append(_create_red_dot_sight(
		"Aimpoint_T1", 0.12, 1.0, 
		0.9, 0.95, 1.1, 0.95, 1.05
	))
	
	attachments.append(_create_holo_sight(
		"EOTech_EXPS3", 0.25, 1.0,
		0.85, 0.9, 1.15, 0.9, 1.1
	))
	
	attachments.append(_create_scope(
		"ACOG_4x32", 0.45, 4.0, Attachment.ReticleType.CHEVRON,
		0.7, 0.8, 1.2, 0.8, 0.9
	))
	
	attachments.append(_create_scope(
		"Vortex_Razor_1-6x", 0.65, 6.0, Attachment.ReticleType.BDC,
		0.65, 0.75, 1.3, 0.75, 0.85
	))

	# ─── MUZZLE DEVICES ──────────────────────────────
	attachments.append(_create_suppressor(
		"Surefire_SOCOM556", 0.35, 0.8, 0.9, 0.3,
		0.95, 0.85, 1.05, 1.0, 0.95
	))
	
	attachments.append(_create_compensator(
		"JP_Enterprises_Comp", 0.18, 0.15,
		1.0, 0.7, 1.0, 1.0, 1.0
	))
	
	attachments.append(_create_flash_hider(
		"A2_Flash_Hider", 0.08, 0.6,
		1.0, 0.9, 1.0, 1.0, 1.0
	))

	# ─── UNDERBARREL ─────────────────────────────────
	attachments.append(_create_vertical_grip(
		"Magpul_AFG", 0.12, 0.8,
		1.05, 0.85, 1.1, 1.0, 1.05
	))
	
	attachments.append(_create_bipod(
		"Harris_Bipod", 0.45, true, 1.5,
		1.1, 0.6, 1.15, 1.0, 1.1
	))
	
	attachments.append(_create_angled_grip(
		"BCM_Gunfighter", 0.09, 0.9,
		1.03, 0.88, 1.08, 1.0, 1.03
	))

	# ─── LASERS & LIGHTS ─────────────────────────────
	attachments.append(_create_laser(
		"PEQ-15", 0.25, 200.0,
		1.0, 1.0, 1.0, 1.0, 1.05
	))
	
	attachments.append(_create_light(
		"Surefire_M600", 0.18, 150.0,
		1.0, 1.0, 1.0, 1.0, 1.0
	))
	
	attachments.append(_create_laser_light_combo(
		"Steiner_DBAL", 0.32, 200.0, 100.0,
		1.0, 1.0, 1.0, 1.0, 1.05
	))

	# ─── MAGAZINES ───────────────────────────────────
	attachments.append(_create_extended_mag(
		"Magpul_PMAG_40", 0.25, 1.33, # 30 → 40 rounds
		1.0, 1.0, 0.95, 0.9, 1.0
	))
	
	attachments.append(_create_drum_mag(
		"Magpul_D60", 0.85, 2.0, # 30 → 60 rounds
		1.0, 1.0, 0.85, 0.8, 1.0
	))

	# Save all attachments
	for attachment in attachments:
		var safe_name = attachment.name.replace(" ", "_").replace("-", "_")
		var path = OUTPUT_PATH + safe_name + ".tres"
		var error = ResourceSaver.save(attachment, path)
		if error != OK:
			push_error("Failed to save attachment %s: error %d" % [attachment.name, error])
		else:
			print("Saved: %s" % path)
	
	print("Generated %d attachment resources in %s" % [attachments.size(), OUTPUT_PATH])

# ─── OPTICS CREATION HELPERS ──────────────────────

func _create_red_dot_sight(name: String, mass: float, magnification: float,
						  accuracy: float, recoil: float, ergo: float, 
						  reload: float, ads: float) -> Attachment:
	var attachment = Attachment.new()
	attachment.name = name
	attachment.type = Attachment.AttachmentType.OPTICS
	attachment.attachment_point = Weapon.AttachmentPoint.TOP_RAIL
	attachment.mass = mass
	attachment.magnification = magnification
	attachment.reticle_type = Attachment.ReticleType.DOT
	attachment.accuracy_modifier = accuracy
	attachment.recoil_modifier = recoil
	attachment.ergonomics_modifier = ergo
	attachment.reload_speed_modifier = reload
	attachment.aim_down_sights_modifier = ads
	return attachment

func _create_holo_sight(name: String, mass: float, magnification: float,
					   accuracy: float, recoil: float, ergo: float,
					   reload: float, ads: float) -> Attachment:
	var attachment = Attachment.new()
	attachment.name = name
	attachment.type = Attachment.AttachmentType.OPTICS
	attachment.attachment_point = Weapon.AttachmentPoint.TOP_RAIL
	attachment.mass = mass
	attachment.magnification = magnification
	attachment.reticle_type = Attachment.ReticleType.CIRCLE_DOT
	attachment.accuracy_modifier = accuracy
	attachment.recoil_modifier = recoil
	attachment.ergonomics_modifier = ergo
	attachment.reload_speed_modifier = reload
	attachment.aim_down_sights_modifier = ads
	return attachment

func _create_scope(name: String, mass: float, magnification: float, 
				  reticle: int, accuracy: float, recoil: float, 
				  ergo: float, reload: float, ads: float) -> Attachment:
	var attachment = Attachment.new()
	attachment.name = name
	attachment.type = Attachment.AttachmentType.OPTICS
	attachment.attachment_point = Weapon.AttachmentPoint.TOP_RAIL
	attachment.mass = mass
	attachment.magnification = magnification
	attachment.reticle_type = reticle
	attachment.zero_distance = 100.0
	attachment.accuracy_modifier = accuracy
	attachment.recoil_modifier = recoil
	attachment.ergonomics_modifier = ergo
	attachment.reload_speed_modifier = reload
	attachment.aim_down_sights_modifier = ads
	return attachment

# ─── MUZZLE DEVICE HELPERS ────────────────────────

func _create_suppressor(name: String, mass: float, sound_suppress: float,
					   flash_suppress: float, recoil_reduce: float,
					   accuracy: float, recoil: float, ergo: float,
					   reload: float, ads: float) -> Attachment:
	var attachment = Attachment.new()
	attachment.name = name
	attachment.type = Attachment.AttachmentType.MUZZLE
	attachment.attachment_point = Weapon.AttachmentPoint.MUZZLE
	attachment.mass = mass
	attachment.sound_suppression = sound_suppress
	attachment.flash_suppression = flash_suppress
	attachment.recoil_reduction = recoil_reduce
	attachment.accuracy_modifier = accuracy
	attachment.recoil_modifier = recoil
	attachment.ergonomics_modifier = ergo
	attachment.reload_speed_modifier = reload
	attachment.aim_down_sights_modifier = ads
	return attachment

func _create_compensator(name: String, mass: float, recoil_reduce: float,
						accuracy: float, recoil: float, ergo: float,
						reload: float, ads: float) -> Attachment:
	var attachment = Attachment.new()
	attachment.name = name
	attachment.type = Attachment.AttachmentType.MUZZLE
	attachment.attachment_point = Weapon.AttachmentPoint.MUZZLE
	attachment.mass = mass
	attachment.recoil_reduction = recoil_reduce
	attachment.accuracy_modifier = accuracy
	attachment.recoil_modifier = recoil
	attachment.ergonomics_modifier = ergo
	attachment.reload_speed_modifier = reload
	attachment.aim_down_sights_modifier = ads
	return attachment

func _create_flash_hider(name: String, mass: float, flash_suppress: float,
						accuracy: float, recoil: float, ergo: float,
						reload: float, ads: float) -> Attachment:
	var attachment = Attachment.new()
	attachment.name = name
	attachment.type = Attachment.AttachmentType.MUZZLE
	attachment.attachment_point = Weapon.AttachmentPoint.MUZZLE
	attachment.mass = mass
	attachment.flash_suppression = flash_suppress
	attachment.accuracy_modifier = accuracy
	attachment.recoil_modifier = recoil
	attachment.ergonomics_modifier = ergo
	attachment.reload_speed_modifier = reload
	attachment.aim_down_sights_modifier = ads
	return attachment

# ─── UNDERBARREL HELPERS ──────────────────────────

func _create_vertical_grip(name: String, mass: float, stability: float,
						  accuracy: float, recoil: float, ergo: float,
						  reload: float, ads: float) -> Attachment:
	var attachment = Attachment.new()
	attachment.name = name
	attachment.type = Attachment.AttachmentType.UNDERBARREL
	attachment.attachment_point = Weapon.AttachmentPoint.UNDER
	attachment.mass = mass
	attachment.stability_bonus = stability
	attachment.accuracy_modifier = accuracy
	attachment.recoil_modifier = recoil
	attachment.ergonomics_modifier = ergo
	attachment.reload_speed_modifier = reload
	attachment.aim_down_sights_modifier = ads
	return attachment

func _create_angled_grip(name: String, mass: float, stability: float,
						accuracy: float, recoil: float, ergo: float,
						reload: float, ads: float) -> Attachment:
	var attachment = Attachment.new()
	attachment.name = name
	attachment.type = Attachment.AttachmentType.UNDERBARREL
	attachment.attachment_point = Weapon.AttachmentPoint.UNDER
	attachment.mass = mass
	attachment.stability_bonus = stability
	attachment.accuracy_modifier = accuracy
	attachment.recoil_modifier = recoil
	attachment.ergonomics_modifier = ergo
	attachment.reload_speed_modifier = reload
	attachment.aim_down_sights_modifier = ads
	return attachment

func _create_bipod(name: String, mass: float, deployable: bool, stability: float,
				  accuracy: float, recoil: float, ergo: float,
				  reload: float, ads: float) -> Attachment:
	var attachment = Attachment.new()
	attachment.name = name
	attachment.type = Attachment.AttachmentType.UNDERBARREL
	attachment.attachment_point = Weapon.AttachmentPoint.UNDER
	attachment.mass = mass
	attachment.deployable = deployable
	attachment.stability_bonus = stability
	attachment.accuracy_modifier = accuracy
	attachment.recoil_modifier = recoil
	attachment.ergonomics_modifier = ergo
	attachment.reload_speed_modifier = reload
	attachment.aim_down_sights_modifier = ads
	return attachment

# ─── LASER/LIGHT HELPERS ──────────────────────────

func _create_laser(name: String, mass: float, range: float,
				  accuracy: float, recoil: float, ergo: float,
				  reload: float, ads: float) -> Attachment:
	var attachment = Attachment.new()
	attachment.name = name
	attachment.type = Attachment.AttachmentType.LASER
	attachment.attachment_point = Weapon.AttachmentPoint.LEFT_RAIL | Weapon.AttachmentPoint.RIGHT_RAIL
	attachment.mass = mass
	attachment.laser_range = range
	attachment.accuracy_modifier = accuracy
	attachment.recoil_modifier = recoil
	attachment.ergonomics_modifier = ergo
	attachment.reload_speed_modifier = reload
	attachment.aim_down_sights_modifier = ads
	return attachment

func _create_light(name: String, mass: float, range: float,
				  accuracy: float, recoil: float, ergo: float,
				  reload: float, ads: float) -> Attachment:
	var attachment = Attachment.new()
	attachment.name = name
	attachment.type = Attachment.AttachmentType.LIGHT
	attachment.attachment_point = Weapon.AttachmentPoint.LEFT_RAIL | Weapon.AttachmentPoint.RIGHT_RAIL
	attachment.mass = mass
	attachment.light_range = range
	attachment.accuracy_modifier = accuracy
	attachment.recoil_modifier = recoil
	attachment.ergonomics_modifier = ergo
	attachment.reload_speed_modifier = reload
	attachment.aim_down_sights_modifier = ads
	return attachment

func _create_laser_light_combo(name: String, mass: float, laser_range: float,
							  light_range: float, accuracy: float, recoil: float,
							  ergo: float, reload: float, ads: float) -> Attachment:
	var attachment = Attachment.new()
	attachment.name = name
	attachment.type = Attachment.AttachmentType.LASER
	attachment.attachment_point = Weapon.AttachmentPoint.LEFT_RAIL | Weapon.AttachmentPoint.RIGHT_RAIL
	attachment.mass = mass
	attachment.laser_range = laser_range
	attachment.light_range = light_range
	attachment.accuracy_modifier = accuracy
	attachment.recoil_modifier = recoil
	attachment.ergonomics_modifier = ergo
	attachment.reload_speed_modifier = reload
	attachment.aim_down_sights_modifier = ads
	return attachment

# ─── MAGAZINE HELPERS ─────────────────────────────

func _create_extended_mag(name: String, mass: float, capacity_mult: float,
						 accuracy: float, recoil: float, ergo: float,
						 reload: float, ads: float) -> Attachment:
	var attachment = Attachment.new()
	attachment.name = name
	attachment.type = Attachment.AttachmentType.MAGAZINE
	attachment.attachment_point = 0  # Magazine replaces the default magazine
	attachment.mass = mass
	attachment.capacity_multiplier = capacity_mult
	attachment.accuracy_modifier = accuracy
	attachment.recoil_modifier = recoil
	attachment.ergonomics_modifier = ergo
	attachment.reload_speed_modifier = reload
	attachment.aim_down_sights_modifier = ads
	return attachment

func _create_drum_mag(name: String, mass: float, capacity_mult: float,
					 accuracy: float, recoil: float, ergo: float,
					 reload: float, ads: float) -> Attachment:
	var attachment = Attachment.new()
	attachment.name = name
	attachment.type = Attachment.AttachmentType.MAGAZINE
	attachment.attachment_point = 0  # Magazine replaces the default magazine
	attachment.mass = mass
	attachment.capacity_multiplier = capacity_mult
	attachment.accuracy_modifier = accuracy
	attachment.recoil_modifier = recoil
	attachment.ergonomics_modifier = ergo
	attachment.reload_speed_modifier = reload
	attachment.aim_down_sights_modifier = ads
	return attachment

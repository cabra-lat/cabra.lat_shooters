# generate_weapons.gd
# Run this as a tool script to generate weapon resources
@tool
extends EditorScript

const OUTPUT_PATH = "res://addons/cabra.lat_shooters/src/resources/weapons/"

func _run():
	var weapons = []

	# ─── PISTOLS ─────────────────────────────────────
	weapons.append(_create_pistol(
		"Glock_17", "9x19mm", 0.62, 1200, 17,
		[Weapon.Firemode.SEMI], AmmoFeed.Type.EXTERNAL,
		2.0, 1.5, 4.0, 0.8, 0.3
	))
	
	weapons.append(_create_pistol(
		"Colt_M1911", ".45 ACP", 1.1, 850, 7,
		[Weapon.Firemode.SEMI], AmmoFeed.Type.EXTERNAL,
		2.2, 1.8, 5.0, 1.2, 0.4
	))
	
	weapons.append(_create_pistol(
		"Desert_Eagle", ".44 Magnum", 2.0, 600, 8,
		[Weapon.Firemode.SEMI], AmmoFeed.Type.EXTERNAL,
		2.5, 2.5, 8.0, 2.5, 0.8
	))

	# ─── SUBMACHINE GUNS ────────────────────────────
	weapons.append(_create_smg(
		"HK_MP5", "9x19mm", 2.5, 800, 30,
		[Weapon.Firemode.SEMI, Weapon.Firemode.AUTO, Weapon.Firemode.BURST], 
		AmmoFeed.Type.EXTERNAL,
		1.8, 1.2, 3.0, 0.6, 0.2
	))
	
	weapons.append(_create_smg(
		"UZI", "9x19mm", 3.5, 600, 32,
		[Weapon.Firemode.SEMI, Weapon.Firemode.AUTO],
		AmmoFeed.Type.EXTERNAL,
		2.0, 1.5, 4.0, 0.8, 0.3
	))

	# ─── ASSAULT RIFLES ─────────────────────────────
	weapons.append(_create_assault_rifle(
		"AK-47", "7.62x39mm", 4.3, 600, 30,
		[Weapon.Firemode.SEMI, Weapon.Firemode.AUTO],
		AmmoFeed.Type.EXTERNAL,
		2.5, 1.0, 4.0, 1.5, 0.6
	))
	
	weapons.append(_create_assault_rifle(
		"AK-74", "5.45x39mm", 3.6, 650, 30,
		[Weapon.Firemode.SEMI, Weapon.Firemode.AUTO],
		AmmoFeed.Type.EXTERNAL,
		2.3, 0.8, 3.0, 1.0, 0.4
	))
	
	weapons.append(_create_assault_rifle(
		"M4_Carbine", "5.56x45mm", 3.4, 800, 30,
		[Weapon.Firemode.SEMI, Weapon.Firemode.AUTO, Weapon.Firemode.BURST],
		AmmoFeed.Type.EXTERNAL,
		2.2, 0.7, 2.5, 0.8, 0.3
	))
	
	weapons.append(_create_assault_rifle(
		"FN_FAL", "7.62x51mm", 4.5, 650, 20,
		[Weapon.Firemode.SEMI, Weapon.Firemode.AUTO],
		AmmoFeed.Type.EXTERNAL,
		3.0, 1.2, 3.5, 2.0, 0.8
	))

	# ─── BATTLE RIFLES / DMR ────────────────────────
	weapons.append(_create_dmr(
		"M14", "7.62x51mm", 5.1, 750, 20,
		[Weapon.Firemode.SEMI, Weapon.Firemode.AUTO],
		AmmoFeed.Type.EXTERNAL,
		3.5, 1.0, 2.0, 2.2, 0.9
	))
	
	weapons.append(_create_dmr(
		"Dragunov_SVD", "7.62x54mmR", 4.3, 650, 10,
		[Weapon.Firemode.SEMI],
		AmmoFeed.Type.EXTERNAL,
		4.0, 1.5, 1.5, 2.5, 1.0
	))

	# ─── SNIPER RIFLES ──────────────────────────────
	weapons.append(_create_sniper(
		"Remington_700", ".30-06", 4.5, 30, 5,
		[Weapon.Firemode.BOLT],
		AmmoFeed.Type.INTERNAL,
		5.0, 3.0, 1.0, 3.5, 1.2
	))
	
	weapons.append(_create_sniper(
		"Barrett_M82", "12.7x99mm", 14.0, 50, 10,
		[Weapon.Firemode.SEMI],
		AmmoFeed.Type.EXTERNAL,
		6.0, 4.0, 1.5, 8.0, 3.0
	))

	# ─── SHOTGUNS ───────────────────────────────────
	weapons.append(_create_shotgun(
		"Mossberg_500", "12 Gauge", 3.4, 60, 8,
		[Weapon.Firemode.PUMP],
		AmmoFeed.Type.INTERNAL,
		3.5, 2.5, 8.0, 3.0, 1.0
	))
	
	weapons.append(_create_shotgun(
		"Saiga_12", "12 Gauge", 3.6, 300, 10,
		[Weapon.Firemode.SEMI, Weapon.Firemode.AUTO],
		AmmoFeed.Type.EXTERNAL,
		3.0, 2.0, 6.0, 2.5, 0.8
	))

	# ─── LIGHT MACHINE GUNS ─────────────────────────
	weapons.append(_create_lmg(
		"PKM", "7.62x54mmR", 9.0, 650, 100,
		[Weapon.Firemode.AUTO],
		AmmoFeed.Type.EXTERNAL,
		4.5, 3.0, 4.0, 1.8, 0.7
	))
	
	weapons.append(_create_lmg(
		"M249", "5.56x45mm", 7.5, 850, 200,
		[Weapon.Firemode.AUTO],
		AmmoFeed.Type.EXTERNAL,
		3.5, 2.5, 3.5, 1.2, 0.5
	))

	# Save all weapons
	for weapon in weapons:
		var safe_name = weapon.name.replace(" ", "_").replace("-", "_")
		var path = OUTPUT_PATH + safe_name + ".tres"
		var error = ResourceSaver.save(weapon, path)
		if error != OK:
			push_error("Failed to save weapon %s: error %d" % [weapon.name, error])
		else:
			print("Saved: %s" % path)
	
	print("Generated %d weapon resources in %s" % [weapons.size(), OUTPUT_PATH])

# ─── WEAPON CREATION HELPERS ──────────────────────

func _create_pistol(name: String, caliber: String, mass: float, firerate: int, 
				   magazine_size: int, firemodes: Array, feed_type: int,
				   reload_time: float, accuracy: float, recoil_v: float, 
				   recoil_h: float, extra: float) -> Weapon:
	var weapon = Weapon.new()
	weapon.name = name
	weapon.mass = mass
	weapon.firerate = firerate
	weapon.base_reload_time = reload_time
	weapon.base_accuracy = accuracy
	weapon.recoil_vertical = recoil_v
	weapon.recoil_horizontal = recoil_h
	weapon.feed_type = feed_type
	
	# Set firemodes
	weapon.firemodes = _firemodes_to_bitmask(firemodes)
	
	# Pistol attachment points
	weapon.attach_points = (
		Weapon.AttachmentPoint.MUZZLE | 
		Weapon.AttachmentPoint.LEFT_RAIL | 
		Weapon.AttachmentPoint.RIGHT_RAIL
	)
	
	# Create compatible ammo feed
	weapon.ammofeed = _create_ammo_feed(caliber, magazine_size, feed_type)
	
	return weapon

func _create_smg(name: String, caliber: String, mass: float, firerate: int,
				magazine_size: int, firemodes: Array, feed_type: int,
				reload_time: float, accuracy: float, recoil_v: float,
				recoil_h: float, extra: float) -> Weapon:
	var weapon = Weapon.new()
	weapon.name = name
	weapon.mass = mass
	weapon.firerate = firerate
	weapon.base_reload_time = reload_time
	weapon.base_accuracy = accuracy
	weapon.recoil_vertical = recoil_v
	weapon.recoil_horizontal = recoil_h
	weapon.feed_type = feed_type
	
	weapon.firemodes = _firemodes_to_bitmask(firemodes)
	
	# SMG attachment points
	weapon.attach_points = (
		Weapon.AttachmentPoint.MUZZLE |
		Weapon.AttachmentPoint.LEFT_RAIL |
		Weapon.AttachmentPoint.RIGHT_RAIL |
		Weapon.AttachmentPoint.TOP_RAIL |
		Weapon.AttachmentPoint.UNDER
	)
	
	weapon.ammofeed = _create_ammo_feed(caliber, magazine_size, feed_type)
	
	return weapon

func _create_assault_rifle(name: String, caliber: String, mass: float, 
						  firerate: int, magazine_size: int, firemodes: Array, 
						  feed_type: int, reload_time: float, accuracy: float,
						  recoil_v: float, recoil_h: float, extra: float) -> Weapon:
	var weapon = Weapon.new()
	weapon.name = name
	weapon.mass = mass
	weapon.firerate = firerate
	weapon.base_reload_time = reload_time
	weapon.base_accuracy = accuracy
	weapon.recoil_vertical = recoil_v
	weapon.recoil_horizontal = recoil_h
	weapon.feed_type = feed_type
	
	weapon.firemodes = _firemodes_to_bitmask(firemodes)
	
	# Full attachment capability
	weapon.attach_points = (
		Weapon.AttachmentPoint.MUZZLE |
		Weapon.AttachmentPoint.LEFT_RAIL |
		Weapon.AttachmentPoint.RIGHT_RAIL |
		Weapon.AttachmentPoint.TOP_RAIL |
		Weapon.AttachmentPoint.UNDER
	)
	
	weapon.ammofeed = _create_ammo_feed(caliber, magazine_size, feed_type)
	
	return weapon

func _create_dmr(name: String, caliber: String, mass: float, firerate: int,
				magazine_size: int, firemodes: Array, feed_type: int,
				reload_time: float, accuracy: float, recoil_v: float,
				recoil_h: float, extra: float) -> Weapon:
	var weapon = Weapon.new()
	weapon.name = name
	weapon.mass = mass
	weapon.firerate = firerate
	weapon.base_reload_time = reload_time
	weapon.base_accuracy = accuracy
	weapon.recoil_vertical = recoil_v
	weapon.recoil_horizontal = recoil_h
	weapon.feed_type = feed_type
	
	weapon.firemodes = _firemodes_to_bitmask(firemodes)
	
	# DMR attachment points (focus on optics and bipods)
	weapon.attach_points = (
		Weapon.AttachmentPoint.MUZZLE |
		Weapon.AttachmentPoint.TOP_RAIL |
		Weapon.AttachmentPoint.UNDER  # for bipods
	)
	
	weapon.ammofeed = _create_ammo_feed(caliber, magazine_size, feed_type)
	
	return weapon

func _create_sniper(name: String, caliber: String, mass: float, firerate: int,
				   magazine_size: int, firemodes: Array, feed_type: int,
				   reload_time: float, accuracy: float, recoil_v: float,
				   recoil_h: float, extra: float) -> Weapon:
	var weapon = Weapon.new()
	weapon.name = name
	weapon.mass = mass
	weapon.firerate = firerate
	weapon.base_reload_time = reload_time
	weapon.base_accuracy = accuracy
	weapon.recoil_vertical = recoil_v
	weapon.recoil_horizontal = recoil_h
	weapon.feed_type = feed_type
	
	weapon.firemodes = _firemodes_to_bitmask(firemodes)
	
	# Sniper attachment points
	weapon.attach_points = (
		Weapon.AttachmentPoint.MUZZLE |
		Weapon.AttachmentPoint.TOP_RAIL |  # for scopes
		Weapon.AttachmentPoint.UNDER       # for bipods
	)
	
	weapon.ammofeed = _create_ammo_feed(caliber, magazine_size, feed_type)
	
	return weapon

func _create_shotgun(name: String, caliber: String, mass: float, firerate: int,
					magazine_size: int, firemodes: Array, feed_type: int,
					reload_time: float, accuracy: float, recoil_v: float,
					recoil_h: float, extra: float) -> Weapon:
	var weapon = Weapon.new()
	weapon.name = name
	weapon.mass = mass
	weapon.firerate = firerate
	weapon.base_reload_time = reload_time
	weapon.base_accuracy = accuracy  # Shotguns have wide spread
	weapon.recoil_vertical = recoil_v
	weapon.recoil_horizontal = recoil_h
	weapon.feed_type = feed_type
	
	weapon.firemodes = _firemodes_to_bitmask(firemodes)
	
	# Shotgun attachment points
	weapon.attach_points = (
		Weapon.AttachmentPoint.MUZZLE |  # for chokes
		Weapon.AttachmentPoint.TOP_RAIL  # for sights
	)
	
	weapon.ammofeed = _create_ammo_feed(caliber, magazine_size, feed_type)
	
	return weapon

func _create_lmg(name: String, caliber: String, mass: float, firerate: int,
				magazine_size: int, firemodes: Array, feed_type: int,
				reload_time: float, accuracy: float, recoil_v: float,
				recoil_h: float, extra: float) -> Weapon:
	var weapon = Weapon.new()
	weapon.name = name
	weapon.mass = mass
	weapon.firerate = firerate
	weapon.base_reload_time = reload_time
	weapon.base_accuracy = accuracy
	weapon.recoil_vertical = recoil_v
	weapon.recoil_horizontal = recoil_h
	weapon.feed_type = feed_type
	
	weapon.firemodes = _firemodes_to_bitmask(firemodes)
	
	# LMG attachment points (limited due to bipod and barrel changes)
	weapon.attach_points = (
		Weapon.AttachmentPoint.TOP_RAIL  # for optics
	)
	
	weapon.ammofeed = _create_ammo_feed(caliber, magazine_size, feed_type)
	
	return weapon

# ─── HELPER FUNCTIONS ─────────────────────────────

func _firemodes_to_bitmask(firemodes: Array) -> int:
	var bitmask = 0
	for firemode in firemodes:
		bitmask |= firemode
	return bitmask

func _create_ammo_feed(caliber: String, capacity: int, feed_type: int) -> AmmoFeed:
	var ammo_feed = AmmoFeed.new()
	ammo_feed.type = feed_type
	ammo_feed.capacity = capacity
	ammo_feed.compatible_calibers = [caliber]
	return ammo_feed

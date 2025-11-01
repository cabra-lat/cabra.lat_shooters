@tool
class_name TestUtilsLoadResources extends EditorScript
# Utils
const RESOURCES_PATH = "res://addons/cabra.lat_shooters/src/resources/"
const AMMO_PATH = RESOURCES_PATH + "ammo/"
const ARMORS_PATH = RESOURCES_PATH + "armor/"
const WEAPONS_PATH = RESOURCES_PATH + "weapons/"
const ATTACHMENTS_PATH = RESOURCES_PATH + "attachments/"

static func load_all_ammo() -> Array[Ammo]:
	var list: Array[Ammo]
	for res in load_all_resources(AMMO_PATH):
		list.append(res as Ammo)
	return list

#static func load_all_weapons() -> Array[Weapon]:
	#var list: Array[Weapon]
	#for res in load_all_resources(WEAPONS_PATH):
		#list.append(res as Weapon)
	#return list
#
#static func load_all_armors() -> Array[Armor]:
	#var list: Array[Armor]
	#for res in load_all_resources(ARMORS_PATH):
		#list.append(res as Armor)
	#return list

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
#
## ─── SIGNAL CAPTURE SYSTEM ──────────────────────
#class SignalCapture:
	#var captured_signals: Array = []
	#var weapon: Weapon
	#
	#func _init(weapon_instance: Weapon):
		#weapon = weapon_instance
		#_connect_weapon_signals()
	#
	#func _connect_weapon_signals():
		## Weapon signals
		#weapon.trigger_locked.connect(_on_trigger_locked)
		#weapon.trigger_pressed.connect(_on_trigger_pressed)
		#weapon.trigger_released.connect(_on_trigger_released)
		#weapon.firemode_changed.connect(_on_firemode_changed)
		#weapon.shell_ejected.connect(_on_shell_ejected)
		#weapon.weapon_racked.connect(_on_weapon_racked)
		#weapon.cartridge_fired.connect(_on_cartridge_fired)
		#weapon.cartridge_ejected.connect(_on_cartridge_ejected)
		#weapon.cartridge_inserted.connect(_on_cartridge_inserted)
		#weapon.ammo_feed_empty.connect(_on_ammofeed_empty)
		#weapon.ammo_feed_changed.connect(_on_ammofeed_changed)
		#weapon.ammo_feed_missing.connect(_on_ammofeed_missing)
		#weapon.ammo_feed_incompatible.connect(_on_ammofeed_incompatible)
		#weapon.attachment_added.connect(_on_attachment_added)
		#weapon.attachment_removed.connect(_on_attachment_removed)
	#
	## Weapon signal handlers
	#func _on_trigger_locked(weapon_param: Weapon):
		#_capture_signal("trigger_locked", [weapon_param])
	#
	#func _on_trigger_pressed(weapon_param: Weapon):
		#_capture_signal("trigger_pressed", [weapon_param])
	#
	#func _on_trigger_released(weapon_param: Weapon):
		#_capture_signal("trigger_released", [weapon_param])
	#
	#func _on_firemode_changed(weapon_param: Weapon, mode: String):
		#_capture_signal("firemode_changed", [weapon_param, mode])
	#
	#func _on_shell_ejected(weapon_param: Weapon):
		#_capture_signal("shell_ejected", [weapon_param])
	#
	#func _on_weapon_racked(weapon_param: Weapon):
		#_capture_signal("weapon_racked", [weapon_param])
	#
	#func _on_cartridge_fired(weapon_param: Weapon, cartridge: Ammo):
		#_capture_signal("cartridge_fired", [weapon_param, cartridge])
	#
	#func _on_cartridge_ejected(weapon_param: Weapon, cartridge: Ammo):
		#_capture_signal("cartridge_ejected", [weapon_param, cartridge])
	#
	#func _on_cartridge_inserted(weapon_param: Weapon, cartridge: Ammo):
		#_capture_signal("cartridge_inserted", [weapon_param, cartridge])
	#
	#func _on_ammofeed_empty(weapon_param: Weapon, ammofeed_param: AmmoFeed):
		#_capture_signal("ammofeed_empty", [weapon_param, ammofeed_param])
	#
	#func _on_ammofeed_changed(weapon_param: Weapon, old_feed: AmmoFeed, new_feed: AmmoFeed):
		#_capture_signal("ammofeed_changed", [weapon_param, old_feed, new_feed])
	#
	#func _on_ammofeed_missing(weapon_param: Weapon):
		#_capture_signal("ammofeed_missing", [weapon_param])
	#
	#func _on_ammofeed_incompatible(weapon_param: Weapon, ammofeed_param: AmmoFeed):
		#_capture_signal("ammofeed_incompatible", [weapon_param, ammofeed_param])
	#
	## Attachment signal handlers
	#func _on_attachment_added(weapon_param: Weapon, attachment: Attachment, point: int):
		#_capture_signal("attachment_added", [weapon_param, attachment, point])
	#
	#func _on_attachment_removed(weapon_param: Weapon, attachment: Attachment, point: int):
		#_capture_signal("attachment_removed", [weapon_param, attachment, point])
	#
	#func _capture_signal(signal_name: String, args: Array):
		#var signal_data = {
			#"signal": signal_name,
			#"timestamp": Time.get_ticks_msec(),
			#"args": args
		#}
		#
		#captured_signals.append(signal_data)
		#print("📡 [%s] %s - Args: %s" % [weapon.name, signal_name, _format_args(args)])
	#
	#func _format_args(args: Array) -> String:
		#var formatted = []
		#for arg in args:
			#if arg is Weapon:
				#formatted.append("Weapon(%s)" % arg.name)
			#elif arg is Ammo:
				#formatted.append("Ammo(%s)" % arg.caliber)
			#elif arg is AmmoFeed:
				#formatted.append("AmmoFeed(%s)" % arg.compatible_calibers[0] if not arg.compatible_calibers.is_empty() else "AmmoFeed(empty)")
			#elif arg is Attachment:
				#formatted.append("Attachment(%s)" % arg.name)
			#elif arg == null:
				#formatted.append("null")
			#else:
				#formatted.append(str(arg))
		#return ", ".join(formatted)
	#
	#func clear():
		#captured_signals.clear()
	#
	#func get_signal_count(signal_name: String) -> int:
		#var count = 0
		#for signal_data in captured_signals:
			#if signal_data.signal == signal_name:
				#count += 1
		#return count
	#
	#func has_signal(signal_name: StringName) -> bool:
		#return get_signal_count(signal_name) > 0
	#
	#func get_last_signal(signal_name: String = ""):
		#if captured_signals.is_empty():
			#return null
		#
		#if signal_name.is_empty():
			#return captured_signals[-1]
		#
		#for i in range(captured_signals.size() - 1, -1, -1):
			#if captured_signals[i].signal == signal_name:
				#return captured_signals[i]
		#
		#return null
	#
	#func get_last_signal_args(signal_name: String) -> Array:
		#var last_signal = get_last_signal(signal_name)
		#return last_signal.args if last_signal else []

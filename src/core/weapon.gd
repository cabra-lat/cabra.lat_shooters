class_name Weapon
extends Resource

signal trigger_locked
signal trigger_pressed
signal trigger_released
signal shell_ejected
signal cartridge_fired
signal cartridge_ejected
signal cartridge_inserted
signal firemode_changed
signal ammofeed_empty
signal ammofeed_changed
signal ammofeed_missing
signal ammofeed_incompatible

# Visual and sound variables
@export var viewmodel: PackedScene
@export var equip_sound: AudioStream  # Sound to be played when equiped
@export var fire_sound: AudioStream   # Sound to be played when firing
@export var feed_sound: AudioStream   # Sound to be played when reloading
@export var empty_sound: AudioStream  # Sound to be played when empty
@export var extra_sound: AudioStream  # Sound to be played when pumped or cocked
@export var ammofeed: AmmoFeed

@export var attach_points: enums.MountPoint = enums.MountPoint.NONE
@export var firemodes: enums.Firemode = enums.Firemode.SEMI
@export var feed_type: enums.FeedType = enums.FeedType.INTERNAL

# Statistics Variables
@export var firerate: float  = 100 # Rounds per minute
@export var burstfire: int   = 3   # Round
@export var mass: float      = 1.0 # Kg

# State Variables
# Base reload time (exported, editable in inspector)
@export var base_reload_time: float = 0.5  # Average reload time

# Computed property — not exported, read-only
var reload_time: float:
	get:
		return get_reload_time()

func get_reload_time() -> float:
	if ammofeed and ammofeed.is_empty():
		return base_reload_time  # Quick reload
	else:
		return base_reload_time * 1.5  # Tactical reload

var firemode = enums.Firemode.SAFE
var semi_control  = false
var burst_control = burstfire

func is_automatic() -> bool:
	return firemode ==  enums.Firemode.AUTO or firemode ==  enums.Firemode.BURST

func get_firemode():
	for firemode_name in enums.Firemode:
		if (enums.Firemode.get(firemode_name) & firemode): return firemode_name

func safe_firemode():
	firemode = enums.Firemode.SAFE
	emit_signal("firemode_changed", "SAFE")

func _is_active_firemode(firemode_name):
	return bool(enums.Firemode.get(firemode_name) & firemodes &~enums.Firemode.SAFE)

func cycle_firemode():
	var firemode_names = enums.Firemode.keys()
	var active_firemodes = Callable(self, "_is_active_firemode")
	var modes = firemode_names.filter(active_firemodes)
	for try in range(2):
		for mode in modes:
			var new_firemode = enums.Firemode.get(mode)
			if new_firemode > firemode:
				firemode = new_firemode
				emit_signal("firemode_changed", mode)
				return
		firemode = enums.Firemode.SAFE

func pull_trigger():
	if firemode == enums.Firemode.SAFE:
		if semi_control: return
		emit_signal("trigger_locked")
		semi_control = true
		return
	if ammofeed and ammofeed.is_empty():
		if semi_control: return
		emit_signal("ammofeed_empty")
		semi_control = true
		return
	if not ammofeed:
		if semi_control: return
		emit_signal("ammofeed_missing")
		semi_control = true
		return
	match firemode:
		enums.Firemode.AUTO:
			var cartridge = ammofeed.eject()
			if cartridge is Ammo:
				emit_signal("cartridge_fired", [cartridge])
		enums.Firemode.SEMI:
			if semi_control: return
			var cartridge = ammofeed.eject()
			if cartridge is Ammo:
				emit_signal("cartridge_fired", [cartridge])
			semi_control = true
		enums.Firemode.BURST:
			if not burst_control > 0: return
			var cartridge = ammofeed.eject()
			if cartridge is Ammo:
				emit_signal("cartridge_fired", [cartridge])
				burst_control -= 1

func release_trigger():
	semi_control  = false
	burst_control = burstfire
	emit_signal("trigger_released")

func remove_cartridge():
	emit_signal("cartridge_ejected")
	return ammofeed.eject()

func insert_cartridge(new_cartridge: Ammo):
	if feed_type != enums.FeedType.INTERNAL:
		emit_signal("ammofeed_incompatible")
		return
	emit_signal("cartridge_inserted")
	ammofeed.insert(new_cartridge)

func change_magazine(new_magazine: AmmoFeed):
	if feed_type == enums.FeedType.INTERNAL \
	or new_magazine.type != feed_type:
		emit_signal("ammofeed_incompatible")
		return
	var old_magazine = ammofeed
	ammofeed = new_magazine.duplicate()
	emit_signal("ammofeed_changed", old_magazine, new_magazine)

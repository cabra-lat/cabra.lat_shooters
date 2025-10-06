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

const SIGNALS = [
	"trigger_locked", 
	"trigger_pressed", 
	"trigger_released",
	"firemode_changed", 
	"cartridge_fired", 
	"ammofeed_empty",
	"ammofeed_changed",
	"ammofeed_missing",
	"ammofeed_incompatible"
]

# Visual and sound variables
@export var viewmodel:   PackedScene
@export var equip_sound: AudioStream  # Sound to be played when equiped
@export var fire_sound:  AudioStream  # Sound to be played when firing
@export var feed_sound:  AudioStream  # Sound to be played when reloading
@export var empty_sound: AudioStream  # Sound to be played when empty
@export var extra_sound: AudioStream  # Sound to be played when pumped or cocked
@export var ammofeed:    AmmoFeed

## End of barrel (suppressors, flash hiders),
## Left rail (vertical grips, lasers),
## Right rail (tactical lights),
## Top rail (scopes, red dots),
## Underbarrel (grenade launchers, grips),
## No mount point (or not applicable)
@export_flags("MUZZLE", "LEFT_RAIL", "RIGHT_RAIL", "TOP_RAIL", "UNDER", "NONE"
) var attach_points: int = enums.MountPoint.NONE

## Safe — trigger disabled,
## Fully automatic,
## Semi-automatic (one shot per trigger pull),
## Burst fire (e.g., 3-round burst),
## Pump-action (shotguns),
## Bolt-action (manual cycling)
@export_flags("SAFE", "AUTO", "SEMI", "BURST", "PUMP", "BOLT"
) var firemodes: int = enums.Firemode.SEMI

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
	return firemode ==  enums.Firemode.AUTO \
		or firemode ==  enums.Firemode.BURST

func get_firemode():
	for firemode_name in enums.Firemode:
		if (enums.Firemode.get(firemode_name) \
		   & firemode): return firemode_name

func safe_firemode():
	firemode = enums.Firemode.SAFE
	firemode_changed.emit(get_firemode())

func is_firemode_active(firemode_name):
	return bool(enums.Firemode.get(firemode_name) \
			 & firemodes &~enums.Firemode.SAFE)

func cycle_firemode():
	var firemode_names = enums.Firemode.keys()
	var active_firemodes = Callable(self, "is_firemode_active")
	var modes = firemode_names.filter(active_firemodes)
	for try in range(2):
		for mode in modes:
			var new_firemode = enums.Firemode.get(mode)
			if new_firemode > firemode:
				firemode = new_firemode
				firemode_changed.emit(get_firemode())
				return
		firemode = enums.Firemode.SAFE

func pull_trigger():
	if firemode == enums.Firemode.SAFE:
		if semi_control: return
		trigger_locked.emit()
		semi_control = true
		return
	if ammofeed and ammofeed.is_empty():
		if semi_control: return
		ammofeed_empty.emit()
		semi_control = true
		return
	if not ammofeed:
		if semi_control: return
		ammofeed_missing.emit()
		semi_control = true
		return
	
	match firemode:
		enums.Firemode.SEMI:
			if semi_control: return
			semi_control = true
		enums.Firemode.BURST:
			if not burst_control > 0: return
			burst_control -= 1

	var cartridge: Ammo = ammofeed.eject()
	cartridge_fired.emit([cartridge])

func release_trigger():
	semi_control  = false
	burst_control = burstfire
	trigger_released.emit()

func remove_cartridge():
	cartridge_ejected.emit()
	return ammofeed.eject()

func insert_cartridge(new_cartridge: Ammo):
	if feed_type != enums.FeedType.INTERNAL:
		ammofeed_incompatible.emit()
		return
	cartridge_inserted.emit()
	ammofeed.insert(new_cartridge)

func change_magazine(new_magazine: AmmoFeed):
	if feed_type == enums.FeedType.INTERNAL \
	or new_magazine.type != feed_type:
		ammofeed_incompatible.emit()
		return
	var old_magazine = ammofeed
	ammofeed = new_magazine.duplicate()
	ammofeed_changed.emit(old_magazine, new_magazine)

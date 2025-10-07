@tool
class_name Weapon extends Resource

signal trigger_locked(weapon: Weapon)
signal trigger_pressed(weapon: Weapon)
signal trigger_released(weapon: Weapon)
signal firemode_changed(weapon: Weapon, mode: String)
signal shell_ejected(weapon: Weapon)
signal weapon_racked(weapon: Weapon)

signal attachment_added(weapon: Weapon, attachment: Attachment, point: int)
signal attachment_removed(weapon: Weapon, attachment: Attachment, point: int)

signal cartridge_fired(weapon: Weapon, cartridge: Ammo)
signal cartridge_ejected(weapon: Weapon, cartridge: Ammo)
signal cartridge_inserted(weapon: Weapon, cartridge: Ammo)

signal ammofeed_empty(weapon: Weapon, ammofeed: AmmoFeed)
signal ammofeed_changed(weapon: Weapon, old: AmmoFeed, new: AmmoFeed)
signal ammofeed_missing(weapon: Weapon)
signal ammofeed_incompatible(weapon: Weapon, ammofeed: AmmoFeed)

const SIGNALS = [
 "trigger_locked",
 "trigger_pressed",
 "trigger_released",
 "shell_ejected",
 "weapon_racked",
 "cartridge_fired",
 "cartridge_ejected",
 "cartridge_inserted",
 "firemode_changed",
 "ammofeed_empty",
 "ammofeed_changed",
 "ammofeed_missing",
 "ammofeed_incompatible"
]

## Fire modes supported by weapons.
## 
## Bit flags allow weapons to support multiple modes (e.g., `SEMI | BURST`).
## Use bitwise AND (`&`) to check if a mode is available.
enum Firemode {
	SAFE  = 1 << 0,  ## Safe — trigger disabled
	AUTO  = 1 << 1,  ## Fully automatic
	SEMI  = 1 << 2,  ## Semi-automatic (one shot per trigger pull)
	BURST = 1 << 3,  ## Burst fire (e.g., 3-round burst)
	PUMP  = 1 << 4,  ## Pump-action (shotguns)
	BOLT  = 1 << 5   ## Bolt-action (manual cycling)
}

## Weapon attachment/mount points.
## 
## Defines where accessories (scopes, grips, etc.) can be mounted.
## Bit flags allow multiple compatible mounts (rare, but possible).
enum AttachmentPoint {
	MUZZLE     = 1 << 0,  ## End of barrel (suppressors, flash hiders)
	LEFT_RAIL  = 1 << 1,  ## Left rail (vertical grips, lasers)
	RIGHT_RAIL = 1 << 2,  ## Right rail (tactical lights)
	TOP_RAIL   = 1 << 3,  ## Top rail (scopes, red dots)
	UNDER      = 1 << 4,  ## Underbarrel (grenade launchers, grips)
}

# Visual and sound variables
@export var name: String = "Unnamed Weapon"
@export_multiline var description: String = "This Weapon is the default one."
@export var view_model: PackedScene
@export var equip_sound: AudioStream
@export var fire_sound: AudioStream
@export var feed_sound: AudioStream
@export var empty_sound: AudioStream
@export var extra_sound: AudioStream
@export var ammofeed: AmmoFeed

@export_flags("MUZZLE", "LEFT_RAIL", "RIGHT_RAIL", "TOP_RAIL", "UNDER", "NONE") 
var attach_points: int = 0

@export_flags("SAFE", "AUTO", "SEMI", "BURST", "PUMP", "BOLT")
var firemodes: int = Firemode.SEMI

@export var feed_type: AmmoFeed.Type = AmmoFeed.Type.INTERNAL

# Statistics - make base stats separate from current stats
@export var firerate: float = 600
@export var burst_count: int = 3
@export var base_mass: float = 3.5
@export var base_reload_time: float = 2.5
@export var base_accuracy: float = 2.0
@export var base_recoil_vertical: float = 1.0
@export var base_recoil_horizontal: float = 0.5


# Current stats (computed properties)
var mass: float:
	get: return get_mass()

var accuracy: float:
	get: return get_current_accuracy()
	
var reload_time: float:
	get: return get_reload_time()

var recoil_vertical: float:
	get: return get_current_recoil_vertical()

var recoil_horizontal: float:
	get: return get_current_recoil_horizontal()

var can_fire: bool:
	get: return _can_fire()

var cycle_time: float:
	get: return 60.0 / firerate

# State variables
var firemode = Firemode.SAFE
var semi_control = false
var burst_counter = 0
var chambered_round: Ammo = null
var is_cycled = true
var current_durability = 100.0
var attachments: Dictionary = {}  # point: Attachment

func get_current_accuracy() -> float:
	var durability_factor = 1.0 + (100.0 - current_durability) / 200.0
	var modified_accuracy = base_accuracy * durability_factor
	
	# Apply attachment modifiers
	for attachment in attachments.values():
		modified_accuracy *= attachment.accuracy_modifier
	
	return modified_accuracy

func get_current_recoil_vertical() -> float:
	var modified_recoil = base_recoil_vertical
	
	# Apply attachment modifiers
	for attachment in attachments.values():
		modified_recoil *= attachment.recoil_modifier
	
	return modified_recoil

func get_current_recoil_horizontal() -> float:
	var modified_recoil = base_recoil_horizontal
	
	# Apply attachment modifiers
	for attachment in attachments.values():
		modified_recoil *= attachment.recoil_modifier
	
	return modified_recoil

func get_reload_time() -> float:
	var time_multiplier = 1.0
	if ammofeed and ammofeed.is_empty():
		time_multiplier = 1.0  # Quick reload
	else:
		time_multiplier = 1.5  # Tactical reload
	
	var modified_time = base_reload_time * time_multiplier
	
	# Apply attachment modifiers
	for attachment in attachments.values():
		modified_time *= attachment.reload_speed_modifier
	
	return modified_time

func get_mass() -> float:
	var total_mass = base_mass
	
	# Add ammo feed mass
	if ammofeed:
		total_mass += ammofeed.mass
	
	# Add attachment masses
	for attachment in attachments.values():
		total_mass += attachment.mass
	
	return total_mass

func attach_attachment(point: int, attachment: Attachment) -> bool:
	# Check if point is available
	if not attach_points & point:
		return false
	
	# Check if point is already occupied
	if attachments.has(point):
		return false
	
	# Check attachment compatibility
	if not attachment.attach_to_weapon(self):
		return false
	
	attachments[point] = attachment
	attachment_added.emit(self, attachment, point)
	
	return true  # No need to recalculate stats - computed properties handle it

func detach_attachment(point: int) -> bool:
	if not attachments.has(point):
		return false
	
	var attachment = attachments[point]
	attachment.detach_from_weapon()
	attachments.erase(point)
	attachment_removed.emit(self, attachment, point)
	
	return true  # No need to recalculate stats - computed properties handle it

func is_automatic() -> bool:
	return firemode == Firemode.AUTO || firemode == Firemode.BURST

func get_firemode_name() -> String:
	for firemode_name in Firemode:
		if Firemode[firemode_name] == firemode:
			return firemode_name
	return "UNKNOWN"

func safe_firemode():
	firemode = Firemode.SAFE
	firemode_changed.emit(self, get_firemode_name())

func is_firemode_available(firemode_check: int) -> bool:
	return bool(firemodes & firemode_check)

func _can_fire() -> bool:
	match firemode:
		Firemode.SAFE:
			return false
		Firemode.SEMI:
			if semi_control: return false
		Firemode.BURST:
			if burst_counter <= 0: return false
		Firemode.PUMP, Firemode.BOLT:
			if not is_cycled: return false
	
	# Check if we have ammo to fire
	if chambered_round:
		return true
	if ammofeed and not ammofeed.is_empty():
		return true
	
	return false

func cycle_firemode():
	var available_modes = []
	var priority_order = [Firemode.AUTO, Firemode.BURST, Firemode.SEMI, Firemode.PUMP, Firemode.BOLT]
	
	for mode in priority_order:
		if is_firemode_available(mode):
			available_modes.append(mode)
	
	if available_modes.is_empty():
		return
	
	var current_index = available_modes.find(firemode)
	var next_index = (current_index + 1) % available_modes.size()
	firemode = available_modes[next_index]
	
	# Reset burst counter when switching to burst mode
	if firemode == Firemode.BURST:
		burst_counter = burst_count
	
	firemode_changed.emit(self, get_firemode_name())

func pull_trigger() -> bool:
	if not _can_fire():
		_handle_fire_failure()
		return false
	
	# Get round to fire
	var round_to_fire = null
	if chambered_round:
		round_to_fire = chambered_round
		chambered_round = null
	elif ammofeed and not ammofeed.is_empty():
		round_to_fire = ammofeed.eject()
	
	if not round_to_fire:
		_handle_fire_failure()
		return false
	
	# Update firing state
	_update_firing_state()
	
	# Emit firing signals
	trigger_pressed.emit(self)
	cartridge_fired.emit(self, round_to_fire)
	
	# Auto-chamber next round for automatic weapons
	if is_automatic() and ammofeed and not ammofeed.is_empty():
		chambered_round = ammofeed.eject()
	
	# Eject shell for non-revolver systems
	if feed_type != AmmoFeed.Type.INTERNAL:
		shell_ejected.emit(self)
	
	return true

func _handle_fire_failure():
	if firemode == Firemode.SAFE:
		if not semi_control:
			trigger_locked.emit(self)
			semi_control = true
	else:
		if (not ammofeed or ammofeed.is_empty()) and not semi_control:
			ammofeed_empty.emit(self, ammofeed)
			semi_control = true
		elif not ammofeed and not semi_control:
			ammofeed_missing.emit(self)
			semi_control = true

func _update_firing_state():
	match firemode:
		Firemode.SEMI:
			semi_control = true
		Firemode.BURST:
			burst_counter -= 1
		Firemode.PUMP, Firemode.BOLT:
			is_cycled = false

func cycle_weapon():
	if not is_cycled and ammofeed and not ammofeed.is_empty():
		chambered_round = ammofeed.eject()
		is_cycled = true
		cartridge_inserted.emit(self, chambered_round)

func insert_cartridge(new_cartridge: Ammo):
	if feed_type != AmmoFeed.Type.INTERNAL:
		ammofeed_incompatible.emit(self, new_cartridge)
		return
	
	if not chambered_round:
		chambered_round = new_cartridge
		cartridge_inserted.emit(self, new_cartridge)
	elif ammofeed:
		ammofeed.insert(new_cartridge)

func change_magazine(new_magazine: AmmoFeed):
	if feed_type == AmmoFeed.Type.INTERNAL or new_magazine.type != feed_type:
		ammofeed_incompatible.emit(self, new_magazine)
		return false
	
	# Check caliber compatibility
	var caliber_compatible = false
	if ammofeed:
		for caliber in new_magazine.compatible_calibers:
			if ammofeed.compatible_calibers.has(caliber):
				caliber_compatible = true
				break
	else:
		# If no current ammofeed, assume compatible if it has calibers
		caliber_compatible = not new_magazine.compatible_calibers.is_empty()
	
	if not caliber_compatible:
		ammofeed_incompatible.emit(self, new_magazine)
		return false
	
	var old_magazine = ammofeed
	ammofeed = new_magazine.duplicate()
	
	# Chamber a round from new magazine if possible
	if ammofeed and not ammofeed.is_empty():
		chambered_round = ammofeed.eject()
		cartridge_inserted.emit(self, chambered_round)
	
	ammofeed_changed.emit(self, old_magazine, new_magazine)
	return true

func get_recoil_vector() -> Vector2:
	return Vector2(
		randf_range(-recoil_horizontal, recoil_horizontal),
		-recoil_vertical * (0.8 + randf() * 0.4)
	)

func release_trigger():
	if firemode == Firemode.BURST:
		burst_counter = burst_count
	semi_control = false
	trigger_released.emit(self)

func _init():
	# Set initial firemode
	if firemodes & Firemode.SEMI:
		firemode = Firemode.SEMI
	elif firemodes & Firemode.AUTO:
		firemode = Firemode.AUTO
	elif firemodes & Firemode.BURST:
		firemode = Firemode.BURST
		burst_counter = burst_count
	elif firemodes & Firemode.PUMP:
		firemode = Firemode.PUMP
	elif firemodes & Firemode.BOLT:
		firemode = Firemode.BOLT
	else:
		firemode = Firemode.SAFE

func get_attachment(point: int) -> Attachment:
	return attachments.get(point)

func get_all_attachments() -> Array:
	return attachments.values()

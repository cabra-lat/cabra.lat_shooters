# attachment.gd
@tool
class_name Attachment extends Resource

signal attachment_attached(attachment: Attachment, weapon: Weapon)
signal attachment_detached(attachment: Attachment, weapon: Weapon)

enum AttachmentType {
	OPTICS,      # Scopes, red dots, holographic sights
	MUZZLE,      # Suppressors, compensators, flash hiders
	UNDERBARREL, # Grips, bipods, grenade launchers
	LASER,       # Laser sights, IR lasers
	LIGHT,       # Flashlights, IR illuminators
	MAGAZINE,    # Extended magazines, drum magazines
	STOCK,       # Adjustable stocks, recoil pads
	RAIL,        # Rail covers, accessories
	OTHER        # Custom attachments
}

enum ReticleType {
	DOT,         # Simple red dot
	CIRCLE_DOT,  # Circle with center dot
	CHEVRON,     # Chevron/triangle
	DUPLEX,      # Crosshair with thick posts
	MIL_DOT,     # Mil-dot ranging reticle
	BDC,         # Bullet Drop Compensator
	CUSTOM       # Custom reticle pattern
}

# Basic properties
@export var name: String = "Generic Attachment"  ## e.g., "Stock"
@export_multiline var description: String = "This Attachment is the default one."
@export var type: AttachmentType = AttachmentType.OTHER
@export var attachment_point: Weapon.AttachmentPoint
@export var mass: float = 0.1
@export var cost: int = 100

# Visual properties
@export var view_model: PackedScene
@export var world_model: PackedScene
@export var icon: Texture2D

# Statistics modifiers
@export var accuracy_modifier: float = 1.0        # Multiplier (1.0 = no change)
@export var recoil_modifier: float = 1.0          # Multiplier (1.0 = no change)
@export var ergonomics_modifier: float = 1.0      # Multiplier (1.0 = no change)
@export var reload_speed_modifier: float = 1.0    # Multiplier (1.0 = no change)
@export var aim_down_sights_modifier: float = 1.0 # Multiplier (1.0 = no change)

# Type-specific properties
@export_group("Optics Properties")
@export var magnification: float = 1.0            # 1.0 = no magnification
@export var reticle_type: ReticleType = ReticleType.DOT
@export var reticle_color: Color = Color.RED
@export var eye_relief: float = 3.0               # Inches
@export var zero_distance: float = 100.0          # Meters

@export_group("Muzzle Properties")
@export var sound_suppression: float = 0.0        # 0.0 = none, 1.0 = full suppression
@export var flash_suppression: float = 0.0        # 0.0 = none, 1.0 = full suppression
@export var recoil_reduction: float = 0.0         # Additional recoil reduction

@export_group("Underbarrel Properties")
@export var stability_bonus: float = 0.0          # Hip fire stability
@export var deployable: bool = false              # Bipod deployment

@export_group("Laser/Light Properties")
@export var laser_active: bool = true
@export var light_active: bool = true
@export var laser_range: float = 50.0             # Meters
@export var light_range: float = 100.0            # Meters

@export_group("Magazine Properties")
@export var capacity_multiplier: float = 1.0      # Magazine capacity modifier

# Compatibility
@export var compatible_weapons: Array[String]     # Weapon names that can use this attachment
@export var incompatible_attachments: Array[AttachmentType] # Attachment types that can't be used together

# State
var is_attached: bool = false
var current_weapon: Weapon = null

func attach_to_weapon(weapon: Weapon) -> bool:
	if not _is_compatible(weapon):
		return false
	
	if not _can_coexist(weapon):
		return false
	
	current_weapon = weapon
	is_attached = true
	attachment_attached.emit(self, weapon)
	return true

func detach_from_weapon() -> bool:
	if not is_attached:
		return false
	
	var old_weapon = current_weapon
	current_weapon = null
	is_attached = false
	attachment_detached.emit(self, old_weapon)
	return true

func _is_compatible(weapon: Weapon) -> bool:
	# Check if weapon has the required attachment point
	if not weapon.attach_points & attachment_point:
		return false
	
	# Check specific weapon compatibility
	if not compatible_weapons.is_empty():
		if not weapon.name in compatible_weapons:
			return false
	
	return true

func _can_coexist(weapon: Weapon) -> bool:
	# Check for incompatible attachments already on the weapon
	# This would need to interface with the weapon's attachment system
	return true

# Getters for modified stats
func get_modified_accuracy(base_accuracy: float) -> float:
	return base_accuracy * accuracy_modifier

func get_modified_recoil(base_recoil: float) -> float:
	return base_recoil * recoil_modifier

func get_modified_reload_speed(base_speed: float) -> float:
	return base_speed * reload_speed_modifier

# Type-specific functionality
func toggle_laser() -> void:
	if type == AttachmentType.LASER:
		laser_active = not laser_active

func toggle_light() -> void:
	if type == AttachmentType.LIGHT:
		light_active = not light_active

func deploy_bipod() -> void:
	if type == AttachmentType.UNDERBARREL and deployable:
		# Bipod deployment logic
		pass

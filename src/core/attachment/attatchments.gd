# res://src/core/attachment/attachment.gd
class_name Attachment
extends Item

# ─── SIGNALS ───────────────────────────────────────
signal attachment_attached(attachment: Attachment, weapon: Weapon)
signal attachment_detached(attachment: Attachment, weapon: Weapon)

# ─── ENUMS ─────────────────────────────────────────
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

# ─── METADATA ──────────────────────────────────────
@export_multiline var description: String = "This Attachment is the default one."
@export var type: AttachmentType = AttachmentType.OTHER
@export var attachment_point: int  # Weapon.AttachmentPoint (bit flag)
@export var cost: int = 100

# ─── STAT MODIFIERS ────────────────────────────────
@export var accuracy_modifier: float = 1.0
@export var recoil_modifier: float = 1.0
@export var ergonomics_modifier: float = 1.0
@export var reload_speed_modifier: float = 1.0
@export var aim_down_sights_modifier: float = 1.0

# ─── TYPE-SPECIFIC PROPERTIES ──────────────────────
@export_group("Optics Properties")
@export var magnification: float = 1.0
@export var reticle_type: ReticleType = ReticleType.DOT
@export var reticle_color: Color = Color.RED
@export var eye_relief: float = 3.0
@export var zero_distance: float = 100.0

@export_group("Muzzle Properties")
@export var sound_suppression: float = 0.0
@export var flash_suppression: float = 0.0
@export var recoil_reduction: float = 0.0

@export_group("Underbarrel Properties")
@export var stability_bonus: float = 0.0
@export var deployable: bool = false

@export_group("Laser/Light Properties")
@export var laser_active: bool = true
@export var light_active: bool = true
@export_custom(PROPERTY_HINT_NONE, "suffix:m") var laser_range: float = 50.0
@export_custom(PROPERTY_HINT_NONE, "suffix:m") var light_range: float = 100.0

@export_group("Magazine Properties")
@export var capacity_multiplier: float = 1.0

# ─── COMPATIBILITY ─────────────────────────────────
@export var compatible_weapons: Array[String] = []
@export var incompatible_attachments: Array[AttachmentType] = []

# ─── STATE ─────────────────────────────────────────
var is_attached: bool = false
var current_weapon: Weapon = null

# ─── PUBLIC METHODS ────────────────────────────────
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

# ─── INTERNAL LOGIC ────────────────────────────────
func _is_compatible(weapon: Weapon) -> bool:
  if not (weapon.attach_points & attachment_point):
    return false
  if not compatible_weapons.is_empty() and not weapon.name in compatible_weapons:
    return false
  return true

func _can_coexist(weapon: Weapon) -> bool:
  # Simplified: assume no conflicts for now
  # (In full version, check `incompatible_attachments`)
  return true

# ─── TYPE-SPECIFIC BEHAVIOR ────────────────────────
func toggle_laser() -> void:
  if type == AttachmentType.LASER:
    laser_active = not laser_active

func toggle_light() -> void:
  if type == AttachmentType.LIGHT:
    light_active = not light_active

func deploy_bipod() -> void:
  if type == AttachmentType.UNDERBARREL and deployable:
    pass  # Placeholder

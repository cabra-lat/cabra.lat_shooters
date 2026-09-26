# res://addons/cabra.lat_shooters/src/core/item.gd
class_name Item
extends Resource

# All inventory items must implement these
@export var name: String = "Item"
## Player-facing prose about the item, in the SOURCE language: this is a
## translation msgid, not a finished string, and it is resolved at render time.
## Additive and default-empty; nothing that exists today reads it.
##
## WHY IT IS HERE RATHER THAN ONLY ON THE SUBCLASSES. Six subclasses (Weapon,
## Ammo, AmmoFeed, Armor, MedicalItem, Attachment) each declared their own
## `description`, so a resource built on one of those carried the field and a
## resource built on the BASE Item did not -- marked_intel.tres was exactly that,
## and its description line was dropped at load with no warning and no way to
## read it back. The property belongs where the identity is.
@export_multiline var description: String = ""
@export var mass: float = 0.0: get = get_mass, set = set_mass
# Default keeps code-created items off the engine logo (no .tres to load an
# icon from): neutral generated placeholder, not res://icon.svg (Godot logo).
@export var icon: Texture2D = preload("res://assets/ui/inventory/generated/placeholder_item.png")
@export var view_model: PackedScene
@export var equip_sound: AudioStream

func get_mass() -> float: return mass
func set_mass(value) -> void: mass = value

func _init() -> void:
  pass

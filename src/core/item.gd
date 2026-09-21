# res://addons/cabra.lat_shooters/src/core/item.gd
class_name Item
extends Resource

# All inventory items must implement these
@export var name: String = "Item"
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

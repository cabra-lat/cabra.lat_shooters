# res://src/core/item.gd
class_name Item
extends Resource

# All inventory items must implement these
@export var name: String = "Item"
@export var mass: float: get = get_mass, set = set_mass
@export var icon: Texture2D = preload("../../assets/ui/inventory/placeholder.png")
@export var view_model: PackedScene
@export var equip_sound: AudioStream

func get_mass() -> float: return mass
func set_mass(value) -> void: mass = value

func _init() -> void:
  pass

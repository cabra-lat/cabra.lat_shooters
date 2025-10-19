class_name WorldItemConfig
extends Resource

@export_group("Collision Settings")
@export var collision_layer: int = 1
@export var collision_mask: int = 1

@export_group("Interaction Settings")
@export var auto_pickup: bool = false
@export var pickup_radius: float = 1.5
@export var highlight_radius: float = 3.0
@export var enable_highlight: bool = true

@export_group("Visual Settings")
@export var enable_bobbing: bool = true
@export var default_bob_height: float = 0.2
@export var default_bob_speed: float = 2.0
@export var default_rotation_speed: float = 0.5

@export_group("Rarity Materials")
@export var rarity_materials: Dictionary = {
    "common": null,
    "uncommon": null, #preload("res://assets/materials/rarity_uncommon.tres"),
    "rare": null, #preload("res://assets/materials/rarity_rare.tres"),
    "epic": null, #preload("res://assets/materials/rarity_epic.tres"),
    "legendary": null #preload("res://assets/materials/rarity_legendary.tres")
}

@export_group("Debug Settings")
@export var debug_mode: bool = false
@export var show_interaction_radius: bool = false

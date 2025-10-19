class_name TestSceneConfig
extends Resource

@export_group("World Item Settings")
@export var world_item_auto_rotate: bool = true
@export var world_item_rotation_speed: float = 0.5
@export var world_item_pickup_radius: float = 1.5

@export_group("Debug Settings")
@export var debug_mode: bool = true
@export var enable_debug_controls: bool = true
@export var log_player_events: bool = true
@export var show_interaction_prompts: bool = true

@export_group("Test Data")
@export var test_ammo_resource: Ammo
@export var test_weapon_resource: Weapon
@export var test_backpack_icon: Texture2D
@export var test_magazine_icon: Texture2D

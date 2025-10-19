class_name TransferConfig
extends Resource

@export_group("Transfer Settings")
@export var position_search_radius: int = 3
@export var enable_auto_stack: bool = true
@export var enable_smart_positioning: bool = true
@export var max_transfer_attempts: int = 5

@export_group("Stack Settings")
@export var ammo_stack_size: int = 30
@export var medical_stack_size: int = 5
@export var food_stack_size: int = 10

@export_group("Item Dimensions")
@export var item_dimensions: Dictionary = {
    "Weapon": Vector2i(3, 2),
    "Armor": Vector2i(2, 2),
    "Backpack": Vector2i(2, 3),
    "Medical": Vector2i(1, 1),
    "Ammo": Vector2i(1, 1),
    "Food": Vector2i(1, 1),
    "Misc": Vector2i(1, 1)
}

@export_group("Debug Settings")
@export var debug_mode: bool = true
@export var log_transfers: bool = true
@export var log_errors: bool = true

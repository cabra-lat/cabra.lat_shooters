class_name Armor
extends Resource

@export var viewmodel: PackedScene
@export var equip_sound: AudioStream # Sound to be played when equiped
@export var hit_sound: AudioStream   # Sound to be played when hit

@export var description = "A generic armor" # (String, MULTILINE)
@export var type = enums.ArmorType.GENERIC # (enums.ArmorType)

# Statistics Variables
@export var max_durability: int = 100 # Durability
@export var material = 1.0 # Durability # (float,  0, 1)
@export var level    = 1 # (int,    1, 6)
@export var turn_speed      = 0.0 # (%) Turn Speed Penalty # (float, -1, 0)
@export var move_speed      = 0.0 # (%) Move Speed Penalty # (float, -1, 0)
@export var ricochet_chance = 0.0 # (%) Ricochet Chance Modifier # (float, -1, 1)
@export var sound_reduction = 0.0 # (%) Sound reduction # (float, -1, 0)
@export var blind_reduction = 0.0 # (%) Blindness reduction # (float, -1, 0)
@export var protection_zones = 0 # (enums.BodyParts,FLAGS)

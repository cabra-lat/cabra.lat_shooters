class_name Ammo
extends Resource

@export var caliber: String = ""

@export var viewmodel: PackedScene
@export var shell_model: PackedScene
@export var shell_sound: AudioStream

@export var description = "A generic ammo" # (String, MULTILINE)
@export var penetration: float = 1 # Penetration Power
@export var speed: float       = 1 # m/s Projectile Speed
@export var accuracy: float    = 1 # mm Accuracy R_50 at 300m
@export var armor_damage    = 0.0 # (%) Armor damage modifier # (float, 0, 1)
@export var bleeding_chance = 0.0 # (%) Bleeding Chance # (float, 0, 1)
@export var ricochet_chance = 0.0 # (%) Ricochet Chance # (float, 0, 1)
@export var fragment_chance = 0.0 # (%) Fragment Chance # (float, 0, 1)
@export var bullet_mass: float    = 1.0 # g
@export var cartridge_mass: float = 1.0 # g

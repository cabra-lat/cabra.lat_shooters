# ConfigNPC.gd
class_name ConfigNPC extends Resource

# Standard config
@export var max_weight: float = 100
@export var default_speed: float = 4.0
@export var default_jump_impulse: float = 4.0

# Perception
@export var detection_radius: float = 15.0
@export var awareness_threshold: float = 0.8
@export var reaction_time: float = 0.5
@export var sound_detection_range: float = 10.0

# Movement
@export var patrol_pattern: int = 0  # 0=linear, 1=circular, 2=random
@export var chase_distance: float = 20.0
@export var retreat_distance: float = 10.0
@export var cover_proximity: float = 3.0
@export var weapon_accuracy: float = 0.9
@export var aggression_level: float = 0.7
@export var fear_threshold: float = 0.6

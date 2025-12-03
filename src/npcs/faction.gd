class_name Faction extends Resource

@export var name: String = "Unknown"
@export var color: Color = Color(1, 0, 0)  # For debugging/UI
@export var aggression_level: float = 0.7  # 0 = passive, 1 = aggressive
@export var fear_threshold: float = 0.6     # When to flee
@export var detection_radius: float = 15.0  # How far they detect player
@export var patrol_pattern: int = 0        # 0 = linear, 1 = circular, 2 = random
@export var preferred_weapon_type: String = "rifle"  # e.g., "pistol", "shotgun", "sniper"
@export var attack_style: String = "direct"  # "flanking", "cover_fire", "melee"
@export var reaction_time: float = 0.5      # Delay before responding
@export var cover_preference: bool = true   # Whether they seek cover
@export var dialogue_prefix: String = "[Enemy] "

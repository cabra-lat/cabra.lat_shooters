@tool
class_name Ammo extends Resource

# ─── CORE METADATA ───────────────────────────────
@export var caliber: String = ""  # e.g., "7.62x39mm", "5.56x45mm NATO"
@export_multiline var description: String = "Generic ammunition"
@export var view_model: PackedScene
@export var shell_model: PackedScene
@export var shell_sound: AudioStream

# ─── BALLISTIC PROPERTIES ─────────────────────────
enum Type {
	FMJ,           # Full Metal Jacket
	JSP,           # Jacketed Soft Point
	JHP,           # Jacketed Hollow Point
	AP,            # Armor-Piercing
	API,           # Armor-Piercing Incendiary
	STEEL_CORE,    # Mild/Steel Core (e.g., 7.62x39mm PS)
	GREEN_TIP,     # SS109 / M855 (steel penetrator tip)
	M995,          # Tungsten AP (5.56mm)
	FSP,           # Fragment (military sim)
	SLUG           # Shotgun slug
}
@export var type: Type = Type.FMJ

@export var bullet_mass: float = 1.0     # grams
@export var cartridge_mass: float = 1.0  # grams
@export var muzzle_velocity: float = 1.0 # m/s
@export var penetration: float = 1.0     # relative or mm RHA

# ─── GAMEPLAY EFFECTS ────────────────────────────
@export_range(0.0, 1.0) var armor_damage: float = 0.0    # % armor durability loss
@export_range(0.0, 1.0) var bleeding_chance: float = 0.0 # % chance to cause bleed
@export_range(0.0, 1.0) var ricochet_chance: float = 0.0 # % chance to ricochet
@export_range(0.0, 1.0) var fragment_chance: float = 0.0 # % chance to fragment
@export var accuracy: float = 1.0  # mm R50 at 300m (lower = better)


# Normalized caliber data (computed from string)
var _caliber_data: Dictionary = {}

func _ready():
	_caliber_data = Utils.parse_caliber(caliber)

func get_bore_mm() -> float:
	return _caliber_data.get("bore_mm", 0.0)

func get_case_mm() -> float:
	return _caliber_data.get("case_mm", 0.0)

func _init(mass: float = bullet_mass, speed: float = muzzle_velocity, type: Type = type) -> void:
	self.bullet_mass = mass
	self.muzzle_velocity = speed
	self.type = type

# ─── PHYSICS ─────────────────────────────────────
func get_energy() -> float:
	return Utils.bullet_energy(bullet_mass, muzzle_velocity)

func get_momentum() -> float:
	return (bullet_mass / 1000.0) * muzzle_velocity  # kg·m/s

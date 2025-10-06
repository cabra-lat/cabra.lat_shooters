class_name Armor
extends Resource

# ─── METADATA ─────────────────────────────────────
@export var viewmodel: PackedScene
@export var equip_sound: AudioStream
@export var hit_sound: AudioStream
@export_multiline var description: String = "Generic armor"

# ─── CLASSIFICATION ───────────────────────────────
enum Standard { NIJ, VPAM, GOST, GA141, MILITARY }
@export var standard: Standard = Standard.NIJ
@export_range(1, 14) var level: int = 1

enum ArmorType { GENERIC, HELMET, VEST }
@export var type: ArmorType = ArmorType.GENERIC

# ─── PROTECTION ZONES ─────────────────────────────
@export_flags(
	"HEAD", "EYES", "LEFT_ARM", "RIGHT_ARM",
	"LEFT_LEG", "RIGHT_LEG", "STOMACH", "THORAX"
) var protection_zones: int = 0

# ─── DURABILITY & TRAUMA ──────────────────────────
@export var max_durability: int = 100
var current_durability: int = 100
@export_range(0, 50) var max_backface_deformation: float = 25.0

# ─── GAMEPLAY PENALTIES ───────────────────────────
@export_range(-1.0, 0.0) var turn_speed_penalty: float = 0.0
@export_range(-1.0, 0.0) var move_speed_penalty: float = 0.0
@export_range(0.0, 1.0) var ricochet_chance: float = 0.0
@export_range(-1.0, 0.0) var sound_reduction: float = 0.0
@export_range(-1.0, 0.0) var blind_reduction: float = 0.0

# ─── THREAT EVALUATION ────────────────────────────

func is_penetrated_by(ammo: Ammo) -> bool:
	if current_durability <= 0:
		return true
		
	# Check if it can stop the bullet
	var certified = _get_certified()
	var energy = certified.get(ammo.type)
	if energy and energy == ammo.get_energy():
		return false
	
	var max_allowed = _get_max_energy(ammo, certified)
	return ammo.get_energy() > max_allowed

func take_hit(ammo: Ammo) -> bool:
	if is_penetrated_by(ammo):
		return true
	current_durability -= randi_range(1, 2)
	return current_durability <= 0

# ─── INTERNAL: ENERGY THRESHOLDS (FROM KB) ────────

func E(m, v):
	return Utils.bullet_energy(m, v)

func _get_certified() -> Dictionary:
	match standard:
		Standard.VPAM:
			match level:
				1: return ({ Ammo.Type.FMJ: E(2.6, 360) })       # .22 LR
				2: return ({ Ammo.Type.FMJ: E(8.0, 360) })       # 9mm PM2
				3: return ({ Ammo.Type.FMJ: E(8.0, 415) })       # 9mm PM3
				4: return ({ Ammo.Type.JSP: E(10.2, 430), Ammo.Type.JHP: E(15.6, 440) }) # .357/.44 Mag
				5: return ({ Ammo.Type.FMJ: E(7.1, 580) })       # .357 FMs
				6: return ({ Ammo.Type.STEEL_CORE: E(8.0, 720) }) # 7.62x39mm PS
				7: return ({ Ammo.Type.GREEN_TIP: E(4.0, 950), Ammo.Type.STEEL_CORE: E(9.55, 830) }) # SS109 + DM111
				8: return ({ Ammo.Type.API: E(7.7, 740) })        # 7.62x39mm BZ API
				9: return ({ Ammo.Type.AP: E(9.7, 820) })         # 7.62x51mm P80 AP
				10: return ({ Ammo.Type.API: E(10.4, 860) })      # 7.62x54mmR B32 API
				11: return ({ Ammo.Type.AP: E(8.4, 930) })        # 7.62x51mm M993 AP
				12: return ({ Ammo.Type.AP: E(12.7, 810) })       # Swiss P AP
				13: return ({ Ammo.Type.AP: E(43.5, 930) })       # 12.7x99mm Swiss P
				14: return ({ Ammo.Type.API: E(63.4, 911) })      # 14.5x114mm B32 API
				_: return {}

		Standard.NIJ:
			match level:
				1: return ({ Ammo.Type.FMJ: max(E(2.6, 329), E(6.2, 322)) }) # .22 LR + .380 ACP
				2: return ({ Ammo.Type.FMJ: E(8.0, 398) })       # 9mm +P
				3: return ({ Ammo.Type.FMJ: E(8.0, 398), Ammo.Type.JSP: E(10.2, 436) }) # 9mm + .357 Mag
				4: return ({ Ammo.Type.AP: E(10.8, 878) })       # .30-06 M2 AP
				# NIJ 0123.00 (2024)
				5: return ({ Ammo.Type.FMJ: E(8.0, 398) })       # HG1 ≈ old II
				6: return ({ Ammo.Type.FMJ: E(8.1, 448), Ammo.Type.JHP: E(15.6, 436) }) # HG2 ≈ old IIIA
				7: return ({ Ammo.Type.FMJ: E(9.6, 847), Ammo.Type.STEEL_CORE: E(8.05, 732) }) # RF1: M80 + 7.62x39msc
				8: return ({ Ammo.Type.FMJ: E(9.6, 847), Ammo.Type.STEEL_CORE: E(8.05, 732), Ammo.Type.GREEN_TIP: E(4.0, 950) }) # RF2: + M855
				9: return ({ Ammo.Type.AP: E(10.8, 878) })       # RF3 ≈ old IV
				_: return {}

		Standard.GOST:
			match level:
				1: return ({ Ammo.Type.STEEL_CORE: E(5.9, 335) })  # 9x18mm Makarov BR1
				2: return ({ Ammo.Type.FMJ: E(7.93, 390) })        # 9x21mm Gyurza BR2
				3: return ({ Ammo.Type.STEEL_CORE: E(5.2, 455) })  # 9x19mm 7N21 BR3
				4: return ({ Ammo.Type.STEEL_CORE: max(E(3.4, 895), E(7.9, 720)) }) # 5.45x39mm + 7.62x39mm BR4
				5: return ({ Ammo.Type.STEEL_CORE: E(9.4, 830) })  # 7.62x54mmR 7N13 BR5
				6: return ({ Ammo.Type.API: E(48.2, 830) })        # 12.7x108mm B32 API BR6
				_: return {}

		Standard.MILITARY:
			match level:
				1: return ({ 
					Ammo.Type.FMJ: E(9.6, 840), 
					Ammo.Type.STEEL_CORE: E(9.5, 700), 
					Ammo.Type.GREEN_TIP: E(4.0, 990) 
				}) # SAPI
				2: return ({ 
					Ammo.Type.FMJ: E(9.6, 840), 
					Ammo.Type.STEEL_CORE: E(9.5, 840), 
					Ammo.Type.AP: E(10.8, 870), 
					Ammo.Type.M995: E(3.6, 1020) 
				}) # ESAPI Rev G
				_: return {}

		Standard.GA141:
			match level:
				1: return ({ Ammo.Type.FMJ: E(4.87, 320) }) # 7.62×17mm
				2: return ({ Ammo.Type.FMJ: E(5.60, 445) }) # 7.62×25mm Tokarev (Pistol)
				3: return ({ Ammo.Type.FMJ: E(5.60, 515) }) # 7.62×25mm Tokarev (SMG)
				4: return ({ Ammo.Type.FMJ: E(5.68, 515) }) # 7.62×25mm Tokarev AP (SMG)
				5: return ({ Ammo.Type.STEEL_CORE: E(8.05, 725) }) # 7.62×39mm
				6: return ({ Ammo.Type.STEEL_CORE: E(9.60, 830) }) # 7.62×54mmR
				_: return {}

		_:
			return {}

# ─── HELPER: THRESHOLD BY BULLET TYPE ──────────────

func _get_max_energy(bullet: Ammo, data: Dictionary) -> float:
	var value = data.get(bullet.type)
	if value != null:
		return value
	# Fallback: use highest energy in the dict (conservative)
	return data.values().max() if not data.is_empty() else 1000.0

# res://src/core/weapon/firemode.gd
class_name Firemode

# Bit flags for fire modes — use bitwise AND (`&`) to check availability
const SAFE: int   = 1 << 0  # Trigger disabled
const AUTO: int   = 1 << 1  # Fully automatic
const SEMI: int   = 1 << 2  # Semi-automatic (one shot per trigger pull)
const BURST: int  = 1 << 3  # Burst fire (e.g., 3-round burst)
const PUMP: int   = 1 << 4  # Pump-action (shotguns)
const BOLT: int   = 1 << 5  # Bolt-action (manual cycling)

static func get_name(mode: int) -> String:
	for name in ["SAFE", "AUTO", "SEMI", "BURST", "PUMP", "BOLT"]:
		if get_constant(name) == mode:
			return name
	return "UNKNOWN"

static func get_priority_order() -> Array[int]:
	return [AUTO, BURST, SEMI, PUMP, BOLT]

static func is_automatic(mode: int) -> bool:
	return mode == AUTO or mode == BURST

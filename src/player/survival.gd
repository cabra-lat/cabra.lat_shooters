# res://addons/cabra.lat_shooters/src/player/survival.gd
class_name PlayerSurvival
extends Resource
## Stamina / energy / hydration + encumbrance. Pure logic, no scene deps, so
## headless harnesses can drive it directly (see test harnesses).
##
## Reference numbers (docs/tarkov-feature-survey.md §5-6, ../tarkov-wiki):
## overweight ~22-25 kg, Endurance gives +1%/level stamina (skill system not
## built yet -> endurance_bonus_per_level hook), jump costs stamina and
## Strength reduces that drain (strength_bonus_per_level hook).

signal stamina_changed(current: float, maximum: float)
signal energy_changed(current: float, maximum: float)
signal hydration_changed(current: float, maximum: float)
signal exhausted_changed(exhausted: bool)

# ─── STAMINA ───────────────────────────────────────
@export var max_stamina: float = 100.0
@export var sprint_drain_per_second: float = 9.0
@export var jump_cost: float = 18.0
@export var regen_per_second: float = 14.0
@export var regen_delay: float = 1.2 # s after the last drain
@export var exhausted_threshold: float = 10.0 # below this: can't start sprint
@export var sprint_min_stamina: float = 15.0
@export var exhausted_recovery: float = 35.0 # must climb back above this
@export var exhaustion_speed_floor: float = 0.45 # speed scale in the last stretch
@export var low_stamina_wobble_at: float = 0.35 # ratio that starts aim wobble
@export var max_wobble: float = 0.02 # radians-ish camera jitter amplitude

# ─── SKILL HOOKS (skills are Fase 3/4) ─────────────
@export var endurance_level: int = 0 # +1%/level stamina (Tarkov Endurance)
@export var strength_level: int = 0 # reduces jump drain (Tarkov Strength)
@export var endurance_bonus_per_level: float = 0.01
@export var strength_jump_reduction_per_level: float = 0.01

# ─── WEIGHT / ENCUMBRANCE ──────────────────────────
@export var max_weight: float = 100.0 # hard limit (PlayerConfig.max_weight)
@export var overweight_at: float = 24.0 # Tarkov "overweight" notion ~22-25 kg
@export var speed_penalty_per_kg: float = 0.004 # -0.4%/kg under the threshold
@export var overweight_speed_penalty: float = 0.35 # extra -35% when overweight
@export var drain_penalty_per_kg: float = 0.02 # +2% stamina drain per kg
@export var overweight_drain_penalty: float = 1.0 # +100% drain when overweight
@export var overweight_blocks_sprint: bool = true

# ─── ENERGY / HYDRATION ────────────────────────────
@export var max_energy: float = 100.0
@export var max_hydration: float = 100.0
@export var energy_drain_per_second: float = 0.05 # ~33 min from full
@export var hydration_drain_per_second: float = 0.07 # ~24 min from full
@export var sprint_drain_multiplier: float = 3.0 # exertion burns faster
@export var starvation_damage_per_second: float = 0.4

# ─── STATE ─────────────────────────────────────────
var stamina: float = 100.0
var energy: float = 100.0
var hydration: float = 100.0
var total_weight: float = 0.0
var exhausted: bool = false

var _regen_timer: float = 0.0
var _max_stamina_effective: float = 100.0

func _init() -> void:
	stamina = _compute_max_stamina()
	_max_stamina_effective = stamina
	energy = max_energy
	hydration = max_hydration

# ─── PUBLIC API ────────────────────────────────────
func _compute_max_stamina() -> float:
	return max_stamina * (1.0 + endurance_level * endurance_bonus_per_level)

func get_max_stamina() -> float:
	var m := _compute_max_stamina()
	# Starving and dehydrated people have less to give.
	m *= clampf(0.6 + 0.4 * minf(energy / maxf(max_energy, 0.01), 1.0), 0.6, 1.0)
	m *= clampf(0.7 + 0.3 * minf(hydration / maxf(max_hydration, 0.01), 1.0), 0.7, 1.0)
	return m

func stamina_ratio() -> float:
	return clampf(stamina / maxf(get_max_stamina(), 0.01), 0.0, 1.0)

func energy_ratio() -> float:
	return clampf(energy / maxf(max_energy, 0.01), 0.0, 1.0)

func hydration_ratio() -> float:
	return clampf(hydration / maxf(max_hydration, 0.01), 0.0, 1.0)

func weight_ratio() -> float:
	return clampf(total_weight / maxf(max_weight, 0.01), 0.0, 2.0)

func is_overweight() -> bool:
	return total_weight > overweight_at

func set_weight(kilograms: float) -> void:
	total_weight = maxf(kilograms, 0.0)

## Speed scale from encumbrance: mild below the threshold, severe above.
func weight_speed_multiplier() -> float:
	var m := 1.0 - total_weight * speed_penalty_per_kg
	if is_overweight():
		var over := clampf((total_weight - overweight_at) / maxf(overweight_at, 0.01), 0.0, 1.0)
		m -= overweight_speed_penalty * (0.5 + 0.5 * over)
	return clampf(m, 0.25, 1.0)

## Speed scale while the pool is nearly empty (last stretch degrades).
func stamina_speed_multiplier() -> float:
	var r := stamina_ratio()
	if r >= low_stamina_wobble_at:
		return 1.0
	return lerpf(exhaustion_speed_floor, 1.0, r / maxf(low_stamina_wobble_at, 0.01))

func stamina_fov_multiplier() -> float:
	var r := stamina_ratio()
	if r >= low_stamina_wobble_at:
		return 1.0
	return lerpf(0.9, 1.0, r / maxf(low_stamina_wobble_at, 0.01))

func drain_multiplier() -> float:
	var m := 1.0 + total_weight * drain_penalty_per_kg
	if is_overweight():
		m += overweight_drain_penalty
	return m

func can_start_sprint() -> bool:
	if is_overweight() and overweight_blocks_sprint:
		return false
	return stamina > sprint_min_stamina and not exhausted

func can_sprint() -> bool:
	if is_overweight() and overweight_blocks_sprint:
		return false
	if exhausted:
		return false
	return stamina > 2.0

func can_jump() -> bool:
	return stamina >= jump_cost * 0.5

## Aim wobble amplitude (low stamina + pain feed the tremor).
func wobble_amplitude(pain: float = 0.0, fracture: bool = false) -> float:
	var low := clampf(1.0 - stamina_ratio() / maxf(low_stamina_wobble_at, 0.01), 0.0, 1.0)
	var a := low * max_wobble
	a += clampf(pain, 0.0, 1.0) * max_wobble * 0.8
	if fracture:
		a += max_wobble * 0.5
	return a

## Spend stamina for a jump. Returns false when too tired (jump denied).
func spend_jump() -> bool:
	var cost := jump_cost * clampf(1.0 - strength_level * strength_jump_reduction_per_level, 0.3, 1.0)
	if stamina < cost:
		return false
	stamina = maxf(stamina - cost, 0.0)
	_regen_timer = regen_delay
	_emit_stamina()
	_refresh_exhausted()
	return true

func consume_stamina(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	_regen_timer = regen_delay
	_emit_stamina()
	_refresh_exhausted()

func add_energy(amount: float) -> void:
	energy = clampf(energy + amount, 0.0, max_energy)
	energy_changed.emit(energy, max_energy)

func add_hydration(amount: float) -> void:
	hydration = clampf(hydration + amount, 0.0, max_hydration)
	hydration_changed.emit(hydration, max_hydration)

## Per-frame integration. `sprinting` must reflect the ACTUALLY applied
## sprint (blocked sprint passes false), `moving` any locomotion at all.
func update(delta: float, sprinting: bool, moving: bool) -> void:
	var exertion := 1.0
	if sprinting:
		exertion = sprint_drain_multiplier

	# Energy / hydration burn.
	energy = maxf(energy - energy_drain_per_second * exertion * delta, 0.0)
	hydration = maxf(hydration - hydration_drain_per_second * exertion * delta, 0.0)

	# Stamina: drain while sprinting, regen after a delay otherwise.
	if sprinting:
		consume_stamina(sprint_drain_per_second * drain_multiplier() * delta)
	else:
		_regen_timer = maxf(_regen_timer - delta, 0.0)
		if _regen_timer <= 0.0:
			var r := stamina_ratio()
			# Regen slows as the pool fills (Tarkov-ish curve).
			var rate := regen_per_second * (1.0 - 0.5 * r)
			stamina = minf(stamina + rate * delta, get_max_stamina())
			_emit_stamina()

	energy_changed.emit(energy, max_energy)
	hydration_changed.emit(hydration, max_hydration)
	_refresh_exhausted()

func _refresh_exhausted() -> void:
	var was := exhausted
	if not exhausted and stamina <= exhausted_threshold:
		exhausted = true
	elif exhausted and stamina >= exhausted_recovery:
		exhausted = false
	if exhausted != was:
		exhausted_changed.emit(exhausted)

func _emit_stamina() -> void:
	stamina_changed.emit(stamina, get_max_stamina())

# res://addons/cabra.lat_shooters/src/ui/hud/status_hud.gd
class_name PlayerStatusHud
extends CanvasLayer
## Discrete survival HUD: stamina, weight/overweight, energy + hydration and
## the medical condition indicators. Self-installed by PlayerController when
## the scene ships none, and styled with the shared HudStyle so it matches the
## arena / debug range look. No crosshair by design.

const COLOUR_STAMINA := Color(0.75, 0.85, 0.95)
const COLOUR_STAMINA_LOW := Color(0.95, 0.55, 0.35)
const COLOUR_ENERGY := Color(0.95, 0.80, 0.45)
const COLOUR_HYDRATION := Color(0.45, 0.75, 0.95)
const COLOUR_OK := Color(0.80, 0.85, 0.88)
const COLOUR_WARN := Color(0.95, 0.72, 0.35)
const COLOUR_BAD := Color(0.95, 0.35, 0.32)

var _player: Node # PlayerController, duck-typed so headless harnesses can load this script
var _bars := {}
var _conditions: Label
var _weight: Label
var _use_label: Label
var _use_bar: ProgressBar
var _result_label: Label
var _malfunction_label: Label
var _malfunction_bar: ProgressBar
var _result_timer: float = 0.0
var _root: Control


func _ready() -> void:
	layer = 20 # above the gameplay HUD, below nothing else
	_build()


func bind_player(player: Node) -> void:
	_player = player
	if not player.consumed.is_connected(_on_consumed):
		player.consumed.connect(_on_consumed)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", HudStyle.panel())
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position = Vector2(24, -132)
	panel.custom_minimum_size = Vector2(240, 0)
	_root.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)

	_bars["stamina"] = _add_bar(box, "STAMINA", COLOUR_STAMINA)
	_bars["energy"] = _add_bar(box, "ENERGY", COLOUR_ENERGY)
	_bars["hydration"] = _add_bar(box, "HYDRATION", COLOUR_HYDRATION)

	_weight = Label.new()
	_weight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weight.add_theme_font_size_override("font_size", 13)
	_weight.add_theme_color_override("font_color", COLOUR_OK)
	box.add_child(_weight)

	_conditions = Label.new()
	_conditions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_conditions.add_theme_font_size_override("font_size", 14)
	_conditions.add_theme_color_override("font_color", COLOUR_WARN)
	box.add_child(_conditions)

	# Item in use: name + use_time progress, then the outcome for a moment.
	_use_label = Label.new()
	_use_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_use_label.add_theme_font_size_override("font_size", 13)
	_use_label.add_theme_color_override("font_color", COLOUR_OK)
	_use_label.visible = false
	box.add_child(_use_label)

	_use_bar = ProgressBar.new()
	_use_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_use_bar.show_percentage = false
	_use_bar.custom_minimum_size = Vector2(150, 6)
	_use_bar.max_value = 1.0
	var use_fill := StyleBoxFlat.new()
	use_fill.bg_color = Color(0.55, 0.85, 0.55)
	use_fill.corner_radius_top_left = 2
	use_fill.corner_radius_top_right = 2
	use_fill.corner_radius_bottom_left = 2
	use_fill.corner_radius_bottom_right = 2
	_use_bar.add_theme_stylebox_override("fill", use_fill)
	var use_bg := StyleBoxFlat.new()
	use_bg.bg_color = Color(0.10, 0.12, 0.15, 0.85)
	use_bg.corner_radius_top_left = 2
	use_bg.corner_radius_top_right = 2
	use_bg.corner_radius_bottom_left = 2
	use_bg.corner_radius_bottom_right = 2
	_use_bar.add_theme_stylebox_override("background", use_bg)
	_use_bar.visible = false
	box.add_child(_use_bar)

	_result_label = Label.new()
	_result_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_label.add_theme_font_size_override("font_size", 13)
	_result_label.add_theme_color_override("font_color", COLOUR_OK)
	_result_label.visible = false
	box.add_child(_result_label)

	# Weapon malfunction (jam): condition + clearing progress.
	_malfunction_label = Label.new()
	_malfunction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_malfunction_label.add_theme_font_size_override("font_size", 13)
	_malfunction_label.add_theme_color_override("font_color", COLOUR_BAD)
	_malfunction_label.visible = false
	box.add_child(_malfunction_label)

	_malfunction_bar = ProgressBar.new()
	_malfunction_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_malfunction_bar.show_percentage = false
	_malfunction_bar.custom_minimum_size = Vector2(150, 6)
	_malfunction_bar.max_value = 1.0
	var jam_fill := StyleBoxFlat.new()
	jam_fill.bg_color = COLOUR_BAD
	jam_fill.corner_radius_top_left = 2
	jam_fill.corner_radius_top_right = 2
	jam_fill.corner_radius_bottom_left = 2
	jam_fill.corner_radius_bottom_right = 2
	_malfunction_bar.add_theme_stylebox_override("fill", jam_fill)
	var jam_bg := StyleBoxFlat.new()
	jam_bg.bg_color = Color(0.10, 0.12, 0.15, 0.85)
	jam_bg.corner_radius_top_left = 2
	jam_bg.corner_radius_top_right = 2
	jam_bg.corner_radius_bottom_left = 2
	jam_bg.corner_radius_bottom_right = 2
	_malfunction_bar.add_theme_stylebox_override("background", jam_bg)
	_malfunction_bar.visible = false
	box.add_child(_malfunction_bar)


func _add_bar(parent: Node, label_text: String, colour: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", COLOUR_OK)
	name_label.custom_minimum_size = Vector2(76, 0)
	row.add_child(name_label)

	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(150, 10)
	bar.max_value = 100.0
	bar.value = 100.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = colour
	fill.corner_radius_top_left = 2
	fill.corner_radius_top_right = 2
	fill.corner_radius_bottom_left = 2
	fill.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.12, 0.15, 0.85)
	bg.corner_radius_top_left = 2
	bg.corner_radius_top_right = 2
	bg.corner_radius_bottom_left = 2
	bg.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("background", bg)
	row.add_child(bar)
	return bar


func _process(delta: float) -> void:
	if _player == null:
		return
	var survival = _player.survival
	if survival == null:
		return

	var stamina_ratio: float = survival.stamina_ratio()
	_set_bar("stamina", stamina_ratio * 100.0, stamina_ratio)
	_set_bar("energy", survival.energy_ratio() * 100.0, survival.energy_ratio())
	_set_bar("hydration", survival.hydration_ratio() * 100.0, survival.hydration_ratio())

	# Weight + overweight marker.
	var w: float = _player.get_total_weight()
	var over: bool = survival.is_overweight()
	_weight.text = "%.1f / %.0f kg%s" % [w, survival.max_weight, "  OVERWEIGHT" if over else ""]
	_weight.add_theme_color_override("font_color", COLOUR_BAD if over else COLOUR_OK)

	_conditions.text = _condition_text(_player.health)

	# Item in use: name + use_time progress.
	if _player.is_consuming() and _player.consuming_item != null:
		var med = _player.consuming_item.extra
		var total: float = (med as MedicalItem).use_time if med is MedicalItem else 1.0
		_use_label.text = "Using %s" % _player.consuming_item.name
		_use_label.visible = true
		_use_bar.value = 1.0 - clampf(_player.consume_time_left / maxf(total, 0.01), 0.0, 1.0)
		_use_bar.visible = true
	else:
		_use_label.visible = false
		_use_bar.visible = false

	if _result_timer > 0.0:
		_result_timer = maxf(_result_timer - delta, 0.0)
		_result_label.visible = _result_timer > 0.0
	else:
		_result_label.visible = false

	_update_malfunction()


## Weapon malfunction block, driven by Weapon.get_state() (no parallel state).
func _update_malfunction() -> void:
	if _malfunction_label == null:
		return
	var state: Dictionary = _player.get_weapon_state() if _player.has_method("get_weapon_state") else {}
	if state.is_empty() or str(state.get("malfunction_name", "none")) == "none":
		_malfunction_label.visible = false
		_malfunction_bar.visible = false
		return
	_malfunction_label.text = malfunction_text(state)
	_malfunction_label.visible = true
	var remaining: float = float(state.get("clearing", 0.0))
	_malfunction_bar.visible = remaining > 0.0
	if remaining > 0.0:
		_malfunction_bar.value = 1.0 - remaining / maxf(_clearing_total(), 0.01)


## Full clearing duration for the held weapon's current fault (for the bar).
func _clearing_total() -> float:
	var hands = _player.get("current_hands")
	if hands == null:
		return 1.0
	var w = hands.get("data")
	if not (w is Weapon):
		return 1.0
	var weapon := w as Weapon
	return maxf(weapon.clearing_time_for(weapon.active_malfunction), 0.01)


## Pure text for the jam block (unit-testable): "JAMMED: FEED FAILURE".
static func malfunction_text(state: Dictionary) -> String:
	var name := str(state.get("malfunction_name", "none")).to_upper().replace("_", " ")
	var remaining := float(state.get("clearing", 0.0))
	if remaining > 0.0:
		return "JAMMED: %s  ·  clearing" % name
	return "JAMMED: %s  (press X)" % name


func _on_consumed(item: InventoryItem, result: Dictionary) -> void:
	_result_label.text = "%s: %s" % [item.name if item != null else "Item", describe(result)]
	_result_label.add_theme_color_override("font_color",
		COLOUR_BAD if result.get("error", "") != "" else COLOUR_OK)
	_result_label.visible = true
	_result_timer = 4.0


## Human-readable outcome of a consumed item (the "feedback" the brief asks for).
static func describe(result: Dictionary) -> String:
	var parts: Array[String] = []
	if result.get("stopped_heavy", false):
		parts.append("heavy bleeding stopped")
	if result.get("stopped_light", false):
		parts.append("bleeding stopped")
	if result.get("fixed_fracture", false):
		parts.append("fracture immobilised")
	if result.get("surgery", false):
		parts.append("limb restored")
	if result.get("pain_seconds", 0.0) > 0.0:
		parts.append("pain suppressed")
	if result.get("healed", 0.0) > 0.0:
		parts.append("+%.0f HP" % result["healed"])
	if result.get("energy", 0.0) != 0.0:
		parts.append("%+.0f energy" % result["energy"])
	if result.get("hydration", 0.0) != 0.0:
		parts.append("%+.0f hydration" % result["hydration"])
	var err: String = result.get("error", "")
	if err != "":
		return err
	if parts.is_empty():
		return "no effect"
	return ", ".join(parts)


func _set_bar(key: String, value: float, ratio: float) -> void:
	var bar: ProgressBar = _bars.get(key)
	if bar == null:
		return
	bar.value = value
	if key == "stamina":
		var fill: StyleBoxFlat = bar.get_theme_stylebox("fill")
		fill.bg_color = COLOUR_STAMINA_LOW if ratio < 0.35 else COLOUR_STAMINA


## Discrete condition readout; the label hides itself when healthy.
func _condition_text(health) -> String:
	if health == null:
		return ""
	var parts: Array[String] = []
	if health.has_heavy_bleeding():
		parts.append("HEAVY BLEED")
	elif health.has_light_bleeding():
		parts.append("bleeding")
	if health.has_fracture():
		parts.append("fracture")
	if health.effective_pain() > 0.25:
		parts.append("pain")
	var blacked: Array = health.get_blacked_parts()
	if not blacked.is_empty():
		parts.append("blacked x%d" % blacked.size())
	if survival_dehydrated(health):
		parts.append("dehydrated")
	return "   ".join(parts)


func survival_dehydrated(_health) -> bool:
	if _player == null or _player.survival == null:
		return false
	return _player.survival.hydration <= 0.0

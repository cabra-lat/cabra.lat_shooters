class_name DebugSingleton
extends Node

# Debug levels
enum DEBUG_LEVEL {
  NONE = 0,
  ERROR = 1,
  WARNING = 2,
  INFO = 3,
  VERBOSE = 4
}

# Singleton instance
static var instance: DebugSingleton

# Debug data storage
var _debug_data: Dictionary = {}
var _timing_data: Dictionary = {}
var _frame_history: Array[float] = []
var _max_history: int = 120  # Keep last 120 frames

# Configuration
var debug_level: DEBUG_LEVEL = DEBUG_LEVEL.INFO
var enabled: bool = true
var show_fps: bool = true
var show_timings: bool = true
var show_states: bool = true
var show_performance: bool = true

# Formatting
var _section_colors: Dictionary = {
  "performance": "#FF6B6B",
  "states": "#4ECDC4",
  "timings": "#45B7D1",
  "movement": "#96CEB4",
  "input": "#FFEAA7",
  "system": "#DDA0DD"
}

func _init():
  instance = self
  name = "DebugSingleton"
  print("DebugSingleton initialized")

func _ready():
  # Set process to true so we can track frame times
  set_process(true)

func _process(delta: float):
  if not enabled:
    return

  # Track frame time for FPS calculation
  var frame_time = Engine.get_frames_per_second()
  _frame_history.append(frame_time)
  if _frame_history.size() > _max_history:
    _frame_history.remove_at(0)

# ─── PUBLIC API ────────────────────────────────────────────────────────────────

# Add any data with optional category and level
static func add(key: String, value, category: String = "general", level: DEBUG_LEVEL = DEBUG_LEVEL.INFO):
  if not instance or not instance.enabled:
    return

  if level > instance.debug_level:
    return

  if not instance._debug_data.has(category):
    instance._debug_data[category] = {}

  instance._debug_data[category][key] = value

# Add timing data
static func time(key: String, duration_ms: float, level: DEBUG_LEVEL = DEBUG_LEVEL.INFO):
  if not instance or not instance.enabled:
    return

  if level > instance.debug_level:
    return

  if not instance._timing_data.has(key):
    instance._timing_data[key] = []

  instance._timing_data[key].append(duration_ms)

  # Keep only last 60 samples
  if instance._timing_data[key].size() > 60:
    instance._timing_data[key].remove_at(0)

# Start a timer and return the stop function
static func timer(key: String, level: DEBUG_LEVEL = DEBUG_LEVEL.INFO) -> Callable:
  if not instance or not instance.enabled:
    return func(): pass

  if level > instance.debug_level:
    return func(): pass

  var start_time = Time.get_ticks_usec()

  return func():
    var end_time = Time.get_ticks_usec()
    var duration = (end_time - start_time) / 1000.0
    Debug.time(key, duration, level)

# Clear all debug data
static func clear():
  if not instance:
    return

  instance._debug_data.clear()
  instance._timing_data.clear()

# Clear specific category
static func clear_category(category: String):
  if not instance:
    return

  if instance._debug_data.has(category):
    instance._debug_data[category].clear()

# Get formatted debug text
static func get_text() -> String:
  if not instance or not instance.enabled:
    return ""

  var text = ""

  # Performance section
  if instance.show_performance:
    text += instance._format_section("Performance", "performance")
    if instance.show_fps:
      text += instance._format_fps()

  # Timings section
  if instance.show_timings and not instance._timing_data.is_empty():
    text += instance._format_section("Timings", "timings")
    text += instance._format_timings()

  # States and other debug data
  for category in instance._debug_data:
    if instance._debug_data[category].is_empty():
      continue

    var category_display = category.capitalize()
    var color_key = category.to_lower()
    if not instance._section_colors.has(color_key):
      color_key = "system"

    text += instance._format_section(category_display, color_key)
    text += instance._format_category(category)

  return text

# Get raw data for custom formatting
static func get_data(category: String = "") -> Dictionary:
  if not instance:
    return {}

  if category.is_empty():
    return instance._debug_data.duplicate(true)

  return instance._debug_data.get(category, {}).duplicate(true)

# Get timing data
static func get_timings(key: String = "") -> Variant:
  if not instance:
    return {} if key.is_empty() else []

  if key.is_empty():
    return instance._timing_data.duplicate(true)

  return instance._timing_data.get(key, []).duplicate()

# ─── FORMATTING METHODS ────────────────────────────────────────────────────────

func _format_section(title: String, color_key: String) -> String:
  var color = _section_colors.get(color_key, "#FFFFFF")
  return "[color=%s][b]%s[/b][/color]\n" % [color, title]

func _format_fps() -> String:
  if _frame_history.is_empty():
    return "  FPS: N/A\n"

  var current_fps = _frame_history[-1]
  var avg_fps = _calculate_average(_frame_history)
  var min_fps = _frame_history.min()
  var max_fps = _frame_history.max()

  return "  FPS: %d (Avg: %d, Min: %d, Max: %d)\n" % [current_fps, avg_fps, min_fps, max_fps]

func _format_timings() -> String:
  var text = ""
  for key in _timing_data:
    var times = _timing_data[key]
    if times.is_empty():
      continue

    var current = times[-1]
    var average = _calculate_average(times)
    var max_time = times.max()

    text += "  %s: %.2fms (Avg: %.2fms, Max: %.2fms)\n" % [key, current, average, max_time]

  return text

func _format_category(category: String) -> String:
  var text = ""
  var data = _debug_data[category]

  for key in data:
    var value = data[key]

    # Format based on type
    if value is String:
      text += "  %s: %s\n" % [key, value]
    elif value is float:
      text += "  %s: %.2f\n" % [key, value]
    elif value is int:
      text += "  %s: %d\n" % [key, value]
    elif value is bool:
      text += "  %s: %s\n" % [key, "[color='green']true[/color]" if value else "[color='red']false[/color]"]
    elif value is Vector2:
      text += "  %s: %.2f %.2f\n" % [key, value.x, value.y]
    elif value is Vector3:
      text += "  %s: %.2f %.2f %.2f\n" % [key, value.x, value.y, value.z]
    else:
      text += "  %s: %s\n" % [key, str(value)]

  return text

func _calculate_average(array: Array) -> float:
  if array.is_empty():
    return 0.0

  var sum = 0.0
  for item in array:
    sum += item
  return sum / array.size()

# ─── CONFIGURATION METHODS ─────────────────────────────────────────────────────

static func set_debug_level(level: DEBUG_LEVEL):
  if instance:
    instance.debug_level = level

static func set_enabled(is_enabled: bool):
  if instance:
    instance.enabled = is_enabled

static func toggle_enabled() -> bool:
  if instance:
    instance.enabled = !instance.enabled
    return instance.enabled
  return false

static func configure(show_fps: bool, show_timings: bool, show_states: bool, show_performance: bool):
  if instance:
    instance.show_fps = show_fps
    instance.show_timings = show_timings
    instance.show_states = show_states
    instance.show_performance = show_performance

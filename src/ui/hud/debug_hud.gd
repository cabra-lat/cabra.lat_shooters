class_name DebugHUD
extends Control

@onready var visibility = $Visibility
@onready var popup = $Popup
@onready var GameLog = $GameLog

func _ready():
  GameLog.text = ''
  popup.text = ''
  popup.hide()
  _on_debug_timer_timeout()

func _on_debug_timer_timeout() -> void:
  $CurrentState.text = Debug.get_text()

func add_log(log):
  GameLog.text = '[' + Time.get_datetime_string_from_system() \
    + '] - ' + str(log) + '\n' + GameLog.text

func show_popup(content: String, wait_time: float = 1.0) -> void:
  visibility.wait_time = wait_time
  visibility.start()
  popup.text = content
  add_log(content)
  popup.show()
  await visibility.timeout
  popup.hide()

func _on_show_firemode(mode: String):
  show_popup(mode.capitalize(), 0.5)

func _on_show_ammo_left(remaining: int, capacity: int):
  var duration = 0.5
  if remaining == 0 and capacity == 0:
    show_popup(tr("dettached"), duration)
    return
  var ratio = float(remaining) / float(capacity)
  if abs(ratio - 1.0) < 0.1:
    show_popup(tr("full"), duration)
  elif abs(ratio - 0.5) < 0.1:
    show_popup(tr("about half"), duration)
  elif ratio > 0:
    show_popup(tr("less than half"), duration)
  else:
    show_popup(tr("empty"), duration)

class_name HUD extends Control

@onready var visibility = $Visibility
@onready var bottom_right_popup   = $BottomRightPopup

func _ready():
    bottom_right_popup.hide()
    
func update_debug(content: String) -> void:
    $CurrentState.text = content

func show_popup(content: String, wait_time: float = 1.0) -> void:
    visibility.wait_time = wait_time
    visibility.start()
    bottom_right_popup.text = content
    bottom_right_popup.show()
    await visibility.timeout
    bottom_right_popup.hide()

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

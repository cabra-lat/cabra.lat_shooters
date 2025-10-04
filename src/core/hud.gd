class_name HUD
extends Control

@onready var visibility = $Visibility
@onready var bottom_right_popup   = $BottomRightPopup

func _ready():
	bottom_right_popup.hide()

func show_popup(content: String, wait_time: float = 1.0):
	visibility.wait_time = wait_time
	visibility.start()
	bottom_right_popup.text = content
	bottom_right_popup.show()
	await visibility.timeout
	bottom_right_popup.hide()

func show_firemode(mode: String):
	show_popup(mode.capitalize(), 0.1)

func show_ammo_left(remaining: int, capacity: int):
	var ratio = float(remaining) / float(capacity)
	if abs(ratio - 1.0) < 0.1:
		show_popup(tr("full"), 0.1)
	elif abs(ratio - 0.5) < 0.1:
		show_popup(tr("about half"), 0.1)
	elif ratio > 0:
		show_popup(tr("less than half"), 0.1)
	else:
		show_popup(tr("empty"), 0.1)

class_name PlayerAnimations extends AnimationPlayer

var tween

func _on_player_aiming(player: PlayerController, reverse: bool) -> void:
	if tween: tween.kill()
	tween = player.create_tween()
	var duration = player.config.aim_time
	var change = 0.14 if not reverse else 0
	print("hello from ", reverse, change, duration, tween)
	tween.tween_property(player.shoulder, "position:x", change, duration)

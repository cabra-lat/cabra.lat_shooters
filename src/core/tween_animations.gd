extends Node

func _on_player_move(player, camera, head, delta):
	# Changes in FOV
	camera.fov = lerp(camera.fov, player.camera_fov, 5 * delta)
	head.position.y = lerp(head.position.y, player.camera_height, 10 * delta)

	# Head Bobbing
	if player.speed > 0:
		var speed_ratio = player.speed / player.walk_speed
		var amplitude = 0.5 * speed_ratio
		player.head_bobbing = -player.head_bobbing
		var animation_speed = 0.25 / clamp(speed_ratio, 1, 1.6)

		var tween = create_tween()
		tween.tween_property($Head/Movements, "rotation_degrees", Vector3(-amplitude, 0, player.head_bobbing), animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property($Head/Movements, "rotation_degrees", Vector3.ZERO, animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_player_lean(player, head, collision, direction):
	var animation_speed = 0.1
	var angle = player.lean_angle * direction
	# Convert degrees to radians for sin()
	var displ = head.position.y * sin(deg_to_rad(angle))

	var tween = create_tween()
	tween.tween_property(head, "rotation_degrees:z", angle, animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(head, "position:x", displ, animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(collision, "rotation_degrees:z", angle, animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(collision, "position:x", displ, animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_player_prone(reverse = false):
	var animation_speed = 0.1
	if not reverse:
		var tween = create_tween()
		tween.tween_property($Head, "position:y",  0, animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property($CollisionShape3D, "shape:height", 0, animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		var tween = create_tween()
		tween.tween_property($Head, "position:y", 0.9, animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property($CollisionShape3D, "shape:height", 0.9, animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_player_crouch():
	var animation_speed = 0.4
	var crouch_tween = create_tween()
	crouch_tween.tween_property($Head, "position:y", 0.9 / 1.5, animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	crouch_tween.tween_property($CollisionShape3D, "shape:height", 1.0 / 1.5, animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var cam_tween = create_tween()
	cam_tween.tween_property($Head/Movements, "rotation_degrees:z", -1, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.35)
	cam_tween.tween_property($Head/Movements, "rotation_degrees:z",  0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.5)
	cam_tween.tween_property($Head/Movements, "rotation_degrees:x", -1, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.35)
	cam_tween.tween_property($Head/Movements, "rotation_degrees:x",  0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.5)


func _on_player_uncrouch():
	var crouch_tween = create_tween()
	crouch_tween.tween_property($Head, "position:y", 0.9, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	crouch_tween.tween_property($CollisionShape3D, "shape:height", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var cam_tween = create_tween()
	cam_tween.tween_property($Head/Movements, "rotation_degrees:z", 1, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cam_tween.tween_property($Head/Movements, "rotation_degrees:z",-1, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.15)
	cam_tween.tween_property($Head/Movements, "rotation_degrees:z", 0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.3)
	cam_tween.tween_property($Head/Movements, "rotation_degrees:x", -1, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cam_tween.tween_property($Head/Movements, "rotation_degrees:x",  0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.3)


func _on_player_jumped():
	var tween = create_tween()
	tween.tween_property($Head/Movements, "rotation_degrees:x", -5, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($Head/Movements, "rotation_degrees:x", 0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.2)
	tween.tween_property($Head/Movements, "rotation_degrees:z", -1, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.2)
	tween.tween_property($Head/Movements, "rotation_degrees:z",  0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.5)
	tween.tween_property($Head/Movements, "position:y", -0.5, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($Head/Movements, "position:y",    0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.2)


func _on_player_landed():
	var tween = create_tween()
	tween.tween_property($Head/Movements, "position:y", -0.5, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($Head/Movements, "position:y",    0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.15)
	tween.tween_property($Head/Movements, "rotation_degrees:x", -5, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($Head/Movements, "rotation_degrees:x",  0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.3)
	tween.tween_property($Head/Movements, "rotation_degrees:z", -1, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($Head/Movements, "rotation_degrees:z",  0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.4)

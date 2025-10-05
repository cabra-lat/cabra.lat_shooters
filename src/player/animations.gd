class_name PlayerAnimations extends AnimationPlayer

const VIEWMODEL_NAME = "WeaponViewModel"

func _on_player_aiming(player: Player, reverse: bool = false):
	var config = player.config
	var camera = player.camera
	var shoulder = player.shoulder
	
	var aim_tween = create_tween()
	if not reverse:
		aim_tween.tween_property(camera, "fov", config.aim_fov, config.aim_time) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)
		aim_tween.tween_property(shoulder, "position:x", 0, config.aim_time) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)
	else:
		aim_tween.tween_property(camera, "fov", config.default_fov, config.aim_time) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
		aim_tween.tween_property(shoulder, "position:x", config.default_shoulder, config.aim_time) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)


func _on_player_moved(player: Player, delta: float):
	var config = player.config
	var camera = player.camera
	var head   = player.head
	var shoulder = player.shoulder
	camera.fov = lerp(camera.fov, config.camera_fov, 5 * delta)
	head.position.y = lerp(head.position.y, config.camera_height, 10 * delta)

	if config.speed > 0:
		var speed_ratio = config.speed / config.walk_speed
		var amplitude = 0.5 * speed_ratio
		config.head_bobbing = -config.head_bobbing
		var animation_speed = 0.25 / clamp(speed_ratio, 1, 1.6)
		var new_vector = Vector3(-amplitude, 0, config.head_bobbing)
		var move_tween = create_tween()
		move_tween.tween_property(camera, "rotation_degrees", new_vector, animation_speed) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)
		move_tween.tween_property(camera, "rotation_degrees", Vector3.ZERO, animation_speed) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)

func _on_player_leaned(player: Player, direction: int):
	var config = player.config
	var camera = player.camera
	var head   = player.head
	var shoulder = player.shoulder
	var collision = player.collision
	var animation_speed = config.lean_speed
	
	var angle = config.lean_angle * direction
	var displ = head.position.y * sin(deg_to_rad(angle))
	
	var crouch_tween = create_tween()
	crouch_tween.tween_property(head, "rotation_degrees:z", angle, animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	crouch_tween.tween_property(head, "position:x", displ, animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	crouch_tween.tween_property(collision, "rotation_degrees:z", angle, animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	crouch_tween.tween_property(collision, "position:x", displ, animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_player_proned(player: Player, reverse = false):
	var config    = player.config
	var head      = player.head
	var collision = player.collision
	var animation_speed = config.prone_speed
	var crouch_tween = create_tween()
	if not reverse:
		crouch_tween.tween_property(head, "position:y", 0, animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		crouch_tween.tween_property(collision, "shape:height", 0, animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		crouch_tween.tween_property(head, "position:y", 0.9, animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		crouch_tween.tween_property(collision, "shape:height", 0.9, animation_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_player_crouched(player: Player, reverse = false):
	var config    = player.config
	var head      = player.head
	var camera    = player.camera
	var collision = player.collision
	var animation_speed = config.crouch_speed
	var crouch_tween = create_tween()
	
	if not reverse:
		crouch_tween.tween_property(head, "position:y", head.position.y / 1.5, animation_speed) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)
		crouch_tween.tween_property(collision, "shape:height", collision.shape.height / 1.5, animation_speed) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)
		crouch_tween.tween_property(camera, "rotation_degrees:z", -1, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.35)
		crouch_tween.tween_property(camera, "rotation_degrees:z", 0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.5)
		crouch_tween.tween_property(camera, "rotation_degrees:x", -1, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.35)
		crouch_tween.tween_property(camera, "rotation_degrees:x", 0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.5)
	else:
		crouch_tween.tween_property(head, "position:y", 0.9, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		crouch_tween.tween_property(collision, "shape:height", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		crouch_tween.tween_property(camera, "rotation_degrees:z", 1, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		crouch_tween.tween_property(camera, "rotation_degrees:z", -1, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.15)
		crouch_tween.tween_property(camera, "rotation_degrees:z", 0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.3)
		crouch_tween.tween_property(camera, "rotation_degrees:x", -1, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		crouch_tween.tween_property(camera, "rotation_degrees:x", 0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.3)

func _on_player_jumped(player: Player):
	var camera = player.camera
	var jump_tween = create_tween()
	jump_tween.tween_property(camera, "rotation_degrees:x", -5, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	jump_tween.tween_property(camera, "rotation_degrees:x", 0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.2)
	jump_tween.tween_property(camera, "rotation_degrees:z", -1, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.2)
	jump_tween.tween_property(camera, "rotation_degrees:z", 0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.5)
	jump_tween.tween_property(camera, "position:y", -0.5, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	jump_tween.tween_property(camera, "position:y", 0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.2)

func _on_player_landed(player: Player, max_velocity: float, delta: float):
	var camera = player.camera
	var jump_tween = create_tween()
	jump_tween.tween_property(camera, "position:y", -0.5, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	jump_tween.tween_property(camera, "position:y", 0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.15)
	jump_tween.tween_property(camera, "rotation_degrees:x", -5, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	jump_tween.tween_property(camera, "rotation_degrees:x", 0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.3)
	jump_tween.tween_property(camera, "rotation_degrees:z", -1, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	jump_tween.tween_property(camera, "rotation_degrees:z", 0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.4)

func _on_player_unequiped(player: Player):
	var old_vm = player.hand.get_node_or_null(VIEWMODEL_NAME)
	if old_vm:
		old_vm.queue_free()
	player.weapon = null
	
func _on_player_equipped(player: Player):
	if not player.weapon: return
	var new_vm = player.weapon.viewmodel.instantiate()
	new_vm.name = VIEWMODEL_NAME
	player.hand.add_child(new_vm)

func _on_player_insert_ammofeed(player: Player) -> void:
	pass # Replace with function body.

func _on_player_check_ammofeed(player: Player, ammofeed: AmmoFeed) -> void:
	pass # Replace with function body.

func _on_player_reloaded(player: Player) -> void:
	pass # Replace with function body.

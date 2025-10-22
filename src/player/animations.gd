class_name PlayerAnimations extends AnimationPlayer

func _on_player_aimed(player: PlayerController, reverse: bool = false) -> void:
  var tween = player.create_tween()
  var duration = player.config.aim_time
  var change = 0.0 if not reverse else 0.117
  print("_on_player_aiming: ", reverse, change, duration, tween)
  tween.tween_property(player.shoulder, "position:x", change, duration)

func _on_player_crouched(player: PlayerController, reverse: bool = false) -> void:
  var tween = player.create_tween()
  var duration = player.config.crouch_time
  var change_height = player.config.crouch_height if not reverse else player.config.default_height
  tween.tween_property(player.head, "position:y", change_height, duration)
  tween.tween_property(player.collision, "shape:height", change_height, duration) # What if there is something over my head?

func _on_player_proned(player: PlayerController, reverse: bool = false) -> void:
  var tween = player.create_tween()
  var duration = player.config.prone_time
  var change_height = player.config.prone_height if not reverse else player.config.default_height
  var change_head_rotation = deg_to_rad(100) if not reverse else  deg_to_rad(0)
  var change_body_rotation = deg_to_rad(-70) if not reverse else  deg_to_rad(0)
  tween.tween_property(player.head, "position:y", change_height, duration)
  tween.tween_property(player.collision, "shape:height", change_height, duration) # What if there is something over my head?

func _on_player_leaned(player: PlayerController, direction: int = 0) -> void:
  var tween = player.create_tween()
  var duration = player.config.lean_time
  var change = direction * player.current_lean_angle
  tween.tween_property(player, "rotation:z", change, duration)

func _on_player_focused(player: PlayerController, reverse: bool = false) -> void:
  var tween = player.create_tween()
  var duration = player.config.aim_time
  var change = player.config.aim_focused_fov if not reverse else player.config.aim_fov
  tween.tween_property(player.camera, "fov", change, duration)

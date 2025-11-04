class_name PlayerAnimations extends AnimationPlayer

static func _on_player_aimed(player: PlayerController, reverse: bool = false) -> void:
  var tween = player.create_tween()
  var duration = player.config.aim_time
  var difference = Vector2(-player.shoulder.position.x, 0.0)
  var change_middle = difference.x if not reverse else 0.0

  tween.set_parallel(true)
  tween.tween_property(player.hand,  "position:x", change_middle, duration)
  tween.tween_property(player.other_hand, "position:x", change_middle, duration)

static func _on_player_crouched(player: PlayerController, reverse: bool = false) -> void:
  var tween = player.create_tween()
  var duration = player.config.crouch_time
  var change_height = player.config.crouch_height if not reverse else player.config.stand_height
  tween.tween_property(player.head, "position:y", change_height, duration)

static func _on_player_proned(player: PlayerController, reverse: bool = false) -> void:
  var tween = player.create_tween()
  var duration = player.config.prone_time
  var change_height = player.config.prone_height if not reverse else player.config.stand_height
  var change_head_rotation = deg_to_rad(100) if not reverse else  deg_to_rad(0)
  var change_body_rotation = deg_to_rad(-70) if not reverse else  deg_to_rad(0)
  tween.tween_property(player.head, "position:y", change_height, duration)

static func _on_player_leaned(player: PlayerController, direction: int = 0) -> void:
  var tween = player.create_tween()
  var duration = player.config.lean_time
  var change = direction * player.current_lean_angle
  tween.tween_property(player, "rotation:z", change, duration)

static func _on_player_focused(player: PlayerController, reverse: bool = false) -> void:
  var tween = player.create_tween()
  var duration = player.config.aim_time
  var change = player.config.aim_focused_fov if not reverse else player.config.aim_fov
  tween.tween_property(player.camera, "fov", change, duration)

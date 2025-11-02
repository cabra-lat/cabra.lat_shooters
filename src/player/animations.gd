class_name PlayerAnimations extends AnimationPlayer

static func _on_player_aimed(player: PlayerController, reverse: bool = false) -> void:
  var tween = player.create_tween()
  var duration = player.config.aim_time
  var difference = Vector2(-player.shoulder.position.x, 0.0)
  var change_middle = difference.x if not reverse else 0.0

  tween.set_parallel(true)
  tween.tween_property(player.hand,  "position:x", change_middle, duration)
  tween.tween_property(player.thumb, "position:x", change_middle, duration)
  tween.tween_property(player.other_hand, "position:x", change_middle, duration)
  tween.tween_property(player.other_thumb, "position:x", change_middle, duration)

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


static func apply_recoil(player: PlayerController, weapon: Weapon) -> void:
  var tween = player.create_tween()
  tween.set_parallel(true)

    # Quick camera kick up
  var kick_up = deg_to_rad(weapon.recoil_vertical)
  tween.tween_property(player.head, "rotation:x", player.head.rotation.x + kick_up * 0.5, 0.05)
  tween.tween_property(player.hand, "rotation:x", player.hand.rotation.x + kick_up, 0.05)
  tween.tween_property(player.hand, "rotation:x", 0.0, 0.15).set_delay(0.05)

    # Slight random horizontal movement
  var kick_horizontal = deg_to_rad(randf_range(-weapon.recoil_horizontal, weapon.recoil_horizontal))
  tween.tween_property(player.head, "rotation:y", player.head.rotation.y + kick_horizontal * 0.5, 0.05)
  tween.tween_property(player.hand, "rotation:y", player.hand.rotation.y + kick_horizontal, 0.05)
  tween.tween_property(player.hand, "rotation:y", 0.0, 0.15).set_delay(0.05)

    # Weapon visual kick
  tween.tween_property(player.weapon_node, "position:z", 0.1, 0.05)
  tween.tween_property(player.weapon_node, "position:z", 0.0, 0.15).set_delay(0.05)

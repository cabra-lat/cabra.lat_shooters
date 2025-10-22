class_name PlayerAnimations extends AnimationPlayer

func _on_player_aimed(player: PlayerController, reverse: bool = false) -> void:
  var tween = player.create_tween()
  var duration = player.config.aim_time
  var change_middle = 0.0 if not reverse else 0.117
  tween.tween_property(player.shoulder, "position:x", change_middle, duration)

  var change_height = -0.117 + 0.117 / 4 if not reverse else -0.117
  tween.tween_property(player.hand, "position:y", change_height, duration)

  print("_on_player_aiming: ", reverse, change_middle, duration, tween)

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

func _on_player_weapon_action(player: PlayerController, weapon: Weapon, state: String) -> void:
  match state:
    PlayerController.TRIGGER_PULLED:
      player.weapon_node.pull_trigger(func(): apply_recoil(player, weapon))
    PlayerController.TRIGGER_RELEASED:
      player.weapon_node.release_trigger()


func apply_recoil(player: PlayerController, weapon: Weapon) -> void:
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

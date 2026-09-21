class_name PlayerAnimations extends AnimationPlayer

static func _on_player_aimed(player: PlayerController, reverse: bool = false) -> void:
  var tween = player.create_tween()
  # Ergonomics/attachments change the ADS duration: ask the weapon.
  var duration = player.get_ads_time()
  var difference = Vector2(player.shoulder.position.x, 0.0)
  var change_middle = 0.0 if not reverse else difference.x

  tween.set_parallel(true)
  tween.tween_property(player.shoulder, "position:x", change_middle, duration)

static func _skel_base_y(player: PlayerController) -> float:
  if not player.has_meta("_skel_base_y"):
    player.set_meta("_skel_base_y", player.skeleton.position.y)
  return float(player.get_meta("_skel_base_y"))

static func _on_player_crouched(player: PlayerController, reverse: bool = false) -> void:
  var tween = player.create_tween()
  var duration = player.config.crouch_time
  var base_y := _skel_base_y(player)
  var target_y := (base_y - 0.45) if not reverse else base_y
  tween.tween_property(player.skeleton, "position:y", target_y, duration)

static func _on_player_proned(player: PlayerController, reverse: bool = false) -> void:
  var tween = player.create_tween()
  var duration = player.config.prone_time
  var base_y := _skel_base_y(player)
  var target_y := (base_y - 0.75) if not reverse else base_y
  tween.tween_property(player.skeleton, "position:y", target_y, duration)

# Lean pose is owned by the controller (_apply_camera_bob_and_lean): it
# rolls the SpringArm and shifts the head laterally, smoothly and frame-rate
# independently. This handler used to tween head.position:x by
# -direction*cos(lean_angle) (≈0.87 m slide) while never rolling the camera,
# which fought the controller. Kept as a no-op so the scene connection holds.
static func _on_player_leaned(player: PlayerController, direction: int = 0) -> void:
  pass

static func _on_player_focused(player: PlayerController, reverse: bool = false) -> void:
  var tween = player.create_tween()
  var duration = player.get_ads_time()
  var change = player.config.aim_focused_fov if not reverse else player.config.aim_fov
  tween.tween_property(player.camera, "fov", change, duration)

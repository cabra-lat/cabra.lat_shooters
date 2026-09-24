# res://addons/cabra.lat_shooters/test/validate_locomotion_orientation.gd
#
# Procedural locomotion/facing regression harness. This intentionally does not
# inspect screenshots or material pixels: it drives the real player and NPC
# bodies through the spotter's straight/turn/stop/reverse stages and checks
# numeric displacement, facing, and nested-transform health.
extends SceneTree

const PLAYER_SCENE := "res://addons/cabra.lat_shooters/src/player/scenes/player.tscn"
const BOT_SCENE := "res://src/npcs/bot/bot.tscn"
const MOVE_FRAMES := 50
const STOP_MID_FRAME := 65
const STOP_TAIL_FRAMES := 30
const MOVE_MIN_DISTANCE := 0.35
const MOVE_MIN_DOT := 0.90
const FACING_MIN_DOT := 0.85
const STOP_MAX_DISTANCE := 0.12
const STOP_MAX_SPEED := 0.12
const SCALE_MIN := 0.90
const SCALE_MAX := 1.10
const SCALE_UNIFORM_TOLERANCE := 0.025
const ORTHOGONAL_TOLERANCE := 0.025
const PLAYER_RIG_Y := 0.8513874
const NPC_RIG_Y := 0.893
const REST_X := Vector3(0.0, 0.0, -1.0)
const REST_Y := Vector3(-1.0, 0.0, 0.0)
const REST_Z := Vector3(0.0, 1.0, 0.0)

var _world: Node3D
var _player: CharacterBody3D
var _bot: CharacterBody3D
var _checks := 0
var _passed := 0
var _failed := 0
var _sabotage := false
var _sabotage_transform := false

func _initialize() -> void:
	var args := OS.get_cmdline_args()
	var mode := OS.get_environment("LOCOMOTION_SABOTAGE")
	_sabotage = args.has("--sabotage") or mode == "1" or mode == "expected"
	_sabotage_transform = args.has("--sabotage-transform") or mode == "transform"
	_run()

func _run() -> void:
	_build_world()
	if not _spawn_actors():
		_finish()
		return

	# SceneTree._initialize() is not fully inside-tree yet; let one frame settle
	# before reading global transforms or initializing the NPC target state.
	await process_frame
	_bot.call("setup", [_bot.global_position + Vector3(0.0, 0.0, -8.0)])
	_neutralize_npc_perception()
	await _wait_frames(60)
	if _sabotage_transform:
		var bot_rig := _bot.get_node_or_null("Skeleton3D") as Node3D
		if bot_rig != null:
			bot_rig.rotation.y += PI * 0.5
	_check_nested_transforms("initial")
	await _run_straight()
	await _run_turn()
	await _run_stop()
	await _run_reverse()
	await _run_final_stop()
	_check("LOC-08", "grounded_after_locomotion",
		_player.is_on_floor() and _bot.is_on_floor(),
		"player_floor=%s npc_floor=%s" % [str(_player.is_on_floor()), str(_bot.is_on_floor())])
	_finish()

func _build_world() -> void:
	_world = Node3D.new()
	_world.name = "LocomotionOrientationWorld"
	root.add_child(_world)
	current_scene = _world

	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 1
	ground.collision_mask = 0
	var ground_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30.0, 0.4, 30.0)
	ground_shape.shape = box
	ground_shape.position.y = -0.2
	ground.add_child(ground_shape)
	_world.add_child(ground)

func _spawn_actors() -> bool:
	var player_scene := load(PLAYER_SCENE) as PackedScene
	var bot_scene := load(BOT_SCENE) as PackedScene
	if player_scene == null or bot_scene == null:
		_check("LOC-00", "locomotion_scenes_load", false,
			"player=%s npc=%s" % [str(player_scene != null), str(bot_scene != null)])
		return false

	_player = player_scene.instantiate() as CharacterBody3D
	_bot = bot_scene.instantiate() as CharacterBody3D
	if _player == null or _bot == null:
		_check("LOC-00", "locomotion_actors_instantiate", false,
			"player=%s npc=%s" % [str(_player != null), str(_bot != null)])
		return false

	_player.name = "PlayerActor"
	_player.collision_layer = 2
	_player.collision_mask = 1
	_player.position = Vector3(-3.0, 0.08, 0.0)
	_world.add_child(_player)
	var player_camera := _player.get_node_or_null("SpringArm3D/Camera3D") as Camera3D
	if player_camera != null:
		player_camera.current = false

	_bot.name = "NpcActor"
	_bot.set("weapon_enabled", false)
	_bot.set("loot_enabled", false)
	_bot.set("sight_range", 0.0)
	_bot.set("use_cover", false)
	_bot.collision_layer = 4
	_bot.collision_mask = 1
	_bot.position = Vector3(3.0, 0.08, 0.0)
	_world.add_child(_bot)
	return true

func _neutralize_npc_perception() -> void:
	# Keep this harness about locomotion, not target acquisition. A valid but
	# unreachable target prevents retargeting while sight_range=0 suppresses
	# the sight transition; the patrol branch remains the only movement source.
	_bot.set("_target", _player)
	_bot.set("_retarget_t", 9999.0)
	_bot.set("alert_state", 0)
	_bot.set("_notice_t", 0.0)
	_bot.set("_squad_has", false)
	_bot.set("_last_noise_pos", Vector3.ZERO)
	_bot.set("current_cover", Vector3.ZERO)

func _run_straight() -> void:
	var expected_player := _player_forward()
	var expected_bot := Vector3(0.0, 0.0, -1.0)
	var player_start := _player.global_position
	var bot_start := _bot.global_position
	Input.action_press("forward")
	_bot.call("setup", [_bot.global_position + expected_bot * 8.0])
	_neutralize_npc_perception()
	await _wait_frames(MOVE_FRAMES)
	_check_motion("straight", player_start, bot_start, expected_player, expected_bot)
	Input.action_release("forward")
	_check_nested_transforms("straight")

func _run_turn() -> void:
	_player.rotation.y = PI * 0.5
	await _wait_frames(2)
	var expected_player := _player_forward()
	var expected_bot := Vector3(1.0, 0.0, 0.0)
	var player_start := _player.global_position
	var bot_start := _bot.global_position
	Input.action_press("forward")
	_bot.call("setup", [_bot.global_position + expected_bot * 8.0])
	_neutralize_npc_perception()
	await _wait_frames(MOVE_FRAMES)
	_check_motion("turn", player_start, bot_start, expected_player, expected_bot)
	_check("LOC-07", "player_turn_yaw", absf(absf(rad_to_deg(_player.rotation.y)) - 90.0) < 0.5,
		"yaw=%.3f" % rad_to_deg(_player.rotation.y))
	Input.action_release("forward")
	_check_nested_transforms("turn")

func _run_stop() -> void:
	Input.action_release("forward")
	_bot.set("waypoints", [])
	_bot.set("_wp_index", 0)
	_neutralize_npc_perception()
	await _wait_frames(STOP_MID_FRAME)
	var player_mid := _player.global_position
	var bot_mid := _bot.global_position
	await _wait_frames(STOP_TAIL_FRAMES)
	_check_stop("stop", player_mid, bot_mid)
	_check_nested_transforms("stop")

func _run_reverse() -> void:
	Input.action_release("forward")
	Input.action_press("back")
	var expected_player := -_player_forward()
	var expected_bot := -_bot_forward()
	var player_start := _player.global_position
	var bot_start := _bot.global_position
	_bot.call("setup", [_bot.global_position + expected_bot * 8.0])
	_neutralize_npc_perception()
	await _wait_frames(MOVE_FRAMES)
	_check_motion("reverse", player_start, bot_start, expected_player, expected_bot)
	Input.action_release("back")
	_check_nested_transforms("reverse")

func _run_final_stop() -> void:
	Input.action_release("back")
	_bot.set("waypoints", [])
	_bot.set("_wp_index", 0)
	_neutralize_npc_perception()
	await _wait_frames(STOP_MID_FRAME)
	var player_mid := _player.global_position
	var bot_mid := _bot.global_position
	await _wait_frames(STOP_TAIL_FRAMES)
	_check_stop("final_stop", player_mid, bot_mid)
	_check_nested_transforms("final_stop")

func _check_motion(label: String, player_start: Vector3, bot_start: Vector3,
		expected_player: Vector3, expected_bot: Vector3) -> void:
	var player_delta := _horizontal(_player.global_position - player_start)
	var bot_delta := _horizontal(_bot.global_position - bot_start)
	var expected_player_dir := _expected(expected_player)
	var expected_bot_dir := _expected(expected_bot)
	var player_dot := _direction_dot(player_delta, expected_player_dir)
	var bot_dot := _direction_dot(bot_delta, expected_bot_dir)
	var player_facing := _direction_dot(_player_forward(), expected_player_dir)
	var bot_facing := _direction_dot(_bot_forward(), expected_bot_dir)
	var player_speed := _horizontal(_player.velocity).length()
	var bot_speed := _horizontal(_bot.velocity).length()
	var player_ok := player_delta.length() > MOVE_MIN_DISTANCE \
		and player_dot > MOVE_MIN_DOT
	if label != "reverse":
		player_ok = player_ok and player_facing > FACING_MIN_DOT
	var bot_ok := bot_delta.length() > MOVE_MIN_DISTANCE \
		and bot_dot > MOVE_MIN_DOT and bot_facing > FACING_MIN_DOT
	_check("LOC-02", "player_%s_motion" % label, player_ok,
		"distance=%.3f dot=%.3f facing=%.3f speed=%.3f" % [
			player_delta.length(), player_dot, player_facing, player_speed])
	_check("LOC-03", "npc_%s_motion" % label, bot_ok,
		"distance=%.3f dot=%.3f facing=%.3f speed=%.3f" % [
			bot_delta.length(), bot_dot, bot_facing, bot_speed])

func _check_stop(label: String, player_mid: Vector3, bot_mid: Vector3) -> void:
	var player_tail := _horizontal(_player.global_position - player_mid)
	var bot_tail := _horizontal(_bot.global_position - bot_mid)
	var player_speed := _horizontal(_player.velocity).length()
	var bot_speed := _horizontal(_bot.velocity).length()
	var moving = _player.get("moving")
	var moving_state := "<none>"
	if moving != null:
		moving_state = str(moving.get("state"))
	_check("LOC-04", "player_%s_stop" % label,
		player_tail.length() < STOP_MAX_DISTANCE and player_speed < STOP_MAX_SPEED,
		"tail=%.3f speed=%.3f" % [player_tail.length(), player_speed])
	_check("LOC-05", "npc_%s_stop" % label,
		bot_tail.length() < STOP_MAX_DISTANCE and bot_speed < STOP_MAX_SPEED,
		"tail=%.3f speed=%.3f" % [bot_tail.length(), bot_speed])
	_check("LOC-09", "player_%s_stopped_state" % label,
		moving_state == "Stopped" and player_tail.length() < STOP_MAX_DISTANCE \
			and player_speed < STOP_MAX_SPEED,
		"moving_state=%s tail=%.3f speed=%.3f" % [
			moving_state, player_tail.length(), player_speed])

func _check_nested_transforms(stage: String) -> void:
	var nodes: Array[Dictionary] = [
		{"id": "player_root", "node": _player},
		{"id": "player_skeleton", "node": _player.get_node_or_null("Skeleton3D")},
		{"id": "npc_root", "node": _bot},
		{"id": "npc_skeleton", "node": _bot.get_node_or_null("Skeleton3D")},
	]
	for entry in nodes:
		var node := entry.get("node") as Node3D
		var id := "%s_%s" % [stage, str(entry.get("id"))]
		if node == null:
			_check("LOC-06", id, false, "node missing")
			continue
		var basis := node.global_transform.basis
		var scale := basis.get_scale()
		var mean_scale := (scale.x + scale.y + scale.z) / 3.0
		var scale_spread := maxf(absf(scale.x - scale.y), absf(scale.y - scale.z))
		var x := basis.x.normalized()
		var y := basis.y.normalized()
		var z := basis.z.normalized()
		var orthogonal := absf(x.dot(y)) < ORTHOGONAL_TOLERANCE \
			and absf(y.dot(z)) < ORTHOGONAL_TOLERANCE \
			and absf(z.dot(x)) < ORTHOGONAL_TOLERANCE \
			and basis.determinant() > 0.5
		var scale_ok := mean_scale >= SCALE_MIN and mean_scale <= SCALE_MAX \
			and scale_spread <= SCALE_UNIFORM_TOLERANCE
		_check("LOC-06", id, scale_ok and orthogonal,
			"scale=%s spread=%.4f det=%.4f axes=(%.3f, %.3f, %.3f)" % [
				str(scale), scale_spread, basis.determinant(), x.dot(y), y.dot(z), z.dot(x)])

	var rigs: Array[Dictionary] = [
		{"id": "player_rig_contract", "root": _player, "rig": _player.get_node_or_null("Skeleton3D"), "origin_y": PLAYER_RIG_Y},
		{"id": "npc_rig_contract", "root": _bot, "rig": _bot.get_node_or_null("Skeleton3D"), "origin_y": NPC_RIG_Y},
	]
	for entry in rigs:
		var root := entry.get("root") as Node3D
		var rig := entry.get("rig") as Node3D
		var id := "%s_%s" % [stage, str(entry.get("id"))]
		if root == null or rig == null:
			_check("LOC-06", id, false, "root/rig node missing")
			continue
		var visual_forward := _horizontal(rig.global_transform.basis * Vector3.RIGHT).normalized()
		var root_forward := _horizontal(-root.global_transform.basis.z).normalized()
		var forward_dot := _direction_dot(visual_forward, root_forward)
		var local_basis := rig.transform.basis
		var rest_ok := _vector_close(local_basis.x.normalized(), REST_X) \
			and _vector_close(local_basis.y.normalized(), REST_Y) \
			and _vector_close(local_basis.z.normalized(), REST_Z)
		var origin_ok := absf(rig.position.y - float(entry.get("origin_y"))) < 0.01
		_check("LOC-06", id, forward_dot > 0.999 and rest_ok and origin_ok,
			"forward_dot=%.4f rest=%s origin_y=%.4f expected_y=%.4f" % [
				forward_dot, str(rest_ok), rig.position.y, float(entry.get("origin_y"))])

func _vector_close(value: Vector3, expected: Vector3, tolerance := 0.002) -> bool:
	return value.distance_to(expected) <= tolerance

func _check(id: String, label: String, ok: bool, detail: String) -> void:
	_checks += 1
	if ok:
		_passed += 1
		print("PASS | %s | %s | %s" % [id, label, detail])
	else:
		_failed += 1
		push_error("FAIL | %s | %s | %s" % [id, label, detail])

func _wait_frames(count: int) -> void:
	for _i in count:
		await physics_frame

func _horizontal(value: Vector3) -> Vector3:
	value.y = 0.0
	return value

func _player_forward() -> Vector3:
	var camera := _player.get_node_or_null("SpringArm3D/Camera3D") as Camera3D
	if camera == null:
		return Vector3.FORWARD
	return _horizontal(-camera.global_transform.basis.z).normalized()

func _bot_forward() -> Vector3:
	return _horizontal(-_bot.global_transform.basis.z).normalized()

func _direction_dot(value: Vector3, expected: Vector3) -> float:
	if value.length_squared() < 0.000001 or expected.length_squared() < 0.000001:
		return -1.0
	return value.normalized().dot(expected.normalized())

func _expected(value: Vector3) -> Vector3:
	var result := _horizontal(value).normalized()
	return -result if _sabotage else result

func _finish() -> void:
	Input.action_release("forward")
	Input.action_release("back")
	if _world != null and is_instance_valid(_world):
		_world.process_mode = Node.PROCESS_MODE_DISABLED
		_world.queue_free()
	print("SUMMARY locomotion checks=%d passed=%d failed=%d sabotage_expected=%s sabotage_transform=%s" % [
		_checks, _passed, _failed, str(_sabotage), str(_sabotage_transform)])
	print("checks passed %d" % _passed)
	print("RESULT: %s" % ("PASS" if _failed == 0 else "FAIL"))
	call_deferred("_quit_deferred")

func _quit_deferred() -> void:
	await process_frame
	quit(0 if _failed == 0 else 1)

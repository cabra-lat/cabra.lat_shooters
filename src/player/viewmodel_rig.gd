class_name ViewmodelRig
extends RefCounted
## Procedural first-person weapon hold.
##
## The gun is a FROZEN rigid body posed every physics frame from the camera
## plus critically-damped offsets (sway, head-bob, recoil kick, reload dip).
## Rule learned the hard way: never integrate Hooke springs on bodies for held
## items — offsets use exponential damping (unconditionally stable), and the
## hands follow the gun through the arm IK effectors, not the other way round.

const HIP_OFFSET := Vector3(0.22, -0.20, -0.45) # right/down/forward of camera
const GRIP_R := Vector3(0.0, -0.09, 0.02) # right hand at trigger guard
const GRIP_L := Vector3(0.0, -0.08, -0.28) # left hand on foreguard
# Per-weapon ADS eye-alignment (camera space). Sight heights differ per
# weapon AND per sight attachment — this table carries measured values;
# unlisted weapons fall back to DEFAULT_ADS_OFFSET (estimate, spotter queue
# for per-weapon screenshots). Key: Weapon resource basename
# (e.g. "M4_Carbine"), else Weapon.name (covers duplicated resources).
const DEFAULT_ADS_OFFSET := Vector3(0.0, -0.135, -0.32)
const ADS_DEPTH := -0.32 # gun-to-eye distance at full ADS (camera space)
const ADS_OFFSETS := {
	"M4_Carbine": Vector3(0.0, -0.064, -0.32), # spotter live-unproject 2026-09-21 (was -0.066)
}
const ADS_K := 10.0 # hip<->ads blend rate (exponential, like the rest)
const ADS_SWAY_SCALE := 0.25 # sway multiplier at full ADS
const ADS_BOB_SCALE := 0.15 # head-bob multiplier at full ADS
const SWAY_K := 10.0
const KICK_K := 12.0
const DIP_K := 5.0
const BOB_FREQ := 9.0

var _player: PlayerController
var _gun: Weapon3D
var _cam: Camera3D
var _eff_r: Node3D
var _eff_l: Node3D
var _grip_r: Marker3D
var _grip_l: Marker3D
var _sway := Vector2.ZERO
var _kick := 0.0
var _kick_pitch := 0.0
var _dip := 0.0
var _bob_phase := 0.0
var _bob := Vector3.ZERO
var _ads := 0.0 # 0 = hip pose, 1 = ADS eye-alignment pose
var _ads_rate := ADS_K # blend rate; ergonomics/attachments scale it
var _ads_offset := DEFAULT_ADS_OFFSET # resolved per weapon in setup()
var _grabbed_layers := {} # RigidBody3D -> [layer, mask] to restore on teardown
var _mounted_attachments := {} # point -> Node3D mounted on the held gun
var _baked_optics_hidden := {} # marker -> [Node3D] hidden while a mounted optic is present

func setup(player: PlayerController, gun: Weapon3D) -> void:
	_player = player
	_gun = gun
	_cam = player.camera
	_ads_offset = resolve_ads_offset(gun)
	# ADS timing is data-driven: Weapon.get_ads_time() folds in ergonomics,
	# durability and attachment modifiers. Rate is derived from the same
	# duration so a heavier/slower gun also settles slower (ADS_K keeps the
	# neutral case identical to before).
	var w0: Weapon = gun.data as Weapon
	if w0 != null and player.config != null:
		var mult := clampf(w0.get_ads_time_multiplier(), 0.25, 4.0)
		_ads_rate = ADS_K / mult
	var skel: Node3D = player.skeleton
	if skel:
		_eff_r = skel.get_node_or_null("GodotIK/IK_rightarm") as Node3D
		_eff_l = skel.get_node_or_null("GodotIK/IK_leftarm") as Node3D
	_grip_r = _make_grip("RightGrip", GRIP_R)
	_grip_l = _make_grip("LeftGrip", GRIP_L)
	var w: Weapon = gun.data as Weapon
	if w and not w.cartridge_fired.is_connected(_on_fired):
		w.cartridge_fired.connect(_on_fired)
	if w:
		if not w.attachment_added.is_connected(_on_attachment_added):
			w.attachment_added.connect(_on_attachment_added)
		if not w.attachment_removed.is_connected(_on_attachment_removed):
			w.attachment_removed.connect(_on_attachment_removed)
		for point in w.attachments.keys():
			_mount_attachment(point, w.attachments[point])
	if not player.reloaded.is_connected(_on_reload_started):
		player.reloaded.connect(_on_reload_started)
	# The gun ROOT is a RigidBody3D itself (weapon scene root), so zero it
	# explicitly — _freeze_gun_descendants only walks children.
	if gun is RigidBody3D:
		_stash_and_zero(gun as RigidBody3D)
		_freeze_body(gun as RigidBody3D)
	_freeze_gun_descendants(gun)

## Remember the body's collision layers, then take it off the shoot ray.
func _stash_and_zero(rb: RigidBody3D) -> void:
	_grabbed_layers[rb] = [rb.collision_layer, rb.collision_mask]
	rb.collision_layer = 0
	rb.collision_mask = 0

func _freeze_body(rb: RigidBody3D) -> void:
	rb.freeze = true
	rb.contact_monitor = false
	if rb.get("is_grabbed") != null:
		rb.set("is_grabbed", false)

func _freeze_gun_descendants(node: Node) -> void:
	for c in node.get_children():
		if c is RigidBody3D:
			var rb := c as RigidBody3D
			_stash_and_zero(rb)
			_freeze_body(rb)
		if c.get("is_grabbed") != null:
			c.set("is_grabbed", false)
		_freeze_gun_descendants(c)

## restore_collision=false when the caller is about to free the gun (equip
## switch / unequip): a body pending deletion must not be put back on the
## shoot layers or it can eat a ray for the rest of the frame.
func teardown(restore_collision: bool = true) -> void:
	if is_instance_valid(_gun):
		var w: Weapon = _gun.data as Weapon
		if w and w.cartridge_fired.is_connected(_on_fired):
			w.cartridge_fired.disconnect(_on_fired)
		if w:
			if w.attachment_added.is_connected(_on_attachment_added):
				w.attachment_added.disconnect(_on_attachment_added)
			if w.attachment_removed.is_connected(_on_attachment_removed):
				w.attachment_removed.disconnect(_on_attachment_removed)
	_unmount_all_attachments()
	if is_instance_valid(_player) and _player.reloaded.is_connected(_on_reload_started):
		_player.reloaded.disconnect(_on_reload_started)
	if restore_collision:
		for c in _grabbed_layers:
			if is_instance_valid(c):
				(c as RigidBody3D).collision_layer = _grabbed_layers[c][0]
				(c as RigidBody3D).collision_mask = _grabbed_layers[c][1]
	_grabbed_layers.clear()
	_player = null
	_gun = null

## 0 = hip pose, 1 = full ADS eye-alignment. For HUD/spotter readouts.
func ads_blend() -> float:
	return _ads

## Per-weapon sight alignment. Precedence: measured table entry (human
## filmstrip wins) -> visible optic "Reticle" marker -> any visible
## "Reticle" marker (iron sights) -> default estimate. Static so the table
## half stays testable wherever Weapon resources load.
static func resolve_ads_offset(gun: Weapon3D) -> Vector3:
	if gun != null:
		var w := gun.data as Weapon
		if w != null:
			var key := w.name
			if w.resource_path != "":
				key = w.resource_path.get_file().get_basename()
			if key != "" and ADS_OFFSETS.has(key):
				return ADS_OFFSETS[key]
		var marker := find_reticle(gun)
		if marker != null:
			var s := gun_relative_pos(gun, marker)
			return Vector3(-s.x, -s.y, ADS_DEPTH - s.z)
	return DEFAULT_ADS_OFFSET


## First usable Marker3D named "Reticle*" under the gun. Optic-mounted dots
## win over irons; hidden optics (unmounted) are skipped via visibility.
static func find_reticle(gun: Node) -> Marker3D:
	var fallback: Marker3D = null
	var stack: Array = [gun]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n != gun and n is Marker3D and (n as Marker3D).name.begins_with("Reticle"):
			var m := n as Marker3D
			if m.is_visible_in_tree():
				if _is_optic_marker(gun, m):
					return m
				if fallback == null:
					fallback = m
		stack.append_array(n.get_children())
	return fallback


static func _is_optic_marker(gun: Node, m: Marker3D) -> bool:
	var n: Node = m.get_parent()
	while n != null and n != gun:
		var lname := n.name.to_lower()
		for key in ["scope", "sight", "optic", "reddot", "reflex", "holo"]:
			if key in lname:
				return true
		n = n.get_parent()
	return false


## Position of target in gun-local space (static chain walk, no globals).
static func gun_relative_pos(gun: Node3D, target: Node3D) -> Vector3:
	if gun == null or target == null or not gun.is_ancestor_of(target):
		return Vector3.ZERO
	var t := Transform3D.IDENTITY
	var n: Node = target
	while n != null and n != gun:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t.origin

func update_rig(delta: float) -> void:
	if not is_instance_valid(_gun) or not is_instance_valid(_cam) or not is_instance_valid(_player):
		return
	var cb: Basis = _cam.global_transform.basis
	var cp: Vector3 = _cam.global_position
	# Sway lags behind look velocity, decays to zero on its own.
	var look: Vector2 = _player.last_look_delta
	var sway_target := Vector2(
		clampf(-look.x * 0.0016, -0.06, 0.06),
		clampf(-look.y * 0.0016, -0.06, 0.06))
	_sway = _damp2(_sway, sway_target, SWAY_K, delta)
	# Head-bob only while grounded and moving; eases back to center when idle.
	var planar := Vector3(_player.velocity.x, 0.0, _player.velocity.z).length()
	var bob_target := Vector3.ZERO
	if _player.is_on_floor() and planar > 0.5:
		_bob_phase += delta * (BOB_FREQ + planar * 0.6)
		var bob_amp := clampf(planar / 4.0, 0.0, 1.0) * 0.012
		bob_target = Vector3(cos(_bob_phase * 0.5) * bob_amp, sin(_bob_phase) * bob_amp, 0.0)
	_bob = _bob.lerp(bob_target, 1.0 - exp(-8.0 * delta))
	# Recoil kick and reload dip recover exponentially.
	_kick = _damp(_kick, 0.0, KICK_K, delta)
	_kick_pitch = _damp(_kick_pitch, 0.0, KICK_K, delta)
	_dip = _damp(_dip, 0.0, DIP_K, delta)
	# ADS blend: hip pose -> eye-alignment pose while the aiming state
	# machine sits in AIMING or FOCUSING. FOV is handled by the controller;
	# the rig only moves the gun. Recoil kick / reload dip stay unscaled.
	var ads_target := 0.0
	var sm = _player.aiming
	if sm != null and (sm.state == PlayerController.AIMING \
			or sm.state == PlayerController.FOCUSING):
		ads_target = 1.0
	_ads = _damp(_ads, ads_target, _ads_rate, delta)
	var sway_scale := 1.0 - _ads * (1.0 - ADS_SWAY_SCALE)
	var bob_scale := 1.0 - _ads * (1.0 - ADS_BOB_SCALE)
	# Compose final gun pose in camera space.
	var euler := Vector3(
		(_sway.y + _kick_pitch + _dip * 0.45) * sway_scale,
		_sway.x * sway_scale,
		_sway.x * 0.4 * sway_scale)
	var gb: Basis = cb * Basis.from_euler(euler)
	var off: Vector3 = HIP_OFFSET.lerp(_ads_offset, _ads) \
		+ _bob * bob_scale + Vector3(0.0, _kick * 0.5 - _dip * 0.22, _kick)
	_gun.global_transform = Transform3D(gb, cp + cb * off)
	# Hands track the gun grips through the arm IK effectors.
	if is_instance_valid(_eff_r) and is_instance_valid(_grip_r):
		_eff_r.global_transform = _grip_r.global_transform
	if is_instance_valid(_eff_l) and is_instance_valid(_grip_l):
		_eff_l.global_transform = _grip_l.global_transform

func _on_fired(_weapon: Weapon, _cartridge: Ammo) -> void:
	_kick = min(_kick + 0.035, 0.09)
	_kick_pitch = min(_kick_pitch + 0.05, 0.14)

func _on_attachment_added(_weapon: Weapon, attachment: Attachment, point: int) -> void:
	_mount_attachment(point, attachment)

func _on_attachment_removed(_weapon: Weapon, attachment: Attachment, point: int) -> void:
	_unmount_attachment(point)

func _attachment_marker(point: int) -> Node3D:
	if not is_instance_valid(_gun):
		return null
	for marker_name in Weapon3D.marker_names_for_point(point):
		var n := _gun.get_node_or_null(marker_name)
		if n is Node3D:
			return n
	return _gun

func _mount_attachment(point: int, attachment: Attachment) -> void:
	_unmount_attachment(point)
	if attachment == null or attachment.model_scene == null or not is_instance_valid(_gun):
		return
	var marker := _attachment_marker(point)
	if marker == null:
		return
	var inst := attachment.model_scene.instantiate()
	if inst == null:
		return
	marker.add_child(inst)
	if inst is Node3D:
		(inst as Node3D).transform = attachment.model_transform
	if inst is RigidBody3D:
		_stash_and_zero(inst as RigidBody3D)
		_freeze_body(inst as RigidBody3D)
	_mounted_attachments[point] = inst
	if point == Weapon.AttachmentPoint.TOP_RAIL:
		Weapon3D.hide_baked_marker_siblings(marker, inst, _baked_optics_hidden)
	_refresh_ads_after_change()

func _unmount_attachment(point: int) -> void:
	if _mounted_attachments.has(point):
		var old = _mounted_attachments[point]
		if is_instance_valid(old):
			old.queue_free()
		_mounted_attachments.erase(point)
	if point == Weapon.AttachmentPoint.TOP_RAIL:
		Weapon3D.restore_baked_marker_siblings(_baked_optics_hidden)
	_refresh_ads_after_change()

## Shared tail of mount/unmount: re-resolve eye alignment (an optic reticle may
## have appeared or gone).
func _refresh_ads_after_change() -> void:
	if is_instance_valid(_gun):
		_ads_offset = resolve_ads_offset(_gun)

func _unmount_all_attachments() -> void:
	for point in _mounted_attachments.keys():
		_unmount_attachment(point)

func _on_reload_started(_player_ref: PlayerController) -> void:
	_dip = 1.0

func _make_grip(gname: String, pos: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.name = gname
	_gun.add_child(m)
	m.position = pos
	return m

func _damp(cur: float, target: float, k: float, dt: float) -> float:
	return lerpf(cur, target, 1.0 - exp(-k * dt))

func _damp2(cur: Vector2, target: Vector2, k: float, dt: float) -> Vector2:
	return cur.lerp(target, 1.0 - exp(-k * dt))

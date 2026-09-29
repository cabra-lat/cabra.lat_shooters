extends Node3D
# RIG PROXY: a ball-and-capsule articulation debug rig with EXPLICIT hand and foot markers.
# PURPOSE: make the NPC roll visible WITHOUT resolving which rest is canonical, so it does
# not inherit the blocked decision on bbbb18.
#
# WHY BALL-AND-CAPSULE AND NOT THE REAL MESH. The real skin is a 249809-byte player_mesh.tres
# whose surface makes a 90-degree roll hard to read, because a rolled body still reads as a
# body. A stick figure has no surface to hide the error: if the up axis is not up, it is
# obvious at a glance, and that is the whole point of the instrument.
#
# WHY EXPLICIT HAND AND FOOT MARKERS. spotter's legs result established the gait is
# structurally correct and anti-phase. A hand and a foot are the two ends that must both
# reach the floor; if the body is rolled, they are the joints that reveal it, because a
# rolled foot cannot be planted. They are named and sized differently from the chain bones so
# a foot that is failing to reach is not mistaken for a limb that is merely short.
#
# FRAME DISCIPLINE, THE RULE THAT BROKE TWICE TONIGHT. Every bone's pose is read as
# skeleton-local and composed ONCE with the skeleton transform: world = skel.global_transform *
# skel.get_bone_global_pose(i). A parent-local rest is NEVER compared against a
# skeleton-local pose, which produced a false 49.1-degree rest and a retracted 27-degree roll.
#
# THIS CLASS DRAWS AND REPORTS. The drawing needs a viewport and a camera, which need GPU and
# a human eye, so the numbers are printed as well and the numbers are what the report quotes.

const RIG := "res://addons/cabra.lat_shooters/src/player/scenes/humanoid_rig.tscn"
const LIB := "res://addons/cabra.lat_shooters/src/player/humanoid_body_anims.res"
# THE CHAIN, AND IT IS A LIST OF BONES NOT OF INDICES. A capsule is drawn only when BOTH ends
# are in CHAIN, so omitting an INTERMEDIATE bone silently disconnects everything beyond it --
# thigh.L_057 -> foot.L_059 needs shin.L_058 present, or the foot floats 170 px from the knee.
# The six intermediates added here are what turn four disconnected islands into a body axis.
# Every name below was verified against humanoid_rig.tscn rather than quoted from a peer -- BUT
# VERIFYING IS NOT THE SAME AS LOOKING FOR THE RIGHT BONES, AND I GOT THAT WRONG ONCE ALREADY:
# MY OWN NAME SEARCH FILTERED ON shin|hand|shoulder|foot|palm|upper_arm|thigh|spine, WHICH
# NEVER MATCHED forearm, SO I NEVER SAW forearm.L_010 AT ALL. hand.L_011_s PARENT IS
# forearm.L_010, NOT upper_arm.L_09, SO THE ARM CHAIN WAS BROKEN AT THE ELBOW AND THE HAND
# SPHERES WERE ORPHANS. THE FIX FOR THE SHINS WAS TO ADD THE MISSING INTERMEDIATE; THE FIX FOR
# THE ARMS WAS THE SAME MISSING INTERMEDIATE, HIDDEN BY MY OWN FILTER RATHER THAN BY ANYONE_s
# TRANSCRIPTION. ENUMERATE THE RIG, DO NOT GREP A LIST YOU WROTE FROM MEMORY.
const CHAIN := ["spine_01", "spine.001_02", "spine.002_03", "thigh.L_057", "thigh.R_062",
	"shin.L_058", "shin.R_063", "foot.L_059", "foot.R_064",
	"shoulder.L_08", "upper_arm.L_09", "forearm.L_010", "hand.L_011", "palm.01.L_012",
	"shoulder.R_031", "upper_arm.R_032", "forearm.R_033", "hand.R_034", "palm.01.R_035"]
const FEET := ["foot.L_059", "foot.R_064"]
const HANDS := ["palm.01.L_012", "palm.01.R_035"]

# ── TWO OPTIONS, BOTH OFF BY DEFAULT, BOTH ADDED IN RESPONSE TO SPOTTER ──
# OPTION 1, hide_rig_mesh. The rig instance carries its OWN MeshInstance3D, so a frame rendered
# through the production mount contains the real 3239-vertex body SURFACE alongside the proxy
# spheres. That is the most likely reason two vision reads of the same pipeline described
# different things: a clothed body with no markers, and markers with no body. Hiding the skin
# makes the stick figure unambiguous. The proxy builds its geometry as children of SELF, never
# of the skeleton, so hiding MeshInstance3D under the skeleton cannot hide the proxy.
var hide_rig_mesh: bool = false
# OPTION 2, seek_phase in 0..1, negative for off. With the manual advance removed the clip is
# driven by the frame clock, so a capture depends on WALL TIME and is not byte-reproducible
# between runs. That is a real cost of removing the coupling, and it should be re-added
# DELIBERATELY as an option rather than regained by accident. Seeking a fixed phase and pausing
# makes a capture reproducible without putting the coupling back.
var seek_phase: float = -1.0

# BUG 2 FIX: anim.current_animation returns EMPTY while paused, so the self-labelling
# readout lost its name in seek_phase mode. Latch the last non-empty name instead.
var _clip_name: String = ""

var skel: Skeleton3D
var anim: AnimationPlayer
var report: Label


func _ready() -> void:
	skel = $Skeleton3D as Skeleton3D
	# DEFECT FIX, FROM spotter's STRUCTURAL CHECK: $AnimationPlayer is a DIRECT-CHILD lookup
	# and bot.tscn nests the player at Skeleton3D/AnimationPlayer, so it resolved FALSE, _ready
	# returned early, and the proxy DREW NOTHING. Recursive lookup, and a real failure message
	# instead of a silent early return that looks like an empty scene.
	anim = _find_anim(self)
	if skel == null or anim == null:
		push_error("rig proxy needs Skeleton3D and AnimationPlayer children")
		return
	# DEFECT FIX FROM spotter S MEASUREMENT: play("walk") here did NOT stick. bot.gd_s
	# _want_anim() runs every frame and returns ANIM_IDLE while the bot is not moving, so the
	# locomotion logic overwrote the request immediately and the captures were of IDLE, 3.1000 s.
	# Forcing a clip on a live AI bot is a production change and is not this instrument_s job, so
	# the proxy does not force one. It REPORTS the clip actually playing, so a capture labels
	# itself and cannot be cited as walk evidence when it is idle.
	if anim.has_animation("walk"):
		anim.play("walk")  # best effort; _tick_anim may override, and the readout will say so
	_apply_mesh_visibility()
	_make_camera()
	_make_report_label()
	_report()

func _make_camera() -> void:
	var cam := Camera3D.new()
	# DEFECT FIX, ORDERING, FROM spotter S BACKTRACE AT LINE 83: look_at() was called BEFORE
	# add_child, on a node outside the tree. Same class as the capsule bug one function earlier.
	# RULE FOR THIS FILE: add_child FIRST, then touch anything global.
	cam.position = Vector3(0.0, 1.1, 3.2)
	add_child(cam)
	cam.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, -35.0, 0.0)
	add_child(light)

func _make_report_label() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	report = Label.new()
	report.position = Vector2(12.0, 12.0)
	# Fixed width so the columns do not jitter as digits change, which makes a live
	# number hard to read against a moving image.
	report.custom_minimum_size = Vector2(620.0, 0.0)
	layer.add_child(report)

func _process(_delta: float) -> void:
	if not String(anim.current_animation).is_empty():
		_clip_name = String(anim.current_animation)
	if seek_phase >= 0.0 and anim.current_animation_length > 0.0:
		# OPTION 2: hold a chosen phase so two runs capture the same pose.
		anim.pause()
		anim.seek(seek_phase * anim.current_animation_length, true)
	# DEFECT FIX FROM spotter S COUPLING FINDING, AND THIS IS THE ONE THAT MATTERS MOST FOR THE
	# INSTRUMENT RATHER THAN FOR A NUMBER. This used to drive the clip by hand:
	#     _ph = fmod(_ph + delta / len, 1.0); anim.advance(_ph * len)
	# That was a workaround for advance() "not applying in a tight loop", which is a property of
	# calling it in a loop, not of calling it per frame. In _process the AnimationPlayer already
	# advances itself from the frame clock, so the manual advance was redundant AND it coupled
	# CLIP ADVANCE to GEOMETRY BUILD inside one callback. spotter found the cost: holding the bot
	# still with process_mode = DISABLED also stops _process, so the one thing you reach for to
	# hold a pose silently stops the clip advancing and the figure being drawn. Letting the
	# player drive itself means the instrument no longer depends on the thing it is instrumenting.
	_rebuild()
	_report()

## OPTION 1: hide the production skin so the proxy geometry is unambiguous. Applied to
## MeshInstance3D under the SKELETON only; the proxy parents its own geometry to self.
func _apply_mesh_visibility() -> void:
	if not hide_rig_mesh:
		return
	var n := 0
	for m in _meshes_under(skel):
		(m as VisualInstance3D).visible = false
		n += 1
	print("[RIGPROXY] OPTION hide_rig_mesh: hid ", n, " MeshInstance3D node(s) under Skeleton3D")

func _meshes_under(x: Node) -> Array:
	var out: Array = []
	if x is MeshInstance3D:
		out.append(x)
	for c in x.get_children():
		out.append_array(_meshes_under(c))
	return out

## Not _draw: queue_redraw() and NOTIFICATION_DRAW are CanvasItem API and do not exist
## on Node3D. The first parse check caught exactly that. This rebuilds real MeshInstance3D
## children instead, which is what it was always doing.
var _built_capsules := 0
var _built_spheres := 0

func _rebuild() -> void:
	_built_capsules = 0
	_built_spheres = 0
	# DEFECT FIX FROM spotter S OBSERVATION: this used to FREE every MeshInstance3D and THEN
	# rebuild, so anything that interrupted the callback -- a process_mode freeze, which also
	# stops _process -- left a near-empty figure. spotter saw exactly 2 children that way.
	# Build the new set FIRST, then prune the old one, so there is never a moment with none.
	var stale: Array[Node] = []
	for c in get_children():
		if c is MeshInstance3D:
			stale.append(c)
	_build_balls()
	for c in stale:
		c.free()

## One ball per joint, one capsule per bone. Balls are where the articulation is; capsules
## are what make a chain read as a chain instead of a cloud of dots.
func _build_balls() -> void:
	for i in range(skel.get_bone_count()):
		var nm := str(skel.get_bone_name(i))
		if not CHAIN.has(nm):
			continue
		_sphere(_world(i), _radius_for(nm), _color_for(nm))
		var p := skel.get_bone_parent(i)
		# DEFECT FIX, NAME TESTED AGAINST AN INDEX, THE CAUSE OF capsules=0. get_bone_parent
		# returns an INDEX, so str() of it is a digit string like "1", and CHAIN holds bone NAMES,
		# so this guard was ALWAYS false and _capsule was never called even once. I had read this
		# exact line earlier, saw the duplicated get_bone_parent call, labelled it redundant but
		# not wrong, and MISSED that the argument was an index being compared to names. Test the
		# NAME, and use the p already computed on the line above.
		if p >= 0 and CHAIN.has(skel.get_bone_name(p)):
			_capsule(_world(i), _world(p), _radius_for(nm) * 0.85)

func _world(i: int) -> Vector3:
	# The composition the earlier probes got wrong. Skeleton-local, composed once.
	return (skel.global_transform * skel.get_bone_global_pose(i)).origin

func _radius_for(nm: String) -> float:
	if FEET.has(nm): return 0.075
	if HANDS.has(nm): return 0.070
	return 0.045

func _color_for(nm: String) -> Color:
	if FEET.has(nm): return Color(0.2, 0.9, 0.3)
	if HANDS.has(nm): return Color(0.95, 0.8, 0.1)
	return Color(0.55, 0.65, 0.95)

func _capsule(a: Vector3, b: Vector3, r: float) -> void:
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	# DEFECT FIX, MATERIAL, WHICH IS WHY 11 SPHERES RENDERED AND 0 CAPSULES DID WITH A SOUND
	# BASIS. _sphere assigns an UNSHADED material_override and _capsule assigned NONE, so
	# capsules took the default shaded material: black on a dark background, while the unshaded
	# spheres stayed bright. The determinant check certified the rotation and could not see this,
	# which is exactly the class a transform assertion is blind to. Same treatment for both
	# primitives, and a distinct colour so a chain reads as a chain rather than as beads.
	cap.radius = r
	cap.height = maxf(a.distance_to(b), r * 2.0 + 0.001)
	mi.mesh = cap
	mi.material_override = _mat(Color(0.45, 0.55, 0.85))
	# DEFECT FIX, AND IT WAS FOUND BY SEEING IT RENDER: spotter measured 11 SPHERES AND 0
	# CAPSULES. The cause was look_at_from_position(..., Vector3.UP), which is DEGENERATE for a
	# near-vertical chain -- and a spine, thighs and shins ARE near-vertical, so the look
	# direction was parallel to the up vector, the basis went bad, and the mesh never drew at
	# all. look_at is the wrong tool whenever the target can point along the up axis, which for
	# a skeleton is most of the time. Build the basis explicitly instead: CapsuleMesh runs along
	# +Y, so y is the bone direction and x/z come from a reference axis chosen NOT to be
	# parallel to it. No up vector, so no degeneracy case.
	var d := b - a
	var l := d.length()
	if l > 0.0001:
		d /= l
		var ref := Vector3.UP if absf(d.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		var x := ref.cross(d)
		if x.length() < 0.0001:
			x = Vector3.FORWARD.cross(d)
		x = x.normalized()
		# DEFECT FIX, HANDEDNESS, FOUND BY A HEADLESS BASIS CHECK WITH NO PIXELS: this was
		# d.cross(x), which is the NEGATION of x.cross(d). Basis(x, y, z) is right-handed only
		# when z = x.cross(y), so every capsule basis had DETERMINANT -1, a MIRROR rather than a
		# rotation, and a mirrored capsule can cull away or shade inside-out. The previous fix
		# removed the look_at degeneracy but introduced this, and only a determinant check finds it.
		var z := x.cross(d).normalized()
		add_child(mi)
		_built_capsules += 1
		# The basis and origin are WORLD-space, and the proxy node is parented under the bot and
		# may itself be transformed, so this must be global too -- which means after add_child.
		mi.global_transform = Transform3D(Basis(x, d, z), (a + b) * 0.5)
	else:
		add_child(mi)
		mi.global_transform = Transform3D(Basis(), a)

func _sphere(p: Vector3, r: float, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.material_override = _mat(c)
	# DEFECT FIX, ORDERING, FROM spotter S BACKTRACE AT LINE 214: global_position was set
	# BEFORE add_child, so get_global_transform() hit !is_inside_tree() and returned
	# Transform3D(). That is why ELEVEN SPHERES NEVER APPEARED and the frame was empty except
	# for the screen-space text, which always survives. add_child FIRST, then the global set.
	add_child(mi)
	_built_spheres += 1
	mi.global_position = p

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

## THE NUMBERS, WHICH ARE WHAT ANY REPORT QUOTES. A sphere at the foot must reach y=0. If
## the body is rolled about the forward axis, the foot lands high or to one side, and that
## is the symptom the user described, in a quantity a person can check.
func _report() -> void:
	var lines: Array[String] = []
	# SELF-LABELLING: name the clip ACTUALLY playing, not the one this file asked for.
	var shown := _clip_name if not _clip_name.is_empty() else String(anim.current_animation)
	lines.append("clip ACTUALLY PLAYING = %s   len %.4f   pos %.4f" % [shown, anim.current_animation_length, anim.current_animation_position])
	var si := _idx("spine_01")
	if si >= 0:
		# THE UP-AXIS READOUT IS DELETED, NOT RELABELLED, ON spotter S ADVICE: a printed number
		# that is not a verdict is one more number somebody will quote later, and spotter quoted a
		# 90 all night before I caught it. The quantity it measured, ~90 at REST, is meaningless as
		# a symptom, so it does not belong in the output at all.
		# THE QUANTITY THAT IS ACTUALLY INFORMATIVE, REST-RELATIVE SO NO MOUNT CONVENTION AND
		# NO ABSOLUTE AXIS CAN CONTAMINATE IT: how far the POSE departs from the rig OWN rest,
		# read in one frame as get_bone_global_rest against get_bone_global_pose. This is the
		# shape of the 92.910 figure and, unlike the up-axis reading, its rest value is ZERO by
		# construction.
		var pose := (skel.global_transform * skel.get_bone_global_pose(si)).basis.get_rotation_quaternion()
		var rst := (skel.global_transform * skel.get_bone_global_rest(si)).basis.get_rotation_quaternion()
		lines.append("spine_01 POSE minus REST = %.3f deg   <- the real quantity" % rad_to_deg(2.0 * acos(clampf(absf(pose.dot(rst)), -1.0, 1.0))))
	for f in FEET:
		var i := _idx(f)
		if i >= 0:
			lines.append("%s world y = %+.3f  (0 = planted)" % [f, _world(i).y])
	# The feet must reach the same height, or the body is leaning, which is the other way
	# this defect presents and is a different fix.
	var fl := _idx(FEET[0]); var fr := _idx(FEET[1])
	if fl >= 0 and fr >= 0:
		lines.append("foot height asymmetry: %.3f m" % absf(_world(fl).y - _world(fr).y))
	report.text = "\n".join(lines)
	print("[RIGPROXY] ", lines[0], " | ", lines[1] if lines.size() > 1 else "")
	# Attribute the primitives explicitly. A reader who cannot see capsules can then tell whether
	# they were BUILT and not drawn, or never BUILT at all. Those are different bugs and the
	# pixels alone cannot distinguish them.
	print("[RIGPROXY] built spheres=", _built_spheres, " capsules=", _built_capsules)

func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r != null:
			return r
	return null

func _idx(nm: String) -> int:
	return skel.find_bone(nm)

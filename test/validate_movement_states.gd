extends SceneTree
## PlayerMovementParameters must be a Resource so movement states can be
## AUTHORED as .tres, which is the standing rule for this project. It also
## mutates itself in resolve(), and a Resource loaded from a .tres is SHARED, so
## the conversion introduces a hazard the RefCounted version did not have.
##
## This harness checks both, and it checks the hazard with a control rather than
## an assertion about it, because "duplicate() is a good idea" is a claim and
## "the shared resource would have been edited" is a measurement.

const P := preload("res://addons/cabra.lat_shooters/src/player/player_movement_parameters.gd")
const C := preload("res://addons/cabra.lat_shooters/src/player/config.gd")

var _pass: int = 0
var _fail: int = 0
const MISSING: float = -99999.0  ## cannot be a real resolved value


func _ok(cond: bool, what: String) -> void:
  if cond:
    _pass += 1
  else:
    _fail += 1
    print("FAIL %s" % what)


func _initialize() -> void:
  _run.call_deferred()


func _run() -> void:
  # --- 1. It is authorable, which is the whole point of the conversion. ---
  var p := P.new()
  _ok(p is Resource, "instance is a Resource, so a .tres can carry one")
  _ok(not (p is Object and p.get_class() == "RefCounted"),
    "get_class() is not bare RefCounted (that was the old base class)")

  # An exported field is what makes a field appear in the editor and land in a
  # .tres. A plain `var` is invisible to both, so this is the assertion that
  # actually tests the conversion rather than the base class name.
  var props: Dictionary = {}
  for p_info in p.get_property_list():
    props[p_info["name"]] = p_info["usage"]
  for field in ["state_id", "speed", "head_bobbing", "camera_height",
      "camera_fov", "collider_factor", "lean_direction"]:
    _ok(props.has(field), "field is present: %s" % field)
    _ok(int(props.get(field, 0)) & PROPERTY_USAGE_STORAGE != 0,
      "field is STORAGE/editor-visible so a .tres can author it: %s" % field)

  # --- 2. resolve() still behaves. A refactor that changes values is a bug. ---
  var cfg := C.new()
  cfg.default_speed = 4.0
  cfg.default_bobing = 0.1
  cfg.stand_height = 1.7
  cfg.default_fov = 50.0
  cfg.walk_speed = 2.5
  cfg.walk_bobbing = 0.2
  cfg.crouch_speed = 1.8
  cfg.crouch_bobbing = 0.15
  cfg.prone_speed = 0.9
  cfg.prone_bobbing = 0.05
  cfg.lean_speed = 2.0
  cfg.aim_fov = 40.0
  cfg.aim_focused_fov = 30.0

  var standing := P.new()
  standing.resolve(cfg, "Stopped", "", "", "", 1.0, 1.0)
  _ok(is_equal_approx(standing.speed, 4.0), "standing speed %.3f == 4.0" % standing.speed)
  # NOT config.stand_height. resolve() assigns it and then the trailing
  # `match crouching_state` default branch overwrites it with EYE_STAND, so
  # stand_height is a DEAD authoring field: setting it in a .tres or the config
  # has no effect on the camera. This asserts the real behaviour rather than the
  # behaviour the field's name implies, because a gate that fails on correct
  # code is a gate nobody trusts. The dead field is reported, not fixed here:
  # honouring it would move the camera from 1.62 to 1.70, which is a product
  # decision and not a refactor.
  _ok(is_equal_approx(standing.camera_height, P.EYE_STAND),
    "standing camera_height %.3f == EYE_STAND, NOT the dead config.stand_height" % standing.camera_height)
  _ok(not is_equal_approx(standing.camera_height, cfg.stand_height),
    "CONFIRMED DEAD FIELD: config.stand_height %.3f never reaches camera_height %.3f" % [cfg.stand_height, standing.camera_height])
  _ok(is_equal_approx(standing.camera_fov, 50.0), "standing camera_fov %.3f == 50.0" % standing.camera_fov)
  _ok(is_equal_approx(standing.collider_factor, P.COLLIDER_STAND),
    "standing collider_factor %.3f == COLLIDER_STAND" % standing.collider_factor)

  var crouching := P.new()
  crouching.resolve(cfg, "Stopped", "Crouching", "", "", 1.0, 1.0)
  _ok(is_equal_approx(crouching.camera_height, P.EYE_CROUCH),
    "crouching camera_height %.3f == EYE_CROUCH" % crouching.camera_height)
  _ok(is_equal_approx(crouching.collider_factor, P.COLLIDER_CROUCH),
    "crouching collider_factor %.3f == COLLIDER_CROUCH" % crouching.collider_factor)

  var proning := P.new()
  proning.resolve(cfg, "Stopped", "Proning", "", "", 1.0, 1.0)
  _ok(is_equal_approx(proning.collider_factor, P.COLLIDER_PRONE),
    "proning collider_factor %.3f == COLLIDER_PRONE" % proning.collider_factor)

  # Multipliers still apply, including a zero that must actually reach the field
  # rather than being treated as "unset" by an exported var's default.
  var slowed := P.new()
  slowed.resolve(cfg, "Stopped", "", "", "", 0.0, 0.5)
  _ok(is_equal_approx(slowed.speed, 0.0), "condition_multiplier 0 reaches speed (%.3f)" % slowed.speed)
  _ok(is_equal_approx(slowed.camera_fov, 25.0), "stamina_fov_multiplier 0.5 reaches fov (%.3f)" % slowed.camera_fov)

  # --- 3. THE HAZARD, MEASURED. Not asserted: demonstrated. ---
  # A .tres in the editor is loaded SHARED. If resolve() were called on the
  # shared asset, the authored state would be edited at runtime, and the second
  # frame of the same run would read different values from the same file. That
  # is the bug the conversion creates, so it is measured, not described.
  var authored := P.new()
  authored.state_id = &"strafe_left"
  var authored_fov: float = authored.camera_fov

  # RED ARM: resolve straight into the shared object, the way load() would hand
  # it over. This MUST corrupt it, or instantiate_local() is decoration.
  var shared_victim := P.new()
  shared_victim.state_id = &"strafe_left"
  shared_victim.resolve(cfg, "Stopped", "", "Aiming", "", 1.0, 1.0)
  _ok(not is_equal_approx(shared_victim.camera_fov, authored_fov),
    "RED ARM: resolving into a SHARED resource mutates it (%.3f -> %.3f) -- this is why instantiate_local exists" % [authored_fov, shared_victim.camera_fov])

  # GREEN ARM: the same resolve through instantiate_local, twice. The authored
  # state must be byte-identical afterwards, which is the property a .tres
  # actually needs.
  var local_a := P.instantiate_local(authored)
  _ok(local_a != null, "instantiate_local returned an instance")
  _ok(local_a != authored, "instantiate_local returned a DISTINCT object, not the shared one")
  _ok(local_a.resource_local_to_scene, "instantiate_local set resource_local_to_scene")
  _ok(local_a.state_id == &"strafe_left", "authored state_id survived the copy (%s)" % local_a.state_id)
  local_a.resolve(cfg, "Stopped", "", "Aiming", "", 1.0, 1.0)
  var local_b := P.instantiate_local(authored)
  local_b.resolve(cfg, "Sprinting", "Crouching", "", "", 2.0, 1.0)
  _ok(is_equal_approx(authored.camera_fov, authored_fov),
    "authored state is UNCHANGED after two resolves through locals (%.3f)" % authored.camera_fov)
  _ok(is_equal_approx(authored.state_id == &"strafe_left" as float, 1.0),
    "authored state_id unchanged after resolves")

  # instantiate_local must reject the wrong type rather than returning null and
  # letting a caller dereference it three frames later.
  var wrong := C.new()
  _ok(P.instantiate_local(wrong) == null, "instantiate_local rejects a non-PlayerMovementParameters Resource")
  _ok(P.instantiate_local(null) == null, "instantiate_local rejects null")

  # The consts are still reachable statically, because controller.gd reads them
  # that way and a conversion that broke that would be a silent behaviour change.
  _ok(is_equal_approx(P.EYE_STAND, 1.62), "EYE_STAND const still 1.62")
  _ok(is_equal_approx(P.EYE_CROUCH, 1.05), "EYE_CROUCH const still 1.05")
  _ok(is_equal_approx(P.EYE_PRONE, 0.45), "EYE_PRONE const still 0.45")
  _ok(is_equal_approx(P.COLLIDER_STAND, 1.0), "COLLIDER_STAND const still 1.0")
  _ok(is_equal_approx(P.COLLIDER_CROUCH, 0.55), "COLLIDER_CROUCH const still 0.55")
  _ok(is_equal_approx(P.COLLIDER_PRONE, 0.35), "COLLIDER_PRONE const still 0.35")
  # And no stale CAPSULE_ name survived, which is the rename this branch builds on.
  # Checked in the SOURCE rather than via get_script_constant_map(), which does not
  # exist on a Resource instance in this engine version -- a check that cannot run
  # is not a check, and quietly dropping it would be worse than finding another way.
  var src := FileAccess.get_file_as_string(
    "res://addons/cabra.lat_shooters/src/player/player_movement_parameters.gd")
  _ok(src.length() > 0, "movement parameters source is readable")
  _ok(not "CAPSULE_" in src, "no stale CAPSULE_ identifier in the source")
  _ok(not "capsule_factor" in src, "no stale capsule_factor identifier in the source")
  _ok("COLLIDER_STAND" in src, "the renamed COLLIDER_STAND is present")

  print("RESULT: %d passed / %d failed" % [_pass, _fail])
  print("RESULT: %s" % ("PASS" if _fail == 0 else "FAIL"))
  quit(0 if _fail == 0 else 1)

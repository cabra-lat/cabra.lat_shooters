class_name PlayerController
extends CharacterBody3D

# ─── STATES ────────────────────────────────────────────────────────────────────
const IDLE = "Idle"
const STOPPED = "Stopped"
const JUMPING = "Jumping"
const PRONING = "Proning"
const CROUCHING = "Crouching"
const BARE_HANDED = "BareHanded"
const TRIGGER_PULLED = "TriggerPulled"
const TRIGGER_RELEASED = "TriggerReleased"
const AIMING = "Aiming"
const FOCUSING = "HoldingBreath"
const CHANGING_MODE = "ChangingMode"
const FALLING = "Falling"
const NOT_LEANING = "NotLeaning"
const LEANING_RIGHT = "LeaningRight"
const LEANING_LEFT = "LeaningLeft"
const RELOADING = "Reloading"
const SPRINTING = "Sprinting"
const WALKING = "Walking"
const VIEW_MODEL_NAME = "WeaponModel"
var debug_text: String = ""

# ─── SIGNALS ───────────────────────────────────────────────────────────────────
signal moved(player: PlayerController, delta: float)
signal leaned(player: PlayerController, direction: int)
signal proned(player: PlayerController, reverse: bool)
signal crouched(player: PlayerController, reverse: bool)
signal aimed(player: PlayerController, reverse: bool)
signal focused(player: PlayerController, reverse: bool)
signal jumped(player: PlayerController)
signal landed(player: PlayerController, max_velocity: float, delta: float)
signal reloaded(player: PlayerController)
signal equipped(player: PlayerController, what: Item)
signal unequiped(player: PlayerController, what: Item)
signal insert_ammo_feed(player: PlayerController)
signal check_ammo_feed(player: PlayerController, ammo_feed: AmmoFeed)
signal debug(player: PlayerController, text: String)
signal consumed(item: InventoryItem, result: Dictionary)
signal consume_started(item: InventoryItem)
signal consume_cancelled(item: InventoryItem)
signal noise_emitted(position: Vector3, loudness: float, source: String)
## A weapon was asked to be modified from the inventory (context menu). The
## arena listens and opens the gunsmith screen for `weapon`.
signal weapon_modify_requested(weapon: Weapon)

# ─── REFERENCES ────────────────────────────────────────────────────────────────
@export var input: PlayerInput
@export var config: PlayerConfig
@export var health: Health
@export var equipment: Equipment
@export var inventory_ui: InventoryUI
@export var survival: PlayerSurvival

@onready var moving: StateMachine = %Moving
@onready var crouching: StateMachine = %Crouching
@onready var leaning: StateMachine = %Leaning
@onready var aiming: StateMachine = %Aiming
@onready var firing: StateMachine = %Firing
@onready var collision: CollisionShape3D = %CollisionShape3D
@onready var head: Node3D = %Head
@onready var skeleton: Node3D = %Skeleton3D
@onready var camera: Camera3D = %Camera3D
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var shoulder: Node3D = %Shoulder
@onready var hand: Node3D = %RightHand
@onready var other_hand: Node3D = %LeftHand
@onready var focus_timer: Timer = %FocusTimer
@onready var reload_timer: Timer = %ReloadTimer
@onready var firemode_timer: Timer = %FiremodeTimer

# ─── MOVEMENT VARIABLES ────────────────────────────────────────────────────────
var max_velocity: float = 0.0
var current_weapon: Weapon = null
## Active weapon slot, OWNED BY THE ARENA (set via set_active_weapon_slot).
## `current_weapon` is ALWAYS resolved from this slot, so a drop / equip /
## quick-switch (whatever the path) can never leave a stale gun for the gunsmith
## or the HUD.
var active_weapon_slot: String = "primary"
var current_hands: Item3D = null
var viewmodel_rig: ViewmodelRig = null
var last_look_delta := Vector2.ZERO
var current_direction: Vector3 = Vector3.ZERO
var _pitch: float = 0.0 # eye pitch (radians), mirrored from the look input
# Medical use: one item at a time, effect lands after the item's use_time.
var consuming_item: InventoryItem = null
var consume_time_left: float = 0.0
var total_weight: float = 0.0
var _tremor_phase: float = 0.0

# Animation targets
var current_speed: float = 0.0
var current_camera_height: float = 0.0
var current_camera_fov: float = 0.0
var current_head_bobbing: float = 0.0
var current_lean_angle: float = 0.0
var current_damping: float = 0.0

# Stance eye heights (applied to head + SpringArm) and capsule factors.
const EYE_STAND: float = 1.62
const EYE_CROUCH: float = 1.05
const EYE_PRONE: float = 0.45
# Inventory HUD: instanced from the scene so it lives in the tree and
# renders (a bare InventoryUI.new() never draws anything). Runtime load
# (not const preload): main.gd references PlayerController, so an eager
# preload would cycle at parse time.
const INVENTORY_UI_SCENE_PATH := "res://addons/cabra.lat_shooters/src/ui/inventory/main.tscn"
const CAPSULE_STAND: float = 1.0
const CAPSULE_CROUCH: float = 0.55
const CAPSULE_PRONE: float = 0.35
# Stance/FOV smoothing rate: exponential (1 - exp(-k*dt)), frame-rate
# independent. k=6.0 matches the old per-frame lerp(...,0.1) feel at 60 Hz
# (~0.16 s time constant) without the frame-rate dependence (QA-016).
const STANCE_SMOOTH_RATE: float = 6.0
# Lean / peek. Leaning must actually let you SEE around a corner, so the core
# effect is a LATERAL TRANSLATION of the eye (the camera lives on the
# SpringArm3D; `head` is only a RemoteTransform3D driving the IK head bone and
# never moved the view). Roll and body tilt are secondary feedback, scaled by
# the offset that actually got applied.
const LEAN_PEEK_OFFSET: float = 0.45 # m of lateral eye travel at full lean
const LEAN_PEEK_MARGIN: float = 0.25 # body radius: stay this far off walls
const LEAN_ROLL_MAX: float = deg_to_rad(8.0) # secondary camera roll
const LEAN_BODY_MAX: float = deg_to_rad(10.0) # visual body tilt about the feet
const LEAN_STANCE_SCALE_CROUCH: float = 0.6
const LEAN_STANCE_SCALE_PRONE: float = 0.25
const LEAN_VISUAL_RATE: float = 10.0
var _lean_dir: float = 0.0 # -1 right, +1 left, 0 none (matches leaned signal)
var _lean_peek: float = 0.0 # lateral offset currently applied to the eye
var _skeleton_rest := Transform3D.IDENTITY
var _bob_phase: float = 0.0

# ─── DEBUG FLYING ──────────────────────────────────────────────────────────────
var debug_flying: bool = false
var debug_fly_speed: float = 10000.0
var debug_fly_acceleration: float = debug_fly_speed
var debug_fly_fast_multiplier: float = 3.0
var debug_fly_slow_multiplier: float = 0.3

# Debug and performance
var _last_debug_time: float = 0.0
var _debug_interval: float = 0.1  # Update debug only 10 times per second
var _condition_cache: Dictionary = {}

# ─── INITIALIZATION ────────────────────────────────────────────────────────────
func _ready():
  # Initialize input if not assigned
  if input == null:
    input = PlayerInput.new()
    add_child(input)

  # Initialize systems if not assigned
  if config == null:
    config = PlayerConfig.new()
  if health == null:
    health = Health.new()
  if equipment == null:
    equipment = Equipment.new()
  if inventory_ui == null:
    var ui_scene := load(INVENTORY_UI_SCENE_PATH) as PackedScene
    inventory_ui = ui_scene.instantiate() as InventoryUI
    add_child(inventory_ui)
  inventory_ui.hide()

  # Survival (stamina / energy / hydration / encumbrance).
  if survival == null:
    survival = PlayerSurvival.new()
  survival.max_weight = config.max_weight
  _install_status_hud()
  _install_starter_medical()
  # Body visibility is applied deferred: a scene's _ready (which used to hide
  # every body mesh) runs AFTER its children are ready, so restoring the layers
  # immediately would be undone. Idempotent, so scenes may call it too.
  call_deferred("_install_body_visibility")

  # Connect equipment changes to update weapon node
  equipment.equipped.connect(_on_equipment_equipped)
  equipment.unequiped.connect(_on_equipment_unequiped)

  # Mirror equipment state into the input edge flags so the aiming SM
  # tracks programmatic equips (arena/range never press weapon_slot1).
  if input:
    input.equipment_source = equipment

  # Stealth: the player's own actions feed the bots' hearing.
  if not reloaded.is_connected(_on_reloaded_noise):
    reloaded.connect(_on_reloaded_noise)
  if not landed.is_connected(_on_landed_noise):
    landed.connect(_on_landed_noise)

  # Connect timers
  if firemode_timer and not firemode_timer.timeout.is_connected(_on_firemode_timeout):
    firemode_timer.timeout.connect(_on_firemode_timeout)
  if reload_timer and not reload_timer.timeout.is_connected(_on_reload_timeout):
    reload_timer.timeout.connect(_on_reload_timeout)
  if focus_timer and not focus_timer.timeout.is_connected(_on_focus_timeout):
    focus_timer.timeout.connect(_on_focus_timeout)

  # Connect state machine signals
  call_deferred("_connect_state_machine_signals")

  # Setup physics
  set_up_direction(Vector3.UP)
  set_floor_stop_on_slope_enabled(false)
  set_max_slides(4)
  set_floor_max_angle(PI / 4)
  # Duplicate the shared BoxShape3D before stance scaling (never edit the asset).
  if collision and collision.shape:
    collision.shape = collision.shape.duplicate()
    set_meta("_capsule_base_size", (collision.shape as BoxShape3D).size)
    set_meta("_capsule_base_y", collision.position.y)
  # Remember the mesh's authored basis so the lean tilt can be composed in
  # the body frame without fighting the baked 90 deg rotation.
  if skeleton:
    _skeleton_rest = skeleton.transform
  # Capture mouse
  Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

  print("PlayerController initialized")

func _connect_state_machine_signals():
  var state_machines = [moving, crouching, aiming, leaning, firing]
  for state_machine in state_machines:
    if state_machine and state_machine.has_signal("state_entered"):
      if not state_machine.state_entered.is_connected(_on_state_entered):
        state_machine.state_entered.connect(_on_state_entered.bind(state_machine.name))
    if state_machine and state_machine.has_signal("state_exited"):
      if not state_machine.state_exited.is_connected(_on_state_exited):
        state_machine.state_exited.connect(_on_state_exited.bind(state_machine.name))
    if state_machine and state_machine.has_signal("state_changed"):
      if not state_machine.state_changed.is_connected(_on_state_changed):
        state_machine.state_changed.connect(_on_state_changed.bind(state_machine.name))

# ─── EQUIPMENT HANDLING ────────────────────────────────────────────────────────
func _on_equipment_equipped(item: Item, slot_name: String):
  var weapon_item = item
  if weapon_item and weapon_item.extra is Weapon:
    # Legacy (signal-driven) path, kept until the arena opts into
    # set_active_weapon_slot(): last equipped wins, so the arena's
    # "equip the active slot last" switch keeps working unchanged.
    current_weapon = weapon_item.extra as Weapon
    _setup_viewmodel_on_hand(current_weapon)
    if not current_weapon.cartridge_fired.is_connected(_on_cartridge_fired_noise):
      current_weapon.cartridge_fired.connect(_on_cartridge_fired_noise)
    print("Weapon %s equipped at %s" % [current_weapon.name, slot_name])

func _on_cartridge_fired_noise(weapon: Weapon, _cartridge: Ammo) -> void:
  if weapon != current_weapon:
    return
  emit_shot_noise()

func _on_reloaded_noise(_player_ref: PlayerController) -> void:
  emit_reload_noise()

func _on_landed_noise(_player_ref: PlayerController, max_velocity: float, _delta: float) -> void:
  emit_land_noise(max_velocity)

## equipment.unequiped emits (item, slot_name). The old 0-arg signature made
## Godot refuse the call ("Method expected 0 argument(s), but called with 2"),
## so a pure unequip (e.g. G world-drop) never released the viewmodel and the
## gun stayed in hand forever. Keep the arity in sync with the signal.
func _on_equipment_unequiped(item: Item, slot_name: String):
  # `item` is typed as Item but the .extra payload lives on InventoryItem,
  # so read it through an untyped local (same trick as the equipped handler).
  var unequipped = item
  var unequipped_weapon: Weapon = null
  if unequipped != null:
    unequipped_weapon = unequipped.extra as Weapon
  if unequipped_weapon == null:
    return # armour / attachment / mag: the gun in hand is unaffected
  # Only release when the weapon leaving the body is the one we posed.
  if current_weapon == null or unequipped_weapon == current_weapon:
    _remove_viewmodel_from_hand()
    current_weapon = null
    print("Weapon unequipped from %s - viewmodel released" % slot_name)

## current_weapon is ALWAYS the weapon equipped in the active slot: the arena
## tells us the slot (set_active_weapon_slot) and any equip/unequip routes here,
## so a dropped/switched gun never lingers for the gunsmith or HUD.
func _refresh_current_weapon() -> void:
  var w: Weapon = null
  if equipment != null and active_weapon_slot != "":
    var items := equipment.get_equipped(active_weapon_slot)
    if not items.is_empty():
      w = items[0].extra as Weapon
  if w == current_weapon:
    return
  current_weapon = w
  _setup_viewmodel_on_hand(w)
  if w != null and not w.cartridge_fired.is_connected(_on_cartridge_fired_noise):
    w.cartridge_fired.connect(_on_cartridge_fired_noise)

## The arena owns the active slot; it calls this on switch/drop so current_weapon
## follows (drop included, whatever the removal path).
func set_active_weapon_slot(slot: String) -> void:
  active_weapon_slot = slot
  _refresh_current_weapon()

func _setup_viewmodel_on_hand(weapon: Weapon):
  # Always drop the previous viewmodel first. It is parented to
  # current_scene (never to `hand`), so it MUST be freed through
  # `current_hands` — a `hand.get_node_or_null(VIEW_MODEL_NAME)` lookup
  # misses it and leaks a ghost body that blocks the shot ray.
  _teardown_viewmodel()

  if not hand:
    return

  # Create new viewmodel if available
  if weapon and weapon.view_model:
    # `current_scene` is null when a harness instantiates the arena via
    # `--script` (nothing registered it as the current scene) -> fall back to the
    # tree root. If that host is still building (add_child during _initialize
    # fails on a busy parent), retry next frame instead of erroring.
    var tree := get_tree()
    if tree == null:
      return
    var host := tree.current_scene if tree.current_scene != null else tree.root
    if host == null:
      return
    if not host.is_node_ready():
      _setup_viewmodel_on_hand.call_deferred(weapon)
      return
    var new_vm: Weapon3D = weapon.view_model.instantiate()
    new_vm.name = VIEW_MODEL_NAME
    # Rigid procedural hold (see ViewmodelRig): freeze the body and pose it
    # from the camera every frame. Never spring-simulate a held item.
    new_vm.freeze = true
    new_vm.contact_monitor = false
    # add_child BEFORE data: Weapon3D._set_data -> _setup_magazine -> grab()
    # reads get_global_transform(), which needs the tree (else the engine warns
    # and the initial pose is wrong). Clear attractors AFTER Item3D._ready
    # repopulates them from the parent (QA-014).
    host.add_child(new_vm)
    new_vm.attractors.clear()
    new_vm.data = weapon
    viewmodel_rig = ViewmodelRig.new()
    viewmodel_rig.setup(self, new_vm)
    current_hands = new_vm

func _remove_viewmodel_from_hand():
  _teardown_viewmodel()

## Single teardown path: restore held-body collision, free the vm, and
## sweep any ghost left under current_scene by older equip paths.
func _teardown_viewmodel():
  if viewmodel_rig:
    # The vm is always freed here, so skip collision restore.
    viewmodel_rig.teardown(false)
    viewmodel_rig = null
  if is_instance_valid(current_hands):
    # Release the canonical name before the deferred free lands, otherwise
    # the incoming viewmodel is auto-renamed (@RigidBody3D@N) by the clash.
    if current_hands.name == VIEW_MODEL_NAME:
      current_hands.name = "_old_" + VIEW_MODEL_NAME
    current_hands.queue_free()
  current_hands = null
  var scene := get_tree().current_scene
  if scene:
    for child in scene.get_children():
      if child.name == VIEW_MODEL_NAME:
        child.queue_free()

# ─── SURVIVAL (stamina / weight / medical) ─────────────────────────────────────
## Total carried mass: equipment slots (weapon incl. mag/attachments, armour,
## the pack itself) + the pack's contents.
func get_total_weight() -> float:
  if equipment == null:
    return 0.0
  var total := equipment.get_total_mass()
  var pack := get_equipped_backpack()
  if pack != null:
    total += pack.get_total_mass()
  return total

func get_equipped_backpack() -> InventoryContainer:
  if equipment == null:
    return null
  var slot: EquipmentSlot = equipment.slots.get("back")
  if slot == null or slot.items.is_empty():
    return null
  var item = slot.items[0]
  var extra = item.extra if item != null else null
  return extra if extra is InventoryContainer else null

func _update_survival(delta: float) -> void:
  if survival == null:
    return
  # Health ticks bleeding / bleed-out / pain decay. Nothing else called it.
  if health != null:
    health.update(delta)

  total_weight = get_total_weight()
  survival.set_weight(total_weight)

  var sprinting := moving != null and moving.state == SPRINTING \
    and input != null and input.sprint_held
  var planar := Vector3(velocity.x, 0.0, velocity.z).length()
  var moving_now := planar > 0.1 or (input != null and input.motion.length_squared() > 0.0)
  survival.update(delta, sprinting, moving_now)

  # Gate the SM inputs from physical state (single writer, before the read).
  if input != null:
    input.sprint_allowed = survival.can_start_sprint() if not sprinting else survival.can_sprint()
    input.jump_allowed = survival.can_jump()

  # Starving / dehydrated costs HP once the pools bottom out.
  if health != null and health.is_alive:
    var starving := survival.energy <= 0.0
    var dehydrated := survival.hydration <= 0.0
    if starving or dehydrated:
      health.apply_environmental_damage(
        survival.starvation_damage_per_second * (2.0 if (starving and dehydrated) else 1.0) * delta,
        "dehydration" if dehydrated else "starvation")

  _tick_consumable(delta)

## Inventory -> gunsmith entry point. The inventory UI owns the context menu and
## calls this; the arena listens to `weapon_modify_requested` and opens the UI.
func request_weapon_modify(weapon: Weapon) -> void:
  if weapon == null:
    return
  weapon_modify_requested.emit(weapon)

## Start using a medical/provision item. Returns false when busy or invalid.
func start_use(item: InventoryItem) -> bool:
  if consuming_item != null:
    return false
  if item == null:
    return false
  var med = item.extra
  if not (med is MedicalItem) or not (med as MedicalItem).can_use():
    return false
  consuming_item = item
  consume_time_left = maxf((med as MedicalItem).use_time, 0.0)
  # Using an item breaks the trigger pull.
  if firing:
    Input.action_release("fire")
  consume_started.emit(item)
  return true

func cancel_use() -> void:
  if consuming_item == null:
    return
  var cancelled := consuming_item
  consuming_item = null
  consume_time_left = 0.0
  consume_cancelled.emit(cancelled)

func _tick_consumable(delta: float) -> void:
  if consuming_item == null:
    return
  consume_time_left -= delta
  if consume_time_left > 0.0:
    return
  var item := consuming_item
  consuming_item = null
  var med = item.extra
  if med is MedicalItem and health != null:
    var result: Dictionary = (med as MedicalItem).apply(health, survival)
    consumed.emit(item, result)

func is_consuming() -> bool:
  return consuming_item != null

## Use the most appropriate item the player carries (bleed -> bandage,
## fracture -> splint, ...). This is the quick-use path (key or inventory).
func try_use_best_medical() -> bool:
  if is_consuming():
    return false
  var item := MedicalKit.find_usable(self)
  if item == null:
    return false
  return start_use(item)

## Starter kit (testing): a bandage, a splint, a tourniquet and water in a
## backpack, only when the player starts empty-handed. Keeps both scenarios
## playable without a console. Returns true if it granted anything.
func _install_starter_medical() -> bool:
  if equipment == null:
    return false
  if not MedicalKit.carried_medical(self).is_empty():
    return false
  var pack := get_equipped_backpack()
  if pack == null:
    var new_pack := Backpack.new()
    new_pack.name = "Field Backpack"
    new_pack.icon = load("res://assets/ui/inventory/backpack.png")
    var pack_item := InventorySystem.create_inventory_item(new_pack)
    pack_item.dimensions = Vector2i(2, 2)
    if not equipment.equip(pack_item, "back"):
      return false
    pack = get_equipped_backpack()
    if pack == null:
      return false
  var granted := false
  for key in MedicalKit.STARTER:
    var item := MedicalKit.make(key)
    if item == null:
      continue
    item.dimensions = Vector2i(1, 1)
    # NOTE: InventoryContainer.add_item defaults its position to (0,0), which
    # collides on the second item; (-1,-1) is the "find free space" sentinel
    # the grid understands.
    if pack.add_item(item, Vector2i(-1, -1)):
      granted = true
    else:
      push_warning("Starter medical: no room for %s" % key)
  return granted

## Troubleshooting entry point (X). No weapon in hand, or a healthy weapon,
## is a no-op. Returns true when a clearing sequence actually started.
func clear_weapon_malfunction() -> bool:
  if current_hands is Weapon3D:
    return (current_hands as Weapon3D).clear_malfunction()
  return false

## Weapon state for the HUD (durability/ergonomics/malfunction). Null when
## nothing is held, so the HUD can hide the block.
func get_weapon_state() -> Dictionary:
  if current_weapon == null:
    return {}
  return current_weapon.get_state()

# ─── STEALTH: player noise for the AI hearing system ───────────────────────────
## Emit a world noise the bots can hear. Loudness is posture/surface/modifier
## aware (see PlayerNoise). Returns the loudness actually emitted.
func emit_noise(loudness: float, source: String = "player") -> float:
  if loudness <= 0.0:
    return 0.0
  var pos := global_position
  NpcBot.emit_noise(pos, loudness)
  noise_emitted.emit(pos, loudness, source)
  return loudness

## Helmet sound_reduction (negative dampens everything the player emits).
func get_helmet_sound_reduction() -> float:
  if equipment == null:
    return 0.0
  var worn := equipment.get_equipped("head")
  if worn.is_empty():
    return 0.0
  var extra = worn[0].extra
  if extra is Armor:
    return (extra as Armor).sound_reduction
  return 0.0

## Muzzle sound_suppression of the mounted suppressor (0..1). Shot only.
func get_suppression() -> float:
  if current_weapon == null:
    return 0.0
  var att: Attachment = current_weapon.get_attachment(Weapon.AttachmentPoint.MUZZLE)
  if att == null:
    return 0.0
  return att.sound_suppression

## Footstep loudness for the current posture/floor. `soft_ground` = dirt/grass.
## Scenes call this next to the footstep sound so audio and AI agree.
func emit_step_noise(soft_ground: bool = false) -> float:
  var planar := Vector3(velocity.x, 0.0, velocity.z).length()
  var base := PlayerNoise.posture_loudness(
    moving.state if moving else "", crouching.state if crouching else "",
    planar, is_on_floor())
  var loud := base * PlayerNoise.surface_factor(soft_ground)
  return emit_noise(PlayerNoise.apply_modifiers(loud, get_helmet_sound_reduction(), 0.0),
    "step")

func emit_shot_noise() -> float:
  return emit_noise(PlayerNoise.apply_modifiers(
    PlayerNoise.LOUDNESS_SHOT, get_helmet_sound_reduction(), get_suppression()), "shot")

func emit_reload_noise() -> float:
  return emit_noise(PlayerNoise.apply_modifiers(
    PlayerNoise.LOUDNESS_RELOAD, get_helmet_sound_reduction(), 0.0), "reload")

func emit_land_noise(impact_speed: float) -> float:
  return emit_noise(PlayerNoise.apply_modifiers(
    PlayerNoise.land_loudness(impact_speed), get_helmet_sound_reduction(), 0.0), "land")

## Is the ground under the player soft (dirt/grass/sand)? Physics query, so it
## must be called from _physics_process. Explicit `meta("surface")` on the
## collider (or an ancestor) wins; otherwise the mesh material is inspected.
func surface_is_soft_ground() -> bool:
  if not is_inside_tree() or get_world_3d() == null:
    return false
  var from := global_position + Vector3.UP * 0.6
  var to := global_position - Vector3.UP * 0.6
  var query := PhysicsRayQueryParameters3D.create(from, to)
  query.exclude = [get_rid()]
  query.collide_with_areas = false
  var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
  if hit.is_empty():
    return false
  var collider = hit.get("collider")
  if collider == null:
    return false
  var node := collider as Node
  while node != null:
    var tagged := str(node.get_meta("surface", ""))
    if tagged != "":
      return tagged.to_lower() in ["dirt", "grass", "sand", "mud", "terrain", "soft"]
    node = node.get_parent()
  var mesh := collider as MeshInstance3D
  if mesh != null:
    return _material_looks_soft(mesh)
  return false

func _material_looks_soft(mesh: MeshInstance3D) -> bool:
  var mat := mesh.get_active_material(0)
  if mat == null:
    return false
  var names := ""
  if mat.resource_path != "":
    names += mat.resource_path.to_lower()
  if mat.resource_name != "":
    names += " " + mat.resource_name.to_lower()
  for key in ["dirt", "grass", "sand", "mud", "terrain"]:
    if key in names:
      return true
  return false

## ADS duration for the held weapon: ergonomics and attachments change it.
func get_ads_time() -> float:
  if current_weapon == null:
    return config.aim_time
  return current_weapon.get_ads_time(config.aim_time)

# ─── STATUS HUD ────────────────────────────────────────────────────────────────
const STATUS_HUD_SCENE_PATH := "res://addons/cabra.lat_shooters/src/ui/hud/status_hud.tscn"

func _install_status_hud() -> void:
  # Scenes may ship their own HUD; only self-install when absent so the arena
  # and the debug range both get one without touching scene files.
  if get_tree() == null or get_tree().current_scene == null:
    return
  if get_tree().current_scene.find_child("PlayerStatusHud", true, false) != null:
    return
  var scene := load(STATUS_HUD_SCENE_PATH) as PackedScene
  if scene == null:
    return
  var hud := scene.instantiate()
  hud.name = "PlayerStatusHud"
  add_child(hud)
  if hud.has_method("bind_player"):
    hud.bind_player(self)

## See PlayerBodyVisibility: keep the body visible to the FPS camera and cut
## only the shell near the lens.
func _install_body_visibility() -> void:
  PlayerBodyVisibility.apply(self, PlayerBodyVisibility.DEFAULT_NEAR_CUTOFF)

# ─── INPUT HANDLING ────────────────────────────────────────────────────────────
func _input(event):
  # Debug flying toggle
  if event.is_action_pressed("debug_toggle_fly"):
    _toggle_debug_flying()

## Inventory toggle lives here (not _input): same dispatch path the arena
## manager uses — GUI gets first crack at the event, unhandled keys (and
## synthetic/harness events) reliably reach the player.
func _unhandled_input(event):
  # Quick-use medical. The action must exist in the InputMap (owned by
  # `range`); guarded so the game runs fine until it is added.
  if InputMap.has_action("use_medical") and event.is_action_pressed("use_medical"):
    if try_use_best_medical():
      get_viewport().set_input_as_handled()
    return

  if inventory_ui == null:
    return

  if event.is_action_pressed("open_inventory"):
    if inventory_ui.visible:
      inventory_ui.close_inventory()
    else:
      inventory_ui.open_inventory(self)
    get_viewport().set_input_as_handled()
    return
  if inventory_ui.visible:
    if event.is_action_pressed("ui_cancel"):
      inventory_ui.close_inventory()
      get_viewport().set_input_as_handled()
    return

# ─── DEBUG FLYING METHODS ──────────────────────────────────────────────────────
func _toggle_debug_flying():
  debug_flying = !debug_flying
  if debug_flying:
    print("Debug flying enabled")
  else:
    print("Debug flying disabled")

func _handle_debug_flying(delta: float):
  # Handle camera rotation (same as normal)
  _handle_camera_rotation()

  # Calculate movement direction
  var move_direction = Vector3.ZERO

  if input and camera:
    # Forward/backward (W/S)
    if Input.is_key_pressed(KEY_W):
      move_direction -= global_transform.basis.z
    if Input.is_key_pressed(KEY_S):
      move_direction += global_transform.basis.z

    # Left/right (A/D)
    if Input.is_key_pressed(KEY_A):
      move_direction -= global_transform.basis.x
    if Input.is_key_pressed(KEY_D):
      move_direction += global_transform.basis.x

    # Up/down (Space/Shift or E/Q)
    if Input.is_key_pressed(KEY_SPACE):
      move_direction += Vector3.UP
    if Input.is_key_pressed(KEY_CTRL):
      move_direction += Vector3.DOWN

  # Normalize direction if moving
  if move_direction.length_squared() > 0:
    move_direction = move_direction.normalized()

  # Apply speed modifiers
  var current_fly_speed = debug_fly_speed
  if Input.is_key_pressed(KEY_SHIFT):  # Fast mode
    current_fly_speed *= debug_fly_fast_multiplier

  # Apply movement
  if move_direction.length_squared() > 0:
    velocity = velocity.move_toward(move_direction * current_fly_speed, debug_fly_acceleration * delta)
  else:
    velocity = velocity.move_toward(Vector3.ZERO, debug_fly_acceleration * delta)

  # Apply movement
  move_and_slide()

  # Update debug info
  DebugSingleton.add("fly_speed", current_fly_speed, "debug")
  DebugSingleton.add("fly_velocity", velocity, "debug")
  DebugSingleton.add("fly_position", global_position, "debug")

# ─── MAIN PHYSICS PROCESS ──────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
  # Clear previous frame's debug data
  DebugSingleton.clear_category("player")
  DebugSingleton.clear_category("timing")

  # Add debug flying state to debug display
  DebugSingleton.add("debug_flying", debug_flying, "debug")

  # Handle debug flying mode
  if debug_flying:
    _handle_debug_flying(delta)
    return  # Skip normal physics processing when flying

  # Time entire frame
  var frame_timer = DebugSingleton.timer("frame")

  # Time each section
  var camera_timer = DebugSingleton.timer("camera")
  _handle_camera_rotation()
  camera_timer.call()

  var movement_timer = DebugSingleton.timer("move")
  _calculate_movement_direction()
  movement_timer.call()

  # Single writer for the moving SM's ground condition. The Falling->Stopped
  # transition ANDs advance_condition 'on_ground' with the is_on_floor()
  # expression, and nothing set that parameter — so the transition could
  # never fire, the player stayed in Falling forever and (as there is no
  # Falling->Jumping) the jump never applied. Set it before reading states.
  if moving:
    moving.set_condition("on_ground", is_on_floor())

  # Troubleshooting: X clears a jammed weapon (Weapon3D owns the timing; the
  # weapon refuses to fire until Weapon.malfunction_cleared fires).
  if input != null and input.clear_malfunction:
    input.clear_malfunction = false # consume the edge
    clear_weapon_malfunction()

  _update_survival(delta)

  var states_timer = DebugSingleton.timer("state")
  _read_states_and_apply(delta)
  states_timer.call()

  var physics_timer = DebugSingleton.timer("physics")
  _apply_movement_and_physics(delta)
  physics_timer.call()

  if viewmodel_rig:
    viewmodel_rig.update_rig(delta)

  frame_timer.call()

  # Add state data
  DebugSingleton.add("moving_state", moving.state, "player")
  DebugSingleton.add("crouching_state", crouching.state, "player")
  DebugSingleton.add("leaning_state", leaning.state, "player")
  DebugSingleton.add("aiming_state", aiming.state, "player")
  DebugSingleton.add("firing_state", firing.state, "player")

  # Add movement data
  DebugSingleton.add("speed", current_speed, "movement")
  DebugSingleton.add("direction", current_direction, "movement")
  DebugSingleton.add("velocity", velocity, "movement")
  DebugSingleton.add("on_ground", is_on_floor(), "movement")

  # Add input data
  DebugSingleton.add("trying_move", input.motion, "input")
  DebugSingleton.add("is_aim_held", input.aim_held, "input")
  DebugSingleton.add("is_fire_held", input.fire_held, "input")
  DebugSingleton.add("is_sprint_held", input.sprint_held, "input")


func _handle_camera_rotation():
  if not input:
    return

  var mouse_delta = input.consume_mouse_delta()
  last_look_delta = mouse_delta
  if mouse_delta.length_squared() > 0:
    rotation_degrees.y -= mouse_delta.x * config.mouse_sensitivity / 10
    head.rotation_degrees.x -= mouse_delta.y * config.mouse_sensitivity / 10
    head.rotation_degrees.x = clamp(head.rotation_degrees.x, -90, 90)
    head.position.z = 10 * sin(head.rotation.x)
  # PITCH MUST REACH THE CAMERA. `head` is a RemoteTransform3D that drives the
  # IK head bone (body/PiP), never the eye: the camera lives on the SpringArm.
  # Without this the FPS view was pitch-locked — you could not look up/down (so
  # "I can't see my feet" was not only a visibility problem), and the shot ray
  # (camera forward) could only be horizontal. Yaw stays on the body, roll on
  # the SpringArm (lean); this only adds the missing pitch to the eye.
  _pitch = clampf(head.rotation.x, deg_to_rad(-90.0), deg_to_rad(90.0))
  if camera:
    camera.rotation.x = _pitch
func _calculate_movement_direction():
  if not input or not camera:
    return

  current_direction = Vector3.ZERO
  if input.motion.length_squared() > 0:
    var camera_basis = camera.global_transform.basis
    current_direction = -camera_basis.z * input.motion.y + camera_basis.x * input.motion.x
    current_direction.y = 0
    current_direction = current_direction.normalized()

func _read_states_and_apply(delta):
  # Apply gravity based on moving state
  if moving and moving.state == FALLING:
    velocity.y -= config.gravity * delta
    max_velocity = max(max_velocity, velocity.length())

  # Set movement parameters based on state combinations
  _update_movement_parameters(delta)

  # Handle state-specific logic
  _handle_state_logic()

func _update_movement_parameters(delta: float = 0.0):
  if not config:
    return

  # Reset to defaults
  current_speed = config.default_speed
  current_head_bobbing = config.default_bobing
  current_lean_angle = config.lean_angle_idle
  current_camera_height = config.stand_height
  current_camera_fov = config.default_fov
  current_damping = config.default_damping

  if not moving:
    return

  # Moving state determines base movement
  match moving.state:
    STOPPED:
      current_speed = config.default_speed
      current_head_bobbing = config.default_bobing
      current_lean_angle = config.lean_angle_idle
    WALKING:
      current_speed = config.walk_speed
      current_head_bobbing = config.walk_bobbing
      current_lean_angle = config.lean_angle_walk
    SPRINTING:
      current_speed = config.sprint_speed
      current_head_bobbing = config.sprint_bobbing
      current_lean_angle = 0
    FALLING:
      max_velocity = max(max_velocity, velocity.length())

  if crouching:
    # Crouching state overrides height and speed
    match crouching.state:
      CROUCHING:
        current_speed = config.crouch_speed
        current_head_bobbing = config.crouch_bobbing
        current_camera_height = config.crouch_height
      PRONING:
        current_speed = config.prone_speed
        current_head_bobbing = config.prone_bobbing
        current_camera_height = config.prone_height

  _lean_dir = 0.0
  if leaning:
    # Leaning state affects speed and (below) the camera/head pose.
    match leaning.state:
      LEANING_RIGHT:
        current_speed = config.lean_speed
        _lean_dir = -1.0
      LEANING_LEFT:
        current_speed = config.lean_speed
        _lean_dir = 1.0

  if aiming:
    # Aiming state affects FOV and bobbing
    match aiming.state:
      AIMING:
        current_speed = config.crouch_speed
        current_head_bobbing = config.NO_BOBBING
        current_camera_fov = config.aim_fov
      FOCUSING:
        current_speed = config.prone_speed
        current_head_bobbing = config.NO_BOBBING
        current_camera_fov = config.aim_focused_fov

  # Stance eye heights override config values (stand 1.62 / crouch 1.05 / prone 0.45).
  var capsule_factor: float = CAPSULE_STAND
  if crouching:
    match crouching.state:
      CROUCHING:
        current_camera_height = EYE_CROUCH
        capsule_factor = CAPSULE_CROUCH
      PRONING:
        current_camera_height = EYE_PRONE
        capsule_factor = CAPSULE_PRONE
      _:
        current_camera_height = EYE_STAND
  else:
    current_camera_height = EYE_STAND

  # Spread the physics/medical/survival scales into the final speed. Applied
  # last so the state machine keeps owning the base value.
  var condition_mult := 1.0
  if survival != null:
    condition_mult *= survival.weight_speed_multiplier()
    condition_mult *= survival.stamina_speed_multiplier()
  if health != null:
    condition_mult *= health.movement_penalty()
  current_speed *= condition_mult
  if survival != null:
    current_camera_fov *= survival.stamina_fov_multiplier()

  # Apply camera effects. Exponential, delta-based smoothing so stance/FOV
  # transitions are frame-rate independent (QA-016).
  var stance_t := 1.0 - exp(-STANCE_SMOOTH_RATE * delta)
  if camera:
    camera.fov = lerp(camera.fov, current_camera_fov, stance_t)
  if head:
    head.position.y = lerp(head.position.y, current_camera_height, stance_t)
  if spring_arm:
    spring_arm.position.y = lerp(spring_arm.position.y, current_camera_height, stance_t)
  _apply_capsule_stance(capsule_factor)
  _apply_camera_bob_and_lean(delta)

func _apply_capsule_stance(factor: float) -> void:
  if not collision or not collision.shape:
    return
  var box := collision.shape as BoxShape3D
  if not box:
    return
  # Vertical extent lives on shape Z (node is rotated ~90 deg about X).
  if not has_meta("_capsule_base_size"):
    return
  var base_size: Vector3 = get_meta("_capsule_base_size")
  var base_y: float = float(get_meta("_capsule_base_y"))
  var bottom_y: float = base_y - base_size.z * 0.5
  var new_size := base_size
  new_size.z = base_size.z * factor
  box.size = new_size
  collision.position.y = bottom_y + new_size.z * 0.5

func _apply_camera_bob_and_lean(delta: float) -> void:
  if delta <= 0.0:
    return
  var planar := Vector3(velocity.x, 0.0, velocity.z).length()
  _bob_phase += delta * (4.0 + planar * 1.5)
  var bob_offset: float = sin(_bob_phase) * current_head_bobbing
  # Aim wobble: low stamina, pain and fractures add a hand tremor. The gun is
  # posed from the camera (ViewmodelRig) so shaking the camera shakes the aim.
  var tremor := _tremor_offset(delta)
  if camera and is_on_floor() and planar > 0.1:
    camera.position.y = bob_offset + tremor.y
  elif camera:
    camera.position.y = lerpf(camera.position.y, 0.0, 0.1) + tremor.y
  if camera:
    camera.position.x = tremor.x
  if spring_arm:
    # Auto-lean while strafing + roll for the leaning states. Roll is
    # secondary: it scales with the peek offset that actually got applied.
    var strafe: float = input.motion.x if input else 0.0
    var roll_target: float = -strafe * 0.03 - _lean_ratio() * LEAN_ROLL_MAX
    spring_arm.rotation.z = lerpf(spring_arm.rotation.z, roll_target,
      1.0 - exp(-LEAN_VISUAL_RATE * delta))
  _apply_lean_peek(delta)

func _lean_ratio() -> float:
  return clampf(_lean_peek / maxf(LEAN_PEEK_OFFSET, 0.001), -1.0, 1.0)

## Hand tremor from exhaustion, pain and fractures. Zero when healthy.
func _tremor_offset(delta: float) -> Vector2:
  if survival == null:
    return Vector2.ZERO
  var pain := 0.0
  var fracture := false
  var stability := 1.0
  if health != null:
    pain = health.effective_pain()
    fracture = health.has_fracture()
    stability = health.aim_stability()
  var amp := survival.wobble_amplitude(pain, fracture) * stability
  if amp <= 0.0001:
    return Vector2.ZERO
  _tremor_phase += delta * 7.5
  return Vector2(
    sin(_tremor_phase) * amp,
    sin(_tremor_phase * 1.7 + 1.3) * amp * 0.7)

func _lean_stance_scale() -> float:
  if not crouching:
    return 1.0
  match crouching.state:
    CROUCHING:
      return LEAN_STANCE_SCALE_CROUCH
    PRONING:
      return LEAN_STANCE_SCALE_PRONE
  return 1.0

## Leaning for real: translate the eye sideways (in body space, so the view
## axis is unchanged) and clamp it against walls so a corner peek cannot see
## through geometry. Physics query -> only ever called from _physics_process.
func _apply_lean_peek(delta: float) -> void:
  var peek_target := 0.0
  if _lean_dir != 0.0:
    # _lean_dir: +1 = left. Left is -X in the body frame.
    peek_target = -_lean_dir * LEAN_PEEK_OFFSET * _lean_stance_scale()
  var rate := 1.0 - exp(-LEAN_VISUAL_RATE * delta)
  _lean_peek = lerpf(_lean_peek, peek_target, rate)
  _lean_peek = _clamp_lean_peek(_lean_peek)
  if spring_arm:
    spring_arm.position.x = _lean_peek
  # Body follows the camera: tilt the mesh about the feet, so the shadow and
  # the third-person view do not stay upright while the eye moves out.
  if skeleton:
    var tilt := Basis(Vector3(0.0, 0.0, 1.0), -_lean_ratio() * LEAN_BODY_MAX)
    skeleton.transform = Transform3D(tilt * _skeleton_rest.basis,
      skeleton.transform.origin)

## Shorten the peek to the first wall in that direction, minus a body margin.
func _clamp_lean_peek(desired: float) -> float:
  if absf(desired) < 0.001 or spring_arm == null:
    return desired
  if not is_inside_tree() or get_world_3d() == null:
    return desired
  var sgn := signf(desired)
  # Neutral eye: the body origin lifted to the current eye height.
  var neutral: Vector3 = global_transform * Vector3(0.0, spring_arm.position.y, 0.0)
  var lateral: Vector3 = global_transform.basis.x * sgn
  var reach := absf(desired) + LEAN_PEEK_MARGIN
  var query := PhysicsRayQueryParameters3D.create(neutral, neutral + lateral * reach)
  query.exclude = [get_rid()]
  query.collide_with_areas = false
  var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
  if hit.is_empty():
    return desired
  var allowed := neutral.distance_to(hit.position) - LEAN_PEEK_MARGIN
  return sgn * clampf(allowed, 0.0, absf(desired))

func _handle_state_logic():
  # Handle sprint blocking when firing
  if moving and firing:
    if firing.state == TRIGGER_PULLED:
      Input.action_release("sprint")

func _apply_movement_and_physics(delta):
  # Apply movement
  velocity.x = current_direction.x * current_speed
  velocity.z = current_direction.z * current_speed

  move_and_slide()

  # Apply damping
  velocity.x *= 1 - exp(-current_damping * delta)
  velocity.z *= 1 - exp(-current_damping * delta)

  # Ground contact zeroes the fall velocity. The Moving SM's Falling->Stopped
  # transition owns the SINGLE landed.emit (see _on_state_exited); keep
  # max_velocity intact here so that emit reports the real impact speed — the
  # landing noise scales with it (QA-008).
  if moving and moving.state == FALLING and is_on_floor():
    velocity.y = 0

# ─── STATE HANDLERS ────────────────────────────────────────────────────────────
func _on_state_entered(state: String, state_machine_name: String):
  print("State entered: ", state_machine_name, " -> ", state)

  match state_machine_name:
    "Crouching":
      match state:
        CROUCHING:
          crouched.emit(self, false)
        PRONING:
          proned.emit(self, false)

    "Aiming":
      match state:
        AIMING:
          aimed.emit(self, false)
        FOCUSING:
          if focus_timer and focus_timer.is_stopped():
            focused.emit(self, false)
            focus_timer.start()

    "Firing":
      if not current_weapon:
        return
      if moving:
        moving.set_condition("can_sprint", false)

      match state:
        TRIGGER_PULLED:
          if current_hands is Weapon3D:
            current_hands.pull_trigger()
        TRIGGER_RELEASED:
          if current_hands is Weapon3D:
            current_hands.release_trigger()
        CHANGING_MODE:
          if firemode_timer and firemode_timer.is_stopped():
            firemode_timer.start()
        RELOADING:
          if reload_timer:
            reload_timer.wait_time = current_weapon.reload_time
            if reload_timer.is_stopped():
              reload_timer.start()
          reloaded.emit(self)

    "Moving":
      match state:
        JUMPING:
          # Cost is charged here; the input gate denies the transition when
          # the pool cannot pay for it (survival.can_jump).
          if survival != null:
            survival.spend_jump()
          velocity.y += config.default_jump_impulse
          jumped.emit(self)

    "Leaning":
      match state:
        LEANING_RIGHT:
          leaned.emit(self, -1)
        LEANING_LEFT:
          leaned.emit(self, 1)
        NOT_LEANING:
          leaned.emit(self, 0)

func _on_state_exited(state: String, state_machine_name: String):
  print("State exited: ", state_machine_name, " -> ", state)

  match state_machine_name:
    "Crouching":
      match state:
        CROUCHING:
          crouched.emit(self, true)
        PRONING:
          proned.emit(self, true)

    "Aiming":
      match state:
        FOCUSING:
          focused.emit(self, true)
          if focus_timer:
            focus_timer.stop()

    "Firing":
      match state:
        CHANGING_MODE:
          if current_weapon and firemode_timer:
            if firemode_timer.time_left != 0:
              WeaponSystem.cycle_firemode(current_weapon)
            firemode_timer.stop()
        RELOADING:
          if current_weapon and reload_timer:
            if reload_timer.time_left != 0:
              check_ammo_feed.emit(self, current_weapon.ammo_feed)
            reload_timer.stop()

    "Moving":
      match state:
        FALLING:
          landed.emit(self, max_velocity, get_process_delta_time())
          velocity.y = 0
          max_velocity = 0

func _on_state_changed(new_state: String, old_state: String, state_machine_name: String):
  if state_machine_name == "Aiming":
    match [old_state, new_state]:
      [AIMING, IDLE]:
        aimed.emit(self, true)
      [ _, BARE_HANDED ]:
        if old_state != "" and current_hands:
          current_hands.throw(-global_basis.z.normalized())
          current_hands.top_level = true
          current_hands = null

# ─── TIMER HANDLERS ────────────────────────────────────────────────────────────
func _on_firemode_timeout():
  # A firemode timer can still be running when the weapon is unequipped
  # (current_weapon is set null) -> guard the deref (QA-015).
  if current_weapon == null:
    return
  current_weapon.safe_firemode()

func _on_reload_timeout():
  insert_ammo_feed.emit(self)

func _on_focus_timeout():
  pass

# ─── PUBLIC METHODS ────────────────────────────────────────────────────────────
func get_camera_basis() -> Basis:
  if camera:
    return camera.global_transform.basis
  return Basis()

func get_head_position() -> Vector3:
  if head:
    return head.global_position
  return global_position

func get_look_direction() -> Vector3:
  if camera:
    return -camera.global_transform.basis.z
  return -global_transform.basis.z

# Cleanup
func _exit_tree():
  if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# res://addons/cabra.lat_shooters/test/validate_inventory_ux.gd
#
# Headless harness for the tetris-inventory UX LOGIC: rotation, swap, stacking,
# container nesting, quick-move (equip inference), weight / free-space feedback.
# The UI is driven by these core calls, so covering them here keeps the visual
# layer honest without a GPU.
#
# Run:
#   godot --headless --path . --script res://addons/cabra.lat_shooters/test/validate_inventory_ux.gd
#
# Exit code: 0 = all checks pass, 1 = at least one failure.
extends SceneTree

const AMMO_PATH := "res://resources/ammo/7_62_39mm_PS_GOST_BR4.tres"
const WEAPON_PATH := "res://resources/weapons/M4_Carbine.tres"

var _pass := 0
var _fail := 0
var _fail_lines: Array[String] = []

func _initialize() -> void:
	_run()
	print("")
	print("=== validate_inventory_ux summary ===")
	print("  checks passed  %d" % _pass)
	print("  FAILURES       %d" % _fail)
	if _fail > 0:
		for line in _fail_lines:
			print("  FAIL  " + line)
		print("RESULT: FAIL")
		quit(1)
	else:
		print("RESULT: PASS")
		quit(0)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		_fail_lines.append(msg)
		print("  FAIL  " + msg)

func _run() -> void:
	print("=== validate_inventory_ux: tetris inventory logic ===")
	_check_rotation_in_place()
	_check_rotation_relocate()
	_check_rotation_fail()
	_check_rotation_square_noop()
	_check_swap_equal()
	_check_swap_rollback()
	_check_stacking()
	_check_stacking_uses_wrapped_identity()
	_check_nesting_mass()
	_check_wrapper_mass_gate()
	_check_free_space()
	_check_quick_equip_core()
	_check_tooltip()
	_check_nested_container_branch()
	_check_generated_icons_wired()

# ─── FIXTURES ───────────────────────────────────────
func _container(w: int, h: int, max_weight: float = 1000.0) -> InventoryContainer:
	var c := InventoryContainer.new()
	c.grid_width = w
	c.grid_height = h
	c.max_weight = max_weight
	return c

func _item(dims: Vector2i, extra: Item = null, mass: float = 0.0) -> InventoryItem:
	var it := InventoryItem.new()
	it.dimensions = dims
	it.extra = extra
	it.mass = mass
	return it

# ─── ROTATION ───────────────────────────────────────
func _check_rotation_in_place() -> void:
	var c := _container(6, 6)
	var a := _item(Vector2i(3, 1))
	_check(c.add_item(a, Vector2i(0, 0)), "rotation: add 3x1")
	var free_before := c.get_free_space()
	_check(c.rotate_item(a), "rotation in place succeeds")
	_check(a.dimensions == Vector2i(1, 3), "rotation swaps dimensions (1x3)")
	_check(a.position == Vector2i(0, 0), "rotation keeps position when it fits")
	_check(c.get_free_space() == free_before, "rotation preserves occupied area")
	_check(c.get_item_at(Vector2i(0, 2)) == a, "rotated footprint occupies (0,2)")
	_check(c.get_item_at(Vector2i(1, 0)) == null, "old footprint cell (1,0) is free")

func _check_rotation_relocate() -> void:
	var c := _container(3, 3)
	var a := _item(Vector2i(3, 1))
	var b := _item(Vector2i(1, 1))
	_check(c.add_item(a, Vector2i(0, 0)), "relocate: add 3x1 at (0,0)")
	_check(c.add_item(b, Vector2i(0, 1)), "relocate: add blocker at (0,1)")
	_check(c.rotate_item(a), "rotation relocates when blocked in place")
	_check(a.dimensions == Vector2i(1, 3), "relocated item is 1x3")
	_check(a.position == Vector2i(1, 0), "relocated to first free 1x3 column")
	_check(c.get_item_at(Vector2i(0, 1)) == b, "blocker untouched by relocation")

func _check_rotation_fail() -> void:
	var c := _container(3, 1)
	var a := _item(Vector2i(3, 1))
	_check(c.add_item(a, Vector2i(0, 0)), "fail: add 3x1")
	_check(not c.rotate_item(a), "rotation fails when 1x3 cannot fit")
	_check(a.dimensions == Vector2i(3, 1), "failed rotation leaves dimensions")
	_check(a.position == Vector2i(0, 0), "failed rotation leaves position")

func _check_rotation_square_noop() -> void:
	var c := _container(4, 4)
	var a := _item(Vector2i(2, 2))
	_check(c.add_item(a, Vector2i(0, 0)), "square: add 2x2")
	_check(not c.rotate_item(a), "square rotation is a no-op (returns false)")
	_check(a.dimensions == Vector2i(2, 2), "square dimensions unchanged")

# ─── SWAP ───────────────────────────────────────────
func _check_swap_equal() -> void:
	var c := _container(4, 1)
	var a := _item(Vector2i(1, 1))
	var b := _item(Vector2i(1, 1))
	c.add_item(a, Vector2i(0, 0))
	c.add_item(b, Vector2i(2, 0))
	_check(c.swap_items(a, b), "swap equal-size succeeds")
	_check(a.position == Vector2i(2, 0), "swap moved A to B's cell")
	_check(b.position == Vector2i(0, 0), "swap moved B to A's cell")
	_check(c.get_item_at(Vector2i(0, 0)) == b, "occupancy follows the swap (A cell)")
	_check(c.get_item_at(Vector2i(2, 0)) == a, "occupancy follows the swap (B cell)")

func _check_swap_rollback() -> void:
	var c := _container(3, 1)
	var a := _item(Vector2i(2, 1))
	var b := _item(Vector2i(1, 1))
	c.add_item(a, Vector2i(0, 0))
	c.add_item(b, Vector2i(2, 0))
	_check(not c.swap_items(a, b), "swap fails when A cannot fit B's cell")
	_check(a.position == Vector2i(0, 0), "failed swap leaves A in place")
	_check(b.position == Vector2i(2, 0), "failed swap leaves B in place")
	_check(c.get_item_at(Vector2i(0, 0)) == a and c.get_item_at(Vector2i(1, 0)) == a,
		"failed swap restores A's full footprint")
	_check(c.get_item_at(Vector2i(2, 0)) == b, "failed swap restores B")

# ─── STACKING ───────────────────────────────────────
func _check_stacking() -> void:
	var c := _container(5, 5)
	var ammo: Ammo = load(AMMO_PATH)
	var a := _item(Vector2i(1, 1), ammo)
	a.max_stack = 30
	a.stack_count = 10
	var b := _item(Vector2i(1, 1), ammo)
	b.max_stack = 30
	b.stack_count = 15
	_check(c.add_item(a, Vector2i(0, 0)), "stack: add first stack (10)")
	_check(c.add_item(b, Vector2i(1, 0)), "stack: add second stack (15)")
	_check(c.items.size() == 1, "stack: merged into one grid slot")
	_check(a.stack_count == 25, "stack: counts summed to 25")

	var room_container := _container(5, 5)
	var ammo_over: Ammo = load(AMMO_PATH)
	var big := _item(Vector2i(1, 1), ammo_over)
	big.max_stack = 100
	big.stack_count = 50
	var small := _item(Vector2i(1, 1), ammo_over)
	small.max_stack = 100
	small.stack_count = 80
	room_container.add_item(big, Vector2i(3, 0))
	room_container.add_item(small, Vector2i(3, 1))
	_check(big.stack_count == 100, "stack: fills to max_stack (100)")
	_check(room_container.items.size() == 2, "stack: overflow remainder keeps a second slot")
	_check(small.stack_count == 30, "stack: overflow remainder is 30")

func _check_stacking_uses_wrapped_identity() -> void:
	# Two DIFFERENT wrapped resources must never merge just because both are
	# wrappers with an empty resource_path (the old bug: can_stack_with compared
	# the wrapper's own path, which is always "").
	var c := _container(5, 5)
	var x := _item(Vector2i(1, 1), load(AMMO_PATH))
	x.max_stack = 30
	x.stack_count = 5
	var other: Ammo = load("res://resources/ammo/5_56_45mm_SS109_VPAM_PM7.tres")
	var y := _item(Vector2i(1, 1), other)
	y.max_stack = 30
	y.stack_count = 5
	_check(not x.can_stack_with(y), "stack identity: different ammo does not stack")
	c.add_item(x, Vector2i(0, 0))
	c.add_item(y, Vector2i(1, 0))
	_check(c.items.size() == 2, "stack identity: both ammo slots kept")

# ─── NESTING / MASS ─────────────────────────────────
func _check_nesting_mass() -> void:
	var pack := Backpack.new()
	pack.name = "TestPack"
	pack.grid_width = 4
	pack.grid_height = 4
	var lead := _item(Vector2i(1, 1), null, 2.5)
	_check(pack.add_item(lead, Vector2i(0, 0)), "nesting: add 2.5kg into the pack")
	var pack_item := _item(Vector2i(2, 2), pack)
	var stash := _container(10, 10)
	_check(stash.add_item(pack_item, Vector2i(0, 0)), "nesting: pack into the stash")
	_check(absf(pack.get_total_mass() - 2.5) < 0.001, "nesting: pack mass = contents (2.5)")
	# The wrapper must surface the nested mass, not its own (0) `mass`.
	_check(absf(stash.get_total_mass() - 2.5) < 0.001, "nesting: stash total includes nested mass")

func _check_wrapper_mass_gate() -> void:
	# QA-005 guard: a wrapper does not copy `mass`, so a naive `item.mass` reads 0
	# and the weight gate goes blind. get_mass() must read the wrapped weapon.
	var weapon: Weapon = load(WEAPON_PATH)
	var wrapped := _item(Vector2i(3, 2), weapon)
	_check(wrapped.get_mass() > 0.5, "mass: wrapper reports the wrapped weapon mass")
	var c := _container(10, 10, 1.0)  # cap below one rifle
	_check(not c.can_add_item(wrapped), "mass gate: over-weight item rejected")
	_check(absf(c.total_weight) < 0.0001, "mass gate: empty container weighs 0")

# ─── FREE SPACE ─────────────────────────────────────
func _check_free_space() -> void:
	var c := _container(4, 4)
	_check(c.get_free_space() == 16, "free space: empty grid is 16")
	var a := _item(Vector2i(2, 3))
	c.add_item(a, Vector2i(0, 0))
	_check(c.get_free_space() == 10, "free space: after 2x3 = 10")
	c.remove_item(a)
	_check(c.get_free_space() == 16, "free space: restored after removal")

# ─── QUICK-EQUIP (core) ─────────────────────────────
func _check_quick_equip_core() -> void:
	var equipment := Equipment.new()
	var weapon: Weapon = load(WEAPON_PATH)
	var wrapped := _item(Vector2i(3, 2), weapon)
	var ok := InventorySystem.transfer_item(null, equipment, wrapped)
	_check(ok, "quick-move: weapon transfers into equipment")
	_check(not equipment.get_equipped("primary").is_empty(), "quick-move: landed in primary slot")
	_check(equipment.get_total_mass() > 0.5, "quick-move: equipment total mass is real")

# ─── TOOLTIP / NESTING BRANCH ───────────────────────
func _check_tooltip() -> void:
	var wrapped := _item(Vector2i(2, 3), load(AMMO_PATH))
	wrapped.name = "Test round"
	var text := InventoryTooltip.text_for(wrapped)
	_check(text.contains("Test round"), "tooltip: shows the name")
	_check(text.contains("2x3"), "tooltip: shows the footprint")
	_check(text.contains("Mass"), "tooltip: shows mass")

func _check_nested_container_branch() -> void:
	# The double-click handler branches on `item.extra is InventoryContainer`.
	var pack := Backpack.new()
	var pack_item := _item(Vector2i(2, 2), pack)
	_check(pack_item.extra is InventoryContainer, "nesting: pack item is an openable container")
	var weapon: Weapon = load(WEAPON_PATH)
	var gun_item := _item(Vector2i(3, 2), weapon)
	_check(not (gun_item.extra is InventoryContainer), "nesting: a weapon is not a container")

## Every item the icon generator rendered must actually point at its PNG. This
## catches the failure mode where the generator runs but the .tres is never
## re-wired (or the wire silently dropped the property).
func _check_generated_icons_wired() -> void:
	const MANIFEST := "res://assets/ui/inventory/generated/manifest.json"
	if not FileAccess.file_exists(MANIFEST):
		_check(false, "icons: manifest missing (run tools/generate_inventory_icons.gd)")
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not (data is Dictionary) or not data.has("items"):
		_check(false, "icons: manifest malformed")
		return
	var items: Dictionary = data["items"]
	var checked := 0
	var wrong := 0
	for res_path in items.keys():
		var expected: String = items[res_path]
		var res = load(res_path)
		if res == null or not (res is Item):
			wrong += 1
			continue
		if res.icon == null or res.icon.resource_path != expected:
			wrong += 1
			print("  icon not wired: %s -> %s" % [res_path, res.icon.resource_path if res.icon else "NULL"])
		checked += 1
	_check(checked > 0, "icons: manifest lists items")
	_check(wrong == 0, "icons: every rendered item points at its generated PNG (%d checked)" % checked)
	# Ballistics 2026-09-21: the Godot logo (Item.icon default) must not ship on
	# items we can cover, so every collected item must have a real icon or a
	# DOCUMENTED placeholder now.
	var missing: Array = data.get("missing_model", [])
	_check(missing.is_empty(), "icons: no item left without an icon (%d missing)" % missing.size())
	_check(data.get("placeholders", {}) is Dictionary, "icons: placeholder map present")
	_check(data.get("real_model", []) is Array, "icons: real-model list present")

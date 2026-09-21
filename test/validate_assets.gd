# res://addons/cabra.lat_shooters/test/validate_assets.gd
#
# FORMAL, reusable asset validator (replaces the throwaway *_tmp.gd harnesses for
# asset integrity). Headless, editor-independent, CI gate.
#
# Run:
#   godot --headless --path . --script res://addons/cabra.lat_shooters/test/validate_assets.gd
#
# Exit code: 0 = all hard checks pass, 1 = at least one hard failure.
# Hard failures: asset missing / fails to load / required field null / dead or
# stale script uid. Warnings (non-fatal): content gaps such as a weapon whose
# declared calibers match no ammo asset in the project.
extends SceneTree

const AMMO_DIR := "res://resources/ammo"
const WEAPON_DIR := "res://resources/weapons"
const ARMOR_DIR := "res://resources/armor"
const ATTACH_DIR := "res://resources/attachments"
const MAG_DIR := "res://resources/magazines"
const VIEWMODEL_DIR := "res://src/weapons"

var _pass := 0
var _fail_count := 0
var _warn_count := 0
var _fail_lines: Array[String] = []
var _warn_lines: Array[String] = []
var _counts: Dictionary = {}

func _fail(msg: String) -> void:
	_fail_count += 1
	_fail_lines.append(msg)
	print("  FAIL  " + msg)

func _warn(msg: String) -> void:
	_warn_count += 1
	_warn_lines.append(msg)
	print("  warn  " + msg)

func _pass_check() -> void:
	_pass += 1

func _initialize() -> void:
	print("=== validate_assets: scanning project assets ===")

	_scan_dead_script_uids("res://resources", [".tres"])
	_scan_dead_script_uids(VIEWMODEL_DIR, [".tscn", ".tres"])

	var ammos := _validate_ammo()
	_validate_weapons(ammos)
	_validate_armor()
	_validate_attachments()
	_validate_magazines()
	_validate_viewmodels()

	print("")
	print("=== validate_assets summary ===")
	for k in _counts.keys():
		print("  %-14s %d" % [k, _counts[k]])
	print("  checks passed  %d" % _pass)
	print("  FAILURES       %d" % _fail_count)
	print("  warnings       %d" % _warn_count)
	if _fail_count > 0:
		print("RESULT: FAIL")
		quit(1)
	else:
		print("RESULT: PASS")
		quit(0)

# ─── DIRECTORY HELPERS ──────────────────────────────
func _walk(dir: String, exts: Array) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		for e in exts:
			if f.ends_with(e):
				out.append(dir + "/" + f)
				break
	for sub in d.get_directories():
		out.append_array(_walk(dir + "/" + sub, exts))
	out.sort()
	return out

# ─── DEAD / STALE SCRIPT UID SCAN ───────────────────
func _scan_dead_script_uids(root: String, exts: Array) -> void:
	var re := RegEx.new()
	re.compile('ext_resource type="Script" uid="(uid://[^"]+)" path="(res://[^"]+)"')
	for path in _walk(root, exts):
		var text := FileAccess.get_file_as_string(path)
		for m in re.search_all(text):
			var uid := m.get_string(1)
			var target := m.get_string(2)
			if not FileAccess.file_exists(target):
				_fail("dead script path in %s -> %s" % [path, target])
			else:
				var uid_file := target + ".uid"
				if FileAccess.file_exists(uid_file):
					var live := FileAccess.get_file_as_string(uid_file).strip_edges()
					if live != uid:
						_fail("stale script uid in %s -> %s (resource %s, file %s)" % [path, target, uid, live])
				else:
					_warn("script has no .uid file: %s (from %s)" % [target, path])

# ─── AMMO ───────────────────────────────────────────
func _validate_ammo() -> Array:
	var out: Array = []
	var files := _walk(AMMO_DIR, [".tres"])
	for p in files:
		var a = load(p)
		if a == null:
			_fail("ammo does not load: " + p)
			continue
		if not (a is Ammo):
			_fail("not an Ammo: " + p)
			continue
		if String(a.caliber).strip_edges() == "":
			_fail("ammo caliber empty: " + p)
		if a.muzzle_velocity <= 0.0:
			_fail("ammo muzzle_velocity<=0: " + p)
		if a.bullet_mass <= 0.0:
			_fail("ammo bullet_mass<=0: " + p)
		if a.reference_penetration <= 0.0:
			_fail("ammo reference_penetration<=0: " + p)
		if a.penetration_at_500m < 0.0:
			_fail("ammo penetration_at_500m<0: " + p)
		if a.sectional_density == INF or is_nan(a.sectional_density):
			if a.bullet_diameter <= 0.0 and ("FSP" in a.caliber or a.type == Ammo.Type.FSP):
				_warn("FSP sectional_density non-finite by design (diameter 0): " + p)
			else:
				_fail("ammo sectional_density not finite: " + p)
		if a.bullet_diameter <= 0.0 and not ("FSP" in a.caliber or a.type == Ammo.Type.FSP):
			_fail("ammo bullet_diameter<=0 (non-FSP): " + p)
		if a.projectile_count < 1:
			_fail("ammo projectile_count<1: " + p)
		if a.projectile_count > 1 and a.base_damage <= 0.0:
			_fail("multi-projectile ammo needs base_damage>0: " + p)
		if a.light_bleed_chance < 0.0 or a.light_bleed_chance > 1.0 \
				or a.heavy_bleed_chance < 0.0 or a.heavy_bleed_chance > 1.0:
			_fail("ammo bleed chance out of [0,1]: " + p)
		if int(a.feed_failure) < 0 or int(a.feed_failure) > int(Ammo.Rating.VERY_HIGH) \
				or int(a.misfire) < 0 or int(a.misfire) > int(Ammo.Rating.VERY_HIGH):
			_fail("ammo feed_failure/misfire rating out of range: " + p)
		if a.durability_burn < 0.0 or a.heat < 0.0:
			_fail("ammo durability_burn/heat negative: " + p)
		_pass_check()
		out.append(a)
	_counts["ammo"] = files.size()
	return out

# ─── WEAPONS ────────────────────────────────────────
func _validate_weapons(ammos: Array) -> void:
	var files := _walk(WEAPON_DIR, [".tres"])
	for p in files:
		var w = load(p)
		if w == null:
			_fail("weapon does not load: " + p)
			continue
		if not (w is Weapon):
			_fail("not a Weapon: " + p)
			continue
		if String(w.name).strip_edges() == "" or w.name == "Item":
			_fail("weapon has no name: " + p)
		if w.firemodes == 0:
			_fail("weapon firemodes==0: " + p)
		if w.max_durability <= 0.0:
			_fail("weapon max_durability<=0: " + p)
		if w.base_ergonomics <= 0.0:
			_fail("weapon base_ergonomics<=0: " + p)
		if w.cleaning_time <= 0.0:
			_fail("weapon cleaning_time<=0: " + p)
		if w.durability_wear_per_shot < 0.0:
			_fail("weapon durability_wear_per_shot<0: " + p)
		if w.base_stovepipe_chance < 0.0 or w.base_stovepipe_chance > 1.0:
			_fail("weapon base_stovepipe_chance out of [0,1]: " + p)
		if w.repair_loss_ratio <= 0.0 or w.repair_loss_ratio >= 1.0:
			_fail("weapon repair_loss_ratio out of (0,1): " + p)
		if w.ammo_feed == null:
			_fail("weapon ammo_feed null: " + p)
		else:
			if w.ammo_feed.max_capacity <= 0:
				_fail("weapon feed max_capacity<=0: " + p)
			var declared: PackedStringArray = w.ammo_feed.compatible_calibers
			if declared.is_empty():
				_warn("weapon feed declares no calibers (unverifiable): " + p)
			else:
				var matched := false
				for a in ammos:
					if w.ammo_feed.is_compatible(a):
						matched = true
						break
				if not matched:
					_warn("weapon declares %s but no ammo asset matches: %s" % [declared, p])
		_pass_check()
	_counts["weapons"] = files.size()

# ─── ARMOR ──────────────────────────────────────────
func _validate_armor() -> void:
	var files := _walk(ARMOR_DIR, [".tres"])
	for p in files:
		var a = load(p)
		if a == null:
			_fail("armor does not load: " + p)
			continue
		if not (a is Armor):
			_fail("not an Armor: " + p)
			continue
		if a.material == null:
			_fail("armor material null: " + p)
		elif a.material is BallisticMaterial:
			if a.material.penetration_resistance <= 0.0:
				_fail("armor material penetration_resistance<=0: " + p)
			if a.material.destructibility <= 0.0 or a.material.destructibility > 1.0:
				_fail("armor destructibility out of (0,1]: " + p)
		if a.level < 1:
			_fail("armor level<1: " + p)
		for plate in [a.front_plate, a.back_plate]:
			if plate != null:
				if plate.material == null:
					_fail("armor plate material null: " + p)
				if plate.level < 1:
					_fail("armor plate level<1: " + p)
				if plate.max_durability <= 0:
					_fail("armor plate max_durability<=0: " + p)
		if a.type == Armor.ArmorType.HELMET and a.ricochet_angle_max <= a.ricochet_angle_min:
			_fail("helmet ricochet window invalid: " + p)
		_pass_check()
	_counts["armor"] = files.size()

# ─── ATTACHMENTS ────────────────────────────────────
func _validate_attachments() -> void:
	var files := _walk(ATTACH_DIR, [".tres"])
	for p in files:
		var a = load(p)
		if a == null:
			_fail("attachment does not load: " + p)
			continue
		if not (a is Attachment):
			_fail("not an Attachment: " + p)
			continue
		if String(a.name).strip_edges() == "" or a.name == "Item":
			_fail("attachment has no name: " + p)
		if a.attachment_point == 0 and a.type != Attachment.AttachmentType.MAGAZINE and a.type != Attachment.AttachmentType.OTHER:
			_fail("attachment attachment_point==0: " + p)
		if a.type == Attachment.AttachmentType.OPTICS and a.magnification <= 0.0:
			_fail("optic magnification<=0: " + p)
		_pass_check()
	_counts["attachments"] = files.size()

# ─── MAGAZINES / FEEDS ──────────────────────────────
func _validate_magazines() -> void:
	var files := _walk(MAG_DIR, [".tres"])
	for p in files:
		var m = load(p)
		if m == null:
			_fail("magazine does not load: " + p)
			continue
		if not (m is AmmoFeed):
			_fail("not an AmmoFeed: " + p)
			continue
		if m.max_capacity <= 0:
			_fail("magazine max_capacity<=0: " + p)
		_pass_check()
	_counts["magazines"] = files.size()

# ─── VIEWMODEL SCENES ───────────────────────────────
func _validate_viewmodels() -> void:
	var files := _walk(VIEWMODEL_DIR, [".tscn"])
	for p in files:
		var s = load(p)
		if s == null:
			_fail("viewmodel scene does not load: " + p)
			continue
		if not (s is PackedScene):
			_fail("viewmodel is not a PackedScene: " + p)
			continue
		_pass_check()
	_counts["viewmodels"] = files.size()

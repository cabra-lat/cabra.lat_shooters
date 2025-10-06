class_name WeaponNode
extends Node3D

const VIEWMODEL_NAME = "Viewmodel"

@onready var ak47_magazine = preload("../resources/magazine_ak47.tres")
@onready var ammo_762x39mm = preload("../resources/ammo_7.62x39mm.tres")

var firerate_timer: Timer

var _data: Weapon
@export var data: Weapon:
	get: return self._data
	set(value):
		var old_vm = get_node_or_null(VIEWMODEL_NAME)
		if old_vm: old_vm.queue_free()
		if value.viewmodel:
			var new_vm = value.viewmodel.instantiate()
			add_child(new_vm)
		for signal_name in value.SIGNALS:
			value.connect(signal_name, Callable(self, "_on_" + signal_name))
		self._data = value
		

func _ready():
	firerate_timer = Timer.new()
	firerate_timer.one_shot = true
	firerate_timer.connect("timeout", Callable(self,"_on_firerate_timeout"))
	add_child(firerate_timer)

func _on_firerate_timeout():
	data.pull_trigger()
	if data.is_automatic():
		firerate_timer.start()

# ─── WEAPON CONTROL ───────────────────────────────

func pull_trigger():
	# Only start timer if weapon is ready to fire
	if not firerate_timer.is_stopped():
		return
	if not data: return
	firerate_timer.wait_time = 60.0 / data.firerate
	data.pull_trigger()
	firerate_timer.start()

func release_trigger():
	firerate_timer.stop()
	if not data: return
	data.release_trigger()

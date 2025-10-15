class_name WeaponNode
extends Node3D

const VIEWMODEL_NAME = "Viewmodel"

var firerate_timer: Timer

var _data: Weapon
@export var data: Weapon:
	get: return self._data
	set(value):
		var old_vm = get_node_or_null(VIEWMODEL_NAME)
		if old_vm: old_vm.queue_free()
		if value.view_model:
			var new_vm = value.view_model.instantiate()
			add_child(new_vm)
		for sig in  value.get_signal_list():
			value.connect(sig.name, Callable(self, "_on_" + sig.name))
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

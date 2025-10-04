class_name WeaponNode
extends Node

@onready var ak47_magazine  = preload("../resources/magazine_ak47.tres")
@onready var ammo_762x39mm  = preload("../resources/ammo_7.62x39mm.tres")

@export var weapon: Weapon
var firerate_cooldown
var reload_cooldown

func _on_trigger_locked():
	print("[can't pull the trigger]")
	firerate_cooldown.stop()
func _on_trigger_pressed(ejected):
	for chambered in ejected:
		print("Pow! ", chambered.caliber)
func _on_trigger_released():
	pass
func _on_firemode_changed(new):
	print("changed firemode: %s" % new)
func _on_ammofeed_empty():
	print("Click!")
	firerate_cooldown.stop()
func _on_ammofeed_missing():
	print('Click!')
	firerate_cooldown.stop()
func _on_ammofeed_changed(old, new):
	print("changed mag %d/%d to %d/%d"
		 % [old.remaining()  if old else 0,
			old.max_capacity if old else 0,
			new.remaining(),
			new.max_capacity])
func _on_ammofeed_incompatible():
	print("- This doesn't fit here")

func _ready():
	firerate_cooldown = Utils.create_timer(60 / weapon.firerate)
	firerate_cooldown.connect("timeout", Callable(weapon, "pull_trigger"))
	add_child(firerate_cooldown)
	reload_cooldown = Utils.create_timer(1.0)
	#reload_cooldown.connect("timeout",)
	add_child(reload_cooldown)
	weapon.connect("trigger_locked", Callable(self, "_on_trigger_locked"))
	weapon.connect("trigger_pressed", Callable(self, "_on_trigger_pressed"))
	weapon.connect("trigger_released", Callable(self, "_on_trigger_released"))
	weapon.connect("firemode_changed", Callable(self, "_on_firemode_changed"))
	weapon.connect("ammofeed_empty", Callable(self, "_on_ammofeed_empty"))
	weapon.connect("ammofeed_changed", Callable(self, "_on_ammofeed_changed"))
	weapon.connect("ammofeed_missing", Callable(self, "_on_ammofeed_missing"))
	weapon.connect("ammofeed_incompatible", Callable(self, "_on_ammofeed_incompatible"))
	add_child(weapon.viewmodel.instantiate())
	
	for i in range(ak47_magazine.max_capacity):
		ak47_magazine.insert(ammo_762x39mm)

func _input(event):
	if Input.is_action_just_pressed("reload"):
		weapon.change_magazine(ak47_magazine)
	
	if Input.is_action_just_pressed("firemode"):
		weapon.cycle_firemode()
	
	if Input.is_action_just_pressed("fire"):
		firerate_cooldown.start()
	
	if Input.is_action_just_released("fire"):
		firerate_cooldown.stop()

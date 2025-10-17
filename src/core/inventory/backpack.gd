# res://src/core/inventory/backpack.gd (UPDATED)
class_name Backpack
extends InventoryContainer

#@export var owner: PlayerController  # optional reference

func _init():
  name = "Backpack"
  grid_width = 6
  grid_height = 10
  max_weight = 25.0
  print("DEBUG: Initializing backpack with grid: ", grid_width, "x", grid_height)
  super._init()  # calls parent _init()

func get_quick_access_items() -> Array[InventoryItem]:
  return items.filter(func(i): return i.content is Weapon)

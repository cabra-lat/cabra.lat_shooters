class_name WorldFactory3D
extends Node3D

# Create item based on type and data
static func create_item(data: Resource = null, position: Vector3 = Vector3.ZERO) -> Item3D:
  var item_3d = null

  if data is Weapon:
    item_3d = Weapon3D.new()
    item_3d.data = data as Weapon
  if data is AmmoFeed:
    item_3d = Magazine3D.new()
    item_3d.data = data as AmmoFeed
  if data is Ammo:
    item_3d = Cartridge3D.new()
    item_3d.data = data as Ammo

  if item_3d:
    item_3d.position = position
    item_3d.rotate_y(randf() * PI * 2)

  return item_3d

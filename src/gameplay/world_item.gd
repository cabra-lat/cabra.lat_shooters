# res://src/gameplay/world_item.gd
class_name WorldItem
extends Node3D

# ─── SIGNALS ───────────────────────────────────────
signal item_picked_up(world_item: WorldItem, player: PlayerController)
signal item_dropped(world_item: WorldItem)

# ─── EXPORTED PROPERTIES ───────────────────────────
@export var inventory_item: InventoryItem:
  set(value):
    inventory_item = value
    _update_visuals()

@export var pickup_radius: float = 1.5  # meters
@export var auto_rotate: bool = true
@export var rotation_speed: float = 0.5

# ─── NODE REFERENCES ───────────────────────────────
@onready var mesh_instance: MeshInstance3D = %MeshInstance3D
@onready var collision_shape: CollisionShape3D = %CollisionShape3D
@onready var area: Area3D = %Area3D

# ─── STATE ─────────────────────────────────────────
var is_pickable: bool = true

# ─── INIT ──────────────────────────────────────────
func _ready():
  if not inventory_item:
    push_warning("WorldItem has no inventory_item!")
    return
  _setup_collision()
  _setup_area()
  _update_visuals()

# ─── PUBLIC METHODS ────────────────────────────────
func pick_up(player: PlayerController) -> bool:
  if not is_pickable or not inventory_item:
    return false
  if not player or not player.inventory_system:
    return false
  # Delegate to InventorySystem
  var success = player.inventory_system.transfer_item_from_world(player.backpack, self)
  if success:
    item_picked_up.emit(self, player)
    queue_free()
  return success

func drop_from_player(player: PlayerController, item: InventoryItem) -> void:
  inventory_item = item.duplicate(true)
  _update_visuals()
  item_dropped.emit(self)
  is_pickable = true

# ─── INTERNAL LOGIC ────────────────────────────────
func _setup_collision():
  if collision_shape and inventory_item:
    # Scale collision to item size (simplified)
    var size = Vector3(0.2, 0.2, 0.2)
    collision_shape.shape = BoxShape3D.new()
    collision_shape.shape.size = size

func _setup_area():
  if area:
    area.monitoring = true
    area.monitorable = false
    area.connect("area_entered", _on_area_entered)

func _update_visuals():
  if mesh_instance and inventory_item:
    # Use item's view_model if available
    if inventory_item.content and inventory_item.content.view_model:
      var instance = inventory_item.content.view_model.instantiate()
      mesh_instance.mesh = instance.mesh if instance is MeshInstance3D else null
    else:
      # Fallback: use a generic item mesh
      pass

func _on_area_entered(area: Area3D):
  # Optional: highlight item when player is near
  pass

func _process(delta: float):
  if auto_rotate and mesh_instance:
    mesh_instance.rotate_y(rotation_speed * delta)

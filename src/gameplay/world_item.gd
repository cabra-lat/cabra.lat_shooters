class_name WorldItem
extends Node3D

# ─── SIGNALS ───────────────────────────────────────
signal item_picked_up(world_item: WorldItem, player: PlayerController)
signal item_dropped(world_item: WorldItem)
signal item_hovered(world_item: WorldItem, player: PlayerController)
signal item_exited(world_item: WorldItem, player: PlayerController)

# ─── EXPORTED PROPERTIES ───────────────────────────
@export var inventory_item: InventoryItem:
    set(value):
        inventory_item = value
        _update_visuals()

@export var pickup_radius: float = 1.5  # meters
@export var auto_rotate: bool = true
@export var rotation_speed: float = 0.5
@export var bob_height: float = 0.2
@export var bob_speed: float = 2.0

# ─── NODE REFERENCES ───────────────────────────────
@onready var mesh_instance: MeshInstance3D = %MeshInstance3D
@onready var area: Area3D = %Area3D
@onready var highlight_area: Area3D = %HighlightArea
@export var outline_material: ShaderMaterial

# ─── STATE ─────────────────────────────────────────
var is_pickable: bool = true
var is_highlighted: bool = false
var original_y: float = 0.0
var bob_time: float = 0.0

# ─── INIT ──────────────────────────────────────────
func _ready():
    if not inventory_item:
        push_warning("WorldItem has no inventory_item!")
        return

    _setup_collision()
    _setup_area()
    _setup_highlight()
    _update_visuals()

    # Store original Y for bobbing animation
    original_y = global_position.y

func _setup_collision():
    if area.get_child(0) and inventory_item:
        var size = _calculate_collision_size()
        area.get_child(0).shape = BoxShape3D.new()
        area.get_child(0).shape.size = size

func _setup_area():
    area.monitoring = true
    area.monitorable = true

    # Set area size from config or default
    var area_shape = SphereShape3D.new()
    area_shape.radius = pickup_radius
    area.get_child(0).shape = area_shape

    # Connect signals
    if not area.body_entered.is_connected(_on_body_entered):
        area.body_entered.connect(_on_body_entered)
    if not area.body_exited.is_connected(_on_body_exited):
        area.body_exited.connect(_on_body_exited)

func _setup_highlight():
    var highlight_shape = SphereShape3D.new()
    highlight_shape.radius = 1.0
    highlight_area.get_child(0).shape = highlight_shape

    if not highlight_area.body_entered.is_connected(_on_highlight_body_entered):
        highlight_area.body_entered.connect(_on_highlight_body_entered)
    if not highlight_area.body_exited.is_connected(_on_highlight_body_exited):
        highlight_area.body_exited.connect(_on_highlight_body_exited)

# ─── PUBLIC METHODS ────────────────────────────────
func pick_up(player: PlayerController) -> bool:
    if not is_pickable or not inventory_item:
        return false
    if not player:
        return false

    # Find suitable container for the item
    var container = _find_suitable_container(player)
    if not container:
        return false

    # Ensure item has valid position before transfer
    if inventory_item.position.x < 0 or inventory_item.position.y < 0:
        inventory_item.position = Vector2i.ZERO

    # Use the refactored Inventory system
    var success = InventorySystem.transfer_item(null, container, inventory_item)
    if success:
        item_picked_up.emit(self, player)
        queue_free()

    return success

func drop_from_player(player: PlayerController, item: InventoryItem, position: Vector3 = Vector3.ZERO) -> void:
    inventory_item = item
    global_position = position
    _update_visuals()
    item_dropped.emit(self)
    is_pickable = true

    # Start bobbing animation
    bob_time = 0.0
    original_y = global_position.y

func set_highlighted(highlight: bool):
    if is_highlighted == highlight:
        return

    is_highlighted = highlight

    if outline_material:
        outline_material.set_shader_parameter("enabled", highlight)

    if highlight:
        # Scale up slightly when highlighted
        var tween = create_tween()
        tween.tween_property(self, "scale", Vector3(1.1, 1.1, 1.1), 0.1)
    else:
        var tween = create_tween()
        tween.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.1)

# ─── INTERNAL LOGIC ────────────────────────────────
func _calculate_collision_size() -> Vector3:
    if not inventory_item:
        return Vector3(0.5, 0.5, 0.5)

    # Calculate size based on item dimensions
    var base_size = 0.5
    var width = base_size * inventory_item.dimensions.x
    var height = base_size * inventory_item.dimensions.y
    var depth = base_size * max(inventory_item.dimensions.x, inventory_item.dimensions.y) * 0.5

    return Vector3(width, height, depth)

func _update_visuals():
    if not mesh_instance or not inventory_item:
        return

    # Clear existing meshes
    for child in mesh_instance.get_children():
        child.queue_free()

    # Use item's world_model if available
    if inventory_item.content and inventory_item.content.view_model:
        var instance = inventory_item.content.view_model.instantiate()
        mesh_instance.add_child(instance)

        # Apply rarity material if available
        _apply_rarity_material(instance)
    else:
        # Fallback: create a basic representation
        _create_fallback_visual()

func _apply_rarity_material(instance: Node3D):
    if not inventory_item:
        return

    var rarity = _get_item_rarity()
    if rarity != "common":
        var material = Material.new()
        # Apply to all MeshInstance3D children
        for child in instance.find_children("*", "MeshInstance3D"):
            var mesh_instance = child as MeshInstance3D
            if mesh_instance:
                mesh_instance.material_override = material

func _create_fallback_visual():
    var box_mesh = BoxMesh.new()
    box_mesh.size = _calculate_collision_size()

    var material = StandardMaterial3D.new()
    if inventory_item and inventory_item.content and inventory_item.content.icon:
        material.albedo_texture = inventory_item.content.icon
    else:
        material.albedo_color = Color(0.8, 0.8, 0.2)  # Yellow fallback

    mesh_instance.mesh = box_mesh
    mesh_instance.material_override = material

func _get_item_rarity() -> String:
    if not inventory_item or not inventory_item.content:
        return "common"
#
    #if inventory_item.content.has_method("get_rarity"):
        #return inventory_item.content.get_rarity()
    #elif inventory_item.content.has_property("rarity"):
        #return inventory_item.content.rarity

    return "common"

func _find_suitable_container(player: PlayerController) -> Resource:
    # Priority 1: Check equipped backpack
    var equipped_backpack = player.equipment.get_equipped("back")
    if not equipped_backpack.is_empty():
        var backpack_item = equipped_backpack[0]
        if backpack_item.content is Backpack:
            var backpack = backpack_item.content as Backpack
            return backpack

    # Priority 2: Check other accessible containers
    if player.has_method("find_accessible_container"):
        var container = player.find_accessible_container()
        if container and container.can_accept_item(inventory_item):
            return container

    # Priority 3: Check if player can equip directly
    if InventorySystem._is_compatible_with_target(inventory_item, player.equipment):
        return player.equipment

    return null

# ─── AREA HANDLERS ─────────────────────────────────
func _on_body_entered(body: Node3D):
    if body is PlayerController:
        var player = body as PlayerController
        pick_up(player)

func _on_body_exited(body: Node3D):
    if body is PlayerController:
        var player = body as PlayerController
        # Could show pickup prompt removal here

func _on_highlight_body_entered(body: Node3D):
    if body is PlayerController:
        var player = body as PlayerController
        set_highlighted(true)
        item_hovered.emit(self, player)

func _on_highlight_body_exited(body: Node3D):
    if body is PlayerController:
        var player = body as PlayerController
        set_highlighted(false)
        item_exited.emit(self, player)

# ─── ANIMATION ─────────────────────────────────────
func _process(delta: float):
    if auto_rotate and mesh_instance:
        mesh_instance.rotate_y(rotation_speed * delta)

    # Bobbing animation
    bob_time += delta
    var new_y = original_y + sin(bob_time * bob_speed) * bob_height
    global_position.y = new_y

# ─── INTERACTION METHODS ───────────────────────────
func get_interaction_prompt() -> String:
    if not inventory_item or not inventory_item.content:
        return "Unknown Item"

    var item_name = inventory_item.content.name
    var stack_text = ""

    if inventory_item.max_stack > 1:
        stack_text = " (%d)" % inventory_item.stack_count

    return "Pick up %s%s" % [item_name, stack_text]

func get_item_weight() -> float:
    if not inventory_item or not inventory_item.content:
        return 0.0

    return inventory_item.content.mass * inventory_item.stack_count

# ─── DEBUG METHODS ─────────────────────────────────
func _get_configuration_warnings() -> PackedStringArray:
    var warnings: PackedStringArray = []

    if not inventory_item:
        warnings.append("WorldItem has no inventory_item assigned")

    if not mesh_instance:
        warnings.append("Missing MeshInstance3D child node")

    if not area.get_child(0):
        warnings.append("Missing CollisionShape3D child node")

    if not area:
        warnings.append("Missing Area3D child node")

    return warnings

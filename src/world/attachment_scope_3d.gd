class_name AttachmentScope3D
extends Item3D

var viewport_texture: ViewportTexture
@onready var sub_viewport: SubViewport = $ScopeViewport
@onready var camera: Camera3D = $ScopeViewport/Camera3D

# Reference to the node that defines the camera position
@export var camera_position_node: Node3D = $CameraPosition

# Zoom settings
@export var min_fov: float = 1.0
@export var max_fov: float = 45.0
@export var default_fov: float = 5.0
@export var zoom_sensitivity: float = 2.0
@export var zoom_step: float = 1.0  # Discrete zoom steps if needed

var current_fov: float
var is_zooming: bool = true

func _ready():
    # Create the viewport and camera
    _create_viewport_and_camera()

    # Set up everything
    _setup_viewport()
    self.grab(self.attractors)

    # Initialize FOV
    current_fov = default_fov
    camera.fov = current_fov

    # Reconnect if scene changes
    get_tree().tree_changed.connect(_on_tree_changed)

func _create_viewport_and_camera():
    # Add camera to viewport
    camera.owner = sub_viewport

    # Add viewport to scope (as a direct child, not under MESH)
    sub_viewport.owner = self

func _on_tree_changed():
    _setup_viewport()

func _setup_viewport():
    # Set up the viewport
    sub_viewport.world_3d = get_tree().root.world_3d
    sub_viewport.own_world_3d = false
    camera.current = true

    # Position the camera to match the camera_position_node
    _update_camera_position()

    # Create and assign the ViewportTexture
    _setup_viewport_texture()

func _setup_viewport_texture():
    # Create ViewportTexture
    viewport_texture = ViewportTexture.new()
    viewport_texture.viewport_path = sub_viewport.get_path()

    # Apply to material
    var mesh_instance = $MESH
    if mesh_instance and mesh_instance.material_override:
        var material = mesh_instance.material_override.duplicate()
        mesh_instance.material_override = material

        if material is ShaderMaterial:
            material.set_shader_parameter("u_scope_texture", viewport_texture)
            print("ViewportTexture assigned to shader")

    # Force refresh
    sub_viewport.size = sub_viewport.size

func _update_camera_position():
    # If we have a specific camera position node, use its transform
    if camera_position_node:
        camera.global_transform = camera_position_node.global_transform
    else:
        # Fallback: position the camera at the scope's location
        # but slightly offset to avoid being inside geometry
        var offset = -global_transform.basis.z * 0.1  # 10cm forward
        camera.global_transform = global_transform.translated(offset)

# Call this whenever the scope moves to update the camera position
func update_scope_view():
    _update_camera_position()

    # Force the viewport to render
    sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
    await get_tree().process_frame
    sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

# Add to your AttachmentScope3D class
var last_global_transform: Transform3D

func _process(delta):
    # Check if the scope has moved significantly
    if global_transform != last_global_transform:
        _update_camera_position()
        last_global_transform = global_transform

        # Optionally force a render if moving fast
        if global_transform.origin.distance_to(last_global_transform.origin) > 0.01:
            sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

# Handle mouse wheel input for zooming
func _input(event):
    if event is InputEventMouseButton and is_zooming:
        if event.pressed:
            match event.button_index:
                MOUSE_BUTTON_WHEEL_UP:
                    # Zoom in (decrease FOV)
                    current_fov = clamp(current_fov - zoom_step, min_fov, max_fov)
                    camera.fov = current_fov
                    print("Zoomed in: FOV = ", current_fov)

                MOUSE_BUTTON_WHEEL_DOWN:
                    # Zoom out (increase FOV)
                    current_fov = clamp(current_fov + zoom_step, min_fov, max_fov)
                    camera.fov = current_fov
                    print("Zoomed out: FOV = ", current_fov)

# Public methods to control zoom state
func start_zooming():
    is_zooming = true
    print("Zoom control enabled")

func stop_zooming():
    is_zooming = false
    print("Zoom control disabled")

# Set specific FOV value
func set_fov(new_fov: float):
    current_fov = clamp(new_fov, min_fov, max_fov)
    camera.fov = current_fov
    print("FOV set to: ", current_fov)

# Reset to default FOV
func reset_fov():
    current_fov = default_fov
    camera.fov = current_fov
    print("FOV reset to: ", current_fov)

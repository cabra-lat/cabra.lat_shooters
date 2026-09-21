class_name AttachmentScope3D
extends Item3D

var viewport_texture: ViewportTexture
@onready var sub_viewport: SubViewport = $ScopeViewport
@onready var camera: Camera3D = $ScopeViewport/Camera3D

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

    # NOTE: deliberately NOT subscribing to get_tree().tree_changed. That
    # global signal fires while nodes are mid-deletion, and re-running
    # _setup_viewport then touched a half-freed SubViewport/Camera and hard
    # crashed the engine on weapon switch (viewmodel free). One-shot setup
    # in _ready is enough; call _setup_viewport() explicitly if needed.

func _create_viewport_and_camera():
    # Add camera to viewport
    camera.owner = sub_viewport

    # Add viewport to scope (as a direct child, not under MESH)
    sub_viewport.owner = self

func _setup_viewport():
    if not is_inside_tree() or get_tree() == null:
        return
    if is_queued_for_deletion():
        return
    # Children are freed before the parent during exit propagation, so the
    # cached @onready refs can be non-null yet already freed: is_instance_valid.
    if not is_instance_valid(sub_viewport) or not is_instance_valid(camera):
        return
    if sub_viewport.is_queued_for_deletion() or camera.is_queued_for_deletion():
        return
    # Setting camera.current touches the viewport's internal camera slot;
    # both ends must still be live and in-tree.
    if not camera.is_inside_tree() or not sub_viewport.is_inside_tree():
        return
    # Set up the viewport
    sub_viewport.world_3d = get_tree().root.world_3d
    sub_viewport.own_world_3d = false
    camera.current = true

    # Create and assign the ViewportTexture
    _setup_viewport_texture()

func _setup_viewport_texture():
    if not is_instance_valid(sub_viewport):
        return
    # Create ViewportTexture
    viewport_texture = ViewportTexture.new()
    viewport_texture.viewport_path = sub_viewport.get_path()

    # Apply to material
    var mesh_instance = get_node_or_null("MESH")
    if mesh_instance and mesh_instance.material_override:
        var material = mesh_instance.material_override.duplicate()
        mesh_instance.material_override = material

        if material is ShaderMaterial:
            material.set_shader_parameter("u_scope_texture", viewport_texture)
            print("ViewportTexture assigned to shader")

    # Force refresh
    sub_viewport.size = sub_viewport.size


# Call this whenever the scope moves to update the camera position
func update_scope_view():
    # Force the viewport to render
    sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
    await get_tree().process_frame
    sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

# Add to your AttachmentScope3D class
var last_global_transform: Transform3D

func _process(delta):
    if not is_instance_valid(sub_viewport):
        return
    # Respect a deliberately disabled viewport (no shader lens to feed):
    # the rig re-poses the held gun every frame, so an unconditional
    # "scope moved" update would render the scope world every frame.
    if sub_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED:
        return
    # Check if the scope has moved significantly
    if global_transform != last_global_transform:
        last_global_transform = global_transform

        # Optionally force a render if moving fast
        if global_transform.origin.distance_to(last_global_transform.origin) > 0.01:
            sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

# Handle mouse wheel input for zooming
func _input(event):
    if not is_instance_valid(camera):
        return
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

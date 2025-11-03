# world/cartridge_3d.gd
class_name Cartridge3D
extends Item3D

func _ready():
    super._ready()

func _enable_physics():
    """Enable physics for the casing"""
    freeze = false
    visible = true

func _on_physics_timeout():
    """Disable physics after timer expires to save performance"""
    if auto_disable_physics:
        freeze = true

# Note: The eject() method is removed since ejection physics is now handled by Weapon3D

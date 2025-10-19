class_name InventoryTheme
extends Theme

@export_group("Colors")
@export var slot_bg_color: Color = Color(0.2, 0.2, 0.2, 0.5)
@export var slot_border_color: Color = Color(0.5, 0.5, 0.5, 1.0)
@export var slot_hover_color: Color = Color(0.3, 0.3, 0.3, 0.7)
@export var slot_occupied_color: Color = Color(0.7, 0.2, 0.2, 0.3)
@export var slot_valid_drop_color: Color = Color(0.2, 0.7, 0.2, 0.3)
@export var slot_invalid_drop_color: Color = Color(0.7, 0.2, 0.2, 0.3)

@export_group("Sizes")
@export var slot_size: int = 48
@export var item_margin: int = 2
@export var grid_spacing: int = 0

@export_group("Animations")
@export var hover_animation_duration: float = 0.1
@export var drag_animation_duration: float = 0.15

@export_group("Equipment Slots")
@export var equipment_slot_sizes: Dictionary = {
    "small": Vector2i(48, 48),
    "medium": Vector2i(64, 64),
    "large": Vector2i(96, 96)
}

@export_group("Item Rarity Colors")
@export var rarity_colors: Dictionary = {
    "common": Color(0.8, 0.8, 0.8),
    "uncommon": Color(0.2, 0.8, 0.2),
    "rare": Color(0.2, 0.5, 0.8),
    "epic": Color(0.6, 0.2, 0.8),
    "legendary": Color(0.9, 0.5, 0.1)
}

# Add these exports to the existing InventoryTheme class

@export_group("Container Styles")
@export var container_bg_color: Color = Color(0.1, 0.1, 0.1, 0.9)
@export var grid_line_color: Color = Color(0.3, 0.3, 0.3, 0.5)
@export var grid_bg_color: Color = Color(0.15, 0.15, 0.15, 0.8)

@export_group("Animation Settings")
@export var item_move_duration: float = 0.2
@export var slot_highlight_duration: float = 0.15
@export var container_open_duration: float = 0.3

# Add style getters
func get_stylebox(style_name: StringName, style_type: StringName = "") -> StyleBox:
    var style_box = StyleBoxFlat.new()

    match style_name:
        "container_panel":
            style_box.bg_color = container_bg_color
            style_box.border_color = slot_border_color
            style_box.border_width_left = 2
            style_box.border_width_top = 2
            style_box.border_width_right = 2
            style_box.border_width_bottom = 2
        "grid_background":
            style_box.bg_color = grid_bg_color
        "slot_hover":
            style_box.bg_color = slot_hover_color

    return style_box

static func get_theme() -> InventoryTheme:
    return InventoryTheme.new()

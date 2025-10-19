class_name InventoryItemUI
extends Control

# Theme and styling
var inventory_item: InventoryItem
var container_ui: BaseInventoryUI
var rarity_color: Color = Color.WHITE

# Visual components
@onready var background: ColorRect = $Background
@onready var icon: TextureRect = $Icon
@onready var stack_label: Label = $StackLabel
@onready var rarity_overlay: ColorRect = $RarityOverlay
@onready var hover_highlight: ColorRect = $HoverHighlight

func _ready():
    # Ensure all mouse events pass through to underlying slots
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _setup_visuals()

func _setup_visuals():
    if not theme:
        theme = InventoryTheme.get_theme()

    # Create visual hierarchy if nodes don't exist
    if not has_node("Background"):
        background = ColorRect.new()
        background.name = "Background"
        background.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(background)

    if not has_node("Icon"):
        icon = TextureRect.new()
        icon.name = "Icon"
        icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(icon)

    if not has_node("StackLabel"):
        stack_label = Label.new()
        stack_label.name = "StackLabel"
        stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        stack_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
        add_child(stack_label)

    if not has_node("RarityOverlay"):
        rarity_overlay = ColorRect.new()
        rarity_overlay.name = "RarityOverlay"
        rarity_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
        rarity_overlay.visible = false
        add_child(rarity_overlay)

    if not has_node("HoverHighlight"):
        hover_highlight = ColorRect.new()
        hover_highlight.name = "HoverHighlight"
        hover_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
        hover_highlight.visible = false
        hover_highlight.color = Color(1, 1, 1, 0.1)
        add_child(hover_highlight)

func setup(item: InventoryItem, container: BaseInventoryUI):
    inventory_item = item
    container_ui = container

    if container_ui and container_ui.has_method("get_theme"):
        theme = container_ui.get_theme()
    else:
        theme = InventoryTheme.get_theme()

    _update_visuals()
    _position_item()

func _update_visuals():
    if not inventory_item or not inventory_item.content:
        return

    # Set icon
    if icon and inventory_item.content.icon:
        icon.texture = inventory_item.content.icon

    # Set stack label
    if stack_label:
        if inventory_item.max_stack > 1:
            stack_label.text = str(inventory_item.stack_count)
            stack_label.visible = true
        else:
            stack_label.visible = false

    # Set rarity color
    if rarity_overlay:
        var rarity = _get_item_rarity()
        if rarity != "common" and theme.rarity_colors.has(rarity):
            rarity_color = theme.rarity_colors[rarity]
            var rarity_color_with_alpha = rarity_color
            rarity_color_with_alpha.a = 0.3
            rarity_overlay.color = rarity_color_with_alpha
            rarity_overlay.visible = true
        else:
            rarity_overlay.visible = false

    # Apply theme styling
    _apply_theme_styles()

func _apply_theme_styles():
    if not theme:
        return

    # Set item size based on dimensions and theme
    var item_size = theme.slot_size * Vector2(inventory_item.dimensions)
    var margin = theme.item_margin

    # Adjust for margins
    item_size -= Vector2(margin * 2, margin * 2)

    custom_minimum_size = item_size
    size = item_size

    # Position and size child elements
    if background:
        background.size = item_size
        background.color = Color(0, 0, 0, 0)  # Transparent background

    if icon:
        icon.custom_minimum_size = item_size
        icon.size = item_size

    if stack_label:
        stack_label.custom_minimum_size = item_size
        stack_label.size = item_size

        # Style the stack label
        var font = stack_label.get_theme_font("font")
        if font:
            stack_label.add_theme_font_override("font", font)
        stack_label.add_theme_font_size_override("font_size", 12)
        stack_label.add_theme_color_override("font_color", Color.WHITE)
        stack_label.add_theme_constant_override("outline_size", 2)
        stack_label.add_theme_color_override("font_outline_color", Color.BLACK)

    if rarity_overlay:
        rarity_overlay.size = item_size

    if hover_highlight:
        hover_highlight.size = item_size

func _position_item():
    if not inventory_item or not container_ui:
        return

    # Calculate position based on item's grid position and theme
    var slot_position = inventory_item.position
    var theme_slot_size = theme.slot_size
    var margin = theme.item_margin

    position = theme_slot_size * Vector2(slot_position) + Vector2(margin, margin)

func _get_item_rarity() -> String:
    if not inventory_item or not inventory_item.content:
        return "common"

    # Check if item content has a rarity property
    if inventory_item.content.has_method("get_rarity"):
        return inventory_item.content.get_rarity()
    elif inventory_item.content.has_property("rarity"):
        return inventory_item.content.rarity

    return "common"

# Optional: Add hover effects for better UX
func set_highlighted(highlight: bool):
    if hover_highlight:
        hover_highlight.visible = highlight

        if highlight:
            # Add subtle animation
            var tween = create_tween()
            tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)
        else:
            var tween = create_tween()
            tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

# Completely remove drag/drop functionality from items
# Let the underlying slots handle all interactions

func _get_drag_data(at_position: Vector2):
    return null

func _can_drop_data(at_position: Vector2, data):
    return false

func _drop_data(at_position: Vector2, data):
    pass

func _gui_input(event):
    # Let all input events pass through to underlying slots
    pass

# Cleanup method
func cleanup():
    if is_instance_valid(self):
        queue_free()

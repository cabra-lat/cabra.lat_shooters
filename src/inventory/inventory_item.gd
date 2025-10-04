class_name InventoryItem extends Resource

@export var content: Resource  # What is inside
@export var preview: Texture2D # Inventory icon
@export var max_stack: int = 0 # How many you can stack
@export var dimensions: Vector2i = Vector2i.ONE
var _rect = Rect2(Vector2i.ZERO, dimensions)

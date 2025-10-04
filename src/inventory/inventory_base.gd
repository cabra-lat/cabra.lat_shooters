class_name Inventory extends Resource

@export var contents: Array[InventoryItem] = []
@export var dimensions: Vector2i = Vector2i(5, 5)

var _rect = Rect2(Vector2i.ZERO, Vector2i.ONE)

func add_item(item: InventoryItem, location: Vector2i):
	if not _rect.encloses(item._rect): return
	contents.append(item)

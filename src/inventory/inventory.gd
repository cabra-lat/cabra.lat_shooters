class_name Inventory extends Resource

@export var contents: Array[InventoryItem] = []
@export var dimensions: Vector2i = Vector2i(5, 5)

var _rect = Rect2(Vector2i.ZERO, Vector2i.ONE)

func add_item(item: InventoryItem):
	if not _rect.encloses(item._rect): return
	contents.append(item)

func add(
	content: Resource, 
	dimensions: Vector2i = Vector2i.ONE,
	max_stack: int = 0
):
	var item = InventoryItem.new()
	item.content = content
	item.max_stack = max_stack
	item.dimensions = dimensions
	add_item(item)

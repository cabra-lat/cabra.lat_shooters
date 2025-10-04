class_name InventoryBase
extends Resource

@export var contents: Array[Resource] = []
@export var dimensions: Vector2

var _rect = Rect2(Vector2.ZERO, Vector2.ONE)

func add_item(item: InventoryItem, location: Vector2):
	if not self.rect.encloses(item.rect): return
	if not self.rect.encloses(item.rect): return
	contents.append(item)

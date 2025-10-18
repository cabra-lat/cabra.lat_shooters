# src/ui/inventory/world_drop_zone.gd
class_name WorldDropZone
extends ColorRect

signal item_dropped(data: Dictionary)

func _can_drop_data(position: Vector2, data) -> bool:
    print("WorldDropZone: Checking if can drop data: ", data)
    return data is Dictionary and data.has("item")

func _drop_data(position: Vector2, data) -> void:
    print("WorldDropZone: Dropping data: ", data)
    item_dropped.emit(data)

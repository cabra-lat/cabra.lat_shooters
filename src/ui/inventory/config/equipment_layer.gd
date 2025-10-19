class_name EquipmentLayerDefinition
extends Resource

@export var layer_name: String
@export var display_name: String
@export var layer_order: int = 0
@export var slots: Array[String] = [] # slot names in this layer
@export var visible_by_default: bool = true

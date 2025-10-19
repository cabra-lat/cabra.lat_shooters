class_name EquipmentConfig
extends Resource

@export_group("Slot Definitions")
@export var slot_definitions: Array[EquipmentSlotDefinition] = []

@export_group("Layer Definitions")
@export var layer_definitions: Array[EquipmentLayerDefinition] = []

func get_slot_definition(slot_name: String) -> EquipmentSlotDefinition:
    for definition in slot_definitions:
        if definition.slot_name == slot_name:
            return definition
    return null

func get_layer_definition(layer_name: String) -> EquipmentLayerDefinition:
    for definition in layer_definitions:
        if definition.layer_name == layer_name:
            return definition
    return null

class_name EquipmentConfig
extends Resource

@export_group("Slot Definitions")
@export var slot_definitions: Array[EquipmentSlotDefinition] = []

@export_group("Layer Definitions")
@export var layer_definitions: Array[EquipmentLayerDefinition] = []

func _init() -> void:
    # Create default slot definitions if empty
    if slot_definitions.is_empty():
        _create_default_slots()

    # Create default layer definitions if empty
    if layer_definitions.is_empty():
        _create_default_layers()

func _create_default_slots():
    slot_definitions = [
        _create_slot_definition("head", "Head", "medium", ["armor"], ["head"]),
        _create_slot_definition("torso", "Torso", "large", ["armor"], ["torso"]),
        _create_slot_definition("legs", "Legs", "large", ["armor"], ["legs"]),
        _create_slot_definition("primary", "Primary Weapon", "large", ["weapon"], ["primary"]),
        _create_slot_definition("secondary", "Secondary Weapon", "medium", ["weapon"], ["secondary"]),
        _create_slot_definition("back", "Backpack", "large", ["backpack"], ["back"])
    ]

func _create_default_layers():
    layer_definitions = [
        _create_layer_definition("armor", "Armor", 0, ["head", "torso", "legs"]),
        _create_layer_definition("weapons", "Weapons", 1, ["primary", "secondary"]),
        _create_layer_definition("gear", "Gear", 2, ["back"])
    ]

func _create_slot_definition(slot_name: String, display_name: String, slot_size: String, allowed_item_types: Array[String], allowed_categories: Array[String]) -> EquipmentSlotDefinition:
    var slot_def = EquipmentSlotDefinition.new()
    slot_def.slot_name = slot_name
    slot_def.display_name = display_name
    slot_def.slot_size = slot_size
    slot_def.allowed_item_types = allowed_item_types
    slot_def.allowed_categories = allowed_categories
    slot_def.max_items = 1
    slot_def.layer = "armor"  # Default layer
    return slot_def

func _create_layer_definition(layer_name: String, display_name: String, layer_order: int, slots: Array[String]) -> EquipmentLayerDefinition:
    var layer_def = EquipmentLayerDefinition.new()
    layer_def.layer_name = layer_name
    layer_def.display_name = display_name
    layer_def.layer_order = layer_order
    layer_def.slots = slots
    layer_def.visible_by_default = true
    return layer_def

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

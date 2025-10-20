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
    # Create definitions that match your scene structure
    slot_definitions = [
        # Armor slots
        _create_slot_definition("head", "Head", "medium", ["armor"], ["head"]),
        _create_slot_definition("eyes", "Eyes", "small", ["armor", "clothing"], ["eyes"]),
        _create_slot_definition("left_ear", "Left Ear", "small", ["armor", "clothing"], ["ear"]),
        _create_slot_definition("right_ear", "Right Ear", "small", ["armor", "clothing"], ["ear"]),
        _create_slot_definition("torso", "Torso", "large", ["armor"], ["torso"]),
        _create_slot_definition("lower_torso", "Lower Torso", "medium", ["armor"], ["torso"]),
        _create_slot_definition("hips", "Hips", "medium", ["armor"], ["hips"]),

        # Left arm slots
        _create_slot_definition("left_upper_arm", "Left Upper Arm", "medium", ["armor"], ["arm", "upper_arm"]),
        _create_slot_definition("left_lower_arm", "Left Lower Arm", "medium", ["armor"], ["arm", "lower_arm"]),
        _create_slot_definition("left_hand", "Left Hand", "small", ["armor", "clothing"], ["hand"]),

        # Right arm slots
        _create_slot_definition("right_upper_arm", "Right Upper Arm", "medium", ["armor"], ["arm", "upper_arm"]),
        _create_slot_definition("right_lower_arm", "Right Lower Arm", "medium", ["armor"], ["arm", "lower_arm"]),
        _create_slot_definition("right_hand", "Right Hand", "small", ["armor", "clothing"], ["hand"]),

        # Left leg slots
        _create_slot_definition("left_upper_leg", "Left Upper Leg", "medium", ["armor"], ["leg", "upper_leg"]),
        _create_slot_definition("left_knee", "Left Knee", "small", ["armor"], ["leg", "knee"]),
        _create_slot_definition("left_lower_leg", "Left Lower Leg", "medium", ["armor"], ["leg", "lower_leg"]),
        _create_slot_definition("left_foot", "Left Foot", "small", ["armor", "clothing"], ["foot"]),

        # Right leg slots
        _create_slot_definition("right_upper_leg", "Right Upper Leg", "medium", ["armor"], ["leg", "upper_leg"]),
        _create_slot_definition("right_knee", "Right Knee", "small", ["armor"], ["leg", "knee"]),
        _create_slot_definition("right_lower_leg", "Right Lower Leg", "medium", ["armor"], ["leg", "lower_leg"]),
        _create_slot_definition("right_foot", "Right Foot", "small", ["armor", "clothing"], ["foot"]),

        # Weapon slots (from your Gear tab)
       # In EquipmentConfig._create_default_slots(), update the primary slot:
        _create_slot_definition("primary", "Primary Weapon", "large", ["weapon"], ["primary", "assault_rifle", "sniper_rifle", "shotgun"]),
        _create_slot_definition("secondary", "Secondary Weapon", "medium", ["weapon"], ["secondary"]),
        _create_slot_definition("utility", "Utility", "medium", ["weapon", "tool"], ["utility"])
    ]

func _create_default_layers():
    layer_definitions = [
        _create_layer_definition("armor", "Armor", 0, [
            "head", "eyes", "left_ear", "right_ear", "torso", "lower_torso", "hips",
            "left_upper_arm", "left_lower_arm", "left_hand",
            "right_upper_arm", "right_lower_arm", "right_hand",
            "left_upper_leg", "left_knee", "left_lower_leg", "left_foot",
            "right_upper_leg", "right_knee", "right_lower_leg", "right_foot"
        ]),
        _create_layer_definition("clothes", "Clothes", 1, [
            "head", "eyes", "left_ear", "right_ear", "torso", "lower_torso", "hips",
            "left_upper_arm", "left_lower_arm", "left_hand",
            "right_upper_arm", "right_lower_arm", "right_hand",
            "left_upper_leg", "left_knee", "left_lower_leg", "left_foot",
            "right_upper_leg", "right_knee", "right_lower_leg", "right_foot"
        ]),
        _create_layer_definition("storage", "Storage", 2, [
            "torso"  # Backpack slot
        ]),
        _create_layer_definition("gear", "Gear", 3, [
            "primary", "secondary", "utility"
        ])
    ]

func _create_slot_definition(slot_name: String, display_name: String, slot_size: String, allowed_item_types: Array[String], allowed_categories: Array[String]) -> EquipmentSlotDefinition:
    var slot_def = EquipmentSlotDefinition.new()
    slot_def.slot_name = slot_name
    slot_def.display_name = display_name
    slot_def.slot_size = slot_size
    slot_def.allowed_item_types = allowed_item_types
    slot_def.allowed_categories = allowed_categories
    slot_def.max_items = 1

    # Assign to appropriate layer based on slot name
    if slot_name in ["primary", "secondary", "utility"]:
        slot_def.layer = "gear"
    elif slot_name == "torso" and display_name == "Torso":  # Backpack slot
        slot_def.layer = "storage"
    else:
        slot_def.layer = "armor"  # Default to armor layer

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

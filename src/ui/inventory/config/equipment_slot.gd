class_name EquipmentSlotDefinition
extends Resource

@export var slot_name: String
@export var display_name: String
@export var slot_size: String = "medium" # small, medium, large
@export var allowed_item_types: Array[String] = [] # "weapon", "armor", "backpack", etc.
@export var allowed_categories: Array[String] = [] # "primary", "secondary", "head", "torso", etc.
@export var max_items: int = 1
@export var layer: String = "gear"
@export var position_weight: int = 0 # for ordering in UI

func is_item_compatible(item: InventoryItem) -> bool:
    if not item or not item.content:
        print("EquipmentSlotDefinition: Item or item content is null")
        return false

    # Check item type
    var item_type = _get_item_type(item.content)
    if allowed_item_types.size() > 0 and not allowed_item_types.has(item_type):
        print("EquipmentSlotDefinition: Item type '%s' not in allowed types: %s" % [item_type, allowed_item_types])
        return false

    # Check categories
    if allowed_categories.size() > 0:
        var item_categories = _get_item_categories(item.content)
        var has_valid_category = false
        for category in allowed_categories:
            if item_categories.has(category):
                has_valid_category = true
                break

        if not has_valid_category:
            print("EquipmentSlotDefinition: Item categories %s don't match allowed categories: %s" % [item_categories, allowed_categories])
            return false

    return true

func _get_item_type(content: Resource) -> String:
    if content is Weapon:
        return "weapon"
    elif content is Armor:
        return "armor"
    elif content is Backpack:
        return "backpack"
    elif content is Ammo:
        return "ammo"
    return "misc"

func _get_item_categories(content: Resource) -> Array[String]:
    var categories: Array[String] = []

    if content is Weapon:
        categories.append("weapon")
        var weapon = content as Weapon
        if weapon.weapon_type:
            categories.append(weapon.weapon_type)
            # Also add weapon_type as a primary/secondary category
            if weapon.weapon_type == "assault_rifle" or weapon.weapon_type == "sniper_rifle" or weapon.weapon_type == "shotgun":
                categories.append("primary")
            elif weapon.weapon_type == "pistol" or weapon.weapon_type == "smg":
                categories.append("secondary")
    elif content is Armor:
        categories.append("armor")
        var armor = content as Armor
        if armor.armor_slot:
            categories.append(armor.armor_slot)
    elif content is Backpack:
        categories.append("backpack")
        categories.append("storage")

    return categories

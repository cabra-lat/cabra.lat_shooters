# res://test/scenes/test_player.gd
extends Node

var can_connect_signals: bool = false

# DEV/DEBUG
@onready var ammo: Ammo = preload("../../src/resources/ammo/7_62_39mm_PS_GOST_BR4.tres")
@onready var weapon: Weapon = preload("../../src/resources/weapons/AK_47.tres")
@onready var player: PlayerController = $Player
# END DEV/DEBUG

#func _ready():
    #magazine_ak47.compatible_calibers = [ "7.62x39mm" ]
    #magazine_ak47.type = AmmoFeed.Type.EXTERNAL
    ## Fill debug magazine
    #for i in range(magazine_ak47.max_capacity):
        #magazine_ak47.insert(ammo_762x39mm)
    #
    #weapon_ak47.change_magazine(magazine_ak47)
    #var item = InventorySystem.create_inventory_item(weapon_ak47)
    #player.equipment.equip(item, "primary")

func _ready():
    # Equip to player body
    var weapon_item = InventorySystem.create_inventory_item(weapon)
    $Player.equipment.equip(weapon_item, "primary")

    var magazine = AmmoFeed.new()
    magazine.compatible_calibers.append(ammo.caliber)
    magazine.type = AmmoFeed.Type.EXTERNAL
    magazine.icon = preload("../../assets/ui/inventory/icon_stock_mag.png")
    magazine.view_model = preload("../../src/weapons/scenes/magazine_ak47.tscn")
    var magazine_item = InventorySystem.create_inventory_item(magazine)
    magazine_item.dimensions = Vector2i(1,2)

    var backpack = Backpack.new()
    backpack.icon = preload("../../assets/ui/inventory/backpack.png")
    backpack.add_item(magazine_item)

    var backpack_item = InventorySystem.create_inventory_item(backpack)
    backpack_item.dimensions = Vector2i(2,2)
    $Player.equipment.equip(backpack_item, "back")

    # Create world item
    var world_item = WorldItem.spawn($Player, ammo, 30)

func _on_trigger_locked():
    $HUD.show_popup("[can't pull the trigger]")

func _on_cartridge_fired(ejected):
    var string = ""
    for chambered in ejected:
        string += "Pow! (%d) %s\n" % [ \
        player.weapon.ammofeed.max_capacity \
        - player.weapon.ammofeed.remaining, \
        chambered.caliber ]
    $HUD.show_popup(string)

func _on_trigger_released():
    $HUD.show_popup("Released trigger")

func _on_firemode_changed(new):
    $HUD.show_popup("changed firemode: %s" % new)

func _on_ammofeed_empty():
    $HUD.show_popup("Click!")

func _on_ammofeed_missing():
    $HUD.show_popup('Click!')

func _on_ammofeed_changed(old, new):
    $HUD.show_popup("changed mag %d/%d to %d/%d"
         % [old.remaining  if old else 0,
            old.max_capacity if old else 0,
            new.remaining,
            new.max_capacity])

func _on_ammofeed_incompatible():
    $HUD.show_popup("- This doesn't fit here")

func _on_player_debug(player: PlayerController, text: String) -> void:
    $HUD.update_debug(text)

func _on_player_landed(player: PlayerController, max_velocity: float, delta: float) -> void:
    var letal_g = player.config.letal_acceleration
    var a = abs(max_velocity - player.velocity.length()) / (2.0 * delta)
    var g = a / player.config.gravity
    var letality_ratio = g / letal_g
    if letality_ratio > 1:
        $HUD.show_popup("Letal fall damage (%.2f g)" % g)
    elif letality_ratio > .5:
        $HUD.show_popup("Minor fall damage (%.2f g)" % g)
    else:
        $HUD.show_popup("Safely landed     (%.2f g)" % g)

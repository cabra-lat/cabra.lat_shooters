# res://test/scenes/test_player.gd
extends Node

var can_connect_signals: bool = false

# DEV/DEBUG
@onready var ammo: Ammo = preload("../../src/resources/ammo/7_62_39mm_PS_GOST_BR4.tres")
@onready var weapon: Weapon = preload("../../src/resources/weapons/AK_47.tres")
@onready var player: PlayerController = $Player
# END DEV/DEBUG

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

  print("Ammo view_model: ", ammo.view_model)
  print("Weapon data: ", weapon)


  # Connect to player's current weapon signals
  $Player.equipped.connect(_on_player_equipped)

  # If weapon is already equipped, connect to it
  var primary = $Player.equipment.get_equipped("primary")
  if not primary.is_empty():
    _connect_weapon_signals(primary[0].extra as Weapon)

  load_ammunition_into_weapon()

func _on_player_equipped(player: PlayerController, item: Item):
  if item is Weapon:
    _connect_weapon_signals(item as Weapon)

func _connect_weapon_signals(weapon: Weapon):
  if weapon:
    print("DEBUG: Connecting to weapon signals: ", weapon.name)

    if not weapon.is_connected("cartridge_fired", Callable(self, "_on_cartridge_fired")):
      weapon.cartridge_fired.connect(_on_cartridge_fired)

    if not weapon.is_connected("trigger_locked", Callable(self, "_on_trigger_locked")):
      weapon.trigger_locked.connect(_on_trigger_locked)

    if not weapon.is_connected("trigger_released", Callable(self, "_on_trigger_released")):
      weapon.trigger_released.connect(_on_trigger_released)

    if not weapon.is_connected("firemode_changed", Callable(self, "_on_firemode_changed")):
      weapon.firemode_changed.connect(_on_firemode_changed)

    if not weapon.is_connected("ammofeed_empty", Callable(self, "_on_ammofeed_empty")):
      weapon.ammofeed_empty.connect(_on_ammofeed_empty)

    if not weapon.is_connected("ammofeed_missing", Callable(self, "_on_ammofeed_missing")):
      weapon.ammofeed_missing.connect(_on_ammofeed_missing)

    if not weapon.is_connected("ammofeed_changed", Callable(self, "_on_ammofeed_changed")):
      weapon.ammofeed_changed.connect(_on_ammofeed_changed)

    if not weapon.is_connected("ammofeed_incompatible", Callable(self, "_on_ammofeed_incompatible")):
      weapon.ammofeed_incompatible.connect(_on_ammofeed_incompatible)

func _on_trigger_locked():
  $HUD.show_popup("[can't pull the trigger]")

func _on_cartridge_fired(ejected):
  print("Cartridge fired signal received, ejected: ", ejected)
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

func load_ammunition_into_weapon():
  var player_weapon = $Player.equipment.get_equipped("primary")[0].extra as Weapon
  if player_weapon:
    # Create and load a magazine
    var magazine = AmmoFeed.new()
    magazine.name = "AK-47 Magazine"
    magazine.compatible_calibers = ["7.62x39mm"]
    magazine.max_capacity = 30
    magazine.type = AmmoFeed.Type.EXTERNAL

    # Fill with ammunition
    for i in range(30):  # Load 10 rounds for testing
      var round = ammo.duplicate()
      round.name = "7.62x39mm Round " + str(i)
      magazine.insert(round)

    # Load into weapon
    var success = WeaponSystem.change_magazine(player_weapon, magazine)
    print("DEBUG: Magazine load success: ", success)

    if success:
      print("DEBUG: Weapon ammofeed: ", player_weapon.ammofeed != null)
      print("DEBUG: Chambered round: ", player_weapon.chambered_round != null)
      if player_weapon.ammofeed:
        print("DEBUG: Rounds in magazine: ", player_weapon.ammofeed.capacity)
  else:
    print("DEBUG: No weapon found to load ammunition")

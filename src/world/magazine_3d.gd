# world/magazine_3d.gd
class_name Magazine3D
extends Item3D

var preloaded_casings: Array[Cartridge3D] = []

func _ready() -> void:
  super._ready()  # Call parent _ready first
  print("Magazine3D _ready called, data: ", data)

func _set_data(value: AmmoFeed):
  print("Magazine3D _set_data called with: ", value)

    # Clean up existing casings
  _unload_casings()

  data = value
  if data:
    mass = data.mass
    print("Magazine data set, contents size: ", data.contents.size() if data.contents else 0)

        # Preload casings now that we have data
    _preload_casings()

func _preload_casings() -> void:
  if not data or not data.contents:
    print("Magazine3D: No data or contents to preload casings from")
    return

  print("Magazine3D: Preloading casings for ", data.contents.size(), " rounds")

    # Preload one casing per round in the magazine
  for i in range(data.contents.size()):
    var ammo = data.contents[i] as Ammo
    if ammo:
      #print("Preloading casing for ammo: ", ammo.name)
      if ammo.view_model:
        var casing = ammo.view_model.instantiate()
        if casing:
          casing.visible = false
          preloaded_casings.append(casing)
          #print("Successfully preloaded casing, total: ", preloaded_casings.size())
        else:
          print("ERROR: Failed to instantiate casing from view_model")
      else:
        print("ERROR: Ammo has no view_model: ", ammo.name)
    else:
      print("ERROR: Invalid ammo in magazine contents at index ", i)

func _unload_casings() -> void:
  print("Unloading ", preloaded_casings.size(), " preloaded casings")
  for casing in preloaded_casings:
    if is_instance_valid(casing):
      casing.queue_free()
  preloaded_casings.clear()

func get_casing() -> Cartridge3D:
  print("get_casing called - preloaded casings available: ", preloaded_casings.size())
  if preloaded_casings.is_empty():
    print("WARNING: No preloaded casings available!")
    return null

  var ejected = preloaded_casings.pop_back()
  ejected.visible = true
  print("Returning casing, remaining: ", preloaded_casings.size())
  return ejected

@tool
class_name Certification extends Resource

enum Standard { NIJ, VPAM, GOST, GA141, MILITARY }

# Keep your existing E(m, v) helper function
static func E(m, v):
  return Utils.bullet_energy(m, v)

static func get_max_certified_energy(standard: Standard, level: int) -> float:
  """Returns the maximum energy threat for a given certification level."""
  # These values represent typical maximum energies for each certification level
  var certified_threats = get_certified_threats(standard, level)
  return certified_threats.map(func(e): return e.energy).max()

static func get_armor_type_for_certification(standard: int, level: int) -> int:
  """Determines the appropriate armor type for a certification level."""
  match standard:
    Standard.NIJ:
      if level <= 2: return BallisticMaterial.Type.ARMOR_SOFT    # Soft armor
      else: return BallisticMaterial.Type.ARMOR_HARD             # Hard plates
      
    Standard.VPAM:
      if level <= 3: return BallisticMaterial.Type.ARMOR_SOFT    # Soft armor
      elif level <= 6: return BallisticMaterial.Type.ARMOR_MEDIUM # Medium plates
      else: return BallisticMaterial.Type.ARMOR_HARD             # Hard plates
      
    Standard.GOST:
      if level <= 2: return BallisticMaterial.Type.ARMOR_SOFT    # Soft armor
      elif level <= 4: return BallisticMaterial.Type.ARMOR_MEDIUM # Medium plates
      else: return BallisticMaterial.Type.ARMOR_HARD             # Hard plates
      
    _:
      return BallisticMaterial.Type.ARMOR_MEDIUM

static func get_certified_threats(standard: Standard, level: int) -> Array:
  match standard:
    Standard.VPAM:
      match level:
        1: return [ # .22 Long Rifle
          {"type": Ammo.Type.FMJ, "energy": E(2.6, 360), "caliber": ".22 LR", "distance": 10.0, "shots": 3}
        ]
        2: return [ # 9×19mm Parabellum
          {"type": Ammo.Type.FMJ, "energy": E(8.0, 360), "caliber": "9x19mm", "distance": 5.0, "shots": 3}
        ]
        3: return [ # 9×19mm Parabellum (higher velocity)
          {"type": Ammo.Type.FMJ, "energy": E(8.0, 415), "caliber": "9x19mm", "distance": 5.0, "shots": 3}
        ]
        4: return [ # .357 Magnum & .44 Magnum
          {"type": Ammo.Type.JSP, "energy": E(10.2, 430), "caliber": ".357 Magnum", "distance": 5.0, "shots": 3},
          {"type": Ammo.Type.JHP, "energy": E(15.6, 440), "caliber": ".44 Magnum", "distance": 5.0, "shots": 3}
        ]
        5: return [ # .357 Magnum FMs
          {"type": Ammo.Type.FMJ, "energy": E(7.1, 580), "caliber": ".357 Magnum", "distance": 5.0, "shots": 3}
        ]
        6: return [ # 7.62×39mm PS
          {"type": Ammo.Type.STEEL_CORE, "energy": E(8.0, 720), "caliber": "7.62x39mm", "distance": 10.0, "shots": 3}
        ]
        7: return [ # 5.56×45mm SS109 & 7.62×51mm DM111
          {"type": Ammo.Type.GREEN_TIP, "energy": E(4.0, 950), "caliber": "5.56x45mm", "distance": 10.0, "shots": 3},
          {"type": Ammo.Type.STEEL_CORE, "energy": E(9.55, 830), "caliber": "7.62x51mm", "distance": 10.0, "shots": 3}
        ]
        8: return [ # 7.62×39mm BZ API
          {"type": Ammo.Type.API, "energy": E(7.7, 740), "caliber": "7.62x39mm", "distance": 10.0, "shots": 3}
        ]
        9: return [ # 7.62×51mm P80 AP
          {"type": Ammo.Type.AP, "energy": E(9.7, 820), "caliber": "7.62x51mm", "distance": 10.0, "shots": 3}
        ]
        10: return [ # 7.62×54mmR B32 API
          {"type": Ammo.Type.API, "energy": E(10.4, 860), "caliber": "7.62×54mmR", "distance": 10.0, "shots": 3}
        ]
        11: return [ # 7.62×51mm Nammo AP8/US M993
          {"type": Ammo.Type.AP, "energy": E(8.4, 930), "caliber": "7.62×51mm", "distance": 10.0, "shots": 3}
        ]
        12: return [ # 7.62×51mm RUAG SWISS P AP
          {"type": Ammo.Type.AP, "energy": E(12.7, 810), "caliber": "7.62×51mm", "distance": 10.0, "shots": 3}
        ]
        13: return [ # 12.7×99mm RUAG SWISS P
          {"type": Ammo.Type.AP, "energy": E(43.5, 810), "caliber": "12.7×99mm", "distance": null, "shots": 3}
        ]
        14: return [ # 14.5×114mm B32 API
          {"type": Ammo.Type.API, "energy": E(63.4, 810), "caliber": "14.5×114mm", "distance": null, "shots": 3}
        ]
        _: return []
    
    Standard.NIJ:
      match level:
        # NIJ 0101.06 (old standard)
        1: return [ # .22 LR & .380 ACP
          {"type": Ammo.Type.FMJ, "energy": E(2.6, 329), "caliber": ".22 LR"},
          {"type": Ammo.Type.FMJ, "energy": E(6.2, 322), "caliber": ".380 ACP"}
        ]
        2: return [ # 9mm
          {"type": Ammo.Type.FMJ, "energy": E(8.0, 373), "caliber": "9x19mm"}
        ]
        3: return [ # .357 Magnum
          {"type": Ammo.Type.JSP, "energy": E(10.2, 436), "caliber": ".357 Magnum"}
        ]
        4: return [ # .30-06 M2 AP
          {"type": Ammo.Type.AP, "energy": E(10.8, 878), "caliber": ".30-06"}
        ]
        # NIJ 0123.00 (2024 new standard)
        5: return [ # HG1 - 9mm & .357 Magnum
          {"type": Ammo.Type.FMJ, "energy": E(8.0, 398), "caliber": "9x19mm"}
        ]
        6: return [ # HG2 - 9mm & .44 Magnum
          {"type": Ammo.Type.FMJ, "energy": E(8.0, 448), "caliber": "9x19mm"},
          {"type": Ammo.Type.JHP, "energy": E(15.6, 436), "caliber": ".44 Magnum"}
        ]
        7: return [ # RF1 - 7.62x51mm & 7.62x39mm
          {"type": Ammo.Type.FMJ, "energy": E(9.6, 847), "caliber": "7.62x51mm"},
          {"type": Ammo.Type.STEEL_CORE, "energy": E(8.05, 732), "caliber": "7.62x39mm"}
        ]
        8: return [ # RF2 - Adds M855 to RF1
          {"type": Ammo.Type.FMJ, "energy": E(9.6, 847), "caliber": "7.62x51mm"},
          {"type": Ammo.Type.STEEL_CORE, "energy": E(8.05, 732), "caliber": "7.62x39mm"},
          {"type": Ammo.Type.GREEN_TIP, "energy": E(4.0, 950), "caliber": "5.56x45mm"}
        ]
        9: return [ # RF3 - .30-06 AP
          {"type": Ammo.Type.AP, "energy": E(10.8, 878), "caliber": ".30-06"}
        ]
        _: return []
    
    Standard.GA141:
      match level:
        1: return [ # 7.62×17mm
          {"type": Ammo.Type.FMJ, "energy": E(4.87, 320), "caliber": "7.62x17mm"}
        ]
        2: return [ # 7.62×25mm Tokarev (Pistol)
          {"type": Ammo.Type.FMJ, "energy": E(5.60, 445), "caliber": "7.62x25mm"}
        ]
        3: return [ # 7.62×25mm Tokarev (SMG)
          {"type": Ammo.Type.FMJ, "energy": E(5.60, 515), "caliber": "7.62x25mm"}
        ]
        4: return [ # 7.62×25mm Tokarev AP (SMG)
          {"type": Ammo.Type.AP, "energy": E(5.68, 515), "caliber": "7.62x25mm"}
        ]
        5: return [ # 7.62×39mm
          {"type": Ammo.Type.STEEL_CORE, "energy": E(8.05, 725), "caliber": "7.62x39mm"}
        ]
        6: return [ # 7.62×54mmR
          {"type": Ammo.Type.STEEL_CORE, "energy": E(9.60, 830), "caliber": "7.62x54mmR"}
        ]
        _: return []
    
    Standard.MILITARY:
      match level:
        1: return [ # SAPI - stops M855
          {"type": Ammo.Type.FMJ, "energy": E(9.6, 840), "caliber": "7.62x51mm"},
          {"type": Ammo.Type.STEEL_CORE, "energy": E(9.5, 700), "caliber": "7.62x54mmR"}, 
          {"type": Ammo.Type.GREEN_TIP, "energy": E(4.0, 990), "caliber": "5.56x45mm"}
        ]
        2: return [ # ESAPI Rev G - stops M995 AP
          {"type": Ammo.Type.FMJ, "energy": E(9.6, 840), "caliber": "7.62x51mm"},
          {"type": Ammo.Type.STEEL_CORE, "energy": E(9.5, 840), "caliber": "7.62x54mmR"},
          {"type": Ammo.Type.AP, "energy": E(10.8, 870), "caliber": ".30-06"},
          {"type": Ammo.Type.M995, "energy": E(3.6, 1020), "caliber": "5.56x45mm"}
        ]
        _: return []
    Standard.GOST:
      match level:
        1: return [ # 9×18mm Makarov
          {"type": Ammo.Type.STEEL_CORE, "energy": E(5.9, 335), "caliber": "9x18mm"}
        ]
        2: return [ # 9×21mm Gyurza
          {"type": Ammo.Type.FMJ, "energy": E(7.93, 390), "caliber": "9x21mm"}
        ]
        3: return [ # 9×19mm 7N21
          {"type": Ammo.Type.STEEL_CORE, "energy": E(5.2, 455), "caliber": "9x19mm"}
        ]
        4: return [ # 5.45×39mm & 7.62×39mm
          {"type": Ammo.Type.STEEL_CORE, "energy": E(3.4, 895), "caliber": "5.45x39mm"},
          {"type": Ammo.Type.STEEL_CORE, "energy": E(7.9, 720), "caliber": "7.62x39mm"}
        ]
        5: return [ # 7.62×54mmR 7N13
          {"type": Ammo.Type.STEEL_CORE, "energy": E(9.4, 830), "caliber": "7.62x54mmR"}
        ]
        6: return [ # 12.7×108mm B32 API
          {"type": Ammo.Type.API, "energy": E(48.2, 830), "caliber": "12.7x108mm"}
        ]
        _: return []
    _:
      return []

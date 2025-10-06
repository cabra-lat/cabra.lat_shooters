## Enumerations used throughout the game for weapons, armor, body parts, and attachments.
## 
## Provides standardized bit-flag enums for:
## - Magazine/feed types
## - Body part hit detection
## - Armor categories
## - Fire modes
## - Weapon attachment points
## 
## All enums use bit flags (powers of two) to allow bitwise operations (e.g., `Firemode.SEMI | Firemode.BURST`).
class_name enums extends Object

## Feed/magazine types for weapons.
## 
## Used to determine how ammunition is loaded and fed into a weapon.
enum FeedType {
	INTERNAL,  ## Internal magazine (e.g., bolt-action rifles)
	EXTERNAL,  ## Detachable box magazine (e.g., AK-47, M4)
	NATO       ## STANAG-compatible magazine (standardized military)
}

## Body parts for hit detection and damage calculation.
## 
## Each part is a unique bit flag to allow combined hit zones (e.g., `HEAD | EYES`).
## Values are powers of two for bitwise operations.
enum BodyParts {
	HEAD      = 1 << 0,   ## Head (non-eye areas)
	EYES      = 1 << 1,   ## Eyes (critical hit zone)
	LEFT_ARM  = 1 << 2,   ## Left arm
	RIGHT_ARM = 1 << 3,   ## Right arm
	LEFT_LEG  = 1 << 4,   ## Left leg
	RIGHT_LEG = 1 << 5,   ## Right leg
	STOMACH   = 1 << 6,   ## Abdomen
	THORAX    = 1 << 7    ## Chest/torso (vital organs)
}

## Armor types for protection and equipment slots.
## 
## Determines what kind of armor piece this is and where it can be equipped.
enum ArmorType {
	GENERIC,  ## Generic armor (e.g., plates, non-specific)
	HELMET,   ## Head protection
	VEST      ## Torso protection (e.g., ballistic vest)
}

## Fire modes supported by weapons.
## 
## Bit flags allow weapons to support multiple modes (e.g., `SEMI | BURST`).
## Use bitwise AND (`&`) to check if a mode is available.
enum Firemode {
	SAFE  = 1 << 0,  ## Safe — trigger disabled
	AUTO  = 1 << 1,  ## Fully automatic
	SEMI  = 1 << 2,  ## Semi-automatic (one shot per trigger pull)
	BURST = 1 << 3,  ## Burst fire (e.g., 3-round burst)
	PUMP  = 1 << 4,  ## Pump-action (shotguns)
	BOLT  = 1 << 5   ## Bolt-action (manual cycling)
}

## Weapon attachment/mount points.
## 
## Defines where accessories (scopes, grips, etc.) can be mounted.
## Bit flags allow multiple compatible mounts (rare, but possible).
enum MountPoint {
	MUZZLE     = 1 << 0,  ## End of barrel (suppressors, flash hiders)
	LEFT_SIDE  = 1 << 1,  ## Left rail (vertical grips, lasers)
	RIGHT_SIDE = 1 << 2,  ## Right rail (tactical lights)
	SIGHTS     = 1 << 3,  ## Top rail (scopes, red dots)
	UNDER      = 1 << 4,  ## Underbarrel (grenade launchers, grips)
}

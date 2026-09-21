# res://addons/cabra.lat_shooters/src/player/player_noise.gd
class_name PlayerNoise
extends RefCounted
## STEALTH layer: how loud the player is for the AI hearing system.
##
## The consumers are the bots: `NpcBot.emit_noise(position, loudness)` gates
## hearing by `radius = loudness * noise_radius_scale` and turns a hearer
## SUSPICIOUS. This class only computes/emits — no audio streams (those are
## `range`'s) and no bot state.
##
## Numbers (coordinator brief): sprint ~1.0, walk ~0.55, crouch ~0.25.
## Surfaces: concrete is the reference (1.0), soft ground is quieter (0.8).
## Modifiers come from data that already exists: Armor.sound_reduction (helmet,
## -1..0) and Attachment.sound_suppression (muzzle, 0..1).

const LOUDNESS_SPRINT := 1.0
const LOUDNESS_WALK := 0.55
const LOUDNESS_CROUCH := 0.25
const LOUDNESS_PRONE := 0.10
const LOUDNESS_SHOT := 2.0
const LOUDNESS_RELOAD := 0.6
const LOUDNESS_LAND_MAX := 1.2
const SURFACE_SOFT_FACTOR := 0.8

## Posture/step loudness. Pure so it is unit-testable without a scene.
static func posture_loudness(moving_state: String, crouching_state: String,
		planar_speed: float, on_floor: bool) -> float:
	if not on_floor or planar_speed < 0.15:
		return 0.0
	match crouching_state:
		"Proning":
			return LOUDNESS_PRONE
		"Crouching":
			return LOUDNESS_CROUCH
	match moving_state:
		"Sprinting":
			return LOUDNESS_SPRINT
	if planar_speed > 0.5:
		return LOUDNESS_WALK
	return 0.0

static func surface_factor(is_soft_ground: bool) -> float:
	return SURFACE_SOFT_FACTOR if is_soft_ground else 1.0

## Helmet sound_reduction is negative (-1..0): -0.2 removes 20% of the noise.
## Suppression is 0..1 and only applies to the muzzle blast.
static func apply_modifiers(base: float, helmet_reduction: float, suppression: float) -> float:
	var m := 1.0 + clampf(helmet_reduction, -1.0, 0.0)
	m *= 1.0 - clampf(suppression, 0.0, 1.0)
	return maxf(base * m, 0.0)

## Landing loudness scales with the impact speed (m/s).
static func land_loudness(impact_speed: float) -> float:
	if impact_speed <= 0.0:
		return 0.0
	return clampf(impact_speed / 8.0, 0.1, 1.0) * LOUDNESS_LAND_MAX

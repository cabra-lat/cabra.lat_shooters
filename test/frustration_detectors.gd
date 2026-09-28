class_name FrustrationDetectors
extends RefCounted
## Slice 2a: DEATH_SPIRE and UNREACHABLE (card 01ba6d, range).
##
## BOTH ARE PURE FUNCTIONS OVER AN EVENT STREAM, deliberately. A detector that
## needs a live arena to be tested can only be tested by a run that sometimes
## produces the condition, which is a detector nobody can demonstrate failing.
## So each takes recorded events and returns a verdict, and the acceptance can
## feed it a scenario where the thing IS wrong and a scenario where it is not.
##
## EVERY THRESHOLD IS CITED IN THE OUTPUT. DEATH_SPIRE is a TWO-parameter claim
## ("three deaths within 15 m"), and the radius is a CHOICE that changes which
## deaths count as one cluster -- 15 m and 50 m give different verdicts on the
## same data. A verdict that does not print the parameters cannot be checked by
## the person reading it, and the reader's only option is to trust a count.
##
## THE RESPAWN-GEOMETRY GUARD IS THE POINT OF DEATH_SPIRE. "Three deaths within
## 15 m of each other" is not the same claim as "the player did something three
## times in one place". If the arena respawns the player at a fixed point, every
## death is at that point, the cluster condition is satisfied trivially, and the
## detector reports a death spiral that is really the spawn solver. So a cluster
## whose members are all at the respawn location is reported as
## RESPAWN_GEOMETRY, a different verdict with a different owner, never as a
## player-facing finding. Finding that early is worth more than the detector.

## A death, as fed in by the caller. Kept as a plain Dictionary so the detector
## does not depend on the arena's types and can be fed synthetic events.
static func death(t: float, pos: Vector3) -> Dictionary:
	return {"t": t, "pos": pos}


const SPIRE_COUNT := 3
const SPIRE_RADIUS := 15.0
const SPIRE_WINDOW := 180.0  ## seconds; a "one raid" cluster, not a whole match
## The respawn anchor is a per-team CONSTANT (mode.get_spawn) but the solver
## scatters it over rings: arena_spawn_solver RINGS=3 x SEPARATION=0.7 = 2.1 m.
## So one logical respawn site legitimately spans 2.1 m, and an exclusion radius
## SMALLER than that would exclude a region the player cannot respawn in.
const RESPAWN_SPREAD := 2.1
## An authored spawn point can be used when the anchor is occupied, so a death
## near one is ambiguous rather than player-caused. Under-counting a spire is
## the safe error: a false spire sends a player to a bug that is not there.
const RAID_DURATION := 600.0  ## arena_manager_core.gd:22
const UNREACHABLE_SECONDS := 20.0
const UNREACHABLE_GAIN := 0.5  ## metres of closest approach that counts as progress


## DEATH_SPIRE. Returns a verdict Dictionary; never a bare bool, because the
## parameters and the members are the evidence.
##
## respawn_point: if supplied and a qualifying cluster sits on it, the verdict is
## RESPAWN_GEOMETRY. Pass Vector3.INF when there is no fixed respawn point.
static func death_spire(deaths: Array, respawn_points: Array = []) -> Dictionary:
	var res: Dictionary = {
		"verdict": "NO_SPIRE", "cluster": [], "count": 0, "samples": 0,
		"radius_m": SPIRE_RADIUS, "min_count": SPIRE_COUNT,
		"window_s": SPIRE_WINDOW, "centroid": Vector3.ZERO,
		"reason": "",
	}
	# Keep only this raid's deaths, then find the DENSEST cluster rather than the
	# first triple: "first three that qualify" reports whichever cluster the log
	# happened to reach first, which is an artefact of ordering, not severity.
	# Exclusions are computed from the points the bot ACTUALLY respawned at, not
	# from a constant in the harness. Each entry is {pos, authored: bool}.
	var exclusions: Array = []
	for rp in respawn_points:
		var reach: float = float(SPIRE_RADIUS) + RESPAWN_SPREAD
		var e := {
			"pos": (rp as Dictionary)["pos"],
			"authored": bool((rp as Dictionary).get("authored", false)),
			"reach": reach,
		}
		exclusions.append(e)
	# Partition, but do NOT discard: a death near a respawn point is excluded from the
	# PLAYER-CAUSED spire and it is ALSO the evidence for the geometry terminal.
	# Dropping it silently turned a respawn cluster into NO_SPIRE, which reads as
	# "the player died in three different places" -- the exact inverse of the truth.
	var in_window: Array = []
	var excluded: Array = []
	for d in deaths:
		if float(d["t"]) > SPIRE_WINDOW:
			continue
		var hit: Dictionary = {}
		for e in exclusions:
			if (d["pos"] as Vector3).distance_to(e["pos"]) <= float(e["reach"]):
				hit = e
				break
		if hit.is_empty():
			in_window.append(d)
		else:
			excluded.append({"death": d, "excluded_by": hit})
	var best: Array = []
	for i in in_window.size():
		var seed: Dictionary = in_window[i]
		var cluster: Array = [seed]
		for j in in_window.size():
			if j == i:
				continue
			var other: Dictionary = in_window[j]
			if seed["pos"].distance_to(other["pos"]) <= SPIRE_RADIUS:
				cluster.append(other)
		if cluster.size() > best.size():
			best = cluster
	res["excluded"] = excluded.size()
	# The respawn-attributable cluster is checked FIRST, on the excluded deaths,
	# because a spire at a respawn site is a different defect with a different
	# owner and must not be reported as a player-caused spire.
	if _cluster_of(excluded).size() >= SPIRE_COUNT:
		var ex: Array = _cluster_of(excluded)
		var c2 := Vector3.ZERO
		var authored := false
		for x in ex:
			c2 += (x["death"] as Dictionary)["pos"]
			if bool((x["excluded_by"] as Dictionary)["authored"]):
				authored = true
		c2 /= float(ex.size())
		res["cluster"] = ex
		res["count"] = ex.size()
		res["centroid"] = c2
		res["verdict"] = "RESPAWN_AMBIGUOUS" if authored else "RESPAWN_GEOMETRY"
		var which := "the team anchor, spread over the solver 2.1 m"
		if authored:
			which = "an authored fallback point, which can be anywhere on the map"
		res["reason"] = "%d deaths within %.1f m of the respawn point the bot ACTUALLY used (%s), excluded from the player-caused spire" % [
			ex.size(), float(SPIRE_RADIUS) + RESPAWN_SPREAD, which]
		return res
	if best.size() < SPIRE_COUNT:
		res["reason"] = "densest cluster is %d of %d required within %.0f m (%d of %d deaths excluded as respawn-attributable, exclusion reach %.1f m)" % [
			best.size(), SPIRE_COUNT, SPIRE_RADIUS, excluded.size(), deaths.size(),
			float(SPIRE_RADIUS) + RESPAWN_SPREAD]
		return res
	var c := Vector3.ZERO
	for d in best:
		c += d["pos"]
	res["cluster"] = best
	res["count"] = best.size()
	res["centroid"] = c / float(best.size())
	res["verdict"] = "DEATH_SPIRE"
	res["reason"] = "%d deaths within %.0f m of each other" % [best.size(), SPIRE_RADIUS]
	res["samples"] = best.size()
	# The guard, on the RUNTIME respawn points. A cluster sitting on a point the
	# bot really respawned at is the spawn solver's story, not the player's --
	# and it must fire on the point actually used, or a solver-spread cluster
	# slips past a check that only knows the constant anchor.
	var nearest: Dictionary = {}
	var nearest_d := INF
	for e in exclusions:
		var dd: float = float(res["centroid"].distance_to(e["pos"]))
		if dd < nearest_d:
			nearest_d = dd
			nearest = e
	if not nearest.is_empty() and nearest_d <= float(SPIRE_RADIUS) + RESPAWN_SPREAD:
		res["verdict"] = "RESPAWN_GEOMETRY" if not bool(nearest["authored"]) else "RESPAWN_AMBIGUOUS"
		res["reason"] = "cluster centroid is %.2f m from the respawn point the bot ACTUALLY used (%s), so the deaths are co-located by the spawn solver rather than by player action" % [
			nearest_d, "an authored fallback point" if bool(nearest["authored"]) else "the team anchor"]
	elif _is_stationary_cluster(best):
		res["verdict"] = "SPAWN_ADJACENT"
		res["reason"] = "every member within 2 m of the centroid: a fixed-spawn signature"
	return res


## A cluster whose members are all essentially on top of each other is the
## signature of a fixed respawn point even when the respawn point was not
## supplied -- worth naming rather than reporting as a death spiral.
static func _is_stationary_cluster(cluster: Array) -> bool:
	if cluster.size() < 2:
		return false
	var c := Vector3.ZERO
	for d in cluster:
		c += d["pos"]
	c /= float(cluster.size())
	for d in cluster:
		if c.distance_to(d["pos"]) > 2.0:
			return false
	return true


## UNREACHABLE: an objective the bot paths toward for `UNREACHABLE_SECONDS`
## without arriving. "Without arriving" is NOT "without moving": a bot that
## closes to within a metre and oscillates is unreachable in the sense that
## matters, and one that walks 19 m and stops is a different bug. So the
## verdict reports the CLOSEST APPROACH and whether it was still improving,
## because those two separate "cannot get there" from "gave up".
static func unreachable(samples: Array, target: Vector3) -> Dictionary:
	var res: Dictionary = {
		"verdict": "REACHED_OR_ARRIVING", "seconds": 0.0,
		"closest_m": INF, "closed_m": 0.0, "still_improving": false,
		"threshold_s": UNREACHABLE_SECONDS, "gain_m": UNREACHABLE_GAIN,
		"samples": samples.size(), "reason": "",
	}
	if samples.size() < 2:
		res["verdict"] = "VOID"
		res["reason"] = "fewer than 2 samples: nothing to judge, and VOID is not REACHED"
		return res
	var t0 := float(samples[0]["t"])
	var d0 := float(samples[0]["pos"].distance_to(target))
	var closest := d0
	var closest_t := t0
	for s in samples:
		var t := float(s["t"])
		var d := float(s["pos"].distance_to(target))
		if d < closest:
			closest = d
			closest_t = t
	res["seconds"] = float(samples[samples.size() - 1]["t"]) - t0
	res["closest_m"] = closest
	res["closed_m"] = d0 - closest
	# "Still improving" must be a TREND IN THE LAST WINDOW, not time-since-closest.
	# A static bot sits at its closest approach forever, so a time-since-closest
	# test calls it improving indefinitely -- which is exactly backwards, since a
	# bot that stopped moving is the definition of not progressing. Compare the
	# final distance against the distance a window ago and ask whether it SHRANK.
	var last_d: float = float(samples[samples.size() - 1]["pos"].distance_to(target))
	var back: int = maxi(0, samples.size() - 1 - int(UNREACHABLE_SECONDS))
	var prev_d: float = float(samples[back]["pos"].distance_to(target))
	res["still_improving"] = (prev_d - last_d) >= UNREACHABLE_GAIN
	res["trend_m"] = prev_d - last_d
	if res["seconds"] < UNREACHABLE_SECONDS:
		res["verdict"] = "REACHED_OR_ARRIVING"
		res["reason"] = "only %.1f s elapsed, under the %.0f s threshold" % [res["seconds"], UNREACHABLE_SECONDS]
		return res
	# Arrived beats everything: if it got close enough, the pathing worked.
	if closest <= 2.0:
		res["verdict"] = "ARRIVED"
		res["reason"] = "closed to %.2f m, within the 2 m arrival radius" % closest
		return res
	if res["closed_m"] >= UNREACHABLE_GAIN and res["still_improving"]:
		res["verdict"] = "SLOW_PROGRESS"
		res["reason"] = "closed %.2f m and was still improving at the end: a slow path, not a wall" % res["closed_m"]
		return res
	res["verdict"] = "UNREACHABLE"
	res["reason"] = "%.1f s elapsed, closest approach %.2f m, closed only %.2f m" % [
		res["seconds"], closest, res["closed_m"]]
	return res


## One line per finding, with the parameters that produced it. A verdict a reader
## cannot check is a verdict they have to believe.
static func report_line(kind: String, res: Dictionary) -> String:
	return "[%s] %s: %s (params: radius=%.0f m, min_count=%d, window=%.0f s / threshold=%.0f s, samples=%d) %s" % [
		res.get("verdict", "?"), kind, res.get("reason", ""),
		float(res.get("radius_m", 0.0)), int(res.get("min_count", 0)),
		float(res.get("window_s", 0.0)), float(res.get("threshold_s", 0.0)),
		int(res.get("samples", 0)), _members(res)]


## SLOW_CONTACT, as DAMAGE_CONTACT and never as hostile.
##
## WHY NOT "hostile": hostility is not carried by the damage path at all.
## health.gd:6 is `signal health_changed(body_part, old_health, new_health)`,
## :101 is `take_ballistic_damage(impact, hit_location, ammo, face)` with no
## source, and BallisticsImpact has no shooter field -- ricochet, penetration,
## fragments, energies, thickness, angle, counts, damage, and nothing that says
## who fired. A detector reporting HOSTILE_CONTACT would assert something the
## data cannot support. If a friendly-fire concept is ever introduced, this
## label has to change with it rather than being quietly assumed.
##
## WHY NO NEW SIGNAL: health_changed already fires on every hit the player takes,
## arena_manager.gd:1031 already subscribes to it, and the detector already has
## the player in hand. The first emission after an approach begins IS the contact
## event, the player's position then IS the contact position, and the raid clock
## IS the clock. Zero production lines.
##
## TWO LIMITATIONS, both recorded rather than smoothed over:
##  1. health_changed fires from inside take_ballistic_damage at :124, so a
##     NON-BALLISTIC source of player damage is not observed. If bots ever hurt
##     the player by another route, SLOW_CONTACT misses it silently.
##  2. A signal that is connected but never emitted reads exactly like a signal
##     that does not exist, so the acceptance must feed a synthetic emission and
##     show the detector DECIDE.
static func slow_contact(raid_start: float, first_damage_t: float, reached_by: float) -> Dictionary:
	var res: Dictionary = {
		"verdict": "NO_CONTACT", "contact_s": -1.0, "raid_duration_s": RAID_DURATION,
		"threshold_s": -1.0, "reached_by_s": reached_by, "label": "DAMAGE_CONTACT",
		"note": "hostility is NOT carried by the damage path; this is damage contact",
	}
	res["contact_s"] = first_damage_t - raid_start
	if res["contact_s"] >= RAID_DURATION:
		res["verdict"] = "SLOW_CONTACT"
		res["threshold_s"] = RAID_DURATION
		res["reason"] = "first damage at %.1f s, at or past the %.0f s raid duration" % [
			res["contact_s"], RAID_DURATION]
	else:
		res["reason"] = "first damage at %.1f s, inside the %.0f s raid duration" % [
			res["contact_s"], RAID_DURATION]
	return res


static func _members(res: Dictionary) -> String:
	var c: Array = res.get("cluster", [])
	if c.is_empty():
		return ""
	var parts: Array[String] = []
	for d in c:
		parts.append("t=%.1f (%.0f, %.0f, %.0f)" % [float(d["t"]), d["pos"].x, d["pos"].y, d["pos"].z])
	return "members: " + ", ".join(parts)


## Densest cluster among the respawn-attributable deaths, using the same radius
## the exclusion used so the two agree by construction.
static func _cluster_of(excluded: Array) -> Array:
	var best: Array = []
	for i in excluded.size():
		var seed: Vector3 = (excluded[i]["death"] as Dictionary)["pos"]
		var c: Array = [excluded[i]]
		for j in excluded.size():
			if j == i:
				continue
			var o: Vector3 = (excluded[j]["death"] as Dictionary)["pos"]
			if seed.distance_to(o) <= float(SPIRE_RADIUS) + RESPAWN_SPREAD:
				c.append(excluded[j])
		if c.size() > best.size():
			best = c
	return best

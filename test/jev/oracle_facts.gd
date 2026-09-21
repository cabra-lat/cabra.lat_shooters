# res://addons/cabra.lat_shooters/test/jev/oracle_facts.gd
#
# Shared, dependency-free oracle logic (TEST TOOLCHAIN — never shipped).
#
# Leaf module: preloads nothing, so both `oracle.gd` and the backends can use it
# without a cyclic preload. Holds:
#   - the exact fact extraction (code computes; models judge),
#   - the typed question map (game domain),
#   - the deterministic verdict rules (the ONLY truth in CI),
#   - the tolerant response parser for model envelopes (Jev Zen and Laya).
class_name OracleFacts
extends RefCounted

const QUESTION_IDS: Array[String] = ["hud_matches_state", "shot_valid", "bug_class", "coherence"]

# Rough width of one HUD ammo digit in px at the default 1280x720 layout. Used
# only to express the ammo desync as a screen-space offset; it is an estimate,
# labelled as such in the facts block.
const PX_PER_ROUND := 12.0
const MIN_PLAUSIBLE_M := 1.0
const MAX_PLAUSIBLE_M := 500.0

# ─── FACT EXTRACTION (code computes, models judge) ──
static func compute_facts(state: Dictionary) -> Dictionary:
	var weapons: Array = state.get("weapons", [])
	var equipped_id := ""
	var feed_count := 0
	var capacity := 0
	var equipped_hud_text := ""
	for w in weapons:
		if w is Dictionary and bool(w.get("equipped", false)):
			equipped_id = str(w.get("id", ""))
			feed_count = int(w.get("feed_count", 0))
			capacity = int(w.get("capacity", 0))
			equipped_hud_text = str(w.get("hud_text", ""))
			break

	var hud: Dictionary = state.get("hud", {})
	var hud_remaining := int(hud.get("ammo_remaining", -1))
	var hud_capacity := int(hud.get("ammo_capacity", capacity))
	var hud_text := str(hud.get("ammo_text", equipped_hud_text))
	var hud_weapon := str(hud.get("weapon_id", equipped_id))

	var expected_text := "%d/%d" % [feed_count, capacity] if capacity > 0 else str(feed_count)
	var delta := hud_remaining - feed_count if hud_remaining >= 0 else 0

	var entities: Array = state.get("entities", [])
	var alive := 0
	for e in entities:
		if e is Dictionary and bool(e.get("alive", false)):
			alive += 1

	var shot: Dictionary = state.get("last_shot", {})
	var fired := bool(shot.get("fired", false))
	var hit := bool(shot.get("hit", false))
	var hit_entity := str(shot.get("hit_entity_id", ""))
	var hit_type := str(shot.get("hit_type", ""))
	var own_weapon := bool(shot.get("hit_own_weapon", false))
	var dist := float(shot.get("hit_distance_m", -1.0))
	if hit_entity != "" and hit_entity == equipped_id:
		own_weapon = true
	if hit and dist >= 0.0 and dist < MIN_PLAUSIBLE_M:
		own_weapon = true
	var plausible := dist >= MIN_PLAUSIBLE_M and dist <= MAX_PLAUSIBLE_M

	return {
		"note": "Facts computed exactly in code. Judge coherence; do not recompute.",
		"frame": int(state.get("frame", -1)),
		"equipped_weapon": equipped_id,
		"feed_count": feed_count,
		"capacity": capacity,
		"hud_weapon": hud_weapon,
		"hud_remaining": hud_remaining,
		"hud_capacity": hud_capacity,
		"hud_text": hud_text,
		"expected_hud_text": expected_text,
		"hud_weapon_matches": hud_weapon == equipped_id,
		"ammo_delta": delta,
		"ammo_delta_px": float(delta) * PX_PER_ROUND,
		"alive_entities": alive,
		"total_entities": entities.size(),
		"shot_fired": fired,
		"shot_hit": hit,
		"shot_hit_entity": hit_entity,
		"shot_hit_type": hit_type,
		"shot_hit_own_weapon": own_weapon,
		"shot_distance_m": dist,
		"shot_distance_plausible": plausible,
	}

# ─── QUESTIONS (game domain) ────────────────────────
# `lang` defaults to env ORACLE_QUESTIONS_LANG, then "pt". Use "en" for the
# English-only Laya base checkpoint (see README: language is a real confound).
static func build_questions(lang := "") -> Dictionary:
	var l := lang.strip_edges().to_lower()
	if l == "":
		l = OS.get_environment("ORACLE_QUESTIONS_LANG").strip_edges().to_lower()
	if l.begins_with("en"):
		return build_questions_en()
	return build_questions_pt()

static func build_questions_en() -> Dictionary:
	return {
		"hud_matches_state": {
			"type": "noul",
			"instructions": "Does the ammo count shown on the HUD match the actual internal magazine round count of the equipped weapon?",
		},
		"shot_valid": {
			"type": "noul",
			"instructions": "Did the shot hit a real target at a plausible combat distance, rather than the shooter's own weapon or body?",
		},
		"bug_class": {
			"type": "choice",
			"instructions": "Which single defect is dominant in this frame?",
			"criteria": {
				"none": "no defect: HUD and shot are coherent",
				"hud_desync": "HUD disagrees with the internal magazine count",
				"self_hit": "the shot hit the shooter's own weapon/body",
				"stale_rig": "stale rig: the shot hits nothing although the HUD is coherent",
				"lean_no_translate": "lean did not translate the camera/pose as expected",
				"outro": "defect outside the categories above",
			},
			"allow_none": true,
		},
		"coherence": {
			"type": "score",
			"instructions": "How coherent is the bot behavior in this frame?",
			"criteria": ["incoherent", "partial", "coherent"],
		},
	}

static func build_questions_pt() -> Dictionary:
	return {
		"hud_matches_state": {
			"type": "noul",
			"instructions": "A contagem de munição exibida no HUD bate exatamente com a do feed interno da arma equipada?",
		},
		"shot_valid": {
			"type": "noul",
			"instructions": "O disparo registrado acertou uma entidade real a uma distância plausível de combate, e não a própria arma ou o próprio atirador?",
		},
		"bug_class": {
			"type": "choice",
			"instructions": "Classifique o defeito dominante no frame.",
			"criteria": {
				"none": "nenhum defeito: HUD e disparo coerentes",
				"hud_desync": "HUD divergente do feed interno",
				"self_hit": "disparo atingiu a própria arma/atirador",
				"stale_rig": "pose/rig desatualizado: disparo não acerta nada apesar de HUD coerente",
				"lean_no_translate": "lean não transladou a câmera/pose como esperado",
				"outro": "defeito fora das categorias acima",
			},
			"allow_none": true,
		},
		"coherence": {
			"type": "score",
			"instructions": "Quão coerente é o comportamento do bot neste frame?",
			"criteria": ["incoerente", "parcial", "coerente"],
		},
	}

# ─── DETERMINISTIC RULES (the only truth in CI) ─────
static func local_verdicts(state: Dictionary) -> Dictionary:
	return verdicts_from_facts(compute_facts(state))

# `facts` is the output of compute_facts (or a raw state with the same keys).
static func verdicts_from_facts(facts: Dictionary) -> Dictionary:
	var hud_ok := int(facts.get("ammo_delta", 0)) == 0 \
		and (str(facts.get("hud_text", "")) == "" or str(facts.get("hud_text", "")) == str(facts.get("expected_hud_text", "")))
	var shot_ok := bool(facts.get("shot_fired", false)) and bool(facts.get("shot_hit", false)) \
		and not bool(facts.get("shot_hit_own_weapon", false)) \
		and bool(facts.get("shot_distance_plausible", false)) \
		and str(facts.get("shot_hit_entity", "")) != ""

	var bug := "none"
	if bool(facts.get("shot_hit_own_weapon", false)):
		bug = "self_hit"
	elif not hud_ok:
		bug = "hud_desync"
	elif bool(facts.get("shot_fired", false)) and not bool(facts.get("shot_hit", false)):
		bug = "stale_rig"

	var score := 2
	if not hud_ok:
		score -= 1
	if not shot_ok:
		score -= 1
	if score < 0:
		score = 0

	return {
		"hud_matches_state": _verdict(hud_ok, 1.0, {}, "deterministic"),
		"shot_valid": _verdict(shot_ok, 1.0, {}, "deterministic"),
		"bug_class": _verdict(bug, 1.0, {}, "deterministic"),
		"coherence": _verdict(score, 1.0, {}, "deterministic"),
	}

static func _verdict(value: Variant, confidence: float, probabilities: Dictionary, source: String) -> Dictionary:
	return {"value": value, "confidence": confidence, "probabilities": probabilities, "source": source, "present": true}

# ─── TOLERANT RESPONSE PARSER ───────────────────────
# Accepts Jev Zen and Laya envelopes:
#   Jev : {answers:{id:{value|choice,confidence,probabilities}}}
#   Laya: {answers:{id:{type:"noul",noul:0.49,confidence:...}}}
#         {answers:{id:{type:"score",score:1.7,probabilities,confidence}}}
#         {answers:{id:{type:"choice",choice:"hud_desync",probabilities,confidence}}}
static func extract_verdicts(response: Dictionary) -> Dictionary:
	var answers: Dictionary = response
	for key in ["answers", "results", "verdicts", "questions", "data"]:
		var cand: Variant = response.get(key)
		if cand is Dictionary and (cand as Dictionary).size() > 0:
			answers = cand
			break

	var out: Dictionary = {}
	for id in QUESTION_IDS:
		var entry: Variant = answers.get(id)
		if entry == null:
			out[id] = {"value": null, "confidence": -1.0, "probabilities": {}, "source": "model", "present": false}
			continue
		if not (entry is Dictionary):
			out[id] = {"value": entry, "confidence": -1.0, "probabilities": {}, "source": "model", "present": true}
			continue
		var d: Dictionary = entry
		var conf := float(_first_present(d, ["confidence", "conf", "certainty"], -1.0))
		var probs: Variant = _first_present(d, ["probabilities", "prob", "probs", "distribution"], {})

		if d.has("noul"):
			# noul is P(true); expose a bool at threshold 0.5, keep the probability.
			var p := float(d["noul"])
			out[id] = {
				"value": p >= 0.5,
				"confidence": conf if conf >= 0.0 else maxf(p, 1.0 - p),
				"probabilities": {"true": p, "false": 1.0 - p},
				"source": "model",
				"present": true,
			}
			continue

		var value: Variant = _first_present(d, ["value", "answer", "verdict", "result", "choice", "score"])
		out[id] = {
			"value": value,
			"confidence": conf,
			"probabilities": probs if probs is Dictionary else {},
			"source": "model",
			"present": value != null,
		}
	return out

static func _first_present(d: Dictionary, keys: Array, default: Variant = null) -> Variant:
	for k in keys:
		if d.has(k):
			return d[k]
	return default

# True when two states are told apart on both the HUD invariant and the bug class.
static func separates(a: Dictionary, b: Dictionary) -> bool:
	return verdict_value(a, "hud_matches_state") != verdict_value(b, "hud_matches_state") \
		and verdict_value(a, "bug_class") != verdict_value(b, "bug_class")

static func verdict_value(verdicts: Dictionary, id: String) -> Variant:
	var v: Variant = verdicts.get(id)
	if v is Dictionary:
		return (v as Dictionary).get("value")
	return null

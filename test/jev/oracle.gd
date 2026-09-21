# res://addons/cabra.lat_shooters/test/jev/oracle.gd
#
# Backend-agnostic judgment oracle (TEST TOOLCHAIN — never shipped).
#
# Golden rule: the model is a JUDGMENT engine, not a calculator. The oracle
# derives exact facts in code (OracleFacts.compute_facts), then asks ONE batched
# call of typed questions. The backend answers; the deterministic rules in
# OracleFacts are the only verdicts trusted in CI.
#
# Backend selection by env ORACLE_BACKEND:
#   jev           -> backend_jev_zen.gd        (cloud, credit-gated)
#   laya          -> backend_laya_local.gd     (local CPU, $0, slow)
#   deterministic -> backend_local_deterministic.gd (pure code, always works)
#   auto (default)-> laya if configured, else jev if key, else deterministic
#
# State schema (matches the SceneTree probes):
#   { frame, player, weapons[], hud, entities[], last_shot }
# See oracle_facts.gd for the full field list.
class_name Oracle
extends RefCounted

const Facts = preload("res://addons/cabra.lat_shooters/test/jev/oracle_facts.gd")
const OracleBackendScript = preload("res://addons/cabra.lat_shooters/test/jev/oracle_backend.gd")
const BackendJevZenScript = preload("res://addons/cabra.lat_shooters/test/jev/backend_jev_zen.gd")
const BackendLayaLocalScript = preload("res://addons/cabra.lat_shooters/test/jev/backend_laya_local.gd")
const BackendLocalDeterministicScript = preload("res://addons/cabra.lat_shooters/test/jev/backend_local_deterministic.gd")

const QUESTION_IDS: Array[String] = Facts.QUESTION_IDS

# ─── SHARED LOGIC DELEGATES (kept stable for callers) ──
static func compute_facts(state: Dictionary) -> Dictionary:
	return Facts.compute_facts(state)

static func build_questions() -> Dictionary:
	return Facts.build_questions()

static func local_verdicts(state: Dictionary) -> Dictionary:
	return Facts.local_verdicts(state)

static func verdicts_from_facts(facts: Dictionary) -> Dictionary:
	return Facts.verdicts_from_facts(facts)

static func extract_verdicts(response: Dictionary) -> Dictionary:
	return Facts.extract_verdicts(response)

static func separates(a: Dictionary, b: Dictionary) -> bool:
	return Facts.separates(a, b)

static func verdict_value(verdicts: Dictionary, id: String) -> Variant:
	return Facts.verdict_value(verdicts, id)

# ─── BACKEND SELECTION ──────────────────────────────
static func backend_choice() -> String:
	var c := OS.get_environment("ORACLE_BACKEND").strip_edges().to_lower()
	return c if c != "" else "auto"

# host: a Node already inside the scene tree (used for HTTPRequest children).
static func select_backend(host: Node = null, model := "") -> OracleBackend:
	var choice := backend_choice()
	if choice == "jev":
		return BackendJevZenScript.new(host, model)
	if choice == "laya":
		return BackendLayaLocalScript.new(host)
	if choice == "deterministic":
		return BackendLocalDeterministicScript.new()
	# auto: local model first (no credit dependency), then cloud, then pure code.
	var laya: OracleBackend = BackendLayaLocalScript.new(host)
	if bool(laya.available().get("available", false)):
		return laya
	var jev: OracleBackend = BackendJevZenScript.new(host, model)
	if bool(jev.available().get("available", false)):
		return jev
	return BackendLocalDeterministicScript.new()

# What `auto` would pick, with per-backend reasons. No network, no run.
static func selection_report(host: Node = null, model := "") -> Dictionary:
	var laya: OracleBackend = BackendLayaLocalScript.new(host)
	var jev: OracleBackend = BackendJevZenScript.new(host, model)
	var det: OracleBackend = BackendLocalDeterministicScript.new()
	return {
		"choice": backend_choice(),
		"selected": select_backend(host, model).backend_name(),
		"laya": laya.available(),
		"jev": jev.available(),
		"deterministic": det.available(),
	}

# ─── EVALUATION ─────────────────────────────────────
# Returns:
#   { ok, backend, facts, local, verdicts?, raw?, latency_ms, persisted?,
#     gated?, gate_reason?, error?, error_type? }
func evaluate(state: Dictionary, host: Node = null, model := "") -> Dictionary:
	var facts := Facts.compute_facts(state)
	var backend: OracleBackend = select_backend(host, model)
	var out := {
		"backend": backend.backend_name(),
		"facts": facts,
		"local": Facts.verdicts_from_facts(facts),
	}
	var res: Dictionary = await backend.predict(facts, Facts.build_questions())
	if not bool(res.get("ok", false)):
		out["ok"] = false
		out["gated"] = bool(res.get("gated", false))
		out["gate_reason"] = str(res.get("gate_reason", ""))
		out["error"] = str(res.get("error", ""))
		out["error_type"] = str(res.get("error_type", ""))
		out["latency_ms"] = float(res.get("latency_ms", -1.0))
		return out
	out["ok"] = true
	out["gated"] = false
	out["error"] = ""
	out["verdicts"] = Facts.extract_verdicts(res.get("answers", {}))
	out["raw"] = str(res.get("raw", ""))
	out["latency_ms"] = float(res.get("latency_ms", -1.0))
	out["persisted"] = str(res.get("persisted", ""))
	return out

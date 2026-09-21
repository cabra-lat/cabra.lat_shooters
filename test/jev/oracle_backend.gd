# res://addons/cabra.lat_shooters/test/jev/oracle_backend.gd
#
# Backend contract for the judgment oracle (TEST TOOLCHAIN — never shipped).
#
# A backend answers the typed-question protocol (noul / choice / score) given a
# state of *computed facts*. Implementations:
#   - backend_local_deterministic.gd : pure code rules (the only CI truth)
#   - backend_jev_zen.gd             : OpenCode Zen / Jev (cloud, credit-gated)
#   - backend_laya_local.gd          : Laya CPU, local, $0 (serve or decide)
#
# Contract of predict():
#   { ok: bool, backend: String, answers: Dictionary, raw: String,
#     latency_ms: float, persisted: String,
#     error: String, error_type: String, gated: bool, gate_reason: String }
#
# `answers` is the raw envelope; oracle.gd normalizes it with
# OracleFacts.extract_verdicts(). A backend must fail clean — never crash and
# never invent an answer.
class_name OracleBackend
extends RefCounted

func backend_name() -> String:
	return "base"

# Cheap, non-network readiness signal used by `auto` selection.
func available() -> Dictionary:
	return {"available": false, "reason": "base backend"}

func predict(_state: Dictionary, _questions: Dictionary) -> Dictionary:
	return OracleBackend.make_failure(backend_name(), "backend not implemented", "not_implemented")

static func make_failure(backend: String, message: String, error_type: String,
		gated := false, gate_reason := "", latency_ms := -1.0) -> Dictionary:
	return {
		"ok": false,
		"backend": backend,
		"error": message,
		"error_type": error_type,
		"gated": gated,
		"gate_reason": gate_reason,
		"answers": {},
		"raw": "",
		"latency_ms": latency_ms,
		"persisted": "",
	}

static func make_success(backend: String, answers: Dictionary, raw: String,
		latency_ms := -1.0, persisted := "") -> Dictionary:
	return {
		"ok": true,
		"backend": backend,
		"error": "",
		"error_type": "",
		"gated": false,
		"gate_reason": "",
		"answers": answers,
		"raw": raw,
		"latency_ms": latency_ms,
		"persisted": persisted,
	}

# Persist raw request/response under /tmp/shooter/jev/ (scratch; never in repo).
static func persist(tag: String, request_text: String, response_text: String) -> String:
	var dir := "/tmp/shooter/jev"
	var made := DirAccess.make_dir_recursive_absolute(dir)
	if made != OK and made != ERR_ALREADY_EXISTS:
		return ""
	var stamp := Time.get_datetime_string_from_system(false, false).replace(":", "-")
	var base := "%s/%s_%s" % [dir, tag, stamp]
	_write(base + "_req.json", request_text)
	_write(base + "_resp.json", response_text)
	return base

static func _write(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(content)
	f.close()

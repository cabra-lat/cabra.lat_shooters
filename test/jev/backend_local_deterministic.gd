# res://addons/cabra.lat_shooters/test/jev/backend_local_deterministic.gd
#
# Deterministic oracle backend (TEST TOOLCHAIN — never shipped).
#
# Pure code rules over computed facts: HUD vs internal feed, self-hit, plausible
# distance. This is the DEFAULT when no model responds, and the ONLY backend
# whose verdicts may be treated as truth in CI. It cannot be gated, is offline,
# and runs in microseconds.
class_name BackendLocalDeterministic
extends OracleBackend

const Facts = preload("res://addons/cabra.lat_shooters/test/jev/oracle_facts.gd")

func backend_name() -> String:
	return "deterministic"

func available() -> Dictionary:
	return {"available": true, "reason": "pure code rules; always available"}

func predict(state: Dictionary, _questions: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	# `state` is already the computed facts block.
	var answers := Facts.verdicts_from_facts(state)
	var latency_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	return make_success(backend_name(), answers, JSON.stringify(answers), latency_ms, "")

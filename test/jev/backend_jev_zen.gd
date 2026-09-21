# res://addons/cabra.lat_shooters/test/jev/backend_jev_zen.gd
#
# Jev (OpenCode Zen) oracle backend (TEST TOOLCHAIN — never shipped).
#
# Wraps the existing JevClient. Cloud route, fast (~250 ms), but GATED on Zen
# credit: `Insufficient account funds` (paid) or `FreeUsageLimitError` (free).
# The gate is surfaced as a clean failure — never an invented verdict.
class_name BackendJevZen
extends OracleBackend

const JevClientScript = preload("res://addons/cabra.lat_shooters/test/jev/jev_client.gd")

var _client: Node
var _model: String

func _init(host: Node = null, model := "") -> void:
	_model = model if model != "" else JevClientScript.DEFAULT_MODEL
	if host != null and host.get_script() == JevClientScript:
		_client = host
	elif host != null:
		_client = JevClientScript.new()
		host.add_child(_client)

func backend_name() -> String:
	return "jev-zen"

func model() -> String:
	return _model

func available() -> Dictionary:
	var key: Dictionary = JevClientScript.resolve_api_key()
	if str(key.get("key", "")) == "":
		return {"available": false, "reason": str(key.get("error", "no key"))}
	return {"available": true, "reason": "key via %s (credit unverified)" % str(key.get("source", "?"))}

func predict(state: Dictionary, questions: Dictionary) -> Dictionary:
	if _client == null:
		return make_failure(backend_name(), "no JevClient host; pass a Node when constructing the backend", "unconfigured")
	if not _client.is_inside_tree():
		return make_failure(backend_name(), "JevClient is not inside the scene tree; add host and await process_frame", "unconfigured")

	var t0 := Time.get_ticks_msec()
	var res: Dictionary = await _client.request(JSON.stringify(state), questions, _model)
	var latency_ms := float(Time.get_ticks_msec() - t0)

	if not bool(res.get("ok", false)):
		return make_failure(
			backend_name(),
			str(res.get("error", "jev request failed")),
			str(res.get("error_type", "unknown")),
			bool(res.get("gated", false)),
			str(res.get("gate_reason", "")),
			latency_ms)
	return make_success(backend_name(), res.get("response", {}), str(res.get("raw", "")), latency_ms, str(res.get("persisted", "")))

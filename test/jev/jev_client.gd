# res://addons/cabra.lat_shooters/test/jev/jev_client.gd
#
# Jev oracle HTTP client (TEST TOOLCHAIN — never shipped with the game).
#
# Talks to the OpenCode Zen "systemone" judgment route. No external dependency:
# plain HTTPRequest + JSON. Key resolution order:
#   1. env OPENCODE_API_KEY
#   2. env OPENCODE_ZEN_API_KEY
#   3. ~/.local/share/opencode/auth.json  -> providers.opencode.key
#      (fallback: providers.opencode-go.key)
#
# Failure policy: fail clean. No key, a 4xx, a transport error, or a credit/limit
# gate all return a verdict Dictionary and never crash the caller. Raw request
# and response are persisted under /tmp/shooter/jev/ (scratch; never in the repo).
#
# Usage:
#   var client := JevClient.new()
#   add_child(client)
#   var res: Dictionary = await client.request(state_text, questions)
#   if not res.ok:
#       print(res.gate_reason if res.gated else res.error)
class_name JevClient
extends Node

const ENDPOINT := "https://opencode.ai/zen/v1/systemone"
const DEFAULT_MODEL := "jev-1.13"
const SCRATCH_DIR := "/tmp/shooter/jev"
const TIMEOUT_SECONDS := 10.0
const MAX_ATTEMPTS := 2 # first try + 1 retry

var _http: HTTPRequest
var _key_cache := ""
var _key_source := ""

func _ready() -> void:
	if _http == null:
		_http = HTTPRequest.new()
		_http.timeout = TIMEOUT_SECONDS
		_http.use_threads = false
		add_child(_http)

# ─── KEY RESOLUTION ─────────────────────────────────
# Returns {key: String, source: String, error: String}. Never logs the key.
static func resolve_api_key() -> Dictionary:
	var k := OS.get_environment("OPENCODE_API_KEY").strip_edges()
	if k != "":
		return {"key": k, "source": "env:OPENCODE_API_KEY", "error": ""}
	k = OS.get_environment("OPENCODE_ZEN_API_KEY").strip_edges()
	if k != "":
		return {"key": k, "source": "env:OPENCODE_ZEN_API_KEY", "error": ""}

	var home := OS.get_environment("HOME")
	if home == "":
		return {"key": "", "source": "", "error": "HOME unset; cannot read auth.json"}
	var auth_path := home.path_join(".local/share/opencode/auth.json")
	if not FileAccess.file_exists(auth_path):
		return {"key": "", "source": "", "error": "no key: set OPENCODE_API_KEY or OPENCODE_ZEN_API_KEY (auth.json not found at %s)" % auth_path}
	var txt := FileAccess.get_file_as_string(auth_path)
	if txt == "":
		return {"key": "", "source": "", "error": "no key: auth.json at %s is empty/unreadable" % auth_path}
	var parsed: Variant = JSON.parse_string(txt)
	if not (parsed is Dictionary):
		return {"key": "", "source": "", "error": "no key: auth.json is not valid JSON" % []}
	var dict: Dictionary = parsed
	for provider in ["opencode", "opencode-go"]:
		var entry: Variant = dict.get(provider)
		if entry is Dictionary:
			var entry_dict: Dictionary = entry
			var raw: Variant = entry_dict.get("key")
			if raw is String and (raw as String).strip_edges() != "":
				return {"key": (raw as String).strip_edges(), "source": "auth.json:%s.key" % provider, "error": ""}
	return {"key": "", "source": "", "error": "no key: no usable 'key' under provider 'opencode' (or 'opencode-go') in %s" % auth_path}

func _ensure_key() -> bool:
	if _key_cache != "":
		return true
	var res := JevClient.resolve_api_key()
	_key_cache = res.key
	_key_source = res.source
	return _key_cache != ""

func key_source() -> String:
	return _key_source

# ─── REQUEST ────────────────────────────────────────
# state_text: the (usually JSON-serialized) state handed to Jev.
# questions:  {id: {type, instructions, ...}} typed question map.
# Returns:
#   { ok, gated, gate_reason, error, error_type, status, attempts,
#     model, response, raw, persisted }
func request(state_text: String, questions: Dictionary, model := DEFAULT_MODEL) -> Dictionary:
	if _http == null:
		# Allow use before _ready (e.g. a client that was never added to a tree).
		_http = HTTPRequest.new()
		_http.timeout = TIMEOUT_SECONDS
		add_child(_http)

	var out := {
		"ok": false,
		"gated": false,
		"gate_reason": "",
		"error": "",
		"error_type": "",
		"status": 0,
		"attempts": 0,
		"model": model,
		"response": {},
		"raw": "",
		"persisted": "",
	}

	if not _ensure_key():
		out.error = JevClient.resolve_api_key().error
		out.error_type = "no_key"
		return out

	if not is_inside_tree():
		out.error = "JevClient is not inside the scene tree; add it to the tree and await process_frame before request()"
		out.error_type = "unconfigured"
		return out

	var payload := {
		"model": model,
		"state": state_text,
		"questions": questions,
	}
	var body := JSON.stringify(payload)
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + _key_cache,
	])

	var attempt := 0
	while attempt < MAX_ATTEMPTS:
		attempt += 1
		out.attempts = attempt
		var err := _http.request(ENDPOINT, headers, HTTPClient.METHOD_POST, body)
		if err != OK:
			out.error = "HTTPRequest.request failed to start: %s" % error_string(err)
			out.error_type = "transport"
			continue
		var completed: Array = await _http.request_completed
		var result: int = completed[0]
		var status: int = completed[1]
		var resp_body: PackedByteArray = completed[3]
		var raw := resp_body.get_string_from_utf8()
		out.status = status
		out.raw = raw

		var parsed: Variant = JSON.parse_string(raw)
		out.response = parsed if parsed is Dictionary else {}

		if status >= 200 and status < 300 and parsed is Dictionary:
			out.ok = true
			out.persisted = _persist(model, body, raw, attempt)
			return out

		# Classify non-2xx.
		var cls := JevClient.classify(status, raw)
		out.gated = cls.gated
		out.gate_reason = cls.gate_reason
		out.error_type = cls.error_type
		out.error = cls.message
		out.persisted = _persist(model, body, raw, attempt)

		# A credit/limit gate is deterministic — retrying wastes time. Only
		# retry transport / 5xx / malformed conditions.
		if cls.gated:
			return out
		if status >= 500 or result != HTTPRequest.RESULT_SUCCESS:
			continue
		return out

	if out.error == "":
		out.error = "request failed after %d attempt(s)" % MAX_ATTEMPTS
		out.error_type = "transport"
	return out

# ─── RESPONSE CLASSIFICATION ────────────────────────
static func classify(status: int, raw: String) -> Dictionary:
	var error_type := ""
	var message := ""
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		var d: Dictionary = parsed
		var e: Variant = d.get("error")
		if e is Dictionary:
			var ed: Dictionary = e
			error_type = str(ed.get("type", ""))
			message = str(ed.get("message", ""))
		elif e != null:
			message = str(e)

	var joined := (raw + "\n" + message)
	var gated := false
	var gate_reason := ""
	if joined.find("Insufficient account funds") != -1:
		gated = true
		gate_reason = "Insufficient account funds — OpenCode Zen credit required for " + DEFAULT_MODEL
	elif joined.find("FreeUsageLimitError") != -1:
		gated = true
		gate_reason = "FreeUsageLimitError — free-tier rate limit exhausted"
	elif joined.find("insufficient_quota") != -1 or joined.find("quota") != -1 and status == 429:
		gated = true
		gate_reason = "quota/rate limit (status %d)" % status

	if error_type == "":
		if gated:
			error_type = "gated"
		elif status == 401 or status == 403:
			error_type = "auth"
		elif status == 429:
			error_type = "rate_limit"
		elif status >= 500:
			error_type = "server_error"
		elif status > 0:
			error_type = "http_%d" % status
		else:
			error_type = "transport"

	if message == "":
		message = "HTTP %d" % status if status > 0 else "no response"
	return {"gated": gated, "gate_reason": gate_reason, "error_type": error_type, "message": message}

# ─── SCRATCH PERSISTENCE ────────────────────────────
func _persist(model: String, req_body: String, resp_body: String, attempt: int) -> String:
	var dir_ok := DirAccess.make_dir_recursive_absolute(SCRATCH_DIR)
	if dir_ok != OK and dir_ok != ERR_ALREADY_EXISTS:
		return ""
	var stamp := Time.get_datetime_string_from_system(false, false).replace(":", "-")
	var base := "%s/%s_a%d_%s" % [SCRATCH_DIR, model, attempt, stamp]
	_write(base + "_req.json", req_body)
	_write(base + "_resp.json", resp_body)
	return base

func _write(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(content)
	f.close()

# ─── SELF-TEST (no network) ─────────────────────────
# Verifies gate classification and key resolution shape without spending a call.
static func self_test() -> Array:
	var checks: Array = []
	checks.append(_check("classify insufficient_funds",
		classify(500, '{"error":{"type":"server_error","message":"Upstream request failed: Insufficient account funds"}}').gated == true))
	checks.append(_check("classify free_limit",
		classify(429, '{"error":{"type":"FreeUsageLimitError"}}').gated == true))
	checks.append(_check("classify 200 not gated",
		classify(200, '{"ok":true}').gated == false))
	var key := resolve_api_key()
	checks.append(_check("key resolution shape has source", key.has("key") and key.has("source") and key.has("error")))
	return checks

static func _check(name: String, ok: bool) -> Dictionary:
	return {"name": name, "ok": ok, "detail": "" if ok else "FAILED"}

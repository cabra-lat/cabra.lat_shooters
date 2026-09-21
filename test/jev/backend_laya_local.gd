# res://addons/cabra.lat_shooters/test/jev/backend_laya_local.gd
#
# Laya local oracle backend (TEST TOOLCHAIN — never shipped).
#
# Laya is the open Apache-2.0 reproduction of Jev (ggmlc runtime, not
# llama.cpp). Its server speaks the SAME TypeSafe body as Jev: POST /v1/systemone
# with {model, state, questions}. Three transports, in preference order:
#   1. serve  : HTTP to `laya serve` (LAYA_ENDPOINT, default http://127.0.0.1:8080)
#   2. decide : one-shot subprocess `laya decide ... --json` (blocking, ~45 s CPU)
#   3. daemon : newline JSON-RPC over stdin/stdout (experimental; only when
#               LAYA_MODE=daemon is explicit)
#
# Mode selection: LAYA_MODE if set, else serve when LAYA_ENDPOINT is set, else
# decide when a `laya` binary is found. Nothing available -> clean failure.
#
# HONEST LIMITATION: the base typed-decisions checkpoint is ~chance zero-shot in
# our game domain (see docs/ai-local-models-survey.md). Treat its answers as an
# auxiliary signal with low confidence, never as truth. Domain value needs
# fine-tuning.
class_name BackendLayaLocal
extends OracleBackend

const DEFAULT_ENDPOINT := "http://127.0.0.1:8080"
const API_PATH := "/v1/systemone"
const DEFAULT_GGUF := "laya-models/laya_typed_decisions_ud_q4_k_m.gguf"
const FAMILY := "typed-decisions"
const DEFAULT_TIMEOUT_SECONDS := 180.0
const SCRATCH_DIR := "/tmp/shooter/jev/laya_run"

var _host: Node
var _http: HTTPRequest
var _mode := ""
var _endpoint := ""

func _init(host: Node = null) -> void:
	_host = host
	_mode = _resolve_mode()
	_endpoint = OS.get_environment("LAYA_ENDPOINT").strip_edges()
	if _endpoint == "":
		_endpoint = DEFAULT_ENDPOINT
	_endpoint = _endpoint.trim_suffix("/")

func backend_name() -> String:
	return "laya-local"

func mode() -> String:
	return _mode

func endpoint() -> String:
	return _endpoint

# ─── AVAILABILITY ───────────────────────────────────
func available() -> Dictionary:
	if _mode == "serve":
		var explicit := OS.get_environment("LAYA_ENDPOINT").strip_edges() != "" \
			or OS.get_environment("LAYA_MODE").strip_edges().to_lower() == "serve"
		if explicit:
			return {"available": true, "reason": "serve endpoint %s (unverified)" % _endpoint}
		return {"available": false, "reason": "no LAYA_ENDPOINT and no laya binary (set LAYA_ENDPOINT or build .#laya-cpu)"}
	var bin := _find_binary()
	if bin == "":
		return {"available": false, "reason": "laya binary not found (set LAYA_BIN, or `nix build .#laya-cpu` / `nix develop`)"}
	var gguf := _gguf_path()
	if gguf == "" or not FileAccess.file_exists(gguf):
		return {"available": false, "reason": "GGUF not found (set LAYA_MODEL or run `fetch-laya-model`)"}
	return {"available": true, "reason": "%s + %s" % [bin.get_file(), gguf.get_file()]}

func _resolve_mode() -> String:
	var m := OS.get_environment("LAYA_MODE").strip_edges().to_lower()
	if m == "serve" or m == "decide" or m == "daemon":
		return m
	if OS.get_environment("LAYA_ENDPOINT").strip_edges() != "":
		return "serve"
	if _find_binary() != "":
		return "decide"
	return "serve"

func _find_binary() -> String:
	var b := OS.get_environment("LAYA_BIN").strip_edges()
	if b != "" and FileAccess.file_exists(b):
		return b
	for dir in OS.get_environment("PATH").split(":", false):
		var p := dir.path_join("laya")
		if FileAccess.file_exists(p):
			return p
	for rel in ["laya-models/laya-cpu-manual", "result/bin/laya"]:
		var ap := ProjectSettings.globalize_path("res://" + rel)
		if FileAccess.file_exists(ap):
			return ap
	return ""

func _family() -> String:
	var f := OS.get_environment("LAYA_FAMILY").strip_edges()
	return f if f != "" else FAMILY

func _gguf_path() -> String:
	var g := OS.get_environment("LAYA_MODEL").strip_edges()
	if g != "" and FileAccess.file_exists(g):
		return g
	var ap := ProjectSettings.globalize_path("res://" + DEFAULT_GGUF)
	if FileAccess.file_exists(ap):
		return ap
	if FileAccess.file_exists(DEFAULT_GGUF):
		return DEFAULT_GGUF
	return ""

# ─── PREDICT ────────────────────────────────────────
func predict(state: Dictionary, questions: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var res: Dictionary
	if _mode == "serve":
		res = await _predict_serve(state, questions)
	elif _mode == "decide":
		res = _predict_decide(state, questions)
	elif _mode == "daemon":
		res = _predict_daemon(state, questions)
	else:
		res = make_failure(backend_name(), "unknown LAYA_MODE '%s'" % _mode, "bad_mode")
	res["latency_ms"] = float(Time.get_ticks_msec() - t0)
	return res

# (1) HTTP to `laya serve` — TypeSafe/Jev-compatible body.
func _predict_serve(state: Dictionary, questions: Dictionary) -> Dictionary:
	if _http == null:
		if _host == null or not _host.is_inside_tree():
			return make_failure(backend_name(), "serve transport needs a host Node inside the tree", "unconfigured")
		_http = HTTPRequest.new()
		_http.timeout = float(OS.get_environment("LAYA_TIMEOUT").to_float()) if OS.get_environment("LAYA_TIMEOUT") != "" else DEFAULT_TIMEOUT_SECONDS
		_host.add_child(_http)
	if not _http.is_inside_tree():
		return make_failure(backend_name(), "HTTPRequest not inside the tree; await process_frame", "unconfigured")

	# `model` selects the Laya family/route (see GET /v1/models), not a model id.
	var payload := {"model": _family(), "state": JSON.stringify(state), "questions": questions}
	var headers := PackedStringArray(["Content-Type: application/json"])
	var key := OS.get_environment("LAYA_API_KEY").strip_edges()
	if key == "":
		key = OS.get_environment("TYPESAFE_API_KEY").strip_edges()
	if key != "":
		headers.append("Authorization: Bearer " + key)

	var err := _http.request(_endpoint + API_PATH, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		return make_failure(backend_name(), "laya serve request failed to start: %s" % error_string(err), "transport")
	var completed: Array = await _http.request_completed
	var status: int = completed[1]
	var raw := (completed[3] as PackedByteArray).get_string_from_utf8()
	var persisted := persist("laya-serve", JSON.stringify(payload), raw)
	var parsed: Variant = JSON.parse_string(raw)
	if status < 200 or status >= 300 or not (parsed is Dictionary):
		return make_failure(backend_name(), "laya serve HTTP %d (is `laya serve` running at %s?)" % [status, _endpoint], "http_%d" % status)
	return make_success(backend_name(), parsed, raw, -1.0, persisted)

# (2) One-shot subprocess `laya decide ... --json` (blocking; ~45 s on CPU).
func _predict_decide(state: Dictionary, questions: Dictionary) -> Dictionary:
	var bin := _find_binary()
	if bin == "":
		return make_failure(backend_name(), "laya binary not found", "no_binary")
	var gguf := _gguf_path()
	if gguf == "" or not FileAccess.file_exists(gguf):
		return make_failure(backend_name(), "Laya GGUF not found (run fetch-laya-model or set LAYA_MODEL)", "no_model")

	DirAccess.make_dir_recursive_absolute(SCRATCH_DIR)
	var stamp := str(Time.get_ticks_usec())
	var state_file := SCRATCH_DIR.path_join("state_%s.json" % stamp)
	var q_file := SCRATCH_DIR.path_join("questions_%s.json" % stamp)
	_write_file(state_file, JSON.stringify(state))
	_write_file(q_file, JSON.stringify(questions))

	var threads := OS.get_environment("LAYA_THREADS").strip_edges()
	if threads == "":
		threads = "4"
	var args := PackedStringArray([
		"decide", gguf, "--family", FAMILY,
		"--state-file", state_file, "--questions-file", q_file,
		"--device", "cpu", "--threads", threads, "--json",
	])
	var out: Array = []
	var code := OS.execute(bin, args, out, true)
	var stdout := str(out[0]) if out.size() > 0 else ""
	var stderr := str(out[1]) if out.size() > 1 else ""
	var persisted := persist("laya-decide", JSON.stringify({"state": state, "questions": questions}), stdout)

	if code != 0:
		return make_failure(backend_name(), "laya decide exit %d: %s" % [code, stderr.strip_edges().substr(0, 400)], "laya_error")
	# `laya` logs a "[laya] ..." banner to stdout; skip to the JSON object.
	var parsed: Variant = _extract_json(stdout)
	if not (parsed is Dictionary):
		return make_failure(backend_name(), "laya decide produced non-JSON output", "laya_parse")
	return make_success(backend_name(), parsed, stdout, -1.0, persisted)

# (3) daemon: newline JSON-RPC over stdin/stdout (experimental, untested here —
# no CPU daemon has been run on this machine yet). Only used when explicit.
func _predict_daemon(state: Dictionary, questions: Dictionary) -> Dictionary:
	var bin := _find_binary()
	if bin == "":
		return make_failure(backend_name(), "laya binary not found for daemon", "no_binary")
	var pipe := OS.execute_with_pipe(bin, PackedStringArray(["daemon"]), false)
	if not (pipe is Dictionary) or not pipe.has("stdio"):
		return make_failure(backend_name(), "failed to spawn `laya daemon`", "daemon_spawn")
	var stdio: FileAccess = pipe["stdio"]
	var request := {"jsonrpc": "2.0", "id": 1, "method": "decide", "params": {"state": state, "questions": questions}}
	stdio.store_line(JSON.stringify(request))
	var line := stdio.get_line()
	var persisted := persist("laya-daemon", JSON.stringify(request), line)
	var parsed: Variant = _extract_json(line)
	if not (parsed is Dictionary):
		return make_failure(backend_name(), "laya daemon returned non-JSON line", "daemon_parse")
	var result: Variant = parsed.get("result", parsed)
	if not (result is Dictionary):
		return make_failure(backend_name(), "laya daemon JSON-RPC error: %s" % JSON.stringify(parsed.get("error", {})), "daemon_error")
	return make_success(backend_name(), result, line, -1.0, persisted)

# Parse the first JSON object in text, tolerating a leading log banner.
static func _extract_json(text: String) -> Variant:
	var start := text.find("{")
	if start == -1:
		return null
	var end := text.rfind("}")
	if end == -1 or end < start:
		return null
	return JSON.parse_string(text.substr(start, end - start + 1))

func _write_file(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(content)
	f.close()

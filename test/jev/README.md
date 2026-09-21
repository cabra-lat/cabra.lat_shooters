# Judgment oracle — backends (test toolchain)

Optional judgment layer for the test harness. **Not game code, not shipped.**

The oracle derives exact facts in code, then asks ONE batched call of typed
questions (`noul` / `choice` / `score`). A pluggable **backend** answers. The
deterministic rules are the only verdicts trusted in CI; models are auxiliary.

## Files

| File | Role |
|---|---|
| `oracle_facts.gd` | Leaf module: fact extraction, question maps (pt/en), deterministic rules, tolerant response parser. |
| `oracle_backend.gd` | Backend contract `predict(state, questions) -> Dictionary` + result helpers + scratch persistence. |
| `backend_local_deterministic.gd` | Pure-code rules. Default fallback; **the only CI truth**. |
| `backend_jev_zen.gd` | Jev via OpenCode Zen (cloud, credit-gated). Wraps `jev_client.gd`. |
| `backend_laya_local.gd` | Laya CPU, local, $0. Transports: `serve` (HTTP `/v1/systemone`), `decide` (subprocess), `daemon` (JSON-RPC). |
| `jev_client.gd` | HTTP client for the Zen route (key resolution, gate handling, persistence). |
| `oracle.gd` | Backend selection (`ORACLE_BACKEND`) + `evaluate()` facade. |
| `oracle_demo.gd` | Headless demo: offline separation, selection report, live run + model-vs-deterministic contrast. |

## Backends and selection

`ORACLE_BACKEND = jev | laya | deterministic | auto` (default `auto`).

`auto` order: **laya** (local, no credit) → **jev** (cloud, needs credit) →
**deterministic** (always works). The report prints which backend was selected
and each backend's availability reason.

| Backend | Transport | Cost | Latency | Gate |
|---|---|---|---|---|
| `deterministic` | in-process code | $0 | <1 ms | none — always available |
| `laya-local` | HTTP `laya serve` / `laya decide` subprocess | $0 | ~7.5–19 s/question (CPU) | CPU build + 404 MiB GGUF |
| `jev-zen` | HTTPS OpenCode Zen | $0.042/M in, out free | ~250 ms | Zen credit |

## Run

```bash
# Offline only (fast, no model):
ORACLE_BACKEND=deterministic godot --headless --path . \
  --script res://addons/cabra.lat_shooters/test/jev/oracle_demo.gd

# Local Laya through the backend (auto-detects the built binary + GGUF):
ORACLE_BACKEND=laya godot --headless --path . \
  --script res://addons/cabra.lat_shooters/test/jev/oracle_demo.gd

# Force the HTTP transport against a running `laya serve`:
ORACLE_BACKEND=laya LAYA_MODE=serve LAYA_ENDPOINT=http://127.0.0.1:8080 \
  godot --headless --path . --script res://addons/cabra.lat_shooters/test/jev/oracle_demo.gd

# Skip the live model run entirely:
ORACLE_LIVE=0 ...
```

### Exit codes

| Code | Meaning |
|---|---|
| `0` | Offline checks passed (and the live model ran, if requested). |
| `1` | Offline separation / plumbing self-test failed. |
| `2` | No model backend available (deterministic only). |
| `3` | Model backend **gated** (Zen credit / free-tier limit). |
| `4` | Model backend unreachable or errored. |

## Deterministic rules (the CI truth)

From `OracleFacts.verdicts_from_facts`:

- `hud_matches_state`: `hud.ammo_remaining == equipped.feed_count` and HUD text matches.
- `shot_valid`: fired, hit a named entity, plausible distance (1–500 m), not own weapon.
- `bug_class`: `self_hit` > `hud_desync` > `stale_rig` > `none`.
- `coherence`: 2 minus one per failed invariant (0–2).

No model is involved. This backend is always available and cannot be gated.

## Laya local — gates and setup

Verified on this machine (i5-7200U, AVX2, 940MX). Details:
`docs/ai-local-models-survey.md` → "VERIFICADO NESTA MÁQUINA".

1. **Official binaries do not run here.** They are CUDA-only (`sm80/86/89`) and
   built with `GGML_NATIVE=ON` (AVX-512) → SIGILL on this AVX2 CPU.
2. **Build the CPU-only binary** (~2.5 MB, no CUDA, ~2 min):
   ```bash
   nix build .#laya-cpu          # -> ./result/bin/laya
   # or: nix develop             # puts `laya` on PATH
   ```
3. **Fetch the GGUF once** (~404 MiB, gitignored in `./laya-models/`):
   ```bash
   fetch-laya-model              # Q4_K_M default
   ```
   Sizes (HF `mys/laya-typed-decisions-GGUF`, anonymous, not gated):
   Q4_K_M **423,581,888 B (404 MiB)** · Q8_0 **455,179,648 B (434 MiB)** ·
   F16 **849,812,128 B (810 MiB)**. Ranged GET returns HTTP 206.
4. **Serve** (preferred) or one-shot decide:
   ```bash
   laya serve laya-models/laya_typed_decisions_ud_q4_k_m.gguf \
     --family typed-decisions --port 8080 --device cpu --threads 4
   # POST /v1/systemone  { "model":"typed-decisions", "state":..., "questions":... }
   laya decide laya-models/laya_typed_decisions_ud_q4_k_m.gguf \
     --family typed-decisions --state-file s.json --questions-file q.json --device cpu --json
   ```
   The HTTP body is the **same TypeSafe/Jev shape**; note `model` selects the
   Laya *family* (`typed-decisions`), not a model id.

Env overrides: `LAYA_MODE=serve|decide|daemon`, `LAYA_ENDPOINT`,
`LAYA_BIN`, `LAYA_MODEL`, `LAYA_FAMILY`, `LAYA_THREADS`, `LAYA_TIMEOUT`,
`LAYA_API_KEY` / `TYPESAFE_API_KEY`.

**Zero-install alternative:** the HF Space `convaiinnovations/laya-demo`
exposes `POST /gradio_api/call/run_playground` with `state_text`/`questions_text`.
Tested from here (439 input tokens, **502 ms**, same base checkpoint).

## MEASURED CONTRAST — model vs deterministic (same BROKEN state)

State: HUD shows **10**, magazine holds **7**, otherwise a clean 15 m hit.
Deterministic truth: `hud=false`, `shot=true`, `bug=hud_desync`, `coherence=1`.

| Backend / run | hud_matches | shot_valid | bug_class | coherence | agreement |
|---|---|---|---|---|---|
| deterministic | false | **true** | **hud_desync** | 1 | — (truth) |
| laya `decide` (PT) | false | false | **outro** (conf 0.041) | 0.936 (conf 0.026) | 2/4 |
| laya `serve` (PT) | false | false | hud_desync (conf 0.026) | 0.992 (conf 0.044) | 3/4 |
| coordinator `decide` (EN) | — | — | **none** (conf 0.03) | 1.69 (p(2)=0.72) | — |

Latency measured: `decide` **78,073 ms**, `serve` **75,690 ms** for these 4
questions (~1.1 k input tokens) — i.e. ~19 s/question on this CPU. The
coordinator measured 7.5 s/question on a smaller state; throughput varies with
prompt length and load.

**Key finding:** the `bug_class` argmax **flipped between runs** (`outro` vs
`hud_desync`) with confidence **0.04 / 0.03** and near-uniform distributions —
that is noise, not signal. `shot_valid` was consistently **wrong** (false, truth
true). This reproduces the documented warning: the base checkpoint is ~chance
outside its training workflows.

## Cost

- `deterministic`: $0, microseconds.
- `laya-local`: $0 (electricity). ~19 s/question here.
- `jev-zen`: ~$0.0001/call (~1–2 k tokens at $0.042/M, output free).

## Honest limitations

- **The Laya base model is not reliable in our domain without fine-tuning.**
  Use the deterministic backend as truth; treat model output as an auxiliary
  signal and read its confidence. The argmax alone is noise.
- **Language confound.** The `laya` English checkpoint degrades outside English
  while keeping high confidence. Our canonical questions are Portuguese; set
  `ORACLE_QUESTIONS_LANG=en` (or fine-tune the multilingual checkpoint) for the
  base model. Jev is multilingual, so this only affects Laya.
- **>20 choice options degrade** (per-label token budget). Keep `choice` small.
- **Calibration** is over-confident; a temperature adjustment is needed before
  thresholds mean anything.
- **CPU is too slow for real-time bot decisions** (seconds per question). Fine
  for a slow CI oracle, not for 1 Hz gameplay.
- **No vision.** Jev/Laya see text only; visual/pixel checks stay with the
  spotter pipeline.
- **Optional layer.** Nothing in the game may hard-depend on this. Callers must
  degrade to the deterministic backend or skip.
- **`daemon` transport is experimental/untested** — no CPU daemon was run here.

## Next phase (required for the model to be worth anything)

**Fine-tune Laya on our domain** (game states: HUD/body/weapon/target/bot) with
the Kaggle notebook (2×T4 free, ~4–5 h, 4 epochs, RLCD). That is what takes the
base 0.36 → ~0.77 on their benchmark. Until then, local Laya does not pay off.

---
description: Free-only, local-first Ollama automation plan with per-task model selection, M1 Pro resource limits, offline bootstrap, and Keychain-backed secrets.
---

**Goals**
- **Local-first**: Standardize all agents on Ollama (free-only), no paid clouds.
- **Task-specialized models**: Per-task best-practice defaults (code, reasoning, PDF/screenshot vision).
- **Resource-safe**: Target ~50% CPU/RAM on M1 Pro 16GB when agents run.
- **Offline after bootstrap**: Pre-pull models and caches; operate without network for inference.
- **Unified adapters**: Single JSON I/O across bash, Python, Swift for drop-in replacement.
- **Observability**: Health, latency, fallbacks, and token estimates in dashboards.
- **Secure secrets**: macOS Keychain default; .env fallback only when Keychain unavailable.

**Scope**
- Replace any direct LLM calls with Ollama adapters; deprecate cloud providers.
- Integrate health checks and circuit-breakers into monitoring and recovery scripts.
- Manage `ollama serve` lifecycle via launchd; add model bootstrap.
- Constrain runtime resources and concurrency across orchestrators.

**Architecture**
- **Adapters**: `ollama_client.sh`, `ollama_client.py`, `OllamaClient.swift` expose a stable JSON contract:
  - Input: `{ task, prompt, system?, files[], images[], params? }`
  - Output: `{ text, model, latency_ms, tokens_est?, fallback_used?, error? }`
  - Reads `model_registry.json` for task presets and fallbacks.
- **Registries**: `model_registry.json` (task→model/presets/fallbacks) and `resource_profile.json` (system-wide limits: parallelism, priorities).
- **Health + Bootstrap**: `ollama_health.sh` (serve/list/ps checks), `bootstrap_models.sh` (pull/verify all registry models; checksum log).
- **Observability**: Standard fields appended to `dashboard_data.json` and surfaced by dashboards.
- **Security**: `keychain_secrets.sh`/`keychain.py` helpers with `.env` fallback.

**Model Registry (M1 Pro 16GB defaults)**
- File: `model_registry.json`
- Fields per task:
  - `task`: name (e.g., `codeGen`, `testGen`, `archAnalysis`, `dashboardSummary`, `visionOcr`, `visionLayout`)
  - `primaryModel`: Ollama tag (confirm locally via `ollama list`)
  - `fallbacks`: ordered array of alternative local tags
  - `preset`: `{ num_ctx, temperature, top_p, top_k, repeat_penalty, num_predict? }`
  - `preprocess`: `{ pdfToText: true|false, ocrIfNoText: true|false, imageToVision: true|false }`
  - `limits`: `{ maxInputTokens, maxParallel, maxImages }`
- Suggested starting points (verify availability with `ollama pull`):
  - **Reasoning/General**: `llama3.1:8b-instruct` (use lower ctx by default); fallbacks `mistral:7b-instruct`, `qwen2:7b-instruct`
  - **Code**: `qwen2.5-coder:7b-instruct`; fallbacks `starcoder2:7b`, `codegemma:7b-instruct`
  - **Architecture/Refactoring**: `mistral:7b-instruct`; fallbacks `llama3.1:8b-instruct`, `qwen2:7b-instruct`
  - **Vision (screenshots)**: lightweight first `moondream:latest` or `llava:7b`; fallback `bakllava:7b`
  - **PDFs**: prefer text extraction (`pdftotext`) then send to text LLM; only use vision when text absent or layout-critical
  - Presets: `num_ctx` 2048–4096 (code/analysis), `temperature` 0.1–0.3 (code), 0.2–0.5 (analysis)

**Resource Profile (~50% usage)**
- File: `resource_profile.json`
- Global settings:
  - `OLLAMA_NUM_PARALLEL`: 1 (default; bump to 2 only for short tasks)
  - `maxConcurrentAgents`: 1–2 (stagger heavy jobs)
  - `agentNice`: 10 (via `renice`), background I/O via `taskpolicy -b`
  - `defaultNumCtx`: 2048 (raise only when needed)
  - `visionConcurrency`: 1 (serialize VLM tasks)
  - `keepAliveSec`: 300 (reuse models briefly without overcommitting RAM)
- Orchestrator guidance:
  - Stagger long-running tasks; avoid concurrent large-context jobs.
  - Prefer text pipelines for PDFs; only switch to vision when necessary.
  - Chunk large inputs (e.g., 2–4k tokens per segment with summaries).

**Adapters (language-specific)**
- `ollama_client.sh`:
  - Reads stdin JSON, selects registry preset, calls `ollama run` or HTTP `POST /api/generate`.
  - Retries with exponential backoff and next fallback model when failures/timeouts.
  - Emits structured JSON; optional `--stream` to proxy tokens to stdout.
- `ollama_client.py`:
  - Same contract; adds helpers for PDF text extraction (`pdftotext`) and OCR fallback (e.g., `ocrmypdf` or `tesseract` if installed).
  - Optionally estimates tokens for dashboard metrics.
- `OllamaClient.swift`:
  - Minimal HTTP client to `/api/generate` and `/api/chat`; base64 image support for vision tasks when needed.

**Health & Bootstrap**
- `bootstrap_models.sh`:
  - Iterate all `primaryModel` and `fallbacks`; `ollama pull <tag>`; log versions and SHA to `models_bootstrap.jsonl`.
  - Validate presence via `ollama list`; abort with actionable errors if missing.
- `ollama_health.sh`:
  - Check `ollama serve` reachable; `GET /api/tags`; `ollama ps`; ensure free memory margin.
  - Output JSON `{ healthy, issues[], loaded_models[], mem_free_mb }` for dashboards/guards.
- Launchd integration:
  - User agent: `~/Library/LaunchAgents/com.tools.ollama.serve.plist` to run `ollama serve` with `RunAtLoad` and `KeepAlive`.
  - Logs to `~/Library/Logs/ollama/serve.log` (rotate with existing `backup_rotation.sh` if applicable).

**Observability**
- Standard log envelope appended per request to `dashboard_data.json`:
  - `{ timestamp, agent, task, model, latency_ms, tokens_est, fallback_used, ok }`
- Dashboards:
  - Update `dashboard_unified.sh` / `code_health_dashboard.py` to show provider health, recent fallbacks, latency p95, and queue depth.

**Security (Keychain First)**
- Keychain helpers (`keychain_secrets.sh`, `keychain.py`): `get_secret <service>`, `set_secret <service> <value>` using `security` CLI.
- `.env` fallback only when Keychain unavailable; warn in logs and mark `secrets_mode="env"` in metrics.

**Refactors (call adapters)**
- Replace direct LLM calls in:
  - `ai_enhanced_automation.sh`, `ai_implementation_automation.sh`, `ci_orchestrator.sh`, `dashboard_unified.sh`, `ai_generate_swift_tests.py` (and any others discovered) with adapter invocations.
- Add flags:
  - `--task <taskName>` selects preset; `--dry-run` prints routing; `--router-debug` shows chosen model and options.

**Offline Mode**
- After `bootstrap_models.sh` completes successfully, agents run without network for inference.
- PDF text extraction uses local tools; vision models loaded locally; retries stick to local fallbacks only.

**Rollout Plan**
1) Add registries and adapters; implement health and bootstrap scripts.
2) Wire launchd plist for `ollama serve`; verify logs and restart behavior.
3) Refactor two lowest-risk orchestrators; enable `--dry-run` to validate routing.
4) Expand to remaining scripts; enable metrics in dashboards; observe p95 latency and memory.
5) Tune `num_ctx`, chunking, and concurrency to hold ~50% system utilization.
6) Finalize docs in `AGENT_ENHANCEMENT_MASTER_PLAN.md`; deprecate any cloud provider code paths.

**Validation & Ops**
- Quick checks:
  - `ollama list` shows all registry models.
  - `./scripts/ollama_health.sh --json` returns `healthy: true`.
  - Adapters return JSON with `model` and `latency_ms` for a smoke prompt.
- macOS commands (examples):
```
launchctl unload ~/Library/LaunchAgents/com.tools.ollama.serve.plist 2>/dev/null || true
launchctl load ~/Library/LaunchAgents/com.tools.ollama.serve.plist
renice 10 -p $(pgrep -x ollama) || true
taskpolicy -b -p $(pgrep -x ollama) || true
```

**Risks & Mitigations**
- Model memory pressure (16GB): prefer 7B class; serialize vision; keep `OLLAMA_NUM_PARALLEL=1`.
- Slow first runs: mitigate with bootstrap pulls and warm-up calls.
- OCR accuracy: prefer text extraction; OCR only when needed; allow manual overrides per task.
- Untitled file creation constraint: plan stored under `plans/` for persistence; can be opened as untitled if desired in editor.

**Next Steps**
- Approve model choices; I’ll generate `model_registry.json` and `resource_profile.json`, then scaffold adapters and health/bootstrap scripts.

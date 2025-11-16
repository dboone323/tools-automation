# Sonar-like Detailed Hotspots Report

This file aggregates findings from local static scans (Bandit + Ruff) and provides recommended fixes for prominent hotspots in the *core* user code.

## How this report was generated
- Bandit security scan on core files: `mcp_server.py`, `run_48hour_validation.py`, `run_phase2_complete.py`, `agents/`, `monitoring/`.
- Ruff linter for common issues (F821, F841, E722).

## Priority: Medium
- monitoring/health_reporter.py (line 587): Request to webhook without timeout; fix: add `timeout=5` — implemented.
  - Recommendation: Use `requests.post(..., timeout=5)` and retry logic or backoff for critical notifications.
- mcp_server.py (lines ~2381-2393): Hardcoded `/tmp` files used for Swift script compile/run; fix: use `tempfile.mkdtemp()` and `os.path.join(...)` for secure temp files, and cleanup on exit — implemented.

## Priority: Low (High noise-priority from bandit/ruff)
- Exec/subprocess usage without explicit `shell=True` or secure arg parsing; many files flagged: `agents/validation_framework.py`, `agents/success_verifier.py`, `agents/validation_framework.py`.
  - Recommendation: Use `shlex.split` to parse commands and `subprocess.run(cmd_list, shell=False)` by default; only allow `shell=True` when explicitly authorized (e.g., `allow_shell` flag or env `ALLOW_SHELL` with appropriate access controls).
- Try/Except/Pass patterns across multiple files (e.g., run_48hour_validation.py) — either log exceptions or catch `Exception` specifically and avoid swallowing `KeyboardInterrupt` and `SystemExit`.
  - Recommendation: Convert `except:` to `except Exception:` where appropriate and add optional `logger.exception` or `logger.debug` for context.

## Triage & Next Steps
1. Merge conservative, low-risk changes implemented — `chore/remove-dummy-tokens-and-shell-safety` and `chore/sonar-hotspot-fixes` include:
   - Replacing dummy tokens with empty defaults & safer README placeholders
   - Adding `ALLOW_SHELL` opt-in behavior and explicit `allow_shell` suite flag
   - Adding `tests/unit/test_shell_policy.py` tests to assert that shell usage is controllable
2. Run a Sonar scan (requires Sonar token) for the PR branches; validate that Bandit & Ruff findings match Sonar hotspots.
3. Fix medium-risk items next: requests timeouts, hardcoded tmp paths, and `subprocess` constructs in user-code while minimizing behavioral changes.
4. Continue to refine allowed exceptions and add more unit tests that assert `subprocess.run` uses `shell` safely.

---
Notes: This report intentionally focuses on *core* files — third-party or `community/showcase` demo files should be marked as false-positives or excluded from strict security rules.

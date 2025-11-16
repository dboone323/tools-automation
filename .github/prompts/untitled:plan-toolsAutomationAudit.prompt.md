Plan: CI & Test Stabilization — toolsAutomationAudit

Purpose:

- Stabilize repository tests and CI for PR #13 with _small, conservative changes_ (no major refactors).
- Make pytest and Swift tests reliably pass in CI, ensure shell scripts are robust, and document the development workflow.

Scope:

- Python: Ensure `mcp_sdk` importability for pytest by installing the SDK or setting PYTHONPATH in CI.
- Swift: Keep a minimal `Shared` SPM package for `swift test` and add `xcodebuild` to CI for full macOS app builds (short-term).
- Shell scripts: Add strict mode, fix `ls` anti-patterns and add `shellcheck` in CI later.
- Documentation: Add `CONTRIBUTING.md` and `docs/ci-python.md` for developer setup and CI steps.

Plan Summary (Conservative Changes):

1. Python SDK import in CI

   - Add `pip install -e sdk/python` to the pytest CI step, with a `PYTHONPATH=./sdk/python` fallback.
   - If `setup.py` works but we want PEP 517, add `sdk/python/pyproject.toml` mirroring `setup.py` metadata.
   - CI command example:
     - `python -m venv .venv`
     - `source .venv/bin/activate`
     - `pip install -U pip`
     - `pip install -e sdk/python` (or `pip install .` at `sdk/python`)
     - `pytest -q -m "not integration and not e2e"`

2. Swift SPM `Shared` + `xcodebuild` CI job

   - Keep `Shared/Package.swift` and its tests; run `swift test` in CI.
   - Add a macOS `xcodebuild` job in `.github/workflows/ci.yml` for full app builds using the Xcode workspace and scheme for `MomentumFinance`.
   - Keep `swift build` on `MomentumFinance` `Sources/MomentumFinanceCore` target to perform a lightweight SPM check.

3. Register pytest markers & selective runs

   - Ensure `pytest.ini` registers markers: `unit`, `integration`, `e2e`, `performance`, `flaky`, `smoke`.
   - In PR CI, run `pytest -q -m "not integration and not e2e and not flaky"`.

4. Shell script hardening and lints

   - Add `#!/usr/bin/env bash` to scripts lacking it; add `set -euo pipefail`.
   - Replace `for file in $(ls ...)` with `find` or null-delimited loops.
   - Add `shellcheck` and optionally `actionlint` to CI to detect script anti-patterns.

5. Create `CONTRIBUTING.md` & `docs/ci-python.md`

   - Document local dev steps: create venv, `pip install -e sdk/python` (or set `PYTHONPATH`), run test subsets with pytest markers, `swift test`, and `xcodebuild` commands.
   - Document CI specifics: what checks run in each workflow (shell tests, pytest markers, swift tests, xcodebuild).

6. Track larger improvements in a plan doc

   - Add `plans/ci-migration-plan.md` describing 20 best-practice enhancements and a follow-up timeline.
   - Prioritize immediate items: packaging (Python `pyproject.toml`), CI install, `xcodebuild`, tests triage.

7. Repo hygiene (separate PR)
   - Remove runtime artifacts from tree `.venv`, `node_modules`, `Pods`, and other large build artifacts. Update `.gitignore` and run `git rm --cached` in follow-up PR.

Detailed Actions and Files to change (Minimal PRs):

- PR 1 (High priority):
  - Add/Update: `.github/workflows/ci.yml` — ensure `pip install -e sdk/python` before pytest. Add `xcodebuild` job for Mac build.
  - Add `sdk/python/pyproject.toml` (if desired) and keep `setup.py` until we fully migrate.
  - Update `pytest.ini` to register markers.
  - Add short CONTRIBUTING/CI docs.
- PR 2 (Low/Medium priority):
  - Shell script fixes: `scripts/trend_helpers.sh` and others (add shebang, `set -euo pipefail`, robust loops). Add `shellcheck` in CI.
  - Add `shellcheck` job to CI and a `pre-commit` or other lint hook.
- PR 3 (Medium):
  - SPM migration plan for `Shared` (split into multiple SPM targets or rework layout) — tracked as a plan but not implemented in this PR.
- PR 4 (Optional):
  - Repo cleanup to remove committed runtime artifacts and update `.gitignore`.

Testing & Validation:

- Local Steps for developers
  - Create venv: `python -m venv .venv` and `source .venv/bin/activate`.
  - Install SDK: `pip install -e sdk/python`.
  - Run unit tests: `pytest -q -m "unit and not flaky"`.
  - Run SPM test: `cd Shared && swift test`.
  - Build the MomentumFinance subset with SPM: `cd MomentumFinance && swift build -v --target MomentumFinanceCore`.
  - Build the full app using `xcodebuild` on macOS: `xcodebuild -workspace MomentumFinance/MomentumFinance.xcworkspace -scheme MomentumFinance -destination "platform=macOS" build`.

Risks & Mitigations:

- Risk: Full SPM conversion of `Shared` may need a larger refactor (duplicate basenames). Mitigation: Use `xcodebuild` in CI short-term.
- Risk: CI machine differences cause flaky tests. Mitigation: Mark flaky/integration/e2e tests and gate them to nightly runs or longer-running jobs.
- Risk: `setup.py` vs `pyproject.toml` differences. Mitigation: Provide `pyproject.toml` in `sdk/python` but keep `setup.py` to not break current installs until we confirm.

Follow-up Plan (20 Best-practice enhancements — draft list):

- Add pre-commit hooks for Python black/isort, ruff/mypy; add shellcheck; add SwiftLint in Gradle/Xcode or via SPM plugin.
- Add a `build matrix` to test on macOS and Linux where applicable.
- Add CI caching for pip, Swift, and Node artifacts.
- Add a macOS `xcodebuild` job to validate workspace/scheme builds and an optional iOS build if needed.
- Add a nightly workflow that runs E2E / integration tests and `swift test` for larger suites.
- Add `flake` or `detect-secrets` to CI to catch leaks.
- Add `actionlint` to validate GitHub Actions workflows.
- Add `lint-staged` or pre-commit hooks for the `.swift` formatting.
- Improve `pytest` collection stability by renaming duplicative test modules and using names with explicit test markers.
- Add unit and integration test labels and gate PRs accordingly.
- Split the `Shared` module to avoid duplicate basename conflicts for `swift build`.
- Use `pip install -e` for all PRs and `python -m pip install -r dev-requirements.txt` in local setups.
- Add `CONTRIBUTING.md` with clear build/test steps.
- Automate snapshots or CI caches for the most expensive tests.
- Add minimal smoke-tests run on PRs, and more thorough tests on nightly or release runs.
- Use `pytest -k` for targeted test re-runs in CI for flaky fixes.
- Add test/CI metrics and reporting in `reports/` (already used for test results).
- Remove large committable directories and add `gitignore` updates with incremental PRs.
- Add `codeowners` and branch protections to require CI checks before merges.
- Add a `CI-Migration` MILestone and track tasks across these PRs.

Next Steps

- Confirm: Preference for short-term `xcodebuild` + keep `Shared` SPM minimal.
- I’ll implement PR 1: add `pip install -e sdk/python` to CI, `xcodebuild` job, `pytest.ini` registrations, and `CONTRIBUTING.md` documentation.

Notes

- This file is a small, conservative stabilization plan. Each recommended change can be implemented in small PRs and reviewed independently.

Contact

- If you prefer, I can implement PR 1 now and also stage follow-ups for PR 2-4 incrementally.

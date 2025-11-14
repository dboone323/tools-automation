Plan: tools-automation repository audit and remediation

Objective

- Make the repository and its submodules fully portable, CI-ready, secure, and developer-friendly.
- Remove hardcoded, developer-specific paths; centralize shared configs.
- Enforce quality and security with tests, pre-commit, and CI checks.

High-level steps

1. Audit repo for hardcoded absolute paths and macOS-only commands

   - Replace /Users/danielstevens/Desktop/Quantum-workspace and similar with WORKSPACE_ROOT env var.
   - Use fallback: WORKSPACE_ROOT=${WORKSPACE_ROOT:-$(git rev-parse --show-toplevel)}

2. Parameterize workspace paths and create setup script

   - scripts/setup_paths.sh to set env: WORKSPACE_ROOT, AGENT_STATUS_PATH, OLLAMA_URL, etc.
   - Update each agent script (shared functions) to respect these envs.

3. Update CI

   - Add `git submodule update --init --recursive` before any build/test steps.
   - Make macOS Xcode steps run only on macOS runners in a matrix.
   - Add checks for required binaries (jq, gh, swiftformat, swiftlint) in `run` steps; fail fast.

4. Packaging & quality

   - Add `pyproject.toml` for Python packages; standardize `requirements.txt` for submodules.
   - Add `.pre-commit-config.yaml` with Black, isort, flake8, yaml-lint and `pre-commit` in CI job.
   - Run `pytest -q` across modules, add coverage report.

5. Centralize agent status and add validation

   - Consolidate into `config/agent_status.json`.
   - Implement `bin/validate_agent_status.py` to check schema and run in CI.

6. Reduce silent failures and replace blind sleeps

   - Replace `|| true` with explicit error handling and exit codes.
   - Replace `sleep infinity` with `sleep 31536000` initially, then add health checks and timeouts.

7. Security & docs
   - Add a secret scanning workflow and avoid hardcoded dev paths in released artifacts.
   - Update README with setup steps and environment requirements.

Validation and tests

- `grep -R "/Users/danielstevens" -n` returns no matches (except documented examples)
- CI runs on Linux and macOS with submodule-init success
- `pre-commit run --all-files` passes on repo
- `pytest` runs and coverage meets desired threshold
- `bin/validate_agent_status.py` succeeds on `config/agent_status.json`

Notes

- Prioritize path parameterization and CI updates (submodules & macOS job) first to unblock developer/CI runs.
- After these are done, add pre-commit and tests to improve long-term quality.

EOF

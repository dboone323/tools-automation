CI Python & Test Setup

This document describes how CI sets up the Python SDK and how to run the tests locally to mirror CI.

CI Steps:

- Setup Python using `actions/setup-python@v4` with `python-version: '3.11'`.
- Create venv, upgrade pip, and install `pytest` and the local SDK in editable mode if possible:
  - `python -m venv .venv`
  - `source .venv/bin/activate`
  - `pip install -U pip setuptools wheel`
  - `pip install -e sdk/python || true` (some environments may skip editable mode)
- Run pytest while skipping long-running integration/e2e tests and flaky tests in PRs:
  - `pytest -q -m "not integration and not e2e and not flaky"`

Local dev tips:

- Prefer installing the SDK locally (`pip install -e sdk/python`) rather than setting `PYTHONPATH`.
- You can set `PYTHONPATH` for one-off runs using `export PYTHONPATH=$(pwd)/sdk/python`.
- Use pytest markers to run targeted tests: `pytest -m unit`, `pytest -m integration`, etc.

CI Troubleshooting:

- If imports fail in CI, ensure `pip install -e sdk/python` step ran successfully — check logs.
- If CI still cannot import `mcp_sdk`, the fallback is to set `PYTHONPATH` in the job to `sdk/python`.
  CI tips: make local `mcp_sdk` importable and install sdk in editable mode

If your CI runs `pytest` and tests import the local SDK at `sdk/python`, either set `PYTHONPATH` or install the SDK in editable mode.

Option A — set PYTHONPATH (no install required)

```bash
export PYTHONPATH=./sdk/python
pytest -q -k "not integration"
```

Option B — install the SDK into the environment

```bash
python -m pip install -e sdk/python
pytest -q -k "not integration"
```

GitHub Actions example step (Option B)

```yaml
- name: Install Python SDK and run tests
  run: |
    python -m pip install --upgrade pip
    python -m pip install -e sdk/python
    pytest -q -k "not integration"
```

Either approach ensures tests that import `mcp_sdk` succeed in CI.

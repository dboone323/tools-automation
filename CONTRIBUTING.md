# Contributing & Development Guide

Quick start for local development and running tests:

1. Create and activate a Python virtual environment

```bash
python -m venv .venv
source .venv/bin/activate
pip install -U pip
```

2. Install the Python SDK locally (editable)

```bash
pip install -e sdk/python
```

Fallback: if you don't want to install, set PYTHONPATH for local runs

```bash
export PYTHONPATH="$(pwd)/sdk/python"
```

3. Run tests

Unit tests (fast):

```bash
pytest -q -m "unit and not flaky"
```

Integration/E2E tests (slow):

```bash
pytest -q -m "integration or e2e"
```

4. Swift tests & builds

Run SPM tests for the `Shared` package:

```bash
cd Shared
swift test
```

Build MomentumFinance core target using SPM:

```bash
cd MomentumFinance
swift build -v --target MomentumFinanceCore
```

Build full MomentumFinance app on macOS with xcodebuild

```bash
# If you have an Xcode workspace
xcodebuild -workspace MomentumFinance/MomentumFinance.xcworkspace -scheme MomentumFinance -destination "platform=macOS" build
```

Notes:

- The CI uses a conservative set of checks (unit tests, `swift test` for Shared, and `xcodebuild` for full app builds). Integration/E2E tests are run on longer-running workflows/nightly.
- If a test appears flaky, tag it with the `@pytest.mark.flaky` marker and add a ticket to stabilize it or gate it to nightly runs.

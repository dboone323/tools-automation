#!/usr/bin/env bash
set -euo pipefail

# Unified test runner for shell, Python, Swift (SwiftPM) tests.
# Flags:
#   RUN_INTEGRATION=1 to include integration tests
#   TEST_MODE=1 to enable AI stubbing
#   CI_FULL=1 to enable parallel pytest (-n auto)
#   FAST_MODE=1 run smoke subset only (future extension)
#   COVERAGE=1 gather coverage artifacts

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

export PATH="$ROOT_DIR/tools/test_shims:$PATH"

# Prefer project virtual environment Python if present
if [[ -x "$ROOT_DIR/.venv/bin/python" ]]; then
    export PATH="$ROOT_DIR/.venv/bin:$PATH"
fi

if [[ "${TEST_MODE:-0}" == "1" ]]; then
    echo "[info] TEST_MODE enabled: AI calls stubbed"
fi

CONFIG_FILE="$ROOT_DIR/tests/config/test_settings.json"
if [[ -f "$CONFIG_FILE" ]]; then
    RUN_INTEGRATION=${RUN_INTEGRATION:-$(jq -r '.run_integration' "$CONFIG_FILE")}
    DEFAULT_TIMEOUT=$(jq -r '.timeout_default_sec' "$CONFIG_FILE")
else
    RUN_INTEGRATION=${RUN_INTEGRATION:-0}
    DEFAULT_TIMEOUT=60
fi

export TIMEOUT_SEC=${TIMEOUT_SEC:-$DEFAULT_TIMEOUT}

shell_tests() {
    echo "[phase] Shell tests"
    local pattern="tests/test_*.sh"
    for f in $pattern; do
        if [[ -f "$f" ]]; then
            echo "[run] $f"
            bash "$f" || return 1
        fi
    done
}

python_tests() {
    echo "[phase] Python tests"
    if [[ -d tests ]]; then
        local PY=python
        # Prefer venv python explicitly if available
        if [[ -x "$ROOT_DIR/.venv/bin/python" ]]; then
            PY="$ROOT_DIR/.venv/bin/python"
        fi
        if ! command -v "$PY" >/dev/null 2>&1; then
            PY=python3
        fi
        if ! command -v "$PY" >/dev/null 2>&1; then
            echo "[skip] No python interpreter found; skipping Python tests"
            return 0
        fi
        if ! "$PY" -c "import pytest" >/dev/null 2>&1; then
            echo "[skip] pytest module not available; skipping Python tests"
            return 0
        fi
        local cmd
        if [[ "${COVERAGE:-0}" == "1" ]] && "$PY" -c "import coverage" >/dev/null 2>&1; then
            cmd=("$PY" -m coverage run -m pytest -q)
        else
            cmd=("$PY" -m pytest -q)
        fi
        if [[ "${CI_FULL:-0}" == "1" ]]; then
            if [[ "${COVERAGE:-0}" == "1" ]] && "$PY" -c "import coverage" >/dev/null 2>&1; then
                cmd=("$PY" -m coverage run -m pytest -n auto -q)
            else
                cmd=("$PY" -m pytest -n auto -q)
            fi
        fi
        if [[ "${RUN_INTEGRATION}" == "1" ]]; then
            cmd+=(-m "not skip")
        else
            cmd+=(-m "not integration")
        fi
        echo "[cmd] ${cmd[*]}"
        "${cmd[@]}"
        if [[ "${COVERAGE:-0}" == "1" ]] && "$PY" -c "import coverage" >/dev/null 2>&1; then
            "$PY" -m coverage json -o reports/python-coverage.json || true
        fi
    fi
}

swift_packages=(MomentumFinance shared-kit)
swift_tests() {
    echo "[phase] Swift tests"
    if ! command -v swift >/dev/null 2>&1; then
        echo "[skip] swift not installed; skipping Swift tests"
        return 0
    fi
    # Optional exclusions via env: comma-separated list
    IFS=',' read -r -a EXCLUDES <<<"${SWIFT_PACKAGE_EXCLUDES:-}"
    for pkg in "${swift_packages[@]}"; do
        if [[ -f "$pkg/Package.swift" ]]; then
            skip_pkg=0
            for ex in "${EXCLUDES[@]}"; do
                [[ "$ex" == "$pkg" ]] && skip_pkg=1 && break
            done
            if [[ $skip_pkg -eq 1 ]]; then
                echo "[skip] Excluding Swift package $pkg"
                continue
            fi
            echo "[run] swift test ($pkg)"
            pushd "$pkg" >/dev/null
            if [[ "${COVERAGE:-0}" == "1" ]]; then
                swift test --enable-code-coverage || return 1
            else
                swift test || return 1
            fi
            popd >/dev/null
        fi
    done
}

main() {
    shell_tests
    python_tests
    swift_tests
    echo "[done] All test phases completed"
}

main "$@"

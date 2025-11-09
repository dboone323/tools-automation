#!/usr/bin/env bash
set -euo pipefail

echo "Testing script"

swift_tests() {
    echo "[phase] Swift tests"
    if ! hash swift 2>/dev/null; then
        echo "[skip] swift not installed; skipping Swift tests"
        return 0
    fi
    echo "Swift found"
}

swift_tests
echo "Done"

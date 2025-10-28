#!/bin/bash
# Wrapper to run AI-Assisted Swift Unit Test Generator
# Usage:
#   ./Tools/Automation/ai_generate_swift_tests.sh [--project <ProjectName>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATOR="${SCRIPT_DIR}/ai_generate_swift_tests.py"

if ! command -v python3 >/dev/null 2>&1; then
    echo "[ERROR] python3 is required but not installed" >&2
    exit 1
fi

chmod +x "${GENERATOR}" || true

ARGS=("$@")

echo "[ai-generate-tests] Running generator..."
python3 "${GENERATOR}" "${ARGS[@]}" || {
    echo "[ERROR] Test generation failed" >&2
    exit 1
}

echo "[ai-generate-tests] Done. Check Projects/<Project>/AutoTests/ and Tools/Automation/results/."

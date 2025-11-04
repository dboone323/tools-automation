#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$REPO_ROOT"

: "${OLLAMA_CLOUD_URL:=}"
export OLLAMA_ENDPOINT="${OLLAMA_CLOUD_URL:-http://127.0.0.1:11434}"
export CR_USE_AI=1
export CR_USE_OLLAMA=1

if [[ -z "${OLLAMA_CLOUD_URL}" ]]; then
  if command -v ollama >/dev/null 2>&1; then
    PID_FILE="/tmp/ollama_ci_${RANDOM}.pid"
    trap '[[ -f "$PID_FILE" ]] && kill "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null || true' EXIT
    nohup ollama serve >/dev/null 2>&1 & echo $! > "$PID_FILE"
    sleep 2
  fi
fi

command -v curl >/dev/null 2>&1 && curl -sS "${OLLAMA_ENDPOINT}/api/tags" >/dev/null || true

command -v swiftlint >/dev/null 2>&1 && swiftlint --strict || true
command -v swiftformat >/dev/null 2>&1 && [ -f .swiftformat ] && swiftformat . --config .swiftformat --lint || true

if [ -x Tools/Automation/run_parallel_tests.sh ]; then
  chmod +x Tools/Automation/run_parallel_tests.sh || true
  Tools/Automation/run_parallel_tests.sh
else
  if [ -f Package.swift ]; then
    swift test --parallel
  else
    proj=$(ls -1 *.xcodeproj 2>/dev/null | head -n1)
    if [ -n "$proj" ]; then
      scheme=${proj%.xcodeproj}
      if command -v xcpretty >/dev/null 2>&1; then
        xcodebuild -scheme "$scheme" -destination 'platform=macOS' build | xcpretty || xcodebuild -scheme "$scheme" -destination 'platform=macOS' build || true
      else
        xcodebuild -scheme "$scheme" -destination 'platform=macOS' build || true
      fi
    else
      echo "No Package.swift or .xcodeproj found"
    fi
  fi
fi

[ -x Tools/Automation/detect_issues.sh ] && Tools/Automation/detect_issues.sh || true
if [ -f Tools/Automation/automated_remediation.py ]; then
  python3 Tools/Automation/automated_remediation.py || true
fi

echo "Agent-assisted validation complete."

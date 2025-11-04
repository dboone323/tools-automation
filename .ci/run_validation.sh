#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$REPO_ROOT"

# Prefer cloud, then local
: "${OLLAMA_CLOUD_URL:=}"
export OLLAMA_ENDPOINT="${OLLAMA_CLOUD_URL:-http://127.0.0.1:11434}"

# Bootstrap local Ollama if cloud not set
.ci/ollama_bootstrap.sh || true

# Quick connectivity check (non-fatal)
if command -v curl >/dev/null 2>&1; then
  curl -sS "${OLLAMA_ENDPOINT}/api/tags" >/dev/null || true
fi

# Optional lint/format
if command -v swiftlint >/dev/null 2>&1; then
  swiftlint --strict || true
fi
if command -v swiftformat >/dev/null 2>&1 && [ -f .swiftformat ]; then
  swiftformat . --config .swiftformat --lint || true
fi

# Test execution
if [ -x "Tools/Automation/run_parallel_tests.sh" ]; then
  chmod +x Tools/Automation/run_parallel_tests.sh || true
  Tools/Automation/run_parallel_tests.sh
else
  if [ -f Package.swift ]; then
    swift test --parallel
  else
    proj=$(ls -1 *.xcodeproj 2>/dev/null | head -n1)
    if [ -n "$proj" ]; then
      scheme=${proj%.xcodeproj}
      xcodebuild -scheme "$scheme" -destination 'platform=macOS' build | xcpretty || xcodebuild -scheme "$scheme" -destination 'platform=macOS' build || true
    else
      echo "No Package.swift or .xcodeproj found"
    fi
  fi
fi

# Optional issue detection script
[ -x Tools/Automation/detect_issues.sh ] && Tools/Automation/detect_issues.sh || true

echo "Validation complete."

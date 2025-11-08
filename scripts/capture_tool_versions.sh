#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPORTS="$ROOT_DIR/reports"
mkdir -p "$REPORTS"

python_version="$(python --version 2>&1 || python3 --version 2>&1 || echo 'python-not-found')"
swift_version="$(swift --version 2>&1 | head -1 || echo 'swift-not-found')"
bash_version="${BASH_VERSION:-unknown}"

cat >"$REPORTS/tool_versions.json" <<EOF
{
  "python": "${python_version}",
  "swift": "${swift_version}",
  "bash": "${bash_version}"
}
EOF

echo "Wrote $REPORTS/tool_versions.json"

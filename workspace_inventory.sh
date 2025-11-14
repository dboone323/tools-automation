#!/usr/bin/env bash
set -euo pipefail

# Inventory script: scans the repo and produces a timestamped report under Tools/Automation/reports.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"
REPORT_DIR="${ROOT_DIR}/Tools/Automation/reports"
mkdir -p "${REPORT_DIR}"

stamp="$(date '+%Y%m%dT%H%M%S')"
report="${REPORT_DIR}/inventory_${stamp}.md"

cd "${ROOT_DIR}"

count() { find . -type f -name "$1" 2>/dev/null | wc -l | tr -d ' '; }
list_dirs_like() { find . -type d -path "$1" 2>/dev/null | sort; }

cat >"${report}" <<EOF
# Workspace Inventory Report
Generated: $(date -R)

## Counts
- cspell.json: $(count 'cspell.json')
- Shell scripts (*.sh): $(find . -type f -name '*.sh' | wc -l | tr -d ' ')
- Xcode projects: $(find . -type d -name '*.xcodeproj' | wc -l | tr -d ' ')
- Xcode workspaces: $(find . -type d -name '*.xcworkspace' | wc -l | tr -d ' ')
- Swift files: $(find . -type f -name '*.swift' | wc -l | tr -d ' ')

## Snapshot/Backup Dirs
- IMPORTS:
$(list_dirs_like '*/IMPORTS/*' | sed 's/^/  - /')
- Imported snapshots:
$(list_dirs_like '*/Imported/*' | sed 's/^/  - /')
- Merge backups:
$(list_dirs_like '*/_merge_backups/*' | sed 's/^/  - /')

## Notes
This is a read-only report. Use workspace_consolidator.sh to perform safe moves.
EOF

echo "Wrote ${report}" >&2

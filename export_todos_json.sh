#!/bin/bash
# Tools/Automation/export_todos_json.sh
# Export all TODO and FIXME comments in the workspace as a JSON array
# - Skips large/backup/vendor directories to avoid hangs
# - Caps scanned file size to speed up
# - Aligns output with processor (Projects/todo-tree-output.json)
# - Supports background mode via --background

set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Default output matches process_todos.sh expectation
OUTPUT_FILE_DEFAULT="${WORKSPACE_DIR}/Projects/todo-tree-output.json"
OUTPUT_FILE="${TODO_OUTPUT:-$OUTPUT_FILE_DEFAULT}"
LOG_FILE="${WORKSPACE_DIR}/Tools/Automation/process_todos.log"

# Allow --background to run detached
if [[ "${1:-}" == "--background" ]]; then
	shift || true
	nohup bash "$0" "$@" >>"${LOG_FILE}" 2>&1 &
	echo $! >"${WORKSPACE_DIR}/Tools/Automation/export_todos.pid"
	echo "🟢 export_todos_json running in background (PID $(cat "${WORKSPACE_DIR}/Tools/Automation/export_todos.pid"))" | tee -a "${LOG_FILE}"
	exit 0
fi

# Ensure jq exists
if ! command -v jq >/dev/null 2>&1; then
	echo "❌ jq not found; please install jq (brew install jq)" | tee -a "${LOG_FILE}"
	exit 1
fi

mkdir -p "$(dirname "${OUTPUT_FILE}")"
mkdir -p "$(dirname "${LOG_FILE}")"

echo "🔎 Exporting TODOs from ${WORKSPACE_DIR} → ${OUTPUT_FILE}" | tee -a "${LOG_FILE}"

# Build find with prunes to skip heavy dirs
read -r -d '' PRUNE_EXPR <<'EOF'
\( \
	-path "*/.git" -o \
	-path "*/.build" -o \
	-path "*/DerivedData" -o \
	-path "*/Pods" -o \
	-path "*/Carthage" -o \
	-path "*/node_modules" -o \
	-path "*/.venv" -o \
	-path "*/env" -o \
	-path "*/__pycache__" -o \
	-path "*/.pytest_cache" -o \
	-path "*/.autofix_backups" -o \
	-path "*/Tools/Automation/Archive" -o \
	-path "*/Tools/Automation/Imported_Tools_snapshot-*" -o \
	-path "*/Tools/Automation/.venv" -o \
	-path "*/logs" -o \
	-path "*/dist" -o \
	-path "*/build" \
\) -prune -false -o
EOF

# Start JSON array
echo "[" >"${OUTPUT_FILE}"
first=1

# shellcheck disable=SC2086
eval find "\"${WORKSPACE_DIR}\"" ${PRUNE_EXPR} -type f \
	\( -name "*.swift" -o -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.sh" -o -name "*.md" \) \
	-size -1M \
	-print0 | while IFS= read -r -d '' file; do
	# Use --text to avoid binary issues; ignore files without matches quickly
	if grep -Iq . "$file" 2>/dev/null; then
		grep -nE --text "TODO|FIXME" "$file" 2>/dev/null | while IFS=: read -r line_num line; do
			if [[ -n "${line_num}" ]]; then
				if [[ ${first} -eq 0 ]]; then echo "," >>"${OUTPUT_FILE}"; fi
				first=0
				jq -n --arg file "${file#"${WORKSPACE_DIR}"/}" --arg line "${line_num}" --arg text "${line}" \
					'{file: $file, line: ($line|tonumber), text: $text}' >>"${OUTPUT_FILE}"
			fi
		done || true
	fi
done

echo "]" >>"${OUTPUT_FILE}"

echo "✅ TODOs exported to ${OUTPUT_FILE}" | tee -a "${LOG_FILE}"

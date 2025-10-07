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
OUTPUT_FILE="${TODO_OUTPUT:-${OUTPUT_FILE_DEFAULT}}"
LOG_FILE="${WORKSPACE_DIR}/Tools/Automation/process_todos.log"

# Allow --background to run detached
if [[ ${1-} == "--background" ]]; then
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

if [[ -n ${TODO_EXPORT_FAST-} ]]; then
  echo "🔎 Exporting TODOs (limited) from ${WORKSPACE_DIR} → ${OUTPUT_FILE}" | tee -a "${LOG_FILE}"
else
  echo "🔎 Exporting TODOs from ${WORKSPACE_DIR} → ${OUTPUT_FILE}" | tee -a "${LOG_FILE}"
fi

TMP_FILE="${OUTPUT_FILE}.tmp.$$"
TMP_ITEMS="${OUTPUT_FILE}.items.$$"
>"${TMP_ITEMS}"

# Set item limit to prevent memory issues (default 5000, override with TODO_ITEM_LIMIT)
ITEM_LIMIT="${TODO_ITEM_LIMIT:-5000}"
ITEM_COUNT=0

# Find files while avoiding heavy directories
find "${WORKSPACE_DIR}" \
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
  -path "*/Tools/agents/*" -o \
  -path "*/Tools/Automation/agents/orchestrator_status_*" -o \
  -path "*/Documentation/*" -o \
  -path "*/logs" -o \
  -path "*/dist" -o \
  -path "*/build" \
  \) -prune -o \
  -type f \
  \( -name "*.swift" -o -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.sh" -o -name "*.md" \) \
  -size -1M \
  -print0 | while IFS= read -r -d '' file; do
  # Skip backup/temp artifacts in limited mode
  if [[ -n ${TODO_EXPORT_FAST-} ]]; then
    case "${file}" in
    *.backup* | *.bak | *.orig | *.tmp | *.temp)
      continue
      ;;
    esac
  fi
  # Use --text to avoid binary issues; ignore files without matches quickly
  if grep -Iq . "${file}" 2>/dev/null; then
    # Use process substitution to keep 'first' state in current shell
    while IFS=: read -r line_num line; do
      if [[ -n ${line_num} ]]; then
        # Check limit before writing
        if [[ ${ITEM_COUNT} -ge ${ITEM_LIMIT} ]]; then
          echo "⚠️ Reached item limit (${ITEM_LIMIT}); stopping collection" | tee -a "${LOG_FILE}"
          break 2 # Break out of both while and find loop
        fi
        jq -n --arg file "${file#"${WORKSPACE_DIR}"/}" --arg line "${line_num}" --arg text "${line}" \
          '{file: $file, line: ($line|tonumber), text: $text}' >>"${TMP_ITEMS}"
        ((ITEM_COUNT++)) || true
      fi
    done < <(grep -nE --text "TODO|FIXME" "${file}" 2>/dev/null)
  fi
done

# Convert NDJSON to JSON array atomically
echo "📊 Collected ${ITEM_COUNT} TODO items; assembling JSON array..." | tee -a "${LOG_FILE}"
jq -s '.' "${TMP_ITEMS}" >"${TMP_FILE}" 2>>"${LOG_FILE}" || {
  echo "❌ Failed to assemble JSON array; leaving items file for debugging: ${TMP_ITEMS}" | tee -a "${LOG_FILE}"
  exit 1
}
rm -f "${TMP_ITEMS}"
mv "${TMP_FILE}" "${OUTPUT_FILE}"

echo "✅ TODOs exported to ${OUTPUT_FILE} (${ITEM_COUNT} items)" | tee -a "${LOG_FILE}"

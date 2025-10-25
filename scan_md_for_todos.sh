#!/bin/bash
# Tools/Automation/scan_md_for_todos.sh
# Scan MD files for actionable items and convert them to todos
# Integrates with the existing todo processing system

set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TODO_JSON="${WORKSPACE_DIR}/Projects/todo-tree-output.json"
LOG_FILE="${WORKSPACE_DIR}/Tools/Automation/process_todos.log"
MD_TODO_LOG="${WORKSPACE_DIR}/Tools/Automation/md_todo_scan.log"

# Limit the number of TODOs to create to avoid long scan times
MAX_TODOS=${MAX_TODOS:-50}
MAX_FILES=${MAX_FILES:-20}

# Ensure jq exists
if ! command -v jq >/dev/null 2>&1; then
    echo "❌ jq not found; please install jq (brew install jq)" | tee -a "${LOG_FILE}"
    exit 1
fi

mkdir -p "$(dirname "${LOG_FILE}")"
mkdir -p "$(dirname "${MD_TODO_LOG}")"

echo "🔍 Scanning MD files for actionable items (max ${MAX_TODOS} todos, max ${MAX_FILES} files)..." | tee -a "${LOG_FILE}" | tee -a "${MD_TODO_LOG}"

# Initialize temporary file as empty array
echo "[]" >"${TODO_JSON}.md_tmp"

# Use a temporary file to communicate scan status
SCAN_STATUS_FILE="${WORKSPACE_DIR}/Tools/Automation/.scan_status.tmp"

# Find all MD files in the workspace (excluding Archives and backups)
find "${WORKSPACE_DIR}" \
    \( \
    -path "*/.git" -o \
    -path "*/.build" -o \
    -path "*/DerivedData" -o \
    -path "*/Archive" -o \
    -path "*/.autofix_backups" -o \
    -path "*/node_modules" -o \
    -path "*/.venv" \
    \) -prune -o \
    -name "*.md" \
    -type f \
    -print0 >"${SCAN_STATUS_FILE}"

# Process files one by one
todo_count=0
file_count=0
while IFS= read -r -d '' md_file; do
    ((file_count++)) || true
    if [[ ${file_count} -gt ${MAX_FILES} ]]; then
        echo "📁 Reached max files limit (${MAX_FILES}), stopping scan" | tee -a "${MD_TODO_LOG}"
        break
    fi

    echo "📄 Scanning: ${md_file} (${file_count}/${MAX_FILES})" | tee -a "${MD_TODO_LOG}"

    # Extract actionable items from MD files
    # Look for patterns like:
    # - [ ] TODO items
    # - [x] Completed items (skip)
    # - TODO: or FIXME: in text
    # - Action items in lists
    # - Recommendations and suggestions

    line_num=0
    while IFS= read -r line; do
        ((line_num++)) || true

        # Skip completed items
        if echo "${line}" | grep -q "^[[:space:]]*-[[:space:]]*\[x\]\|[[:space:]]*-[[:space:]]*\[X\]"; then
            continue
        fi

        # Extract TODO items from checklists
        if echo "${line}" | grep -q "^[[:space:]]*-[[:space:]]*\[[[:space:]]*\]"; then
            todo_text=$(echo "${line}" | sed 's/^[[:space:]]*-[[:space:]]*\[[[:space:]]*\]//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            if [[ -n "${todo_text}" ]]; then
                echo "✅ Found checklist TODO: ${todo_text}" | tee -a "${MD_TODO_LOG}"
                # Add to todo JSON
                jq --arg file "${md_file#"${WORKSPACE_DIR}"/}" --arg line "${line_num}" --arg text "TODO: ${todo_text}" \
                    '. += [{file: $file, line: ($line|tonumber), text: $text, source: "md_checklist"}]' "${TODO_JSON}.md_tmp" >"${TODO_JSON}.md_tmp.tmp" && mv "${TODO_JSON}.md_tmp.tmp" "${TODO_JSON}.md_tmp"
                ((todo_count++)) || true

                # Check if we've reached the TODO limit after adding
                if [[ ${todo_count} -ge ${MAX_TODOS} ]]; then
                    echo "📝 Reached max TODOs limit (${MAX_TODOS}), stopping scan" | tee -a "${MD_TODO_LOG}"
                    break
                fi
            fi
        fi

        # Extract TODO/FIXME from regular text
        if echo "${line}" | grep -i -q "todo\|fixme"; then
            # Clean up the text
            todo_text=$(echo "${line}" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/^#\+[[:space:]]*//')
            if [[ -n "${todo_text}" ]]; then
                echo "📝 Found text TODO: ${todo_text}" | tee -a "${MD_TODO_LOG}"
                jq --arg file "${md_file#"${WORKSPACE_DIR}"/}" --arg line "${line_num}" --arg text "${todo_text}" \
                    '. += [{file: $file, line: ($line|tonumber), text: $text, source: "md_text"}]' "${TODO_JSON}.md_tmp" >"${TODO_JSON}.md_tmp.tmp" && mv "${TODO_JSON}.md_tmp.tmp" "${TODO_JSON}.md_tmp"
                ((todo_count++)) || true

                # Check if we've reached the TODO limit after adding
                if [[ ${todo_count} -ge ${MAX_TODOS} ]]; then
                    echo "📝 Reached max TODOs limit (${MAX_TODOS}), stopping scan" | tee -a "${MD_TODO_LOG}"
                    break
                fi
            fi
        fi

        # Extract recommendations and suggestions
        if echo "${line}" | grep -i -q "recommend\|suggest\|should\|consider\|implement\|add\|create\|update\|improve\|optimize"; then
            # Look for action-oriented sentences
            if echo "${line}" | grep -i -q "^[[:space:]]*-\|[[:space:]]*[0-9]\+\.\|[[:space:]]*•"; then
                todo_text=$(echo "${line}" | sed 's/^[[:space:]]*[-•*0-9.]*[[:space:]]*//' | sed 's/[[:space:]]*$//')
                if [[ -n "${todo_text}" ]] && [[ ${#todo_text} -gt 10 ]]; then
                    echo "💡 Found recommendation: ${todo_text}" | tee -a "${MD_TODO_LOG}"
                    jq --arg file "${md_file#"${WORKSPACE_DIR}"/}" --arg line "${line_num}" --arg text "ACTION: ${todo_text}" \
                        '. += [{file: $file, line: ($line|tonumber), text: $text, source: "md_recommendation"}]' "${TODO_JSON}.md_tmp" >"${TODO_JSON}.md_tmp.tmp" && mv "${TODO_JSON}.md_tmp.tmp" "${TODO_JSON}.md_tmp"
                    ((todo_count++)) || true

                    # Check if we've reached the TODO limit after adding
                    if [[ ${todo_count} -ge ${MAX_TODOS} ]]; then
                        echo "📝 Reached max TODOs limit (${MAX_TODOS}), stopping scan" | tee -a "${MD_TODO_LOG}"
                        break
                    fi
                fi
            fi
        fi

        # Extract error/warning items that need fixing
        if echo "${line}" | grep -i -q "error\|warning\|issue\|problem\|bug\|fix\|resolve"; then
            if echo "${line}" | grep -i -q "need\|required\|must\|should"; then
                todo_text=$(echo "${line}" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/^#\+[[:space:]]*//')
                if [[ -n "${todo_text}" ]]; then
                    echo "⚠️ Found issue to fix: ${todo_text}" | tee -a "${MD_TODO_LOG}"
                    jq --arg file "${md_file#"${WORKSPACE_DIR}"/}" --arg line "${line_num}" --arg text "FIX: ${todo_text}" \
                        '. += [{file: $file, line: ($line|tonumber), text: $text, source: "md_issue"}]' "${TODO_JSON}.md_tmp" >"${TODO_JSON}.md_tmp.tmp" && mv "${TODO_JSON}.md_tmp.tmp" "${TODO_JSON}.md_tmp"
                    ((todo_count++)) || true

                    # Check if we've reached the TODO limit after adding
                    if [[ ${todo_count} -ge ${MAX_TODOS} ]]; then
                        echo "📝 Reached max TODOs limit (${MAX_TODOS}), stopping scan" | tee -a "${MD_TODO_LOG}"
                        break
                    fi
                fi
            fi
        fi

    done <"${md_file}"

done <"${SCAN_STATUS_FILE}"

# Clean up
rm -f "${SCAN_STATUS_FILE}"

# Merge MD-generated todos with existing todos
if [[ -f "${TODO_JSON}.md_tmp" ]]; then
    echo "🔄 Merging MD-generated todos with existing todo list..." | tee -a "${LOG_FILE}"

    # Create or merge with existing todo file
    if [[ -f "${TODO_JSON}" ]]; then
        # Combine existing todos with new MD todos
        jq -s 'add' "${TODO_JSON}" "${TODO_JSON}.md_tmp" >"${TODO_JSON}.merged"
        mv "${TODO_JSON}.merged" "${TODO_JSON}"
    else
        # No existing todos, just use MD todos
        mv "${TODO_JSON}.md_tmp" "${TODO_JSON}"
    fi

    # Remove duplicates based on file, line, and text
    jq 'unique_by(.file, .line, .text)' "${TODO_JSON}" >"${TODO_JSON}.unique"
    mv "${TODO_JSON}.unique" "${TODO_JSON}"

    md_todo_count=$(jq length "${TODO_JSON}.md_tmp" 2>/dev/null || echo "0")
    echo "✅ Added ${md_todo_count} todos from MD file scanning" | tee -a "${LOG_FILE}"
    rm -f "${TODO_JSON}.md_tmp"
else
    echo "ℹ️ No actionable items found in MD files" | tee -a "${LOG_FILE}"
fi

echo "✅ MD file scanning completed" | tee -a "${LOG_FILE}"

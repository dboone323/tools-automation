#!/bin/bash
# Tools/Automation/process_todos.sh
# Process exported todo-tree-output.json and take action on TODOs
# Actions: generate issues, assign agents, or trigger workflows based on TODOs
# Now includes MD file scanning for actionable items

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
echo "[DEBUG] WORKSPACE_DIR is: ${WORKSPACE_DIR}" >&2
TODO_JSON="${WORKSPACE_DIR}/Projects/todo-tree-output.json"
LOG_FILE="${WORKSPACE_DIR}/Tools/Automation/process_todos.log" # Corrected LOG_FILE path

if [[ ! -f ${TODO_JSON} ]]; then
  mkdir -p "$(dirname \""${LOG_FILE}"\")" # Ensure the directory for LOG_FILE exists
  echo "❌ TODO JSON file not found: ${TODO_JSON}" | tee -a "${LOG_FILE}"
  exit 1
fi

echo "🔍 Processing TODOs from ${TODO_JSON}..." | tee -a "${LOG_FILE}"

# First, scan MD files for actionable items and add them to todos
echo "📄 Scanning MD files for additional todos..." | tee -a "${LOG_FILE}"
"$(dirname "$0")/scan_md_for_todos.sh" | tee -a "${LOG_FILE}"

# Example: For each TODO, print details and (optionally) trigger further automation
jq -c '.[]' "${TODO_JSON}" | while read -r todo; do
  file=$(echo "${todo}" | jq -r '.file')
  line=$(echo "${todo}" | jq -r '.line')
  text=$(echo "${todo}" | jq -r '.text')
  source=$(echo "${todo}" | jq -r '.source // "code"')
  echo "➡️  TODO [${source}] in ${file} at line ${line}: ${text}" | tee -a "${LOG_FILE}"
  # Create a local issue for this TODO
  "$(dirname "$0")/create_issue.sh" "${file}" "${line}" "${text}" | tee -a "${LOG_FILE}"
  # Assign an agent to this TODO/issue
  "$(dirname "$0")/assign_agent.sh" "${file}" "${line}" "${text}" | tee -a "${LOG_FILE}"
done

echo "✅ TODO processing complete." | tee -a "${LOG_FILE}"

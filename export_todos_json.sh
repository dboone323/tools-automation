#!/bin/bash
# Tools/Automation/export_todos_json.sh
# Export all TODO and FIXME comments in the workspace as a JSON array

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT_FILE="${WORKSPACE_DIR}/todo-tree-output.json"

# Start JSON array
echo "[" >"${OUTPUT_FILE}"
first=1
find "${WORKSPACE_DIR}" -type f \( -name "*.swift" -o -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.sh" -o -name "*.md" \) | while read -r file; do
	grep -nE "TODO|FIXME" "${file}" | while IFS=: read -r line_num line; do
		if [[ ${first} -eq 0 ]]; then echo "," >>"${OUTPUT_FILE}"; fi
		first=0
		jq -n --arg file "${file#"${WORKSPACE_DIR}"/}" --arg line "${line_num}" --arg text "${line}" \
			'{file: $file, line: ($line|tonumber), text: $text}' >>"${OUTPUT_FILE}"
	done
done
echo "]" >>"${OUTPUT_FILE}"

echo "✅ TODOs exported to ${OUTPUT_FILE}"

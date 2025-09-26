#!/bin/bash
# create_issue.sh - Create a local issue from a TODO
# Usage: create_issue.sh <file> <line> <text>

ISSUES_FILE="$(dirname "$0")/issues_local.json"
file="$1"
line="$2"
text="$3"

if [[ -z ${file} || -z ${line} || -z ${text} ]]; then
	echo "Usage: $0 <file> <line> <text>"
	exit 1
fi

# Create a new issue object
issue_id="issue_$(date +%s%N)"
issue_json="{\"id\": \"${issue_id}\", \"file\": \"${file}\", \"line\": ${line}, \"text\": \"${text}\", \"status\": \"open\"}"

# Append to issues file (create if missing)
if [[ ! -f ${ISSUES_FILE} ]]; then
	echo "[]" >"${ISSUES_FILE}"
fi

jq ". + [${issue_json}]" "${ISSUES_FILE}" >"${ISSUES_FILE}.tmp" && mv "${ISSUES_FILE}.tmp" "${ISSUES_FILE}"
echo "Created issue: ${issue_id} for ${file}:${line}"

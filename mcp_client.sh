#!/usr/bin/env bash
set -euo pipefail

# Minimal MCP client for local testing
MCP_URL="http://127.0.0.1:5005"

usage() {
	echo "Usage: $0 register <agent-name>"
	echo "       $0 run <agent-name> <command> [project] [--execute]"
	exit 2
}

if [[ $# -lt 2 ]]; then
	usage
fi

cmd="$1"
agent="$2"

case "$cmd" in
register)
	curl -s -X POST "$MCP_URL/register" -H 'Content-Type: application/json' -d "{\"agent\": \"$agent\", \"capabilities\": [\"automation\"]}" | jq .
	;;
run)
	if [[ $# -lt 3 ]]; then
		echo "run requires a command"
		exit 2
	fi
	command="$3"
	project="${4-}"
	execute=false
	for a in "$@"; do
		if [[ $a == "--execute" ]]; then execute=true; fi
	done
	payload=$(jq -n --arg agent "$agent" --arg command "$command" --arg project "$project" --argjson execute $execute '{agent:$agent,command:$command,project:$project,execute:$execute}')
	curl -s -X POST "$MCP_URL/run" -H 'Content-Type: application/json' -d "$payload" | jq .
	;;
*) usage ;;
esac

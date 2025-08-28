#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="$ROOT/.venv/bin/python"
LOGDIR="$ROOT/logs"
mkdir -p "$LOGDIR"

AGENTS=(
	"subproc-agent:monitor,execute"
	"e2e-agent:test,monitor"
	"int-test:test,monitor"
	"test-agent-1:status"
)

for a in "${AGENTS[@]}"; do
	NAME="${a%%:*}"
	CAPS="${a#*:}"
	nohup "$VENV" "$ROOT/agents/run_agent.py" --name "$NAME" --capabilities "$CAPS" >"$LOGDIR/${NAME}.out" 2>"$LOGDIR/${NAME}.err" &
	echo $! >"$LOGDIR/${NAME}.pid"
	echo "started $NAME (pid $(cat "$LOGDIR/${NAME}.pid"))"
done

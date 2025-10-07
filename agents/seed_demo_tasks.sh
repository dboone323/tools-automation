#!/bin/bash
# Seed a set of demo tasks into the orchestrator task queue for dashboard metrics
# Usage: ./seed_demo_tasks.sh [COUNT]

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

set -euo pipefail
SCRIPT_DIR="$(dirname "$0")"
TASK_QUEUE_FILE="${SCRIPT_DIR}/task_queue.json"
COUNT=${1:-6}

if ! command -v jq &>/dev/null; then
  echo "jq is required for seeding demo tasks" >&2
  exit 1
fi

if [[ ! -f ${TASK_QUEUE_FILE} ]]; then
  echo '{"tasks": [], "completed": [], "failed": []}' >"${TASK_QUEUE_FILE}"
fi

echo "Seeding ${COUNT} demo tasks..."

for i in $(seq 1 ${COUNT}); do
  id=$(date +%s%N | cut -b1-13)$RANDOM
  # Rotate through a few task types to exercise agent selection
  case $((i % 6)) in
  0)
    type="build"
    desc="Build pipeline"
    ;;
  1)
    type="test"
    desc="Run unit tests"
    ;;
  2)
    type="generate"
    desc="Scaffold feature"
    ;;
  3)
    type="debug"
    desc="Investigate issue"
    ;;
  4)
    type="performance"
    desc="Profile hotspot"
    ;;
  5)
    type="security"
    desc="Security scan"
    ;;
  esac
  priority=$(((RANDOM % 5) + 1))
  # Minimal task object; orchestrator will enrich
  tmp="${TASK_QUEUE_FILE}.tmp$$"
  if jq --arg id "$id" --arg type "$type" --arg desc "$desc" --argjson prio "$priority" '.tasks += [{"id":$id, "type":$type, "description":$desc, "priority":$prio, "status":"queued", "created_at": (now|floor)}]' "${TASK_QUEUE_FILE}" >"${tmp}"; then
    mv "${tmp}" "${TASK_QUEUE_FILE}"
    echo "Added task $id ($type)"
  else
    echo "Failed to add task $id" >&2
    rm -f "${tmp}"
  fi
  sleep 0.1
done

echo "Done."

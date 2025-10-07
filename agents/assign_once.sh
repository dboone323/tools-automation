#!/usr/bin/env bash
# One-shot assigner: normalize agent aliases, notify available agents, mark tasks assigned

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

set -eu
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TASK_QUEUE_FILE="$ROOT_DIR/task_queue.json"
AGENT_STATUS_FILE="$ROOT_DIR/agent_status.json"
COMM_DIR="$ROOT_DIR/communication"
KNOWN_AGENTS=(
  "agent_build.sh"
  "agent_debug.sh"
  "agent_codegen.sh"
  "testing_agent.sh"
  "uiux_agent.sh"
  "apple_pro_agent.sh"
  "collab_agent.sh"
  "updater_agent.sh"
  "search_agent.sh"
  "pull_request_agent.sh"
  "auto_update_agent.sh"
  "knowledge_base_agent.sh"
)

assigned_count=0
skipped_count=0

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required"
  exit 1
fi

is_known_agent() {
  local candidate="$1"
  for known in "${KNOWN_AGENTS[@]}"; do
    if [[ ${known} == "${candidate}" ]]; then
      return 0
    fi
  done
  return 1
}

map_alias() {
  local a="$1"
  local options=()
  options+=("${a}")

  if [[ "$a" == agent_* ]]; then
    local without_prefix="${a#agent_}"
    local stem="${without_prefix%.sh}"
    local alt="${stem}_agent.sh"
    if [[ "${alt}" != "${a}" ]]; then
      options+=("${alt}")
    fi
  fi

  if [[ "$a" == *_agent.sh ]]; then
    local stem="${a%_agent.sh}"
    local alt="agent_${stem}.sh"
    if [[ "${alt}" != "${a}" ]]; then
      options+=("${alt}")
    fi
  fi

  options+=("agent_${a}")

  for option in "${options[@]}"; do
    if [[ -f "$ROOT_DIR/$option" ]] && is_known_agent "${option}"; then
      echo "$option"
      return
    fi
  done

  for option in "${options[@]}"; do
    if [[ -f "$ROOT_DIR/$option" ]]; then
      echo "$option"
      return
    fi
  done

  echo "$a"
}

queued_ids=$(jq -r '.tasks[] | select(.status=="queued") | .id' "$TASK_QUEUE_FILE")
for task_id in $queued_ids; do
  assigned_agent=$(jq -r ".tasks[] | select(.id==\"${task_id}\") | .assigned_agent" "$TASK_QUEUE_FILE")
  normalized_agent=$(map_alias "$assigned_agent")

  agent_status=$(jq -r ".agents[\"${normalized_agent}\"].status // \"unknown\"" "$AGENT_STATUS_FILE" || echo "unknown")

  if [[ "$agent_status" == "unknown" || -z "$agent_status" ]]; then
    alias_status=$(jq -r ".agents[\"${assigned_agent}\"].status // \"unknown\"" "$AGENT_STATUS_FILE" || echo "unknown")
    if [[ "$alias_status" != "unknown" && -n "$alias_status" ]]; then
      normalized_agent="$assigned_agent"
      agent_status="$alias_status"
    fi
  fi

  if [[ "$agent_status" == "available" ]]; then
    # Append notification
    echo "$(date +%s)|execute_task|${task_id}" >>"$COMM_DIR/${normalized_agent}_notification.txt"
    # Update task status to assigned
    jq --arg id "$task_id" '(.tasks[] | select(.id==$id) | .status) |= "assigned"' "$TASK_QUEUE_FILE" >"$TASK_QUEUE_FILE.tmp" && mv "$TASK_QUEUE_FILE.tmp" "$TASK_QUEUE_FILE"
    assigned_count=$((assigned_count + 1))
  else
    skipped_count=$((skipped_count + 1))
  fi

done

echo "Assigned notifications created: $assigned_count"
echo "Skipped (agent not available): $skipped_count"

echo "\nSample notifications (tail 5):"
for f in "$COMM_DIR"/*_notification.txt; do
  echo "--- $(basename "$f") ---"
  tail -n 5 "$f" 2>/dev/null || true
done

echo "\nPost-run counts:"
echo "Queued: $(jq '.tasks[] | select(.status=="queued") | .id' "$TASK_QUEUE_FILE" | wc -l)"
echo "Assigned: $(jq '.tasks[] | select(.status=="assigned") | .id' "$TASK_QUEUE_FILE" | wc -l)"

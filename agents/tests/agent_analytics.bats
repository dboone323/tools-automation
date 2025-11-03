#!/usr/bin/env bats
# Tests for agent_analytics.sh

setup() {
  export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export STATUS_FILE="$SCRIPT_DIR/test_analytics_status.json"
  export TASK_QUEUE_FILE="$SCRIPT_DIR/test_analytics_queue.json"
  echo '{"agents":{},"last_update":0}' > "$STATUS_FILE"
  echo '{"tasks":[]}' > "$TASK_QUEUE_FILE"
}

teardown() {
  rm -f "$STATUS_FILE" "$TASK_QUEUE_FILE"
}

@test "agent_analytics.sh exists and has no syntax errors" {
  [[ -f "$SCRIPT_DIR/agent_analytics.sh" ]]
  bash -n "$SCRIPT_DIR/agent_analytics.sh"
}

@test "agent_analytics.sh has a shebang and references shared functions" {
  head -n1 "$SCRIPT_DIR/agent_analytics.sh" | grep -q '^#!/'
  grep -q 'shared_functions.sh' "$SCRIPT_DIR/agent_analytics.sh"
}

@test "agent_analytics: can update status via shared_functions" {
  source "$SCRIPT_DIR/shared_functions.sh"
  run update_agent_status "agent_analytics" "idle" "$$"
  [ "$status" -eq 0 ]
  run python3 -c "import json; json.load(open('$STATUS_FILE'))"
  [ "$status" -eq 0 ]
}

@test "agent_analytics: task aliasing works for get_next_task" {
  source "$SCRIPT_DIR/shared_functions.sh"
  cat > "$TASK_QUEUE_FILE" <<'EOF'
{ "tasks": [
  {"id":"a1","agent":"agent_analytics","status":"pending","priority":2},
  {"id":"a2","assigned_agent":"analytics_agent","status":"waiting","priority":7}
]}
EOF
  result=$(get_next_task "agent_analytics.sh")
  [[ -n "$result" ]]
}

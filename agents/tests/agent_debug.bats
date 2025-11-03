#!/usr/bin/env bats
# Tests for agent_debug.sh

setup() {
  export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export STATUS_FILE="$SCRIPT_DIR/test_debug_status.json"
  export TASK_QUEUE_FILE="$SCRIPT_DIR/test_debug_queue.json"
  echo '{"agents":{},"last_update":0}' > "$STATUS_FILE"
  echo '{"tasks":[]}' > "$TASK_QUEUE_FILE"
}

teardown() {
  rm -f "$STATUS_FILE" "$TASK_QUEUE_FILE"
}

@test "agent_debug.sh exists and has no syntax errors" {
  [[ -f "$SCRIPT_DIR/agent_debug.sh" ]]
  bash -n "$SCRIPT_DIR/agent_debug.sh"
}

@test "agent_debug.sh has a shebang and references shared functions" {
  head -n1 "$SCRIPT_DIR/agent_debug.sh" | grep -q '^#!/'
  grep -q 'shared_functions.sh' "$SCRIPT_DIR/agent_debug.sh"
}

@test "agent_debug: can update status via shared_functions" {
  source "$SCRIPT_DIR/shared_functions.sh"
  run update_agent_status "agent_debug" "idle" "$$"
  [ "$status" -eq 0 ]
  run python3 -c "import json; json.load(open('$STATUS_FILE'))"
  [ "$status" -eq 0 ]
}

@test "agent_debug: task aliasing works for get_next_task" {
  source "$SCRIPT_DIR/shared_functions.sh"
  cat > "$TASK_QUEUE_FILE" <<'EOF'
{ "tasks": [
  {"id":"d1","agent":"agent_debug","status":"pending","priority":2},
  {"id":"d2","assigned_agent":"debug_agent","status":"queued","priority":4}
]}
EOF
  result=$(get_next_task "agent_debug.sh")
  [[ -n "$result" ]]
}

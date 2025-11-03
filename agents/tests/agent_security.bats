#!/usr/bin/env bats
# Tests for agent_security.sh

setup() {
  export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export STATUS_FILE="$SCRIPT_DIR/test_security_status.json"
  export TASK_QUEUE_FILE="$SCRIPT_DIR/test_security_queue.json"
  echo '{"agents":{},"last_update":0}' > "$STATUS_FILE"
  echo '{"tasks":[]}' > "$TASK_QUEUE_FILE"
}

teardown() {
  rm -f "$STATUS_FILE" "$TASK_QUEUE_FILE"
}

@test "agent_security.sh exists and has no syntax errors" {
  [[ -f "$SCRIPT_DIR/agent_security.sh" ]]
  bash -n "$SCRIPT_DIR/agent_security.sh"
}

@test "agent_security.sh has a shebang and references shared functions" {
  head -n1 "$SCRIPT_DIR/agent_security.sh" | grep -q '^#!/'
  grep -q 'shared_functions.sh' "$SCRIPT_DIR/agent_security.sh"
}

@test "agent_security: can update status via shared_functions" {
  source "$SCRIPT_DIR/shared_functions.sh"
  run update_agent_status "agent_security" "idle" "$$"
  [ "$status" -eq 0 ]
  run python3 -c "import json; json.load(open('$STATUS_FILE'))"
  [ "$status" -eq 0 ]
}

@test "agent_security: task aliasing works for get_next_task" {
  source "$SCRIPT_DIR/shared_functions.sh"
  cat > "$TASK_QUEUE_FILE" <<'EOF'
{ "tasks": [
  {"id":"s1","agent":"agent_security","status":"pending","priority":6},
  {"id":"s2","assigned_agent":"security_agent","status":"assigned","priority":9}
]}
EOF
  result=$(get_next_task "agent_security.sh")
  [[ -n "$result" ]]
}

#!/usr/bin/env bats
# Tests for agent_build.sh

setup() {
  export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export STATUS_FILE="$SCRIPT_DIR/test_build_status.json"
  export TASK_QUEUE_FILE="$SCRIPT_DIR/test_build_queue.json"
  echo '{"agents":{},"last_update":0}' > "$STATUS_FILE"
  echo '{"tasks":[]}' > "$TASK_QUEUE_FILE"
}

teardown() {
  rm -f "$STATUS_FILE" "$TASK_QUEUE_FILE"
}

@test "agent_build.sh exists and has no syntax errors" {
  [[ -f "$SCRIPT_DIR/agent_build.sh" ]]
  bash -n "$SCRIPT_DIR/agent_build.sh"
}

@test "agent_build.sh has a shebang and sources shared functions" {
  head -n1 "$SCRIPT_DIR/agent_build.sh" | grep -q '^#!/'
  grep -q 'shared_functions.sh' "$SCRIPT_DIR/agent_build.sh"
}

@test "agent_build: can update status via shared_functions" {
  source "$SCRIPT_DIR/shared_functions.sh"
  run update_agent_status "agent_build" "idle" "$$"
  [ "$status" -eq 0 ]
  run python3 -c "import json; json.load(open('$STATUS_FILE'))"
  [ "$status" -eq 0 ]
}

@test "agent_build: task aliasing works for get_next_task" {
  source "$SCRIPT_DIR/shared_functions.sh"
  cat > "$TASK_QUEUE_FILE" <<'EOF'
{ "tasks": [
  {"id":"b1","agent":"agent_build","status":"pending","priority":3},
  {"id":"b2","assigned_agent":"build_agent","status":"queued","priority":5}
]}
EOF
  result=$(get_next_task "agent_build.sh")
  [[ -n "$result" ]]
}

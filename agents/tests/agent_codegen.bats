#!/usr/bin/env bats
# Tests for agent_codegen.sh

setup() {
  export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export STATUS_FILE="$SCRIPT_DIR/test_codegen_status.json"
  export TASK_QUEUE_FILE="$SCRIPT_DIR/test_codegen_queue.json"
  echo '{"agents":{},"last_update":0}' > "$STATUS_FILE"
  echo '{"tasks":[]}' > "$TASK_QUEUE_FILE"
}

teardown() {
  rm -f "$STATUS_FILE" "$TASK_QUEUE_FILE"
}

@test "agent_codegen.sh exists and has no syntax errors" {
  [[ -f "$SCRIPT_DIR/agent_codegen.sh" ]]
  bash -n "$SCRIPT_DIR/agent_codegen.sh"
}

@test "agent_codegen.sh has a shebang and references shared functions" {
  head -n1 "$SCRIPT_DIR/agent_codegen.sh" | grep -q '^#!/'
  grep -q 'shared_functions.sh' "$SCRIPT_DIR/agent_codegen.sh"
}

@test "agent_codegen: can update status via shared_functions" {
  source "$SCRIPT_DIR/shared_functions.sh"
  run update_agent_status "agent_codegen" "idle" "$$"
  [ "$status" -eq 0 ]
  run python3 -c "import json; json.load(open('$STATUS_FILE'))"
  [ "$status" -eq 0 ]
}

@test "agent_codegen: task aliasing works for get_next_task" {
  source "$SCRIPT_DIR/shared_functions.sh"
  cat > "$TASK_QUEUE_FILE" <<'EOF'
{ "tasks": [
  {"id":"c1","agent":"agent_codegen","status":"pending","priority":8},
  {"id":"c2","assigned_agent":"codegen_agent","status":"queued","priority":10}
]}
EOF
  result=$(get_next_task "agent_codegen.sh")
  [[ -n "$result" ]]
}

#!/usr/bin/env bats

setup() {
  export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

# Test each agent individually to avoid complex subshell issues
@test "agent_testing.sh quick-exits when piped" {
  run timeout 5 bash -c "cd '${SCRIPT_DIR}' && env -i PATH='/usr/bin:/bin' MAX_INTERVAL=60 SLEEP_INTERVAL=1 bash ./agent_testing.sh 2>&1 | head -5"
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "TestingAgent" ]] || [[ "${output}" =~ "pipeline" ]]
}

@test "agent_build.sh quick-exits when piped" {
  run timeout 5 bash -c "cd '${SCRIPT_DIR}' && env -i PATH='/usr/bin:/bin' MAX_INTERVAL=60 SLEEP_INTERVAL=1 bash ./agent_build.sh 2>&1 | head -5"
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "agent_build" ]] || [[ "${output}" =~ "pipeline" ]]
}

@test "agent_debug.sh quick-exits when piped" {
  run timeout 5 bash -c "cd '${SCRIPT_DIR}' && env -i PATH='/usr/bin:/bin' MAX_INTERVAL=60 SLEEP_INTERVAL=1 bash ./agent_debug.sh 2>&1 | head -5"
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "agent_debug" ]] || [[ "${output}" =~ "pipeline" ]]
}

@test "agent_codegen.sh quick-exits when piped" {
  run timeout 5 bash -c "cd '${SCRIPT_DIR}' && env -i PATH='/usr/bin:/bin' MAX_INTERVAL=60 SLEEP_INTERVAL=1 bash ./agent_codegen.sh 2>&1 | head -5"
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "agent_codegen" ]] || [[ "${output}" =~ "pipeline" ]]
}

@test "agent_security.sh quick-exits when piped" {
  run timeout 5 bash -c "cd '${SCRIPT_DIR}' && env -i PATH='/usr/bin:/bin' MAX_INTERVAL=60 SLEEP_INTERVAL=1 bash ./agent_security.sh 2>&1 | head -5"
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "agent_security" ]] || [[ "${output}" =~ "pipeline" ]]
}

@test "agent_analytics.sh quick-exits when piped" {
  run timeout 5 bash -c "cd '${SCRIPT_DIR}' && env -i PATH='/usr/bin:/bin' MAX_INTERVAL=60 SLEEP_INTERVAL=1 bash ./agent_analytics.sh 2>&1 | head -5"
  [ "$status" -eq 0 ]
  [[ "${output}" =~ "agent_analytics" ]] || [[ "${output}" =~ "pipeline" ]]
}

#!/bin/bash

# Test suite for bridge_assignments_to_tasks.sh
# Comprehensive tests covering all functionality

# Source the test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shell_test_framework.sh"

# Override PROJECT_ROOT for this test
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BRIDGE_SCRIPT="$PROJECT_ROOT/bridge_assignments_to_tasks.sh"

# Test: Basic assignment to task conversion
test_bridge_basic_conversion() {
    echo "Testing basic assignment to task conversion..."

    # Create test workspace
    local test_workspace="/tmp/test_quantum_workspace"
    mkdir -p "$test_workspace/Tools/Automation"
    mkdir -p "$test_workspace/Tools/Automation/agents"

    # Create assignments file
    cat >"$test_workspace/Tools/Automation/agent_assignments.json" <<'EOF'
[
  {
    "id": "test_001",
    "file": "src/main.swift",
    "line": 42,
    "text": "TODO: Implement user authentication",
    "agent": "apple_pro_agent.sh"
  }
]
EOF

    # Create initial task queue
    cat >"$test_workspace/Tools/Automation/agents/task_queue.json" <<'EOF'
{
  "tasks": []
}
EOF

    # Mock the script to use our test workspace
    # Since hardcoded, we need to modify or use sed
    # For simplicity, create symbolic link or modify the script temporarily
    local original_script="$BRIDGE_SCRIPT"
    local temp_script="/tmp/bridge_test.sh"
    sed "s|WORKSPACE_DIR=\"/Users/danielstevens/Desktop/Quantum-workspace\"|WORKSPACE_DIR=\"$test_workspace\"|g" "$original_script" >"$temp_script"
    chmod +x "$temp_script"

    # Run the bridge script
    "$temp_script"

    assert_success "Bridge script execution"

    # Check that task was added
    local task_count
    task_count=$(jq '.tasks | length' "$test_workspace/Tools/Automation/agents/task_queue.json")
    assert_equals 1 "$task_count" "Should have 1 task"

    # Check task details
    local task_id
    task_id=$(jq -r '.tasks[0].id' "$test_workspace/Tools/Automation/agents/task_queue.json")
    assert_equals "todo_test_001" "$task_id" "Task ID should be correct"

    local task_type
    task_type=$(jq -r '.tasks[0].type' "$test_workspace/Tools/Automation/agents/task_queue.json")
    assert_equals "swift" "$task_type" "Task type should be swift"

    # Clean up
    rm -rf "$test_workspace" "$temp_script"
}

# Test: No assignments file
test_bridge_no_assignments() {
    echo "Testing no assignments file..."

    # Create test workspace without assignments file
    local test_workspace="/tmp/test_quantum_workspace_no_assign"
    mkdir -p "$test_workspace/Tools/Automation/agents"

    # Create task queue
    cat >"$test_workspace/Tools/Automation/agents/task_queue.json" <<'EOF'
{
  "tasks": []
}
EOF

    # Modify script
    local temp_script="/tmp/bridge_test_no.sh"
    sed "s|WORKSPACE_DIR=\"/Users/danielstevens/Desktop/Quantum-workspace\"|WORKSPACE_DIR=\"$test_workspace\"|g" "$BRIDGE_SCRIPT" >"$temp_script"
    chmod +x "$temp_script"

    # Run the bridge script
    "$temp_script"

    assert_success "Bridge script with no assignments"

    # Check that no tasks were added
    local task_count
    task_count=$(jq '.tasks | length' "$test_workspace/Tools/Automation/agents/task_queue.json")
    assert_equals 0 "$task_count" "Should have 0 tasks"

    # Clean up
    rm -rf "$test_workspace" "$temp_script"
}

# Test: Duplicate task handling
test_bridge_duplicate_task() {
    echo "Testing duplicate task handling..."

    # Create test workspace
    local test_workspace="/tmp/test_quantum_workspace_dup"
    mkdir -p "$test_workspace/Tools/Automation"
    mkdir -p "$test_workspace/Tools/Automation/agents"

    # Create assignments file with duplicate id
    cat >"$test_workspace/Tools/Automation/agent_assignments.json" <<'EOF'
[
  {
    "id": "test_001",
    "file": "src/main.swift",
    "line": 42,
    "text": "TODO: Implement user authentication",
    "agent": "apple_pro_agent.sh"
  },
  {
    "id": "test_001",
    "file": "src/auth.swift",
    "line": 10,
    "text": "TODO: Add password validation",
    "agent": "security_agent.sh"
  }
]
EOF

    # Create initial task queue
    cat >"$test_workspace/Tools/Automation/agents/task_queue.json" <<'EOF'
{
  "tasks": []
}
EOF

    # Modify script
    local temp_script="/tmp/bridge_test_dup.sh"
    sed "s|WORKSPACE_DIR=\"/Users/danielstevens/Desktop/Quantum-workspace\"|WORKSPACE_DIR=\"$test_workspace\"|g" "$BRIDGE_SCRIPT" >"$temp_script"
    chmod +x "$temp_script"

    # Run the bridge script
    "$temp_script"

    assert_success "Bridge script with duplicates"

    # Check that only 1 task was added (no duplicates)
    local task_count
    task_count=$(jq '.tasks | length' "$test_workspace/Tools/Automation/agents/task_queue.json")
    assert_equals 1 "$task_count" "Should have 1 task (no duplicates)"

    # Clean up
    rm -rf "$test_workspace" "$temp_script"
}

# Test: Multiple agents
test_bridge_multiple_agents() {
    echo "Testing multiple agents..."

    # Create test workspace
    local test_workspace="/tmp/test_quantum_workspace_multi"
    mkdir -p "$test_workspace/Tools/Automation"
    mkdir -p "$test_workspace/Tools/Automation/agents"

    # Create assignments file
    cat >"$test_workspace/Tools/Automation/agent_assignments.json" <<'EOF'
[
  {
    "id": "test_001",
    "file": "src/main.swift",
    "line": 42,
    "text": "TODO: Implement user authentication",
    "agent": "apple_pro_agent.sh"
  },
  {
    "id": "test_002",
    "file": "src/test.py",
    "line": 15,
    "text": "TODO: Add unit tests",
    "agent": "testing_agent.sh"
  }
]
EOF

    # Create initial task queue
    cat >"$test_workspace/Tools/Automation/agents/task_queue.json" <<'EOF'
{
  "tasks": []
}
EOF

    # Modify script
    local temp_script="/tmp/bridge_test_multi.sh"
    sed "s|WORKSPACE_DIR=\"/Users/danielstevens/Desktop/Quantum-workspace\"|WORKSPACE_DIR=\"$test_workspace\"|g" "$BRIDGE_SCRIPT" >"$temp_script"
    chmod +x "$temp_script"

    # Run the bridge script
    "$temp_script"

    assert_success "Bridge script with multiple agents"

    # Check that 2 tasks were added
    local task_count
    task_count=$(jq '.tasks | length' "$test_workspace/Tools/Automation/agents/task_queue.json")
    assert_equals 2 "$task_count" "Should have 2 tasks"

    # Check task types
    local task_types
    task_types=$(jq -r '.tasks[].type' "$test_workspace/Tools/Automation/agents/task_queue.json" | sort)
    local expected="swift
testing"
    assert_equals "$expected" "$task_types" "Task types should be correct"

    # Clean up
    rm -rf "$test_workspace" "$temp_script"
}

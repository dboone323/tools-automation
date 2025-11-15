#!/usr/bin/env bash
        # Auto-injected health & reliability shim

        DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Prefer shared helpers when available
if [[ -f "$DIR/shared_functions.sh" ]]; then
  # shellcheck disable=SC1091
  source "$DIR/shared_functions.sh"
fi

if [[ -f "$DIR/agent_helpers.sh" ]]; then
  # shellcheck disable=SC1091
  source "$DIR/agent_helpers.sh"
fi

set -euo pipefail

AGENT_NAME="test_agents_dependency_graph_agent.sh"
LOG_FILE="${LOG_FILE:-$DIR/${AGENT_NAME}.log}"
PID=$$

if type update_agent_status >/dev/null 2>&1; then
  trap 'update_agent_status "${AGENT_NAME}" "stopped" $$ ""; exit 0' SIGTERM SIGINT
else
  trap 'exit 0' SIGTERM SIGINT
fi

if [[ "${1-}" == "--health" || "${1-}" == "health" || "${1-}" == "-h" ]]; then
  if type agent_health_check >/dev/null 2>&1; then
    agent_health_check
    exit $?
  fi
  issues=()
  if [[ ! -w "/tmp" ]]; then
    issues+=("tmp_not_writable")
  fi
  if [[ ! -d "$DIR" ]]; then
    issues+=("cwd_missing")
  fi
  if [[ ${#issues[@]} -gt 0 ]]; then
    printf '{"ok":false,"issues":["%s"]}\n' "${issues[*]}"
    exit 2
  fi
  printf '{"ok":true}\n'
  exit 0
fi

# Original agent script continues below
#!/bin/bash
# Comprehensive test suite for dependency_graph_agent.sh
# Tests dependency scanning, graph building, file operations, and monitoring functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="${SCRIPT_DIR}/test_tmp"
AGENT_SCRIPT="${SCRIPT_DIR}/agents/dependency_graph_agent.sh"

# Source test framework
source "${SCRIPT_DIR}/shell_test_framework.sh"

# Setup test environment
setup_test_env() {
    mkdir -p "$TEST_DIR"
    export TEST_MODE=true

    # Create test workspace structure with Sources directories
    mkdir -p "${TEST_DIR}/CodingReviewer/Sources"
    mkdir -p "${TEST_DIR}/PlannerApp/Sources"
    mkdir -p "${TEST_DIR}/shared-kit/Sources"

    # Create mock Package.swift files
    cat >"${TEST_DIR}/CodingReviewer/Package.swift" <<'EOF'
// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "CodingReviewer",
    dependencies: [
        .package(name: "shared-kit", path: "../shared-kit"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.6.0"),
    ]
)
EOF

    cat >"${TEST_DIR}/PlannerApp/Package.swift" <<'EOF'
// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "PlannerApp",
    dependencies: [
        .package(name: "shared-kit", path: "../shared-kit"),
        .package(url: "https://github.com/ReactiveX/RxSwift.git", from: "6.5.0"),
    ]
)
EOF

    # Create mock Swift files with imports
    cat >"${TEST_DIR}/CodingReviewer/Sources/Main.swift" <<'EOF'
import Foundation
import shared_kit
import Alamofire

class MainClass {
    // Main implementation
}
EOF

    cat >"${TEST_DIR}/PlannerApp/Sources/App.swift" <<'EOF'
import UIKit
import shared_kit
import RxSwift

class AppDelegate {
    // App delegate implementation
}
EOF

    cat >"${TEST_DIR}/shared-kit/Sources/Kit.swift" <<'EOF'
import Foundation

public class SharedKit {
    // Shared functionality
}
EOF

    # Set up environment variables for testing
    export WORKSPACE_ROOT="$TEST_DIR"
    export GRAPH_FILE="${TEST_DIR}/dependency_graph.json"
    export SCAN_INTERVAL=1 # Fast scanning for tests
}

# Cleanup test environment
cleanup_test_env() {
    # Clean up test files
    rm -rf "$TEST_DIR"
    rm -f "${SCRIPT_DIR}/agents/dependency_graph_agent.log"
    rm -f "${SCRIPT_DIR}/dependency_graph.json"

    # Kill any test processes
    pkill -f "dependency_graph_agent.sh" || true
}

# Test 1: Swift dependency scanning
test_swift_dependency_scanning() {
    local test_name="test_swift_dependency_scanning"
    announce_test "$test_name"

    # Source the agent script to get functions
    source "$AGENT_SCRIPT" 2>/dev/null || true

    # Test scanning CodingReviewer dependencies
    local deps
    deps=$(scan_swift_dependencies "CodingReviewer")
    if echo "$deps" | grep -q "shared-kit"; then
        assert_true true "Should find shared-kit dependency"
    else
        assert_true false "Should find shared-kit dependency - found: $deps"
    fi

    # Test scanning PlannerApp dependencies
    deps=$(scan_swift_dependencies "PlannerApp")
    if echo "$deps" | grep -q "shared-kit"; then
        assert_true true "Should find shared-kit dependency in PlannerApp"
    else
        assert_true false "Should find shared-kit dependency in PlannerApp - found: $deps"
    fi

    test_passed "$test_name"
}

# Test 2: Swift import scanning
test_swift_import_scanning() {
    local test_name="test_swift_import_scanning"
    announce_test "$test_name"

    # Source the agent script to get functions
    source "$AGENT_SCRIPT" 2>/dev/null || true

    # Test scanning CodingReviewer imports
    local imports
    imports=$(scan_swift_imports "CodingReviewer")
    if echo "$imports" | grep -q "Foundation\|shared_kit\|Alamofire"; then
        assert_true true "Should find Swift imports in CodingReviewer"
    else
        assert_true false "Should find Swift imports in CodingReviewer"
    fi

    # Test scanning PlannerApp imports
    imports=$(scan_swift_imports "PlannerApp")
    if echo "$imports" | grep -q "UIKit\|RxSwift"; then
        assert_true true "Should find Swift imports in PlannerApp"
    else
        assert_true false "Should find Swift imports in PlannerApp"
    fi

    test_passed "$test_name"
}

# Test 3: Graph building functionality
test_graph_building() {
    local test_name="test_graph_building"
    announce_test "$test_name"

    # Source the agent script to get functions
    source "$AGENT_SCRIPT" 2>/dev/null || true

    # Mock the log_message function to avoid file writes
    log_message() { :; }

    # Test graph building
    build_graph

    # Check if graph file was created
    if [[ -f "$GRAPH_FILE" ]]; then
        assert_true true "Dependency graph file should be created"
    else
        assert_true false "Dependency graph file should be created"
    fi

    # Check if graph contains valid JSON
    if [[ -f "$GRAPH_FILE" ]]; then
        local content
        content=$(cat "$GRAPH_FILE")
        if echo "$content" | grep -q '"version"\|"nodes"\|"edges"'; then
            assert_true true "Graph file should contain valid JSON structure"
        else
            assert_true false "Graph file should contain valid JSON structure"
        fi
    fi

    test_passed "$test_name"
}

# Test 4: Log file creation
test_log_file_creation() {
    local test_name="test_log_file_creation"
    announce_test "$test_name"

    # Clear any existing log
    rm -f "${SCRIPT_DIR}/agents/dependency_graph_agent.log"

    # Run agent once
    bash "$AGENT_SCRIPT" once >/dev/null 2>&1

    # Check if log file was created
    assert_file_exists "${SCRIPT_DIR}/agents/dependency_graph_agent.log" "Log file should be created"

    # Check log contains agent name
    local log_content
    log_content=$(cat "${SCRIPT_DIR}/agents/dependency_graph_agent.log" 2>/dev/null || echo "")
    if echo "$log_content" | grep -q "dependency_graph_agent.sh"; then
        assert_true true "Log should contain agent name"
    else
        assert_true false "Log should contain agent name"
    fi

    test_passed "$test_name"
}

# Test 5: Environment variable handling
test_environment_variables() {
    local test_name="test_environment_variables"
    announce_test "$test_name"

    # Source the agent script to check variables
    source "$AGENT_SCRIPT" 2>/dev/null || true

    # Check if key variables are set
    if [[ -n "$AGENT_NAME" && "$AGENT_NAME" == "dependency_graph_agent.sh" ]]; then
        assert_true true "AGENT_NAME should be set correctly"
    else
        assert_true false "AGENT_NAME should be set correctly"
    fi

    if [[ -n "$WORKSPACE_ROOT" ]]; then
        assert_true true "WORKSPACE_ROOT should be set"
    else
        assert_true false "WORKSPACE_ROOT should be set"
    fi

    if [[ -n "$GRAPH_FILE" ]]; then
        assert_true true "GRAPH_FILE should be set"
    else
        assert_true false "GRAPH_FILE should be set"
    fi

    test_passed "$test_name"
}

# Test 6: File system operations
test_file_system_operations() {
    local test_name="test_file_system_operations"
    announce_test "$test_name"

    # Source the agent script to get functions
    source "$AGENT_SCRIPT" 2>/dev/null || true

    # Mock log_message
    log_message() { :; }

    # Test with existing directories
    build_graph

    # Check if graph file exists and is readable
    if [[ -f "$GRAPH_FILE" && -r "$GRAPH_FILE" ]]; then
        assert_true true "Graph file should be created and readable"
    else
        assert_true false "Graph file should be created and readable"
    fi

    # Test file size is reasonable
    local file_size
    file_size=$(stat -f%z "$GRAPH_FILE" 2>/dev/null || echo "0")
    if [[ "$file_size" -gt 10 ]]; then # Should contain some JSON content
        assert_true true "Graph file should contain content"
    else
        assert_true false "Graph file should contain content"
    fi

    test_passed "$test_name"
}

# Test 7: Error handling for missing files
test_missing_file_handling() {
    local test_name="test_missing_file_handling"
    announce_test "$test_name"

    # Source the agent script to get functions
    source "$AGENT_SCRIPT" 2>/dev/null || true

    # Test scanning non-existent project
    local deps
    deps=$(scan_swift_dependencies "NonExistentProject")
    if [[ -z "$deps" ]]; then
        assert_true true "Should handle missing Package.swift gracefully"
    else
        assert_true false "Should handle missing Package.swift gracefully"
    fi

    # Test scanning imports from non-existent project
    local imports
    imports=$(scan_swift_imports "NonExistentProject")
    if [[ -z "$imports" ]]; then
        assert_true true "Should handle missing project directory gracefully"
    else
        assert_true false "Should handle missing project directory gracefully"
    fi

    test_passed "$test_name"
}

# Test 8: JSON structure validation
test_json_structure() {
    local test_name="test_json_structure"
    announce_test "$test_name"

    # Source the agent script to get functions
    source "$AGENT_SCRIPT" 2>/dev/null || true

    # Mock log_message
    log_message() { :; }

    # Build graph
    build_graph

    # Check JSON structure
    if [[ -f "$GRAPH_FILE" ]]; then
        local content
        content=$(cat "$GRAPH_FILE")

        # Check for required JSON fields
        if echo "$content" | grep -q '"version"'; then
            assert_true true "JSON should contain version field"
        else
            assert_true false "JSON should contain version field"
        fi

        if echo "$content" | grep -q '"updated"'; then
            assert_true true "JSON should contain updated timestamp"
        else
            assert_true false "JSON should contain updated timestamp"
        fi

        if echo "$content" | grep -q '"nodes"'; then
            assert_true true "JSON should contain nodes array"
        else
            assert_true false "JSON should contain nodes array"
        fi

        if echo "$content" | grep -q '"edges"'; then
            assert_true true "JSON should contain edges array"
        else
            assert_true false "JSON should contain edges array"
        fi
    else
        assert_true false "Graph file should exist for JSON validation"
    fi

    test_passed "$test_name"
}

# Test 9: Submodule scanning
test_submodule_scanning() {
    local test_name="test_submodule_scanning"
    announce_test "$test_name"

    # Source the agent script to get functions
    source "$AGENT_SCRIPT" 2>/dev/null || true

    # Mock log_message
    log_message() { :; }

    # Build graph and check if submodules were scanned
    build_graph

    # Check if graph contains the test submodules
    if [[ -f "$GRAPH_FILE" ]]; then
        local content
        content=$(cat "$GRAPH_FILE")

        # Should contain at least some of our test modules
        if echo "$content" | grep -q "CodingReviewer\|PlannerApp\|shared-kit"; then
            assert_true true "Graph should contain scanned submodules"
        else
            assert_true false "Graph should contain scanned submodules"
        fi
    else
        assert_true false "Graph file should exist for submodule validation"
    fi

    test_passed "$test_name"
}

# Test 10: Agent execution and monitoring
test_agent_execution() {
    local test_name="test_agent_execution"
    announce_test "$test_name"

    # Clear log file
    rm -f "${SCRIPT_DIR}/agents/dependency_graph_agent.log"

    # Run agent once
    bash "$AGENT_SCRIPT" once >/dev/null 2>&1

    # Check if agent ran (log should contain messages)
    local log_content
    log_content=$(cat "${SCRIPT_DIR}/agents/dependency_graph_agent.log" 2>/dev/null || echo "")
    if echo "$log_content" | grep -q "Building dependency graph\|Scanning"; then
        assert_true true "Agent should execute and log dependency scanning"
    else
        assert_true false "Agent should execute and log dependency scanning"
    fi

    # Check if graph file was created
    assert_file_exists "$GRAPH_FILE" "Graph file should be created during execution"

    test_passed "$test_name"
}

# Run all tests
run_tests() {
    setup_test_env

    echo "Running comprehensive tests for dependency_graph_agent.sh..."
    echo "================================================================="

    # Run individual tests
    test_swift_dependency_scanning
    test_swift_import_scanning
    test_graph_building
    test_log_file_creation
    test_environment_variables
    test_file_system_operations
    test_missing_file_handling
    test_json_structure
    test_submodule_scanning
    test_agent_execution

    echo "================================================================="
    echo "Test Summary:"
    echo "Total tests: $(get_total_tests)"
    echo "Passed: $(get_passed_tests)"
    echo "Failed: $(get_failed_tests)"

    cleanup_test_env

    # Return success/failure
    if [[ $(get_failed_tests) -eq 0 ]]; then
        echo "✅ All tests passed!"
        return 0
    else
        echo "❌ Some tests failed!"
        return 1
    fi
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi

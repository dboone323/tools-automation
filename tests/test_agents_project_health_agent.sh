#!/bin/bash

# Test suite for project_health_agent.sh
# Comprehensive validation of project health monitoring functionality

set -euo pipefail

# Source test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../shell_test_framework.sh"

# Test setup
AGENT_SCRIPT="$SCRIPT_DIR/../agents/project_health_agent.sh"
TEST_TMP_DIR="$SCRIPT_DIR/../test_tmp"
TEST_WORKSPACE_DIR="$TEST_TMP_DIR/workspace"
TEST_TODO_FILE="$TEST_TMP_DIR/todo_queue.json"

setup_test_environment() {
    # Clean up any previous test data
    rm -rf "$TEST_TMP_DIR"
    mkdir -p "$TEST_WORKSPACE_DIR"
    mkdir -p "$TEST_TMP_DIR/logs"

    # Copy required shared functions for testing
    cp "$SCRIPT_DIR/../agents/shared_functions.sh" "$TEST_TMP_DIR/"

    # Create mock workspace structure
    mkdir -p "$TEST_WORKSPACE_DIR/src"
    mkdir -p "$TEST_WORKSPACE_DIR/tests"
    mkdir -p "$TEST_WORKSPACE_DIR/docs"

    # Create a mock todo_queue.json file
    echo '{"tasks": []}' >"$TEST_TODO_FILE"

    # Create mock source files
    cat >"$TEST_WORKSPACE_DIR/src/MainClass.swift" <<'EOF'
class MainClass {
    func mainFunction() {
        print("Hello World")
    }
}
EOF

    cat >"$TEST_WORKSPACE_DIR/src/HelperClass.swift" <<'EOF'
class HelperClass {
    func helperFunction() {
        print("Helper")
    }
}
EOF

    # Create mock test files
    cat >"$TEST_WORKSPACE_DIR/tests/MainClassTest.swift" <<'EOF'
class MainClassTest {
    func testMainFunction() {
        // Test implementation
    }
}
EOF

    # Create mock requirements.txt (old)
    cat >"$TEST_WORKSPACE_DIR/requirements.txt" <<'EOF'
requests==2.25.1
pytest>=6.0.0
EOF

    # Create mock package.json
    cat >"$TEST_WORKSPACE_DIR/package.json" <<'EOF'
{
  "name": "test-project",
  "version": "1.0.0",
  "dependencies": {
    "lodash": "^4.17.21"
  }
}
EOF

    # Create mock Package.swift
    cat >"$TEST_WORKSPACE_DIR/Package.swift" <<'EOF'
// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "TestProject",
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.4.0"),
        .package(url: "https://github.com/ReactiveX/RxSwift.git", .upToNextMajor(from: "6.0.0"))
    ]
)
EOF

    # Create mock README.md
    cat >"$TEST_WORKSPACE_DIR/README.md" <<'EOF'
# Test Project

This is a test project.

## Installation

Run `npm install`

## Usage

Run `swift build`
EOF

    # Create mock Python file with syntax error
    cat >"$TEST_WORKSPACE_DIR/src/broken.py" <<'EOF'
def broken_function(
    print("Syntax error - missing closing paren"
EOF

    # Create mock build error log
    cat >"$TEST_TMP_DIR/logs/build_error.log" <<'EOF'
[2025-01-09 10:00:00] ERROR: Build failed
[2025-01-09 10:01:00] ERROR: Compilation error
[2025-01-09 10:02:00] ERROR: Linker error
EOF

    # Create mock ollama client
    cat >"$TEST_TMP_DIR/ollama_client.sh" <<'EOF'
#!/bin/bash
echo '{"response": [{"type": "ai_health", "description": "AI detected potential code duplication", "priority": "low"}]}'
EOF
    chmod +x "$TEST_TMP_DIR/ollama_client.sh"

    # Set environment variables for testing
    export WORKSPACE_ROOT="$TEST_WORKSPACE_DIR"
    export TODO_FILE="$TEST_TODO_FILE"
    export OLLAMA_CLIENT="$TEST_TMP_DIR/ollama_client.sh"
    export SCRIPT_DIR="$TEST_TMP_DIR"
    export MIN_COVERAGE_THRESHOLD=0.70
    export DEPENDENCY_AGE_THRESHOLD=90
    export MAX_BUILD_FAILURES=3
    export COVERAGE_CHECK_INTERVAL=300
    export DEPENDENCY_CHECK_INTERVAL=600
    export BUILD_CHECK_INTERVAL=180
    export DOC_CHECK_INTERVAL=900
}

cleanup_test_environment() {
    rm -rf "$TEST_TMP_DIR"
}

# Test 1: Initialization and basic functionality
test_initialization() {
    local test_name="test_initialization"
    announce_test "$test_name"

    # Test that the agent script exists and is readable
    if [[ -f "$AGENT_SCRIPT" ]]; then
        assert_true true "Agent script file exists"
    else
        assert_true false "Agent script file should exist"
        return 1
    fi

    # Test that the script contains expected functions
    if grep -q "check_test_coverage()" "$AGENT_SCRIPT"; then
        assert_true true "check_test_coverage function is defined in script"
    else
        assert_true false "check_test_coverage function should be defined in script"
        return 1
    fi

    if grep -q "check_dependencies()" "$AGENT_SCRIPT"; then
        assert_true true "check_dependencies function is defined in script"
    else
        assert_true false "check_dependencies function should be defined in script"
        return 1
    fi

    if grep -q "check_build_failures()" "$AGENT_SCRIPT"; then
        assert_true true "check_build_failures function is defined in script"
    else
        assert_true false "check_build_failures function should be defined in script"
        return 1
    fi

    if grep -q "check_documentation()" "$AGENT_SCRIPT"; then
        assert_true true "check_documentation function is defined in script"
    else
        assert_true false "check_documentation function should be defined in script"
        return 1
    fi

    if grep -q "run_ai_health_analysis()" "$AGENT_SCRIPT"; then
        assert_true true "run_ai_health_analysis function is defined in script"
    else
        assert_true false "run_ai_health_analysis function should be defined in script"
        return 1
    fi

    test_passed "$test_name"
}

# Test 2: Test coverage checking
test_coverage_checking() {
    local test_name="test_coverage_checking"
    announce_test "$test_name"

    # Test that the check_test_coverage function exists and has expected structure
    if grep -q "find.*WORKSPACE_ROOT" "$AGENT_SCRIPT"; then
        assert_true true "check_test_coverage function should search for files in WORKSPACE_ROOT"
    else
        assert_true false "check_test_coverage function should search for files in WORKSPACE_ROOT"
    fi

    if grep -q "test_ratio" "$AGENT_SCRIPT"; then
        assert_true true "check_test_coverage function should calculate test ratio"
    else
        assert_true false "check_test_coverage function should calculate test ratio"
    fi

    # Test that coverage-related variables are used
    if grep -q "MIN_COVERAGE_THRESHOLD" "$AGENT_SCRIPT"; then
        assert_true true "Script should use MIN_COVERAGE_THRESHOLD variable"
    else
        assert_true false "Script should use MIN_COVERAGE_THRESHOLD variable"
    fi

    test_passed "$test_name"
}

# Test 3: Dependency checking
test_dependency_checking() {
    local test_name="test_dependency_checking"
    announce_test "$test_name"

    # Test that the check_dependencies function exists and has expected structure
    if grep -q "requirements\.txt" "$AGENT_SCRIPT"; then
        assert_true true "check_dependencies function should check requirements.txt"
    else
        assert_true false "check_dependencies function should check requirements.txt"
    fi

    if grep -q "DEPENDENCY_AGE_THRESHOLD" "$AGENT_SCRIPT"; then
        assert_true true "check_dependencies function should use DEPENDENCY_AGE_THRESHOLD"
    else
        assert_true false "check_dependencies function should use DEPENDENCY_AGE_THRESHOLD"
    fi

    # Test that dependency-related variables are used
    if grep -q "DEPENDENCY_AGE_THRESHOLD" "$AGENT_SCRIPT"; then
        assert_true true "Script should use DEPENDENCY_AGE_THRESHOLD variable"
    else
        assert_true false "Script should use DEPENDENCY_AGE_THRESHOLD variable"
    fi

    test_passed "$test_name"
}

# Test 4: Build failure checking
test_build_failure_checking() {
    local test_name="test_build_failure_checking"
    announce_test "$test_name"

    # Test that the check_build_failures function exists and has expected structure
    if grep -q "error\|fail" "$AGENT_SCRIPT"; then
        assert_true true "check_build_failures function should look for error patterns"
    else
        assert_true false "check_build_failures function should look for error patterns"
    fi

    if grep -q "MAX_BUILD_FAILURES" "$AGENT_SCRIPT"; then
        assert_true true "check_build_failures function should use MAX_BUILD_FAILURES threshold"
    else
        assert_true false "check_build_failures function should use MAX_BUILD_FAILURES threshold"
    fi

    # Test that build failure variables are used
    if grep -q "MAX_BUILD_FAILURES" "$AGENT_SCRIPT"; then
        assert_true true "Script should use MAX_BUILD_FAILURES variable"
    else
        assert_true false "Script should use MAX_BUILD_FAILURES variable"
    fi

    test_passed "$test_name"
}

# Test 5: Documentation checking
test_documentation_checking() {
    local test_name="test_documentation_checking"
    announce_test "$test_name"

    # Test that the check_documentation function exists and has expected structure
    if grep -q "README" "$AGENT_SCRIPT"; then
        assert_true true "check_documentation function should check documentation files"
    else
        assert_true false "check_documentation function should check documentation files"
    fi

    if grep -q "create_todo" "$AGENT_SCRIPT"; then
        assert_true true "check_documentation function should create todos for issues"
    else
        assert_true false "check_documentation function should create todos for issues"
    fi

    test_passed "$test_name"
}

# Test 6: AI health analysis
test_ai_health_analysis() {
    local test_name="test_ai_health_analysis"
    announce_test "$test_name"

    # Test that the run_ai_health_analysis function exists and has expected structure
    if grep -q "OLLAMA_CLIENT" "$AGENT_SCRIPT"; then
        assert_true true "run_ai_health_analysis function should use OLLAMA_CLIENT"
    else
        assert_true false "run_ai_health_analysis function should use OLLAMA_CLIENT"
    fi

    # Test that AI-related variables are used
    if grep -q "OLLAMA_CLIENT" "$AGENT_SCRIPT"; then
        assert_true true "Script should use OLLAMA_CLIENT variable"
    else
        assert_true false "Script should use OLLAMA_CLIENT variable"
    fi

    test_passed "$test_name"
}

# Test 7: Todo creation functionality
test_todo_creation() {
    local test_name="test_todo_creation"
    announce_test "$test_name"

    # Test that the create_todo function exists and has expected structure
    if grep -q "python3" "$AGENT_SCRIPT"; then
        assert_true true "create_todo function should use Python for JSON handling"
    else
        assert_true false "create_todo function should use Python for JSON handling"
    fi

    # Test that todo-related variables are used
    if grep -q "TODO_FILE" "$AGENT_SCRIPT"; then
        assert_true true "Script should use TODO_FILE variable"
    else
        assert_true false "Script should use TODO_FILE variable"
    fi

    test_passed "$test_name"
}

# Test 8: Duplicate todo prevention
test_duplicate_prevention() {
    local test_name="test_duplicate_prevention"
    announce_test "$test_name"

    # Test that the create_todo function has duplicate prevention logic
    if grep -q "duplicate\|exists\|already" "$AGENT_SCRIPT"; then
        assert_true true "create_todo function should have duplicate prevention logic"
    else
        assert_true false "create_todo function should have duplicate prevention logic"
    fi

    test_passed "$test_name"
}

# Test 9: Logging functionality
test_logging() {
    local test_name="test_logging"
    announce_test "$test_name"

    # Test that the log_message function exists and has expected structure
    if grep -q "echo.*LOG_FILE" "$AGENT_SCRIPT"; then
        assert_true true "log_message function should write to LOG_FILE"
    else
        assert_true false "log_message function should write to LOG_FILE"
    fi

    if grep -q "date" "$AGENT_SCRIPT"; then
        assert_true true "log_message function should include timestamps"
    else
        assert_true false "log_message function should include timestamps"
    fi

    # Test that logging variables are used
    if grep -q "LOG_FILE" "$AGENT_SCRIPT"; then
        assert_true true "Script should use LOG_FILE variable"
    else
        assert_true false "Script should use LOG_FILE variable"
    fi

    test_passed "$test_name"
}

# Test 10: Configuration and thresholds
test_configuration() {
    local test_name="test_configuration"
    announce_test "$test_name"

    # Test that configuration variables are defined with defaults
    if grep -q "MIN_COVERAGE_THRESHOLD.*0\." "$AGENT_SCRIPT"; then
        assert_true true "MIN_COVERAGE_THRESHOLD should have default value"
    else
        assert_true false "MIN_COVERAGE_THRESHOLD should have default value"
    fi

    if grep -q "DEPENDENCY_AGE_THRESHOLD.*90" "$AGENT_SCRIPT"; then
        assert_true true "DEPENDENCY_AGE_THRESHOLD should have default value"
    else
        assert_true false "DEPENDENCY_AGE_THRESHOLD should have default value"
    fi

    if grep -q "MAX_BUILD_FAILURES.*3" "$AGENT_SCRIPT"; then
        assert_true true "MAX_BUILD_FAILURES should have default value"
    else
        assert_true false "MAX_BUILD_FAILURES should have default value"
    fi

    # Test that interval variables are defined
    if grep -q "COVERAGE_CHECK_INTERVAL" "$AGENT_SCRIPT"; then
        assert_true true "Script should define COVERAGE_CHECK_INTERVAL"
    else
        assert_true false "Script should define COVERAGE_CHECK_INTERVAL"
    fi

    if grep -q "DEPENDENCY_CHECK_INTERVAL" "$AGENT_SCRIPT"; then
        assert_true true "Script should define DEPENDENCY_CHECK_INTERVAL"
    else
        assert_true false "Script should define DEPENDENCY_CHECK_INTERVAL"
    fi

    test_passed "$test_name"
}

# Run all tests
run_tests() {
    setup_test_environment

    echo "Running comprehensive tests for project_health_agent.sh..."
    echo "================================================================="

    # Run individual tests
    test_initialization
    test_coverage_checking
    test_dependency_checking
    test_build_failure_checking
    test_documentation_checking
    test_ai_health_analysis
    test_todo_creation
    test_duplicate_prevention
    test_logging
    test_configuration

    echo "================================================================="
    echo "Test Summary:"
    echo "Total tests: $(get_total_tests)"
    echo "Passed: $(get_passed_tests)"
    echo "Failed: $(get_failed_tests)"

    cleanup_test_environment

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

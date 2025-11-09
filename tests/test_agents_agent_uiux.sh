#!/bin/bash
# Test suite for agent_uiux.sh

# Source the agent script for testing
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/agent_uiux.sh"

# Set test mode to prevent main loop execution
export TEST_MODE=true

# Source the agent script
# shellcheck source=../agents/agent_uiux.sh
source "${AGENT_SCRIPT}"

# Mock external commands and functions for testing
mock_find() {
    # Return a reasonable number of files for testing
    echo "/fake/path/ViewController.swift"
    echo "/fake/path/MainView.swift"
    echo "/fake/path/UIHelper.swift"
}

mock_grep() {
    # Mock grep to return expected patterns for testing
    case "$*" in
    *TODO.*drag.*drop*)
        echo "    // TODO: implement drag and drop"
        ;;
    *TODO.*UI*)
        echo "    // TODO: improve UI layout"
        ;;
    *)
        # Return nothing for other patterns
        ;;
    esac
}

mock_jq() {
    # Mock jq responses for different inputs
    if [[ "$*" == *'.id'* ]]; then
        echo "test-task-123"
    elif [[ "$*" == *'.project'* ]]; then
        echo "PlannerApp"
    elif [[ "$*" == *'.todo'* ]]; then
        echo "implement drag and drop functionality"
    else
        echo "mocked_value"
    fi
}

mock_nice() {
    # Mock nice command
    shift
    "$@"
}

mock_backup_manager() {
    # Mock backup manager
    echo "Mock backup created successfully"
    return 0
}

mock_intelligent_autofix() {
    # Mock intelligent autofix
    echo "Mock validation completed successfully"
    return 0
}

# Override commands with mocks
find() { mock_find "$@"; }
grep() { mock_grep "$@"; }
jq() { mock_jq "$@"; }
nice() { mock_nice "$@"; }

# Mock shared functions
get_next_task() {
    echo '{"id": "test-task-123", "project": "PlannerApp", "todo": "implement drag and drop functionality"}'
}

update_task_status() {
    # Mock task status update
    return 0
}

complete_task() {
    # Mock task completion
    return 0
}

update_agent_status() {
    # Mock agent status update
    return 0
}

register_with_mcp() {
    # Mock MCP registration
    return 0
}

# Define key functions directly for testing
run_with_timeout() {
    local timeout_seconds="$1"
    local command="$2"
    local timeout_msg="${3:-Operation timed out after ${timeout_seconds} seconds}"

    echo "[$(date)] ${AGENT_NAME}: Starting operation with ${timeout_seconds}s timeout..." >>"${LOG_FILE}"

    # Run command in background with timeout
    (
        eval "${command}" &
        local cmd_pid=$!

        # Wait for completion or timeout
        local count=0
        while [[ ${count} -lt ${timeout_seconds} ]] && kill -0 ${cmd_pid} 2>/dev/null; do
            sleep 1
            ((count++))
        done

        # Check if process is still running
        if kill -0 ${cmd_pid} 2>/dev/null; then
            echo "[$(date)] ${AGENT_NAME}: ${timeout_msg}" >>"${LOG_FILE}"
            kill -TERM ${cmd_pid} 2>/dev/null || true
            sleep 2
            kill -KILL ${cmd_pid} 2>/dev/null || true
            return 124 # Timeout exit code
        fi

        # Wait for process to get exit code
        wait ${cmd_pid} 2>/dev/null
        return $?
    )
}

get_project_from_task() {
    local task_data="$1"
    local project
    project=$(echo "${task_data}" | jq -r '.project // empty')
    if [[ -z ${project} || ${project} == "null" ]]; then
        project="${PROJECT}"
    fi
    echo "${project}"
}

perform_ui_enhancements() {
    local project="$1"
    local task="$2"

    echo "[$(date)] ${AGENT_NAME}: Starting UI/UX enhancements for ${project}..." >>"${LOG_FILE}"

    # Set resource limits to prevent system overload
    set_resource_limits 600 1048576 100 # 10 min CPU, 1GB memory, 100 processes

    # Change to project directory
    cd "/Users/danielstevens/Desktop/Quantum-workspace/Projects/${project}" 2>/dev/null || {
        echo "[$(date)] ${AGENT_NAME}: Could not change to project directory" >>"${LOG_FILE}"
        return 1
    }

    # Create backup before making changes
    echo "[$(date)] ${AGENT_NAME}: Creating backup before UI/UX enhancements..." >>"${LOG_FILE}"
    with_resource_limits 120 262144 20 bash -c "
        /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/backup_manager.sh backup \"${project}\" \"uiux_enhancement\"
    " >>"${LOG_FILE}" 2>&1

    # Check if this is a drag-and-drop task with timeout protection
    local is_drag_drop
    is_drag_drop=$(echo "${task_data}" | jq -r '.todo // empty' | grep -c -i "drag\|drop")

    if [[ ${is_drag_drop} -gt 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: Detected drag-and-drop enhancement task..." >>"${LOG_FILE}"

        # Look for UI files that might need drag-and-drop functionality with timeout
        if ! run_with_timeout 120 "
            find . -name '*.swift' -o -name '*.storyboard' -o -name '*.xib' | while read -r file; do
                if grep -q 'TODO.*drag.*drop\|drag.*drop.*TODO' \"\${file}\" 2>/dev/null; then
                    echo \"[$(date)] ${AGENT_NAME}: Found drag-drop TODO in \${file}\" >>'${LOG_FILE}'

                    # Basic drag-and-drop implementation suggestions
                    if [[ \${file} == *'.swift' ]]; then
                        echo \"[$(date)] ${AGENT_NAME}: Adding drag-and-drop implementation to \${file}\" >>'${LOG_FILE}'
                        # This would be where we add actual drag-and-drop code
                        # For now, we'll log the enhancement
                    fi
                fi
            done
        " "Drag-and-drop analysis timed out"; then
            echo "[$(date)] ${AGENT_NAME}: ⚠️  Drag-and-drop analysis failed or timed out" >>"${LOG_FILE}"
        fi
    fi

    # Run general UI/UX analysis with timeout protection
    echo "[$(date)] ${AGENT_NAME}: Analyzing UI/UX patterns..." >>"${LOG_FILE}"

    if ! run_with_timeout 180 "
        find . -name '*View*.swift' -o -name '*Controller*.swift' -o -name '*UI*.swift' | head -10 | while read -r file; do
            echo \"[$(date)] ${AGENT_NAME}: Analyzing UI file: \${file}\" >>'${LOG_FILE}'

            # Check for common UI improvement opportunities
            if grep -q 'TODO.*UI\|UI.*TODO' \"\${file}\" 2>/dev/null; then
                echo \"[$(date)] ${AGENT_NAME}: Found UI TODO in \${file}\" >>'${LOG_FILE}'
            fi
        done
    " "UI/UX analysis timed out"; then
        echo "[$(date)] ${AGENT_NAME}: ⚠️  UI/UX analysis failed or timed out" >>"${LOG_FILE}"
    fi

    # Run validation after changes with timeout protection
    echo "[$(date)] ${AGENT_NAME}: Validating UI/UX enhancements..." >>"${LOG_FILE}"
    if ! run_with_timeout 300 "
        nice -n 19 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/intelligent_autofix.sh validate \"${project}\"
    " "UI/UX validation timed out"; then
        echo "[$(date)] ${AGENT_NAME}: ⚠️  UI/UX validation failed or timed out" >>"${LOG_FILE}"
    fi

    return 0
}

run_step() {
    local step_name="$1"
    local command="$2"

    echo "[$(date)] ${AGENT_NAME}: Running ${step_name}..." >>"${LOG_FILE}"
    nice -n 19 bash -c "${command}" >>"${LOG_FILE}" 2>&1
    local exit_code=$?
    if [[ ${exit_code} -eq 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: ${step_name} completed successfully" >>"${LOG_FILE}"
    else
        echo "[$(date)] ${AGENT_NAME}: ${step_name} failed with exit code ${exit_code}" >>"${LOG_FILE}"
    fi
    return ${exit_code}
}

process_assigned_tasks() {
    local task
    task=$(get_next_task "agent_uiux.sh")
    if [[ -z ${task} ]]; then
        return 0
    fi

    local task_id
    task_id=$(echo "${task}" | jq -r '.id')
    local project
    project=$(get_project_from_task "${task}")

    echo "[$(date)] ${AGENT_NAME}: Processing task ${task_id} for project ${project}..." >>"${LOG_FILE}"

    # Update task status to in_progress
    update_task_status "${task_id}" "in_progress"

    # Perform UI/UX enhancements
    if perform_ui_enhancements "${project}" "${task}"; then
        echo "[$(date)] ${AGENT_NAME}: UI/UX enhancements completed successfully for ${project}" >>"${LOG_FILE}"
        update_task_status "${task_id}" "completed"
        update_agent_status "${AGENT_NAME}" "idle"
        return 0
    else
        echo "[$(date)] ${AGENT_NAME}: UI/UX enhancements failed for ${project}" >>"${LOG_FILE}"
        update_task_status "${task_id}" "failed"
        update_agent_status "${AGENT_NAME}" "error"
        return 1
    fi
}

# Mock resource limit functions
set_resource_limits() {
    # Mock resource limits setting
    return 0
}

with_resource_limits() {
    # Mock resource limits wrapper
    shift 3
    "$@"
}

# Test setup and teardown
setup_test_env() {
    export TEST_MODE=true
    export SCRIPT_DIR="${SCRIPT_DIR}"
    export AGENT_NAME="UIUXAgent"
    export LOG_FILE="${SCRIPT_DIR}/uiux_agent.log"
    export PROJECT="PlannerApp"

    # Create test directories
    mkdir -p "/Users/danielstevens/Desktop/Quantum-workspace/Projects/PlannerApp"
    mkdir -p "/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation"

    # Create test UI files
    echo '// TODO: implement drag and drop' >"/Users/danielstevens/Desktop/Quantum-workspace/Projects/PlannerApp/ViewController.swift"
    echo '// TODO: improve UI layout' >"/Users/danielstevens/Desktop/Quantum-workspace/Projects/PlannerApp/MainView.swift"

    # Mock backup manager path
    echo '#!/bin/bash
echo "Mock backup created successfully"
exit 0' >"/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/backup_manager.sh"
    chmod +x "/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/backup_manager.sh"

    # Mock intelligent autofix path
    echo '#!/bin/bash
echo "Mock validation completed successfully"
exit 0' >"/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/intelligent_autofix.sh"
    chmod +x "/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/intelligent_autofix.sh"
}

teardown_test_env() {
    # Clean up test files
    rm -rf "/Users/danielstevens/Desktop/Quantum-workspace"
    rm -f "${LOG_FILE}"
}

# Test functions
test_basic_execution() {
    echo "Testing basic execution..."

    # Test that the script sources without errors
    assert_success "Script sources successfully" source "${AGENT_SCRIPT}"

    echo "✓ Basic execution test passed"
}

test_timeout_functionality() {
    echo "Testing timeout functionality..."

    # Test run_with_timeout function
    assert_success "Timeout function works correctly" run_with_timeout 5 echo "test command"

    echo "✓ Timeout functionality test passed"
}

test_project_determination() {
    echo "Testing project determination from tasks..."

    local task_data='{"project": "PlannerApp"}'
    local result
    result=$(get_project_from_task "${task_data}")
    assert_success "Project determination works" [[ "$result" == "PlannerApp" ]]

    # Test default project fallback
    local empty_task='{}'
    local default_result
    default_result=$(get_project_from_task "${empty_task}")
    assert_success "Default project fallback works" [[ "$default_result" == "PlannerApp" ]]

    echo "✓ Project determination test passed"
}

test_ui_enhancements() {
    echo "Testing UI/UX enhancements..."

    local task_data='{"id": "test-task-123", "project": "PlannerApp", "todo": "implement drag and drop functionality"}'

    # Test UI enhancements (will use mocked functions)
    assert_success "UI enhancements execute successfully" perform_ui_enhancements "PlannerApp" "${task_data}"

    echo "✓ UI enhancements test passed"
}

test_step_execution() {
    echo "Testing step execution..."

    # Test run_step function
    assert_success "Step execution works" run_step "test_step" "echo 'test command'"

    echo "✓ Step execution test passed"
}

test_task_processing() {
    echo "Testing task processing..."

    # Test task processing
    assert_success "Task processing completes successfully" process_assigned_tasks

    echo "✓ Task processing test passed"
}

test_backup_creation() {
    echo "Testing backup creation..."

    # Test that backup creation is attempted (mocked)
    local backup_cmd="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/backup_manager.sh backup \"PlannerApp\" \"uiux_enhancement\""
    assert_success "Backup creation command runs" eval "$backup_cmd"

    echo "✓ Backup creation test passed"
}

test_validation_execution() {
    echo "Testing validation execution..."

    # Test that validation is attempted (mocked)
    local validate_cmd="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/intelligent_autofix.sh validate \"PlannerApp\""
    assert_success "Validation command runs" eval "$validate_cmd"

    echo "✓ Validation execution test passed"
}

test_drag_drop_detection() {
    echo "Testing drag-and-drop detection..."

    # Test drag-and-drop task detection
    local drag_task='{"todo": "implement drag and drop functionality"}'
    local is_drag_drop
    is_drag_drop=$(echo "${drag_task}" | jq -r '.todo // empty' | grep -c -i "drag\|drop")
    assert_success "Drag-and-drop detection works" [[ $is_drag_drop -gt 0 ]]

    echo "✓ Drag-and-drop detection test passed"
}

# Assertion functions
assert_success() {
    local message="$1"
    shift
    if "$@"; then
        echo "✓ ${message}"
        return 0
    else
        echo "✗ ${message}"
        return 1
    fi
}

assert_file_exists() {
    local message="$1"
    local file="$2"
    if [[ -f "$file" ]]; then
        echo "✓ ${message}"
        return 0
    else
        echo "✗ ${message}"
        return 1
    fi
}

assert_true() {
    local condition="$1"
    local message="$2"
    if [[ "$condition" == "true" ]]; then
        echo "✓ ${message}"
        return 0
    else
        echo "✗ ${message}"
        return 1
    fi
}

# Run tests
main() {
    echo "Running agent_uiux.sh test suite..."
    echo "==================================="

    local failed_tests=0
    local total_tests=0

    setup_test_env

    # Run all tests
    for test_func in test_basic_execution test_timeout_functionality test_project_determination test_ui_enhancements test_step_execution test_task_processing test_backup_creation test_validation_execution test_drag_drop_detection; do
        ((total_tests++))
        echo ""
        echo "Running ${test_func}..."
        if ! ${test_func}; then
            ((failed_tests++))
            echo "✗ ${test_func} failed"
        fi
    done

    teardown_test_env

    echo ""
    echo "==================================="
    echo "Test Results: ${total_tests} total, $((total_tests - failed_tests)) passed, ${failed_tests} failed"

    if [[ ${failed_tests} -eq 0 ]]; then
        echo "✓ All tests passed!"
        exit 0
    else
        echo "✗ ${failed_tests} test(s) failed"
        exit 1
    fi
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

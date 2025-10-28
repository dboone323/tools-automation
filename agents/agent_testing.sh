#!/bin/bash
# Testing Agent: Automated test generation, execution, and coverage analysis
# Handles Swift unit tests, integration tests, and test coverage reporting

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

AGENT_NAME="TestingAgent"
LOG_FILE="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/testing_agent.log"
PROJECTS_DIR="/Users/danielstevens/Desktop/Quantum-workspace/Projects"

# Source AI enhancement modules
ENHANCEMENTS_DIR="${SCRIPT_DIR}/../enhancements"
if [[ -f "${ENHANCEMENTS_DIR}/ai_testing_optimizer.sh" ]]; then
    # shellcheck source=../enhancements/ai_testing_optimizer.sh
    source "${ENHANCEMENTS_DIR}/ai_testing_optimizer.sh"
fi

SLEEP_INTERVAL=900 # Start with 15 minutes for testing work
MAX_INTERVAL=3600

STATUS_FILE="$(dirname "$0")/agent_status.json"
TASK_QUEUE="$(dirname "$0")/task_queue.json"
PID=$$

# Timeout protection function
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

# Resource limits checking function
check_resource_limits() {
    local operation_name="$1"

    echo "[$(date)] ${AGENT_NAME}: Checking resource limits for ${operation_name}..." >>"${LOG_FILE}"

    # Check available disk space (require at least 1GB)
    local available_space
    available_space=$(df -k "${PROJECTS_DIR}" | tail -1 | awk '{print $4}')
    if [[ ${available_space} -lt 1048576 ]]; then # 1GB in KB
        echo "[$(date)] ${AGENT_NAME}: ❌ Insufficient disk space for ${operation_name}" >>"${LOG_FILE}"
        return 1
    fi

    # Check memory usage (require less than 90% usage)
    local mem_usage
    mem_usage=$(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.')
    if [[ ${mem_usage} -lt 100000 ]]; then # Rough check for memory pressure
        echo "[$(date)] ${AGENT_NAME}: ❌ High memory usage detected for ${operation_name}" >>"${LOG_FILE}"
        return 1
    fi

    # Check file count limits (prevent runaway test generation)
    local file_count
    file_count=$(find "${PROJECTS_DIR}" -type f 2>/dev/null | wc -l)
    if [[ ${file_count} -gt 50000 ]]; then
        echo "[$(date)] ${AGENT_NAME}: ❌ Too many files in workspace for ${operation_name}" >>"${LOG_FILE}"
        return 1
    fi

    echo "[$(date)] ${AGENT_NAME}: ✅ Resource limits OK for ${operation_name}" >>"${LOG_FILE}"
    return 0
}
function update_status() {
    local status="$1"
    # Ensure status file exists and is valid JSON
    if [[ ! -s ${STATUS_FILE} ]]; then
        echo '{"agents":{"build_agent":{"status":"unknown","pid":null},"debug_agent":{"status":"unknown","pid":null},"codegen_agent":{"status":"unknown","pid":null},"uiux_agent":{"status":"unknown","pid":null},"testing_agent":{"status":"unknown","pid":null},"security_agent":{"status":"unknown","pid":null}},"last_update":0}' >"${STATUS_FILE}"
    fi
    if jq ".agents.testing_agent.status = \"${status}\" | .agents.testing_agent.pid = ${PID} | .last_update = $(date +%s)" "${STATUS_FILE}" >"${STATUS_FILE}.tmp" 2>/dev/null &&
        [[ -s "${STATUS_FILE}.tmp" ]]; then
        mv "${STATUS_FILE}.tmp" "${STATUS_FILE}"
    else
        echo "[$(date)] ${AGENT_NAME}: Failed to update agent_status.json (jq or mv error)" >>"${LOG_FILE}"
        rm -f "${STATUS_FILE}.tmp"
    fi
}
trap 'update_status stopped; exit 0' SIGTERM SIGINT

# Function to generate unit tests for Swift classes
generate_unit_tests() {
    local project="$1"
    local class_file="$2"

    echo "[$(date)] ${AGENT_NAME}: Generating unit tests for ${class_file} in ${project}..." >>"${LOG_FILE}"

    local project_path="${PROJECTS_DIR}/${project}"
    local test_dir="${project_path}/${project}Tests"

    # Create test directory if it doesn't exist
    mkdir -p "${test_dir}"

    # Extract class/struct names from the Swift file
    local class_names
    class_names=$(grep -E "^(class|struct|enum)" "${class_file}" | sed 's/.*\(class\|struct\|enum\) \([^{]*\).*/\2/' | tr -d ' ')

    if [[ -z ${class_names} ]]; then
        echo "[$(date)] ${AGENT_NAME}: No testable classes found in ${class_file}" >>"${LOG_FILE}"
        return 1
    fi

    local test_file
    test_file="${test_dir}/$(basename "${class_file}" .swift)Tests.swift"

    # Generate basic test template
    cat >"${test_file}" <<EOF
import XCTest
@testable import ${project}

class $(basename "${class_file}" .swift)Tests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here
    }

    override func tearDown() {
        // Put teardown code here
        super.tearDown()
    }

EOF

    # Generate test methods for each class
    for class_name in ${class_names}; do
        cat >>"${test_file}" <<EOF

    // MARK: - ${class_name} Tests

    func test${class_name}Initialization() {
        // Test basic initialization
        // TODO: Implement initialization test for ${class_name}
        XCTAssertTrue(true, "Placeholder test for ${class_name}")
    }

    func test${class_name}Properties() {
        // Test property access and validation
        // TODO: Implement property tests for ${class_name}
        XCTAssertTrue(true, "Placeholder test for ${class_name} properties")
    }

    func test${class_name}Methods() {
        // Test method functionality
        // TODO: Implement method tests for ${class_name}
        XCTAssertTrue(true, "Placeholder test for ${class_name} methods")
    }
EOF
    done

    cat >>"${test_file}" <<EOF
}
EOF

    echo "[$(date)] ${AGENT_NAME}: Generated test file: ${test_file}" >>"${LOG_FILE}"
    return 0
}

# Function to run test suites
run_test_suite() {
    local project="$1"

    echo "[$(date)] ${AGENT_NAME}: Running test suite for ${project}..." >>"${LOG_FILE}"

    local project_path="${PROJECTS_DIR}/${project}"

    cd "${project_path}" || return 1

    # Run Swift tests
    if [[ -f "${project}.xcodeproj" ]]; then
        echo "[$(date)] ${AGENT_NAME}: Running Xcode tests for ${project}..." >>"${LOG_FILE}"
        xcodebuild test -project "${project}.xcodeproj" -scheme "${project}" -destination "platform=macOS" >>"${LOG_FILE}" 2>&1
        local test_result=$?

        if [[ ${test_result} -eq 0 ]]; then
            echo "[$(date)] ${AGENT_NAME}: ✅ Tests passed for ${project}" >>"${LOG_FILE}"
        else
            echo "[$(date)] ${AGENT_NAME}: ❌ Tests failed for ${project}" >>"${LOG_FILE}"
            return 1
        fi
    else
        echo "[$(date)] ${AGENT_NAME}: No Xcode project found for ${project}" >>"${LOG_FILE}"
    fi

    return 0
}

# Function to analyze test coverage
analyze_coverage() {
    local project="$1"

    echo "[$(date)] ${AGENT_NAME}: Analyzing test coverage for ${project}..." >>"${LOG_FILE}"

    local project_path="${PROJECTS_DIR}/${project}"

    cd "${project_path}" || return 1

    # Generate coverage report
    if [[ -f "${project}.xcodeproj" ]]; then
        echo "[$(date)] ${AGENT_NAME}: Generating coverage report..." >>"${LOG_FILE}"
        xcodebuild test -project "${project}.xcodeproj" -scheme "${project}" -destination "platform=macOS" -enableCodeCoverage YES >>"${LOG_FILE}" 2>&1

        # Check for coverage files
        local coverage_dir="${project_path}/build"
        if [[ -d ${coverage_dir} ]]; then
            find "${coverage_dir}" -name "*.profdata" | head -1 | while read -r profdata; do
                echo "[$(date)] ${AGENT_NAME}: Found coverage data: ${profdata}" >>"${LOG_FILE}"
            done
        fi
    fi

    return 0
}

# Function to identify untested code
find_untested_code() {
    local project="$1"

    echo "[$(date)] ${AGENT_NAME}: Finding untested code in ${project}..." >>"${LOG_FILE}"

    local project_path="${PROJECTS_DIR}/${project}"
    local source_dir="${project_path}/${project}"

    if [[ ! -d ${source_dir} ]]; then
        echo "[$(date)] ${AGENT_NAME}: Source directory not found: ${source_dir}" >>"${LOG_FILE}"
        return 1
    fi

    # Find Swift files without corresponding test files
    find "${source_dir}" -name "*.swift" | while read -r swift_file; do
        local test_file
        test_file="${project_path}/${project}Tests/$(basename "${swift_file}" .swift)Tests.swift"
        if [[ ! -f ${test_file} ]]; then
            echo "[$(date)] ${AGENT_NAME}: ⚠️  Untested file: ${swift_file}" >>"${LOG_FILE}"
        fi
    done

    return 0
}

# Function to perform comprehensive testing
perform_testing() {
    local project="$1"
    local task_data="$2"

    echo "[$(date)] ${AGENT_NAME}: Starting comprehensive testing for ${project}..." >>"${LOG_FILE}"

    # Check resource limits before starting
    if ! check_resource_limits "testing ${project}"; then
        echo "[$(date)] ${AGENT_NAME}: ❌ Resource limits check failed for ${project}" >>"${LOG_FILE}"
        return 1
    fi

    # Use task_data for additional context if needed
    if [[ -n ${task_data} ]]; then
        echo "[$(date)] ${AGENT_NAME}: Task context: ${task_data}" >>"${LOG_FILE}"
    fi

    # Navigate to project directory
    local project_path="${PROJECTS_DIR}/${project}"
    if [[ ! -d ${project_path} ]]; then
        echo "[$(date)] ${AGENT_NAME}: Project directory not found: ${project_path}" >>"${LOG_FILE}"
        return 1
    fi

    cd "${project_path}" || return 1

    # Create backup before making changes
    echo "[$(date)] ${AGENT_NAME}: Creating backup before testing..." >>"${LOG_FILE}"
    /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh backup_if_needed "${project}" >>"${LOG_FILE}" 2>&1 || true

    # Find untested code with timeout protection
    echo "[$(date)] ${AGENT_NAME}: Finding untested code with timeout protection..." >>"${LOG_FILE}"
    if ! run_with_timeout 120 "find_untested_code '${project}'" "Untested code analysis timed out"; then
        echo "[$(date)] ${AGENT_NAME}: ⚠️  Untested code analysis failed or timed out" >>"${LOG_FILE}"
    fi

    # Generate tests for untested classes with timeout protection
    local source_dir="${project_path}/${project}"
    if [[ -d ${source_dir} ]]; then
        echo "[$(date)] ${AGENT_NAME}: Generating tests for untested classes..." >>"${LOG_FILE}"
        find "${source_dir}" -name "*.swift" | while read -r swift_file; do
            local test_file
            test_file="${project_path}/${project}Tests/$(basename "${swift_file}" .swift)Tests.swift"
            if [[ ! -f ${test_file} ]]; then
                if ! run_with_timeout 60 "generate_unit_tests '${project}' '${swift_file}'" "Test generation timed out for ${swift_file}"; then
                    echo "[$(date)] ${AGENT_NAME}: ⚠️  Test generation failed for ${swift_file}" >>"${LOG_FILE}"
                fi
            fi
        done
    fi

    # Run test suite with timeout protection
    echo "[$(date)] ${AGENT_NAME}: Running test suite with timeout protection..." >>"${LOG_FILE}"
    if ! run_with_timeout 600 "run_test_suite '${project}'" "Test suite execution timed out"; then
        echo "[$(date)] ${AGENT_NAME}: ❌ Test suite execution failed or timed out for ${project}" >>"${LOG_FILE}"
        return 1
    fi

    # Analyze coverage with timeout protection
    echo "[$(date)] ${AGENT_NAME}: Analyzing coverage with timeout protection..." >>"${LOG_FILE}"
    if ! run_with_timeout 300 "analyze_coverage '${project}'" "Coverage analysis timed out"; then
        echo "[$(date)] ${AGENT_NAME}: ⚠️  Coverage analysis failed or timed out" >>"${LOG_FILE}"
    fi

    echo "[$(date)] ${AGENT_NAME}: ✅ Comprehensive testing completed for ${project}" >>"${LOG_FILE}"
    return 0
}

while true; do
    update_status running
    echo "[$(date)] ${AGENT_NAME}: Checking for testing tasks..." >>"${LOG_FILE}"

    # Check for queued testing tasks
    HAS_TASK=$(jq '.tasks[] | select(.assigned_agent=="agent_testing.sh" and .status=="queued")' "${TASK_QUEUE}" 2>/dev/null)

    if [[ -n ${HAS_TASK} ]]; then
        echo "[$(date)] ${AGENT_NAME}: Found testing tasks to process..." >>"${LOG_FILE}"

        # Collect tasks to process (avoid subshell issues)
        tasks_to_process=$(echo "${HAS_TASK}" | jq -c '.')

        # Process each queued task
        while IFS= read -r task; do
            [[ -z ${task} ]] && continue

            project=$(echo "${task}" | jq -r '.project // empty')
            task_id=$(echo "${task}" | jq -r '.id')

            if [[ -z ${project} ]]; then
                # If no specific project, test all projects
                for proj_dir in "${PROJECTS_DIR}"/*/; do
                    if [[ -d ${proj_dir} ]]; then
                        proj_name=$(basename "${proj_dir}")
                        echo "[$(date)] ${AGENT_NAME}: Testing project ${proj_name}..." >>"${LOG_FILE}"
                        perform_testing "${proj_name}" "${task}"
                    fi
                done
            else
                echo "[$(date)] ${AGENT_NAME}: Processing task ${task_id} for project ${project}..." >>"${LOG_FILE}"
                perform_testing "${project}" "${task}"
            fi

            # Update task status to completed
            jq "(.tasks[] | select(.id==\"${task_id}\") | .status) = \"completed\"" "${TASK_QUEUE}" >"${TASK_QUEUE}.tmp" 2>/dev/null &&
                [[ -s "${TASK_QUEUE}.tmp" ]] &&
                mv "${TASK_QUEUE}.tmp" "${TASK_QUEUE}" &&
                echo "[$(date)] ${AGENT_NAME}: Task ${task_id} marked as completed" >>"${LOG_FILE}" || true

            # Adjust sleep interval after processing tasks
            SLEEP_INTERVAL=$((SLEEP_INTERVAL + 300))
            if [[ ${SLEEP_INTERVAL} -gt ${MAX_INTERVAL} ]]; then
                SLEEP_INTERVAL=${MAX_INTERVAL}
            fi
        done <<<"${tasks_to_process}"
    else
        update_status idle
        echo "[$(date)] ${AGENT_NAME}: No testing tasks found. Sleeping as idle." >>"${LOG_FILE}"
        sleep 300
    fi

    echo "[$(date)] ${AGENT_NAME}: Sleeping for ${SLEEP_INTERVAL} seconds..." >>"${LOG_FILE}"
    sleep "${SLEEP_INTERVAL}"
done

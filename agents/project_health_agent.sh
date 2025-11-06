#!/bin/bash
# Project Health Agent: Monitors test coverage gaps, outdated dependencies, build failures, and documentation completeness

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

AGENT_NAME="project_health_agent.sh"
LOG_FILE="${SCRIPT_DIR}/project_health_agent.log"
TODO_FILE="${WORKSPACE_ROOT}/todo_queue.json"
WORKSPACE_ROOT="/Users/danielstevens/Desktop/github-projects/tools-automation"
OLLAMA_CLIENT="${SCRIPT_DIR}/../../../ollama_client.sh"

# Monitoring intervals (in seconds)
COVERAGE_CHECK_INTERVAL="${COVERAGE_CHECK_INTERVAL:-300}"     # 5 minutes (reduced for testing)
DEPENDENCY_CHECK_INTERVAL="${DEPENDENCY_CHECK_INTERVAL:-600}" # 10 minutes (reduced for testing)
BUILD_CHECK_INTERVAL="${BUILD_CHECK_INTERVAL:-180}"           # 3 minutes (reduced for testing)
DOC_CHECK_INTERVAL="${DOC_CHECK_INTERVAL:-900}"               # 15 minutes (reduced for testing)

# Thresholds
MIN_COVERAGE_THRESHOLD="${MIN_COVERAGE_THRESHOLD:-0.70}"   # 70%
DEPENDENCY_AGE_THRESHOLD="${DEPENDENCY_AGE_THRESHOLD:-90}" # days
MAX_BUILD_FAILURES="${MAX_BUILD_FAILURES:-3}"

# Initialize agent
log_message() {
    local level="$1"
    shift
    local message="$*"
    echo "[$(date)] [${AGENT_NAME}] [${level}] ${message}" >>"${LOG_FILE}"
}

# Create a todo for identified issues
create_todo() {
    local file_path="$1"
    local line_number="$2"
    local issue_type="$3"
    local description="$4"
    local priority="$5"
    local project="$6"

    # Create todo entry
    local todo_entry
    todo_entry=$(python3 -c "
import json
import time
entry = {
    'file': '${file_path}',
    'line': ${line_number},
    'text': 'PROJECT-HEALTH: ${description}',
    'type': '${issue_type}',
    'priority': '${priority}',
    'ai_generated': True,
    'project': '${project}',
    'timestamp': int(time.time() * 1000),
    'source': 'project_health_agent',
    'agent': '${AGENT_NAME}'
}
print(json.dumps(entry))
" 2>/dev/null)

    if [[ -z "$todo_entry" ]]; then
        log_message "ERROR" "Failed to create todo entry for ${file_path}:${line_number}"
        return 1
    fi

    # Read existing todos
    local existing_todos="[]"
    if [[ -f "$TODO_FILE" ]]; then
        existing_todos=$(cat "$TODO_FILE")
    fi

    # Check for duplicate
    local is_duplicate
    is_duplicate=$(python3 -c "
import json
try:
    existing = json.loads('${existing_todos}')
    new_todo = json.loads('''${todo_entry}''')
    for todo in existing:
        if (todo.get('file') == new_todo.get('file') and
            todo.get('text') == new_todo.get('text') and
            todo.get('type') == new_todo.get('type')):
            print('true')
            exit(0)
    print('false')
except:
    print('false')
" 2>/dev/null || echo "false")

    if [[ "$is_duplicate" == "true" ]]; then
        log_message "DEBUG" "Skipping duplicate todo for ${description}"
        return 0
    fi

    # Add new todo
    local updated_todos
    updated_todos=$(python3 -c "
import json
import sys
try:
    existing = json.loads('${existing_todos}')
    new_todo = json.loads('''${todo_entry}''')
    existing.append(new_todo)
    print(json.dumps(existing, indent=2))
except Exception as e:
    sys.stderr.write(f'Error adding todo: {e}\n')
    print('${existing_todos}')
" 2>/dev/null || echo "$existing_todos")

    # Write back to file
    echo "$updated_todos" >"$TODO_FILE"
    log_message "INFO" "Created todo: ${description} for ${project}"
}

# Check test coverage gaps
check_test_coverage() {
    log_message "INFO" "Checking test coverage across workspace..."

    # Check the entire workspace for test coverage
    local project="tools-automation"

    # Count source files vs test files
    local source_files
    source_files=$(find "$WORKSPACE_ROOT" -name "*.swift" -o -name "*.py" -o -name "*.js" | grep -v -E "(test|Test|spec|Spec)" | wc -l)
    local test_files
    test_files=$(find "$WORKSPACE_ROOT" -name "*test*" -o -name "*Test*" -o -name "*spec*" -o -name "*Spec*" | wc -l)

    # Calculate test-to-source ratio
    local test_ratio=0
    if [[ $source_files -gt 0 ]]; then
        test_ratio=$((test_files * 100 / source_files))
    fi

    if [[ $test_ratio -lt 30 ]]; then
        create_todo "tests/" "1" "test_coverage" \
            "Low test coverage: ${test_files} test files for ${source_files} source files (${test_ratio}%)" \
            "high" "$project"
    fi

    # Check for source files without tests (simplified check)
    local untested_files=0
    while IFS= read -r source_file; do
        local base_name
        base_name=$(basename "$source_file" | sed 's/\.[^.]*$//')
        local test_file_found=false

        # Look for corresponding test file
        if [[ -f "${source_file%/*}/${base_name}Test.${source_file##*.}" ]] ||
            [[ -f "${source_file%/*}/${base_name}Tests.${source_file##*.}" ]] ||
            [[ -f "${source_file%/*}/test_${base_name}.${source_file##*.}" ]]; then
            test_file_found=true
        fi

        if [[ "$test_file_found" == "false" ]]; then
            ((untested_files++))
        fi
    done < <(find "$WORKSPACE_ROOT" -name "*.swift" -o -name "*.py" -o -name "*.js" | grep -v -E "(test|Test|spec|Spec)" | head -20)

    if [[ $untested_files -gt 5 ]]; then
        create_todo "tests/" "1" "test_coverage" \
            "${untested_files}+ source files without corresponding test files" \
            "medium" "$project"
    fi
}

# Check for outdated dependencies
check_dependencies() {
    log_message "INFO" "Checking for outdated dependencies..."

    local project="tools-automation"

    # Check for Python requirements
    local requirements_file="${WORKSPACE_ROOT}/requirements.txt"
    if [[ -f "$requirements_file" ]]; then
        # Check file age
        local file_age
        file_age=$((($(date +%s) - $(stat -f %m "$requirements_file")) / 86400))
        if [[ $file_age -gt $DEPENDENCY_AGE_THRESHOLD ]]; then
            create_todo "requirements.txt" "1" "dependencies" \
                "Python requirements file is ${file_age} days old - check for updates" \
                "medium" "$project"
        fi

        # Check for unpinned versions
        local unpinned_versions
        unpinned_versions=$(grep -c "==" "$requirements_file")
        local total_deps
        total_deps=$(wc -l <"$requirements_file")
        local pinned_ratio=0
        if [[ $total_deps -gt 0 ]]; then
            pinned_ratio=$((unpinned_versions * 100 / total_deps))
        fi

        if [[ $pinned_ratio -lt 80 ]]; then
            create_todo "requirements.txt" "1" "dependencies" \
                "Only ${pinned_ratio}% of Python dependencies are pinned to specific versions" \
                "medium" "$project"
        fi
    fi

    # Check for Node.js package.json
    local package_json="${WORKSPACE_ROOT}/package.json"
    if [[ -f "$package_json" ]]; then
        # Check for security vulnerabilities in dependencies
        if command -v npm &>/dev/null; then
            local vuln_count
            vuln_count=$(cd "$WORKSPACE_ROOT" && npm audit --audit-level moderate --json 2>/dev/null | python3 -c "
import json
import sys
try:
    data = json.load(sys.stdin)
    print(data.get('metadata', {}).get('vulnerabilities', {}).get('total', 0))
except:
    print(0)
" 2>/dev/null || echo "0")

            if [[ $vuln_count -gt 0 ]]; then
                create_todo "package.json" "1" "dependencies" \
                    "${vuln_count} security vulnerabilities found in Node.js dependencies" \
                    "high" "$project"
            fi
        fi
    fi

    # Check for Swift Package.swift
    local package_swift="${WORKSPACE_ROOT}/Package.swift"
    if [[ -f "$package_swift" ]]; then
        # Check for dependencies without version constraints
        local unconstrained_deps
        unconstrained_deps=$(grep -c "dependencies:" "$package_swift")
        if [[ $unconstrained_deps -gt 0 ]]; then
            create_todo "Package.swift" "1" "dependencies" \
                "Dependencies without version constraints detected" \
                "medium" "$project"
        fi

        # Check for major version 0 dependencies (unstable)
        local unstable_deps
        unstable_deps=$(grep -c '"0\.' "$package_swift")
        if [[ $unstable_deps -gt 0 ]]; then
            create_todo "Package.swift" "1" "dependencies" \
                "${unstable_deps} dependencies using major version 0 (unstable)" \
                "low" "$project"
        fi
    fi
}

# Check for build failures
check_build_failures() {
    log_message "INFO" "Checking for build failures..."

    local project="tools-automation"

    # Check for build logs
    local build_logs_dir="${SCRIPT_DIR}/../../../logs"
    if [[ -d "$build_logs_dir" ]]; then
        # Count recent build failures
        local recent_failures
        recent_failures=$(find "$build_logs_dir" -name "*error*" -o -name "*fail*" -mtime -1 | wc -l)

        if [[ $recent_failures -gt $MAX_BUILD_FAILURES ]]; then
            create_todo "logs/" "1" "build_failure" \
                "${recent_failures} build failures detected in the last 24 hours" \
                "high" "$project"
        fi
    fi

    # Check for Swift build issues
    if [[ -f "${WORKSPACE_ROOT}/Package.swift" ]]; then
        # Try a quick build check
        if command -v swift &>/dev/null; then
            local build_output
            build_output=$(cd "$WORKSPACE_ROOT" && swift build --build-tests 2>&1 | head -20)
            if echo "$build_output" | grep -q -i "error"; then
                local error_count
                error_count=$(echo "$build_output" | grep -c -i "error")
                create_todo "Package.swift" "1" "build_failure" \
                    "Swift build errors detected (${error_count} errors)" \
                    "high" "$project"
            fi
        fi
    fi

    # Check for Python syntax errors
    local python_files
    python_files=$(find "$WORKSPACE_ROOT" -name "*.py" | wc -l)
    if [[ $python_files -gt 0 ]]; then
        local syntax_errors=0
        while IFS= read -r py_file; do
            if ! python3 -m py_compile "$py_file" 2>/dev/null; then
                ((syntax_errors++))
            fi
        done < <(find "$WORKSPACE_ROOT" -name "*.py" | head -10)

        if [[ $syntax_errors -gt 0 ]]; then
            create_todo "python_files/" "1" "build_failure" \
                "${syntax_errors} Python files with syntax errors" \
                "high" "$project"
        fi
    fi
}

# Check documentation completeness
check_documentation() {
    log_message "INFO" "Checking documentation completeness..."

    local project="tools-automation"

    # Check for README
    local readme_file=""
    for readme_name in "README.md" "README.txt" "README" "readme.md"; do
        if [[ -f "${WORKSPACE_ROOT}/${readme_name}" ]]; then
            readme_file="${WORKSPACE_ROOT}/${readme_name}"
            break
        fi
    done

    if [[ -z "$readme_file" ]]; then
        create_todo "README.md" "1" "documentation" \
            "Missing README file - project needs documentation" \
            "medium" "$project"
    else
        # Check README completeness
        local readme_lines
        readme_lines=$(wc -l <"$readme_file")
        if [[ $readme_lines -lt 10 ]]; then
            create_todo "$readme_file" "1" "documentation" \
                "README file is too short (${readme_lines} lines) - needs more comprehensive documentation" \
                "low" "$project"
        fi

        # Check for required sections
        local has_installation
        has_installation=$(grep -i -c "install" "$readme_file")
        local has_usage
        has_usage=$(grep -i -c "usage" "$readme_file")

        if [[ $has_installation -eq 0 ]]; then
            create_todo "$readme_file" "1" "documentation" \
                "README missing installation instructions" \
                "medium" "$project"
        fi

        if [[ $has_usage -eq 0 ]]; then
            create_todo "$readme_file" "1" "documentation" \
                "README missing usage instructions" \
                "medium" "$project"
        fi
    fi

    # Check for code documentation
    local swift_files
    swift_files=$(find "$WORKSPACE_ROOT" -name "*.swift" | wc -l)
    if [[ $swift_files -gt 0 ]]; then
        # Check documentation coverage
        local documented_functions
        documented_functions=$(find "$WORKSPACE_ROOT" -name "*.swift" -exec grep -l "///" {} \; | wc -l)
        local documentation_ratio=0
        if [[ $swift_files -gt 0 ]]; then
            documentation_ratio=$((documented_functions * 100 / swift_files))
        fi

        if [[ $documentation_ratio -lt 50 ]]; then
            create_todo "swift_files/" "1" "documentation" \
                "Low code documentation: only ${documentation_ratio}% of Swift files have documentation comments" \
                "low" "$project"
        fi
    fi
}

# Use AI for advanced project health analysis
run_ai_health_analysis() {
    log_message "INFO" "Running AI-powered project health analysis..."

    if [[ ! -f "$OLLAMA_CLIENT" ]]; then
        log_message "WARN" "Ollama client not found, skipping AI analysis"
        return
    fi

    local project="tools-automation"

    # Analyze project structure
    local file_count
    file_count=$(find "$WORKSPACE_ROOT" -type f | wc -l)
    local test_files
    test_files=$(find "$WORKSPACE_ROOT" -name "*test*" -o -name "*Test*" | wc -l)
    local config_files
    config_files=$(find "$WORKSPACE_ROOT" -name "Package.swift" -o -name "package.json" -o -name "requirements.txt" | wc -l)

    # Prepare AI prompt
    local prompt="Analyze this project for health issues:

Project: ${project}
Total files: ${file_count}
Test files: ${test_files}
Config files: ${config_files}

Assess:
1. Test coverage adequacy
2. Dependency management health
3. Build system robustness
4. Documentation completeness
5. Code organization and structure

Provide specific recommendations as a JSON array with 'type', 'description', and 'priority' fields."

    # Run AI analysis
    local ai_response
    if ai_response=$("$OLLAMA_CLIENT" projectHealth "$prompt" 2>/dev/null); then
        # Parse AI response and create todos
        echo "$ai_response" | python3 -c "
import json
import sys

try:
    response = json.load(sys.stdin)
    findings = response.get('response', [])
    
    if isinstance(findings, list):
        for finding in findings:
            if isinstance(finding, dict):
                print(json.dumps(finding))
except:
    pass
" 2>/dev/null | while read -r finding_json; do
            if [[ -n "$finding_json" ]]; then
                local finding_type
                finding_type=$(echo "$finding_json" | python3 -c "import json, sys; print(json.load(sys.stdin).get('type', 'health_issue'))" 2>/dev/null)
                local description
                description=$(echo "$finding_json" | python3 -c "import json, sys; print(json.load(sys.stdin).get('description', 'AI-detected health issue'))" 2>/dev/null)
                local priority
                priority=$(echo "$finding_json" | python3 -c "import json, sys; print(json.load(sys.stdin).get('priority', 'medium'))" 2>/dev/null)

                create_todo "" "1" "$finding_type" "$description" "$priority" "$project"
            fi
        done
    fi
}

# Main agent loop
log_message "INFO" "Starting Project Health Agent..."

# Initialize counters
coverage_check_counter=0
dependency_check_counter=0
build_check_counter=0
doc_check_counter=0

while true; do
    # Check test coverage
    ((coverage_check_counter++))
    if [[ $coverage_check_counter -ge $((COVERAGE_CHECK_INTERVAL / 60)) ]]; then
        coverage_check_counter=0
        check_test_coverage
    fi

    # Check dependencies
    ((dependency_check_counter++))
    if [[ $dependency_check_counter -ge $((DEPENDENCY_CHECK_INTERVAL / 60)) ]]; then
        dependency_check_counter=0
        check_dependencies
    fi

    # Check build status
    ((build_check_counter++))
    if [[ $build_check_counter -ge $((BUILD_CHECK_INTERVAL / 60)) ]]; then
        build_check_counter=0
        check_build_failures
    fi

    # Check documentation
    ((doc_check_counter++))
    if [[ $doc_check_counter -ge $((DOC_CHECK_INTERVAL / 60)) ]]; then
        doc_check_counter=0
        check_documentation
    fi

    # Run AI analysis (less frequently)
    if [[ $((coverage_check_counter % 10)) -eq 0 ]]; then
        run_ai_health_analysis
    fi

    log_message "DEBUG" "Health check cycle completed, sleeping for 60 seconds..."
    sleep 60
done
name="filePath" <parameter >/Users/danielstevens/Desktop/github-projects/tools-automation/agents/project_health_agent.sh

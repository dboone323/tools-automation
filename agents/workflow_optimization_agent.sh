#!/bin/bash
# Workflow Optimization Agent: Identifies manual processes to automate, inefficient CI/CD pipelines, and redundant code/configurations

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

AGENT_NAME="workflow_optimization_agent.sh"
LOG_FILE="${SCRIPT_DIR}/workflow_optimization_agent.log"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "${SCRIPT_DIR}/.." && git rev-parse --show-toplevel 2>/dev/null || cd "${SCRIPT_DIR}/.." && pwd)}"
TODO_FILE="${WORKSPACE_ROOT}/todo_queue.json"
OLLAMA_CLIENT="${SCRIPT_DIR}/../../../ollama_client.sh"

# Analysis intervals (in seconds)
MANUAL_PROCESS_CHECK_INTERVAL="${MANUAL_PROCESS_CHECK_INTERVAL:-300}" # 5 minutes (reduced for testing)
CICD_CHECK_INTERVAL="${CICD_CHECK_INTERVAL:-600}"                     # 10 minutes (reduced for testing)
REDUNDANCY_CHECK_INTERVAL="${REDUNDANCY_CHECK_INTERVAL:-900}"         # 15 minutes (reduced for testing)

# Thresholds
MIN_AUTOMATION_RATIO="${MIN_AUTOMATION_RATIO:-0.3}"       # 30% of processes should be automated
MAX_CICD_STEPS="${MAX_CICD_STEPS:-20}"                    # Maximum reasonable CI/CD steps
DUPLICATE_CODE_THRESHOLD="${DUPLICATE_CODE_THRESHOLD:-5}" # Lines for duplicate detection

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
    'text': 'WORKFLOW-OPTIMIZATION: ${description}',
    'type': '${issue_type}',
    'priority': '${priority}',
    'ai_generated': True,
    'project': '${project}',
    'timestamp': int(time.time() * 1000),
    'source': 'workflow_optimization_agent',
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

# Identify manual processes that could be automated
identify_manual_processes() {
    log_message "INFO" "Identifying manual processes that could be automated..."

    local project="tools-automation"

    # Check for shell scripts that could be automated
    local shell_scripts
    shell_scripts=$(find "$WORKSPACE_ROOT" -name "*.sh" -type f | wc -l)
    if [[ $shell_scripts -gt 10 ]]; then
        create_todo "scripts/" "1" "manual_process" \
            "${shell_scripts} shell scripts found - consider consolidating into automated workflows" \
            "medium" "$project"
    fi

    # Check for manual deployment indicators
    local manual_deploy_indicators
    manual_deploy_indicators=$(find "$WORKSPACE_ROOT" -type f -exec grep -l -i "manual\|deploy\|upload\|scp\|rsync" {} \; | wc -l)
    if [[ $manual_deploy_indicators -gt 3 ]]; then
        create_todo "" "1" "manual_process" \
            "Manual deployment processes detected - consider CI/CD automation" \
            "high" "$project"
    fi

    # Check for repetitive build commands in documentation
    local readme_file=""
    for readme_name in "README.md" "README.txt" "README" "readme.md"; do
        if [[ -f "${WORKSPACE_ROOT}/${readme_name}" ]]; then
            readme_file="${WORKSPACE_ROOT}/${readme_name}"
            break
        fi
    done

    if [[ -n "$readme_file" ]]; then
        local build_commands
        build_commands=$(grep -c -i -E "(swift build|npm run|xcodebuild|gradle|make)" "$readme_file")
        if [[ $build_commands -gt 3 ]]; then
            create_todo "$readme_file" "1" "manual_process" \
                "Multiple manual build commands in documentation - consider automation scripts" \
                "medium" "$project"
        fi
    fi

    # Check for repetitive file operations
    local file_ops_scripts
    file_ops_scripts=$(find "$WORKSPACE_ROOT" -name "*.sh" -exec grep -l -E "(cp|mv|mkdir|rm|tar|zip)" {} \; | wc -l)
    if [[ $file_ops_scripts -gt 5 ]]; then
        create_todo "scripts/" "1" "manual_process" \
            "${file_ops_scripts} scripts with manual file operations - consider automation" \
            "low" "$project"
    fi

    # Check for environment setup scripts
    local setup_scripts
    setup_scripts=$(find "$WORKSPACE_ROOT" -name "*setup*.sh" -o -name "*install*.sh" -o -name "*init*.sh" | wc -l)
    if [[ $setup_scripts -gt 2 ]]; then
        create_todo "scripts/" "1" "manual_process" \
            "Multiple setup/installation scripts - consider unified automation" \
            "medium" "$project"
    fi
}

# Analyze CI/CD pipeline efficiency
analyze_cicd_pipelines() {
    log_message "INFO" "Analyzing CI/CD pipeline efficiency..."

    local project="tools-automation"

    # Check for GitHub Actions
    local github_actions_dir="${WORKSPACE_ROOT}/.github/workflows"
    if [[ -d "$github_actions_dir" ]]; then
        local workflow_files
        workflow_files=$(find "$github_actions_dir" -name "*.yml" -o -name "*.yaml" | wc -l)

        # Use find to get the files instead of globbing in for loop
        while IFS= read -r -d '' workflow_file; do
            if [[ -f "$workflow_file" ]]; then
                # Count steps in workflow
                local step_count
                step_count=$(grep -c "uses:\|run:" "$workflow_file")
                if [[ $step_count -gt $MAX_CICD_STEPS ]]; then
                    create_todo ".github/workflows/$(basename "$workflow_file")" "1" "cicd_efficiency" \
                        "CI/CD workflow has ${step_count} steps - consider optimization or splitting" \
                        "medium" "$project"
                fi

                # Check for redundant jobs
                local job_count
                job_count=$(grep -c "^jobs:" "$workflow_file")
                if [[ $job_count -gt 5 ]]; then
                    create_todo ".github/workflows/$(basename "$workflow_file")" "1" "cicd_efficiency" \
                        "Workflow has ${job_count} jobs - consider consolidation" \
                        "low" "$project"
                fi

                # Check for missing caching
                local has_cache
                has_cache=$(grep -c "cache" "$workflow_file")
                if [[ $has_cache -eq 0 ]]; then
                    create_todo ".github/workflows/$(basename "$workflow_file")" "1" "cicd_efficiency" \
                        "No caching configured - consider adding dependency/build caching" \
                        "medium" "$project"
                fi
            fi
        done < <(find "$github_actions_dir" \( -name "*.yml" -o -name "*.yaml" \) -print0 2>/dev/null)
    else
        create_todo ".github/workflows/" "1" "cicd_efficiency" \
            "Missing CI/CD workflows - project needs automated testing and deployment" \
            "high" "$project"
    fi

    # Check for other CI/CD systems
    local has_jenkins
    has_jenkins=$(find "$WORKSPACE_ROOT" -name "Jenkinsfile" -o -name "*jenkins*" | wc -l)
    local has_circleci
    has_circleci=$(find "$WORKSPACE_ROOT" -name ".circleci" -type d | wc -l)
    local has_travis
    has_travis=$(find "$WORKSPACE_ROOT" -name ".travis.yml" | wc -l)

    local ci_systems_count=$((has_jenkins + has_circleci + has_travis))
    if [[ $ci_systems_count -gt 1 ]]; then
        create_todo "ci-cd/" "1" "cicd_efficiency" \
            "Multiple CI/CD systems detected - consider consolidating to one platform" \
            "medium" "$project"
    fi

    # Check for long-running CI jobs
    if [[ -d "$github_actions_dir" ]]; then
        local long_jobs
        long_jobs=$(find "$github_actions_dir" \( -name "*.yml" -o -name "*.yaml" \) -exec grep -l "timeout-minutes.*[5-9][0-9]*\|timeout-minutes.*[1-9][0-9][0-9]*" {} \; | wc -l)
        if [[ $long_jobs -gt 0 ]]; then
            create_todo ".github/workflows/" "1" "cicd_efficiency" \
                "${long_jobs} CI jobs with long timeouts - consider optimization" \
                "low" "$project"
        fi
    fi
}

# Detect redundant code and configurations
detect_redundancy() {
    log_message "INFO" "Detecting redundant code and configurations..."

    local project="tools-automation"

    # Check for duplicate code patterns (simplified detection)
    local swift_files
    swift_files=$(find "$WORKSPACE_ROOT" -name "*.swift" -type f)

    if [[ -n "$swift_files" ]]; then
        # Look for repeated function signatures
        local duplicate_functions
        duplicate_functions=$(echo "$swift_files" | xargs grep -h "func " | sort | uniq -c | sort -nr | awk '$1 > 1 {print $1-1}' | paste -sd+ | bc 2>/dev/null || echo "0")

        if [[ $duplicate_functions -gt 0 ]]; then
            create_todo "swift_files/" "1" "code_redundancy" \
                "${duplicate_functions} duplicate function signatures detected - consider refactoring" \
                "medium" "$project"
        fi

        # Check for repeated import statements
        local duplicate_imports
        duplicate_imports=$(echo "$swift_files" | xargs grep -h "^import " | sort | uniq -c | sort -nr | awk '$1 > 2 {print $1-1}' | paste -sd+ | bc 2>/dev/null || echo "0")

        if [[ $duplicate_imports -gt 0 ]]; then
            create_todo "swift_files/" "1" "code_redundancy" \
                "${duplicate_imports} files with duplicate import statements" \
                "low" "$project"
        fi
    fi

    # Check for redundant configuration files
    local config_files
    config_files=$(find "$WORKSPACE_ROOT" -maxdepth 2 -name "*.json" -o -name "*.yml" -o -name "*.yaml" -o -name "*.xml" -o -name "*.config" | wc -l)
    if [[ $config_files -gt 15 ]]; then
        create_todo "config/" "1" "config_redundancy" \
            "${config_files} configuration files - consider consolidation" \
            "low" "$project"
    fi

    # Check for duplicate package declarations
    if [[ -f "${WORKSPACE_ROOT}/Package.swift" ]]; then
        local package_targets
        package_targets=$(grep -c "targets:" "${WORKSPACE_ROOT}/Package.swift")
        if [[ $package_targets -gt 5 ]]; then
            create_todo "Package.swift" "1" "config_redundancy" \
                "Package.swift has ${package_targets} targets - consider modularization" \
                "medium" "$project"
        fi
    fi

    # Check for redundant build scripts
    local build_scripts
    build_scripts=$(find "$WORKSPACE_ROOT" -name "*build*.sh" -o -name "*compile*.sh" | wc -l)
    if [[ $build_scripts -gt 3 ]]; then
        create_todo "scripts/" "1" "script_redundancy" \
            "${build_scripts} build scripts - consider consolidation" \
            "low" "$project"
    fi
}

# Use AI for advanced workflow optimization
run_ai_workflow_analysis() {
    log_message "INFO" "Running AI-powered workflow optimization analysis..."

    if [[ ! -f "$OLLAMA_CLIENT" ]]; then
        log_message "WARN" "Ollama client not found, skipping AI analysis"
        return
    fi

    local project="tools-automation"

    # Gather workflow data
    local script_count
    script_count=$(find "$WORKSPACE_ROOT" -name "*.sh" | wc -l)
    local workflow_files
    workflow_files=$(find "$WORKSPACE_ROOT" -path "*/.github/workflows/*" -name "*.yml" -o -name "*.yaml" | wc -l)
    local config_files
    config_files=$(find "$WORKSPACE_ROOT" -name "*.json" -o -name "*.yml" -o -name "*.yaml" | wc -l)

    # Prepare AI prompt
    local prompt="Analyze this project's workflow for optimization opportunities:

Project: ${project}
Shell scripts: ${script_count}
CI/CD workflows: ${workflow_files}
Config files: ${config_files}

Identify:
1. Manual processes that could be automated
2. Inefficient CI/CD pipeline steps
3. Redundant code or configurations
4. Workflow bottlenecks or improvements

Provide specific recommendations as a JSON array with 'type', 'description', and 'priority' fields."

    # Run AI analysis
    local ai_response
    if ai_response=$("$OLLAMA_CLIENT" workflowOptimization "$prompt" 2>/dev/null); then
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
                finding_type=$(echo "$finding_json" | python3 -c "import json, sys; print(json.load(sys.stdin).get('type', 'workflow_issue'))" 2>/dev/null)
                local description
                description=$(echo "$finding_json" | python3 -c "import json, sys; print(json.load(sys.stdin).get('description', 'AI-detected workflow issue'))" 2>/dev/null)
                local priority
                priority=$(echo "$finding_json" | python3 -c "import json, sys; print(json.load(sys.stdin).get('priority', 'medium'))" 2>/dev/null)

                create_todo "" "1" "$finding_type" "$description" "$priority" "$project"
            fi
        done
    fi
}

# Main agent loop
log_message "INFO" "Starting Workflow Optimization Agent..."

# Initialize counters
manual_process_counter=0
cicd_check_counter=0
redundancy_check_counter=0

while true; do
    # Check for manual processes
    ((manual_process_counter++))
    if [[ $manual_process_counter -ge $((MANUAL_PROCESS_CHECK_INTERVAL / 60)) ]]; then
        manual_process_counter=0
        identify_manual_processes
    fi

    # Analyze CI/CD pipelines
    ((cicd_check_counter++))
    if [[ $cicd_check_counter -ge $((CICD_CHECK_INTERVAL / 60)) ]]; then
        cicd_check_counter=0
        analyze_cicd_pipelines
    fi

    # Check for redundancy
    ((redundancy_check_counter++))
    if [[ $redundancy_check_counter -ge $((REDUNDANCY_CHECK_INTERVAL / 60)) ]]; then
        redundancy_check_counter=0
        detect_redundancy
    fi

    # Run AI analysis (less frequently)
    if [[ $((manual_process_counter % 10)) -eq 0 ]]; then
        run_ai_workflow_analysis
    fi

    log_message "DEBUG" "Optimization analysis cycle completed, sleeping for 60 seconds..."
    sleep 60
done
name="filePath" <parameter >/Users/danielstevens/Desktop/github-projects/tools-automation/agents/workflow_optimization_agent.sh

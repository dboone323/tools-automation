#!/usr/bin/env bash
# Quantum Enhanced TODO Processing Agent: AI-powered code review, analysis, and automated task delegation
# Integrates AI code review and analysis to automatically discover and delegate improvement tasks

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source AI configuration
source "${SCRIPT_DIR}/todo_ai_config.sh"

AGENTS_DIR="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents"
TODO_FILE="/Users/danielstevens/Desktop/Quantum-workspace/Projects/todo-tree-output.json"
LOG_FILE="${AGENTS_DIR}/todo_agent.log"
MCP_URL="http://127.0.0.1:5005"
WORKSPACE_ROOT="/Users/danielstevens/Desktop/Quantum-workspace"

# Add reliability features for enterprise-grade operation
set -euo pipefail

# Portable run_with_timeout: run a command and kill it if it exceeds timeout (seconds)
# Usage: run_with_timeout <seconds> <cmd> [args...]
run_with_timeout() {
    local timeout="$1"
    shift
    local cmd="$*"

    # Use timeout command if available (Linux), otherwise implement with background process
    if command -v timeout >/dev/null 2>&1; then
        timeout --kill-after=5s "${timeout}s" bash -c "$cmd"
    else
        # macOS/BSD implementation using background process
        local pid_file
        pid_file=$(mktemp)
        local exit_file
        exit_file=$(mktemp)

        # Run command in background
        (
            if bash -c "$cmd"; then
                echo 0 >"$exit_file"
            else
                echo $? >"$exit_file"
            fi
        ) &
        local cmd_pid
        cmd_pid=$!

        echo "$cmd_pid" >"$pid_file"

        # Wait for completion or timeout
        local count
        count=0
        while [[ $count -lt $timeout ]] && kill -0 "$cmd_pid" 2>/dev/null; do
            sleep 1
            ((count++))
        done

        # Check if still running
        if kill -0 $cmd_pid 2>/dev/null; then
            # Kill the process group
            pkill -TERM -P $cmd_pid 2>/dev/null || true
            sleep 1
            pkill -KILL -P $cmd_pid 2>/dev/null || true
            rm -f "$pid_file" "$exit_file"
            log "ERROR" "Command timed out after ${timeout}s: $cmd"
            return 124
        else
            # Command completed, get exit code
            local exit_code
            if [[ -f "$exit_file" ]]; then
                exit_code=$(cat "$exit_file")
                rm -f "$pid_file" "$exit_file"
                return "$exit_code"
            else
                rm -f "$pid_file" "$exit_file"
                return 0
            fi
        fi
    fi
}

# Check resource limits before operations
check_resource_limits() {
    # Check file count limit (1000 files max)
    local file_count
    file_count=$(find "${WORKSPACE_ROOT}" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [[ $file_count -gt 1000 ]]; then
        log "ERROR" "File count limit exceeded: $file_count files (max: 1000)"
        return 1
    fi

    # Check memory usage (80% max)
    if command -v vm_stat >/dev/null 2>&1; then
        # macOS memory check
        local mem_usage
        mem_usage=$(vm_stat | grep "Pages active" | awk '{print $3}' | tr -d '.')
        local total_mem
        total_mem=$(echo "$(sysctl -n hw.memsize) / 1024 / 1024" | bc 2>/dev/null || echo "8192")
        local mem_percent
        mem_percent=$((mem_usage * 4096 * 100 / (total_mem * 1024 * 1024 / 4096)))
        if [[ $mem_percent -gt 80 ]]; then
            log "ERROR" "Memory usage too high: ${mem_percent}% (max: 80%)"
            return 1
        fi
    fi

    # Check CPU usage (90% max)
    if command -v ps >/dev/null 2>&1; then
        local cpu_usage
        cpu_usage=$(ps -A -o %cpu | awk '{s+=$1} END {print s}')
        if [[ $(echo "$cpu_usage > 90" | bc 2>/dev/null) -eq 1 ]]; then
            log "ERROR" "CPU usage too high: ${cpu_usage}% (max: 90%)"
            return 1
        fi
    fi

    return 0
}

# Standardized logging function
log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')

    case "$level" in
    "ERROR") echo "[$timestamp] [agent_todo] ❌ $message" | tee -a "${LOG_FILE}" ;;
    "WARN") echo "[$timestamp] [agent_todo] ⚠️  $message" | tee -a "${LOG_FILE}" ;;
    "INFO") echo "[$timestamp] [agent_todo] ℹ️  $message" | tee -a "${LOG_FILE}" ;;
    "DEBUG") echo "[$timestamp] [agent_todo] 🔍 $message" | tee -a "${LOG_FILE}" ;;
    *) echo "[$timestamp] [agent_todo] 📝 $message" | tee -a "${LOG_FILE}" ;;
    esac
}

# AI Code Review Integration - Analyze code and generate improvement suggestions
run_ai_code_review() {
    local file_path="$1"
    local project="$2"

    if [[ "${ENABLE_AI_CODE_REVIEW}" != "true" ]]; then
        return 0
    fi

    log_message "INFO" "Running AI code review on ${file_path}"

    # Check if Ollama is available
    if ! curl -s "${AI_ENDPOINT}/api/tags" >/dev/null 2>&1; then
        log_message "WARN" "Ollama not available, skipping AI code review"
        return 1
    fi

    # Read file content (limit to configured max lines)
    if [[ ! -f "$file_path" ]]; then
        log_message "ERROR" "File not found for AI review: $file_path"
        return 1
    fi

    local file_content
    file_content=$(head -"${AI_MAX_FILE_SIZE}" "$file_path" 2>/dev/null || echo "")

    if [[ -z "$file_content" ]]; then
        log_message "WARN" "Empty or unreadable file: $file_path"
        return 1
    fi

    # Prepare AI prompt for code review
    local prompt
    prompt="Analyze this code file and identify potential improvements, bugs, or TODO items. Focus on:
1. Code quality issues
2. Performance improvements
3. Security vulnerabilities
4. Best practices violations
5. Missing error handling
6. Code maintainability issues

File: ${file_path}
Project: ${project}
Language: $(basename "$file_path" | sed 's/.*\.//')

Code:
${file_content}

Provide specific, actionable suggestions as a JSON array of objects with 'type', 'description', 'priority' (high/medium/low), and 'line_number' if applicable."

    # Call Ollama for code analysis with timeout
    local ai_response
    ai_response=$(run_with_timeout "${AI_TIMEOUT}" "curl -s -X POST '${AI_ENDPOINT}/api/generate' -H 'Content-Type: application/json' -d '{\"model\": \"${AI_MODEL}\", \"prompt\": \"${prompt}\", \"stream\": false}'" 2>/dev/null)
    if run_with_timeout "${AI_TIMEOUT}" "curl -s -X POST '${AI_ENDPOINT}/api/generate' -H 'Content-Type: application/json' -d '{\"model\": \"${AI_MODEL}\", \"prompt\": \"${prompt}\", \"stream\": false}'" >/dev/null 2>&1; then

        # Extract JSON from response
        local suggestions
        suggestions=$(echo "$ai_response" | python3 -c "
import json
import sys
try:
    data = json.load(sys.stdin)
    response = data.get('response', '')
    # Try to parse as JSON array
    try:
        suggestions = json.loads(response)
        if isinstance(suggestions, list):
            print(json.dumps(suggestions))
        else:
            print('[]')
    except:
        # Fallback: extract TODO-like items from text
        lines = response.split('\n')
        todos = []
        for line in lines:
            line = line.strip()
            if any(keyword in line.lower() for keyword in ['todo', 'fix', 'improve', 'optimize', 'security', 'performance']):
                todos.append({
                    'type': 'ai_suggestion',
                    'description': line[:200],  # Limit length
                    'priority': '${AI_SUGGESTION_PRIORITY_DEFAULT}',
                    'line_number': 0
                })
        print(json.dumps(todos))
except:
    print('[]')
" 2>/dev/null || echo "[]")

        # Process AI suggestions and add to todo list
        if [[ "$suggestions" != "[]" && -n "$suggestions" ]]; then
            log_message "INFO" "AI code review found suggestions for ${file_path}"

            # Add AI-generated TODOs to the todo file
            add_ai_todos "$file_path" "$suggestions" "$project"
        fi
    else
        log_message "WARN" "AI code review failed for ${file_path}"
    fi
}

# AI Analysis Integration - Analyze project-wide patterns and issues
run_ai_project_analysis() {
    local project="$1"

    if [[ "${ENABLE_AI_PROJECT_ANALYSIS}" != "true" ]]; then
        return 0
    fi

    log_message "INFO" "Running AI project analysis for ${project}"

    # Check if Ollama is available
    if ! curl -s "${AI_ENDPOINT}/api/tags" >/dev/null 2>&1; then
        log_message "WARN" "Ollama not available, skipping AI project analysis"
        return 1
    fi

    # Get project structure
    local project_dir="${WORKSPACE_ROOT}/Projects/${project}"
    if [[ ! -d "$project_dir" ]]; then
        log_message "ERROR" "Project directory not found: $project_dir"
        return 1
    fi

    # Analyze project structure and recent changes
    local file_list
    file_list=$(find "$project_dir" -name "*.swift" -o -name "*.py" -o -name "*.js" -o -name "*.ts" | head -"${PROJECT_ANALYSIS_MAX_FILES}")

    local analysis_prompt
    analysis_prompt="Analyze this project structure and identify potential improvements or issues:

Project: ${project}
Files: $(echo "$file_list" | tr '\n' ', ')

Based on the file structure, suggest:
1. Architecture improvements
2. Missing features or integrations
3. Code organization issues
4. Testing gaps
5. Documentation needs
6. Performance optimizations
7. Security enhancements

Provide specific, actionable suggestions as a JSON array of objects with 'type', 'description', 'priority' (high/medium/low)."

    # Call Ollama for project analysis with timeout
    local ai_response
    ai_response=$(run_with_timeout "${PROJECT_ANALYSIS_TIMEOUT}" "curl -s -X POST '${AI_ENDPOINT}/api/generate' -H 'Content-Type: application/json' -d '{\"model\": \"${AI_MODEL}\", \"prompt\": \"${analysis_prompt}\", \"stream\": false}'" 2>/dev/null)
    if run_with_timeout "${PROJECT_ANALYSIS_TIMEOUT}" "curl -s -X POST '${AI_ENDPOINT}/api/generate' -H 'Content-Type: application/json' -d '{\"model\": \"${AI_MODEL}\", \"prompt\": \"${analysis_prompt}\", \"stream\": false}'" >/dev/null 2>&1; then

        local suggestions
        suggestions=$(echo "$ai_response" | python3 -c "
import json
import sys
try:
    data = json.load(sys.stdin)
    response = data.get('response', '')
    try:
        suggestions = json.loads(response)
        if isinstance(suggestions, list):
            print(json.dumps(suggestions))
        else:
            print('[]')
    except:
        lines = response.split('\n')
        todos = []
        for line in lines:
            line = line.strip()
            if len(line) > 10 and any(keyword in line.lower() for keyword in ['add', 'implement', 'create', 'improve', 'fix', 'optimize']):
                todos.append({
                    'type': 'project_improvement',
                    'description': line[:200],
                    'priority': '${AI_SUGGESTION_PRIORITY_DEFAULT}',
                    'line_number': 0
                })
        print(json.dumps(todos))
except:
    print('[]')
" 2>/dev/null || echo "[]")

        # Process AI suggestions and add to todo list
        if [[ "$suggestions" != "[]" && -n "$suggestions" ]]; then
            log_message "INFO" "AI project analysis found suggestions for ${project}"

            # Add AI-generated TODOs to the todo file
            add_ai_project_todos "$project" "$suggestions"
        fi
    else
        log_message "WARN" "AI project analysis failed for ${project}"
    fi
}

# Add AI-generated TODOs to the todo file
add_ai_todos() {
    local file_path="$1"
    local suggestions_json="$2"
    local project="$3"

    log_message "INFO" "Adding AI-generated TODOs for ${file_path}"

    # Create temporary file for new TODOs
    local temp_file
    temp_file=$(mktemp)

    # Generate AI TODOs in the expected format
    echo "$suggestions_json" | python3 -c "
import json
import sys
import time

try:
    suggestions = json.load(sys.stdin)
    timestamp = int(time.time() * 1000)

    for i, suggestion in enumerate(suggestions):
        relative_path = '${file_path#"${WORKSPACE_ROOT}"/}'
        todo = {
            'file': relative_path,
            'line': suggestion.get('line_number', 1),
            'text': f'AI-SUGGESTION: {suggestion[\"description\"]}',
            'type': suggestion.get('type', 'ai_suggestion'),
            'priority': suggestion.get('priority', 'medium'),
            'ai_generated': True,
            'timestamp': timestamp + i
        }
        print(json.dumps(todo))
except Exception as e:
    sys.stderr.write(f'Error processing suggestions: {e}\n')
" >"$temp_file"

    # Read existing TODOs
    local existing_todos="[]"
    if [[ -f "$TODO_FILE" ]]; then
        existing_todos=$(cat "$TODO_FILE")
    fi

    # Merge AI TODOs with existing TODOs
    local merged_todos
    merged_todos=$(python3 -c "
import json
import sys

try:
    existing = json.loads('${existing_todos}')
    with open('${temp_file}', 'r') as f:
        ai_todos = [json.loads(line.strip()) for line in f if line.strip()]

    # Remove duplicates based on description
    existing_descriptions = {todo.get('text', '') for todo in existing}
    new_ai_todos = [todo for todo in ai_todos if todo.get('text', '') not in existing_descriptions]

    merged = existing + new_ai_todos
    print(json.dumps(merged, indent=2))
except Exception as e:
    sys.stderr.write(f'Error merging TODOs: {e}\n')
    print('${existing_todos}')
" 2>/dev/null || echo "$existing_todos")

    # Write merged TODOs back to file
    echo "$merged_todos" >"$TODO_FILE"

    # Cleanup
    rm -f "$temp_file"

    log_message "INFO" "Added $(echo "$suggestions_json" | jq length 2>/dev/null || echo "unknown") AI-generated TODOs"
}

# Add AI-generated project-level TODOs
add_ai_project_todos() {
    local project="$1"
    local suggestions_json="$2"

    log_message "INFO" "Adding AI-generated project TODOs for ${project}"

    # Create temporary file for new TODOs
    local temp_file
    temp_file=$(mktemp)

    # Generate AI project TODOs
    echo "$suggestions_json" | python3 -c "
import json
import sys
import time

try:
    suggestions = json.loads(sys.stdin)
    timestamp = int(time.time() * 1000)

    for i, suggestion in enumerate(suggestions):
        todo = {
            'file': 'Projects/${project}/README.md',
            'line': 1,
            'text': f'AI-PROJECT-SUGGESTION: {suggestion[\"description\"]}',
            'type': suggestion.get('type', 'project_improvement'),
            'priority': suggestion.get('priority', 'medium'),
            'ai_generated': True,
            'project': '${project}',
            'timestamp': timestamp + i
        }
        print(json.dumps(todo))
except Exception as e:
    sys.stderr.write(f'Error processing project suggestions: {e}\n')
" >"$temp_file"

    # Read existing TODOs
    local existing_todos="[]"
    if [[ -f "$TODO_FILE" ]]; then
        existing_todos=$(cat "$TODO_FILE")
    fi

    # Merge AI project TODOs with existing TODOs
    local merged_todos
    merged_todos=$(python3 -c "
import json
import sys

try:
    existing = json.loads('${existing_todos}')
    with open('${temp_file}', 'r') as f:
        ai_todos = [json.loads(line.strip()) for line in f if line.strip()]

    # Remove duplicates based on description
    existing_descriptions = {todo.get('text', '') for todo in existing}
    new_ai_todos = [todo for todo in ai_todos if todo.get('text', '') not in existing_descriptions]

    merged = existing + new_ai_todos
    print(json.dumps(merged, indent=2))
except Exception as e:
    sys.stderr.write(f'Error merging project TODOs: {e}\n')
    print('${existing_todos}')
" 2>/dev/null || echo "$existing_todos")

    # Write merged TODOs back to file
    echo "$merged_todos" >"$TODO_FILE"

    # Cleanup
    rm -f "$temp_file"

    log_message "INFO" "Added $(echo "$suggestions_json" | jq length 2>/dev/null || echo "unknown") AI-generated project TODOs"
}

# Ensure running in bash
if [[ -z ${BASH_VERSION} ]]; then
    echo "This script must be run with bash."
    exec bash "$0" "$@"
    exit 1
fi

# Function to scan code files for TODO comments and add them to the JSON file
scan_for_todos() {
    log_message "INFO" "Scanning codebase for TODO comments"

    local temp_todos_file
    temp_todos_file=$(mktemp)

    # Find all relevant code files
    find "${WORKSPACE_ROOT}/Projects" -type f \( -name "*.swift" -o -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.sh" -o -name "*.md" \) | while read -r file_path; do
        # Skip files in build directories or node_modules
        if [[ "$file_path" == *"/.build/"* || "$file_path" == *"/node_modules/"* || "$file_path" == *"/.git/"* ]]; then
            continue
        fi

        # Extract TODO comments with line numbers
        if [[ -f "$file_path" ]]; then
            grep -n -i "todo\|fixme\|hack\|xxx" "$file_path" 2>/dev/null | while IFS=':' read -r line_num content; do
                # Clean up the content
                content=$(echo "$content" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/\/\/\|#\|\/\*\|--//g' | sed 's/\*\///g')

                # Skip if content is too short or generic
                if [[ ${#content} -lt 5 ]] || [[ "$content" == "TODO" ]] || [[ "$content" == "FIXME" ]]; then
                    continue
                fi

                # Determine project from path
                local project=""
                if [[ $file_path == *"/CodingReviewer/"* ]]; then
                    project="CodingReviewer"
                elif [[ $file_path == *"/PlannerApp/"* ]]; then
                    project="PlannerApp"
                elif [[ $file_path == *"/AvoidObstaclesGame/"* ]]; then
                    project="AvoidObstaclesGame"
                elif [[ $file_path == *"/MomentumFinance/"* ]]; then
                    project="MomentumFinance"
                elif [[ $file_path == *"/HabitQuest/"* ]]; then
                    project="HabitQuest"
                fi

                # Create TODO entry
                local relative_path="${file_path#"${WORKSPACE_ROOT}"/}"
                local todo_entry
                todo_entry=$(python3 -c "
import json
import time
entry = {
    'file': '${relative_path}',
    'line': ${line_num},
    'text': 'TODO: ${content}',
    'type': 'code_comment',
    'priority': 'medium',
    'ai_generated': False,
    'project': '${project}',
    'timestamp': int(time.time() * 1000),
    'source': 'file_scan'
}
print(json.dumps(entry))
" 2>/dev/null)

                if [[ -n "$todo_entry" ]]; then
                    echo "$todo_entry" >>"$temp_todos_file"
                fi
            done
        fi
    done

    # Read existing TODOs
    local existing_todos="[]"
    if [[ -f "$TODO_FILE" ]]; then
        existing_todos=$(cat "$TODO_FILE")
    fi

    # Merge scanned TODOs with existing TODOs (avoid duplicates)
    local merged_todos
    merged_todos=$(python3 -c "
import json
import sys

try:
    existing = json.loads('${existing_todos}')
    scanned = []
    with open('${temp_todos_file}', 'r') as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    scanned.append(json.loads(line))
                except:
                    pass

    # Create lookup for existing TODOs (file + line + text)
    existing_lookup = set()
    for todo in existing:
        key = f\"{todo.get('file', '')}:{todo.get('line', 0)}:{todo.get('text', '')}\"
        existing_lookup.add(key)

    # Filter out duplicates
    new_todos = []
    for todo in scanned:
        key = f\"{todo.get('file', '')}:{todo.get('line', 0)}:{todo.get('text', '')}\"
        if key not in existing_lookup:
            new_todos.append(todo)

    merged = existing + new_todos
    print(json.dumps(merged, indent=2))
except Exception as e:
    sys.stderr.write(f'Error merging scanned TODOs: {e}\n')
    print('${existing_todos}')
" 2>/dev/null || echo "$existing_todos")

    # Write merged TODOs back to file
    echo "$merged_todos" >"$TODO_FILE"

    # Cleanup
    rm -f "$temp_todos_file"

    local new_count
    new_count=$(echo "$merged_todos" | jq '. | length' 2>/dev/null || echo "unknown")
    local existing_count
    existing_count=$(echo "$existing_todos" | jq '. | length' 2>/dev/null || echo "unknown")

    log_message "INFO" "TODO scan completed. Total TODOs: ${new_count} (added $((new_count - existing_count)) new)"
}

# Function to determine which agent should handle a TODO
delegate_todo() {
    local file="$1"
    local line="$2"
    local text="$3"

    # Extract the actual TODO text (remove "TODO: " prefix)
    local todo_text="${text#TODO: }"

    # Determine project from file path
    local project=""
    if [[ ${file} == AvoidObstaclesGame/* ]]; then
        project="AvoidObstaclesGame"
    elif [[ ${file} == CodingReviewer/* ]]; then
        project="CodingReviewer"
    elif [[ ${file} == HabitQuest/* ]]; then
        project="HabitQuest"
    elif [[ ${file} == MomentumFinance/* ]]; then
        project="MomentumFinance"
    elif [[ ${file} == PlannerApp/* ]]; then
        project="PlannerApp"
    fi

    # Smart delegation based on TODO content with AI enhancement
    local agent=""
    local command=""

    # Handle AI-generated TODOs with special logic
    if [[ ${todo_text} == *"AI-SUGGESTION:"* ]]; then
        local ai_suggestion="${todo_text#AI-SUGGESTION: }"
        if [[ ${ai_suggestion} == *"security"* || ${ai_suggestion} == *"vulnerability"* ]]; then
            agent="security"
            command="fix-security-issue"
        elif [[ ${ai_suggestion} == *"performance"* || ${ai_suggestion} == *"optimize"* ]]; then
            agent="debug"
            command="performance-optimization"
        elif [[ ${ai_suggestion} == *"test"* || ${ai_suggestion} == *"coverage"* ]]; then
            agent="testing"
            command="add-tests"
        elif [[ ${ai_suggestion} == *"documentation"* || ${ai_suggestion} == *"comment"* ]]; then
            agent="documentation"
            command="improve-documentation"
        elif [[ ${ai_suggestion} == *"architecture"* || ${ai_suggestion} == *"structure"* ]]; then
            agent="codegen"
            command="refactor-architecture"
        else
            agent="codegen"
            command="implement-improvement"
        fi
    elif [[ ${todo_text} == *"AI-PROJECT-SUGGESTION:"* ]]; then
        local project_suggestion="${todo_text#AI-PROJECT-SUGGESTION: }"
        if [[ ${project_suggestion} == *"test"* || ${project_suggestion} == *"testing"* ]]; then
            agent="testing"
            command="add-project-tests"
        elif [[ ${project_suggestion} == *"documentation"* ]]; then
            agent="documentation"
            command="create-project-docs"
        elif [[ ${project_suggestion} == *"architecture"* ]]; then
            agent="codegen"
            command="improve-architecture"
        elif [[ ${project_suggestion} == *"security"* ]]; then
            agent="security"
            command="security-audit"
        else
            agent="codegen"
            command="project-enhancement"
        fi
    # Original delegation logic for regular TODOs
    elif [[ ${todo_text} == *"collision"* || ${todo_text} == *"performance"* ]]; then
        agent="debug"
        command="optimize-performance"
    elif [[ ${todo_text} == *"code review"* || ${todo_text} == *"language"* ]]; then
        agent="codegen"
        command="enhance-review-engine"
    elif [[ ${todo_text} == *"streak"* || ${todo_text} == *"feature"* ]]; then
        agent="codegen"
        command="implement-feature"
    elif [[ ${todo_text} == *"API"* || ${todo_text} == *"integrate"* ]]; then
        agent="build"
        command="integrate-api"
    elif [[ ${todo_text} == *"drag"* || ${todo_text} == *"UI"* ]]; then
        agent="uiux"
        command="enhance-ui"
    else
        agent="codegen"
        command="implement-todo"
    fi

    echo "${agent}|${command}|${project}|${file}|${line}|${todo_text}"
}

# Function to submit task to MCP server
submit_task() {
    local agent="$1"
    local command="$2"
    local project="$3"
    local file="$4"
    local line="$5"
    local todo_text="$6"

    log_message "INFO" "Delegating TODO to ${agent} agent: ${todo_text}"

    # Submit task to MCP server
    local response
    if response=$(curl -s -X POST "${MCP_URL}/run" \
        -H "Content-Type: application/json" \
        -d "{\"agent\": \"${agent}\", \"command\": \"${command}\", \"project\": \"${project}\", \"file\": \"${file}\", \"line\": \"${line}\", \"todo\": \"${todo_text}\", \"execute\": true}"); then
        if [[ ${response} == *"\"ok\": true"* ]]; then
            log_message "INFO" "Successfully delegated TODO to ${agent} agent"
            return 0
        else
            log_message "ERROR" "Failed to delegate TODO: ${response}"
            return 1
        fi
    else
        log_message "ERROR" "Failed to submit task to MCP server"
        return 1
    fi
}

# Function to check if TODO has been completed
check_todo_completion() {
    local file="$1"
    local line="$2"
    local todo_text="$3"

    # Check if the TODO comment still exists in the file
    if [[ -f ${file} ]]; then
        if grep -n "TODO.*${todo_text}" "${file}" >/dev/null 2>&1; then
            return 1 # TODO still exists
        else
            return 0 # TODO completed
        fi
    fi

    return 1 # File not found or error
}

# Signal handling for clean shutdown
cleanup() {
    log_message "INFO" "Received shutdown signal, cleaning up..."
    # Remove any processing markers
    rm -f "${AGENTS_DIR}/todo_*.processing"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Alias log to log_message for backward compatibility
log() {
    log_message "INFO" "$1"
}

# Function to read TODOs from JSON file
read_todos() {
    if [[ ! -f ${TODO_FILE} ]]; then
        log_message "ERROR" "TODO file not found: ${TODO_FILE}"
        return 1
    fi

    # Use python to parse JSON and extract TODOs
    python3 -c "
import json
import sys

try:
    with open('${TODO_FILE}', 'r') as f:
        todos = json.load(f)

    for i, todo in enumerate(todos):
        print(f'{i}|{todo[\"file\"]}|{todo[\"line\"]}|{todo[\"text\"]}')
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
"
}

# Function to prioritize and sort TODOs
prioritize_todos() {
    log_message "INFO" "Prioritizing TODOs for processing"

    if [[ ! -f "$TODO_FILE" ]]; then
        log_message "WARN" "TODO file not found for prioritization"
        return 1
    fi

    local prioritized_todos
    prioritized_todos=$(python3 -c "
import json
import sys
from datetime import datetime

try:
    with open('${TODO_FILE}', 'r') as f:
        todos = json.load(f)

    # Priority mapping
    priority_weights = {'high': 3, 'medium': 2, 'low': 1}

    # Sort by priority (high first), then by timestamp (older first)
    def sort_key(todo):
        priority = todo.get('priority', 'medium').lower()
        weight = priority_weights.get(priority, 2)
        timestamp = todo.get('timestamp', 0)
        # AI-generated and security issues get higher priority
        ai_boost = 1 if todo.get('ai_generated', False) else 0
        security_boost = 1 if 'security' in todo.get('text', '').lower() else 0
        return (-weight - ai_boost - security_boost, timestamp)

    todos.sort(key=sort_key)
    print(json.dumps(todos, indent=2))
except Exception as e:
    sys.stderr.write(f'Error prioritizing TODOs: {e}\n')
    sys.exit(1)
" 2>/dev/null)

    if [[ -n "$prioritized_todos" ]]; then
        echo "$prioritized_todos" >"$TODO_FILE"
        log_message "INFO" "TODOs prioritized successfully"
    else
        log_message "ERROR" "Failed to prioritize TODOs"
    fi
}

# Function to inject manual TODOs
inject_manual_todo() {
    local file="$1"
    local line="$2"
    local text="$3"
    local priority="${4:-medium}"
    local project="${5:-}"

    log_message "INFO" "Injecting manual TODO: $text"

    # Create manual TODO entry
    local todo_entry
    todo_entry=$(python3 -c "
import json
import time
entry = {
    'file': '$file',
    'line': ${line:-1},
    'text': 'MANUAL-TODO: $text',
    'type': 'manual_injection',
    'priority': '$priority',
    'ai_generated': False,
    'project': '$project',
    'timestamp': int(time.time() * 1000),
    'source': 'manual'
}
print(json.dumps(entry))
" 2>/dev/null)

    if [[ -z "$todo_entry" ]]; then
        log_message "ERROR" "Failed to create manual TODO entry"
        return 1
    fi

    # Read existing TODOs
    local existing_todos="[]"
    if [[ -f "$TODO_FILE" ]]; then
        existing_todos=$(cat "$TODO_FILE")
    fi

    # Add new TODO
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
    sys.stderr.write(f'Error injecting manual TODO: {e}\n')
    print('${existing_todos}')
" 2>/dev/null || echo "$existing_todos")

    # Write back to file
    echo "$updated_todos" >"$TODO_FILE"
    log_message "INFO" "Manual TODO injected successfully"
}

# Function to generate TODO processing metrics
generate_metrics() {
    log_message "INFO" "Generating TODO processing metrics"

    if [[ ! -f "$TODO_FILE" ]]; then
        log_message "WARN" "TODO file not found for metrics generation"
        return 1
    fi

    local metrics
    metrics=$(python3 -c "
import json
import sys
from collections import Counter

try:
    with open('${TODO_FILE}', 'r') as f:
        todos = json.load(f)

    total_todos = len(todos)
    ai_generated = sum(1 for t in todos if t.get('ai_generated', False))
    manual_todos = sum(1 for t in todos if t.get('type') == 'manual_injection')
    code_comments = sum(1 for t in todos if t.get('type') == 'code_comment')

    priorities = Counter(t.get('priority', 'medium').lower() for t in todos)
    types = Counter(t.get('type', 'unknown') for t in todos)
    projects = Counter(t.get('project', 'unknown') for t in todos if t.get('project'))

    metrics = {
        'total_todos': total_todos,
        'ai_generated': ai_generated,
        'manual_injections': manual_todos,
        'code_comments': code_comments,
        'priorities': dict(priorities),
        'types': dict(types),
        'projects': dict(projects),
        'timestamp': int(__import__('time').time() * 1000)
    }

    print(json.dumps(metrics, indent=2))
except Exception as e:
    sys.stderr.write(f'Error generating metrics: {e}\n')
    sys.exit(1)
" 2>/dev/null)

    if [[ -n "$metrics" ]]; then
        echo "$metrics" >"${AGENTS_DIR}/todo_metrics.json"
        log_message "INFO" "Metrics generated and saved to ${AGENTS_DIR}/todo_metrics.json"
    fi
}

# Main processing loop with AI integration
log_message "INFO" "Starting Quantum Enhanced TODO Processing Agent with AI Integration"

# Initialize cycle counters
ai_analysis_cycle=0
scan_cycle=0
metrics_cycle=0

while true; do
    # Check resource limits before processing
    if ! check_resource_limits; then
        log_message "WARN" "Resource limits exceeded, skipping cycle"
        sleep 60
        continue
    fi

    log_message "INFO" "Starting TODO processing cycle..."

    # Scan for new TODOs from code comments (every N cycles)
    ((scan_cycle++))
    if [[ $scan_cycle -ge ${TODO_SCAN_CYCLE} ]] && [[ "${ENABLE_CODE_SCANNING}" == "true" ]]; then
        scan_cycle=0
        if scan_for_todos; then
            log_message "INFO" "Codebase scan for TODOs completed"
        else
            log_message "WARN" "Codebase scan for TODOs failed"
        fi
    fi

    # Prioritize TODOs for processing
    if [[ "${ENABLE_PRIORITIZATION}" == "true" ]]; then
        if prioritize_todos; then
            log_message "DEBUG" "TODOs prioritized for processing"
        fi
    fi

    # Generate metrics (every N cycles)
    ((metrics_cycle++))
    if [[ $metrics_cycle -ge ${METRICS_GENERATION_CYCLE} ]] && [[ "${ENABLE_METRICS}" == "true" ]]; then
        metrics_cycle=0
        if generate_metrics; then
            log_message "INFO" "TODO metrics generated"
        fi
    fi

    # Run AI project analysis every N cycles (configured)
    ((ai_analysis_cycle++))
    # shellcheck disable=SC2153  # comparing counter (ai_analysis_cycle) to configured threshold (AI_ANALYSIS_CYCLE)
    if [[ $ai_analysis_cycle -ge ${AI_ANALYSIS_CYCLE} ]]; then
        ai_analysis_cycle=0
        log_message "INFO" "Running AI project analysis cycle"

        # Analyze each project
        for project in "CodingReviewer" "PlannerApp" "AvoidObstaclesGame" "MomentumFinance" "HabitQuest"; do
            if [[ -d "${WORKSPACE_ROOT}/Projects/${project}" ]]; then
                if run_with_timeout "${PROJECT_ANALYSIS_TIMEOUT}" "run_ai_project_analysis '${project}'"; then
                    log_message "INFO" "AI project analysis completed for ${project}"
                else
                    log_message "WARN" "AI project analysis timed out or failed for ${project}"
                fi
            fi
        done
    fi

    # Run AI code review on recently modified files
    log_message "INFO" "Running AI code review on recently modified files"
    find "${WORKSPACE_ROOT}/Projects" -name "*.swift" -o -name "*.py" -o -name "*.js" -o -name "*.ts" | head -"${AI_CODE_REVIEW_LIMIT}" | while read -r file_path; do
        # Determine project from path
        project=""
        if [[ $file_path == *"/CodingReviewer/"* ]]; then
            project="CodingReviewer"
        elif [[ $file_path == *"/PlannerApp/"* ]]; then
            project="PlannerApp"
        elif [[ $file_path == *"/AvoidObstaclesGame/"* ]]; then
            project="AvoidObstaclesGame"
        elif [[ $file_path == *"/MomentumFinance/"* ]]; then
            project="MomentumFinance"
        elif [[ $file_path == *"/HabitQuest/"* ]]; then
            project="HabitQuest"
        fi

        if [[ -n "$project" ]]; then
            if run_with_timeout "${CODE_REVIEW_TIMEOUT}" "run_ai_code_review '${file_path}' '${project}'"; then
                log_message "DEBUG" "AI code review completed for ${file_path}"
            else
                log_message "DEBUG" "AI code review timed out or failed for ${file_path}"
            fi
        fi
    done

    # Read current TODOs with timeout protection
    if ! todos=$(run_with_timeout 30 "read_todos 2>>'${LOG_FILE}'"); then
        log_message "ERROR" "Error reading TODOs: ${todos}"
        sleep 60
        continue
    fi

    # Process each TODO with timeout protection
    echo "${todos}" | while IFS='|' read -r index file line text; do
        if [[ ${index} == "ERROR:"* ]]; then
            log_message "ERROR" "JSON parsing error: ${index}"
            continue
        fi

        log_message "INFO" "Processing TODO: ${text} in ${file}:${line}"

        # Check if TODO is already being processed
        if [[ -f "${AGENTS_DIR}/todo_${index}.processing" ]]; then
            log_message "DEBUG" "TODO ${index} already being processed, skipping"
            continue
        fi

        # Check if TODO has been completed with timeout
        if run_with_timeout 10 "check_todo_completion '${file}' '${line}' '${text}'"; then
            log_message "INFO" "TODO ${index} appears to be completed, removing marker"
            rm -f "${AGENTS_DIR}/todo_${index}.processing"
            continue
        fi

        # Mark as being processed
        touch "${AGENTS_DIR}/todo_${index}.processing"

        # Delegate to appropriate agent with timeout
        if delegation=$(run_with_timeout 10 "delegate_todo '${file}' '${line}' '${text}'"); then
            if [[ -n ${delegation} ]]; then
                IFS='|' read -r agent command project todo_file todo_line todo_text <<<"${delegation}"
                if run_with_timeout 30 "submit_task '${agent}' '${command}' '${project}' '${todo_file}' '${todo_line}' '${todo_text}'"; then
                    log_message "INFO" "Successfully delegated TODO to ${agent} agent"
                else
                    log_message "ERROR" "Failed to delegate TODO to ${agent} agent"
                fi
            else
                log_message "WARN" "Could not determine delegation for TODO: ${text}"
            fi
        else
            log_message "ERROR" "Delegation timed out for TODO: ${text}"
        fi
    done

    log_message "INFO" "TODO processing cycle completed, sleeping for 300 seconds"
    sleep 300 # Check every 5 minutes
done

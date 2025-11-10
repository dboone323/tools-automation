#!/bin/bash
# Code Analysis Agent: Actively scans for code smells, anti-patterns, missing error handling, performance bottlenecks, and security vulnerabilities

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

AGENT_NAME="code_analysis_agent.sh"
LOG_FILE="${SCRIPT_DIR}/code_analysis_agent.log"
WORKSPACE_ROOT="/Users/danielstevens/Desktop/github-projects/tools-automation"
TODO_FILE="${WORKSPACE_ROOT}/todo_queue.json"
OLLAMA_CLIENT="${SCRIPT_DIR}/../../../ollama_client.sh"

# Analysis intervals (in seconds)
CODE_ANALYSIS_INTERVAL="${CODE_ANALYSIS_INTERVAL:-300}"       # 5 minutes
SECURITY_SCAN_INTERVAL="${SECURITY_SCAN_INTERVAL:-600}"       # 10 minutes
PERFORMANCE_SCAN_INTERVAL="${PERFORMANCE_SCAN_INTERVAL:-180}" # 3 minutes

# Thresholds
COMPLEXITY_THRESHOLD="${COMPLEXITY_THRESHOLD:-20}"
FORCE_UNWRAP_LIMIT="${FORCE_UNWRAP_LIMIT:-3}"
PRINT_STATEMENTS_LIMIT="${PRINT_STATEMENTS_LIMIT:-5}"

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
    'text': 'CODE-ANALYSIS: ${description}',
    'type': '${issue_type}',
    'priority': '${priority}',
    'ai_generated': True,
    'project': '${project}',
    'timestamp': int(time.time() * 1000),
    'source': 'code_analysis_agent',
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
            todo.get('line') == new_todo.get('line') and
            todo.get('text') == new_todo.get('text')):
            print('true')
            exit(0)
    print('false')
except:
    print('false')
" 2>/dev/null || echo "false")

    if [[ "$is_duplicate" == "true" ]]; then
        log_message "DEBUG" "Skipping duplicate todo for ${file_path}:${line_number}"
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
    log_message "INFO" "Created todo: ${description} in ${file_path}:${line_number}"
}

# Scan for code smells and anti-patterns
scan_code_smells() {
    log_message "INFO" "Scanning for code smells and anti-patterns..."

    # Find all Swift files in the workspace
    while IFS= read -r -d '' file; do
        local relative_path="${file#${WORKSPACE_ROOT}/}"
        local project="tools-automation" # Default project name

        # Check for force unwraps
        local force_unwraps
        force_unwraps=$(grep -n "!" "$file" | wc -l)
        if [[ $force_unwraps -gt $FORCE_UNWRAP_LIMIT ]]; then
            create_todo "$relative_path" "1" "code_smell" \
                "High number of force unwraps (${force_unwraps}) - consider using optional binding" \
                "medium" "$project"
        fi

        # Check for print statements in production code
        local print_statements
        print_statements=$(grep -n -E "(print|debugPrint|NSLog)" "$file" | grep -v -E "(test|Test|debug)" | wc -l)
        if [[ $print_statements -gt $PRINT_STATEMENTS_LIMIT ]]; then
            create_todo "$relative_path" "1" "code_smell" \
                "Excessive print statements (${print_statements}) in production code" \
                "low" "$project"
        fi

        # Check for large functions
        local long_functions
        long_functions=$(awk '/^func / {func_start=NR} /^}/ {if (NR - func_start > 50) print NR - func_start}' "$file" | wc -l)
        if [[ $long_functions -gt 0 ]]; then
            create_todo "$relative_path" "1" "code_smell" \
                "Large functions detected (${long_functions}) - consider breaking down into smaller functions" \
                "medium" "$project"
        fi

        # Check for magic numbers
        local magic_numbers
        magic_numbers=$(grep -n -E "[^a-zA-Z_][0-9]{2,}[^a-zA-Z_.]" "$file" | grep -v -E "(let|var|case|return|if |for |while )" | wc -l)
        if [[ $magic_numbers -gt 3 ]]; then
            create_todo "$relative_path" "1" "code_smell" \
                "Magic numbers detected (${magic_numbers}) - consider using named constants" \
                "low" "$project"
        fi

    done < <(find "$WORKSPACE_ROOT" -name "*.swift" -print0 2>/dev/null)
}

# Scan for missing error handling
scan_error_handling() {
    log_message "INFO" "Scanning for missing error handling..."

    # Find all Swift files in the workspace
    while IFS= read -r -d '' file; do
        local relative_path="${file#${WORKSPACE_ROOT}/}"
        local project="tools-automation"

        # Check for try! usage (force try)
        local force_tries
        force_tries=$(grep -n "try!" "$file" | wc -l)
        if [[ $force_tries -gt 0 ]]; then
            while IFS=':' read -r line_num content; do
                create_todo "$relative_path" "$line_num" "error_handling" \
                    "Force try! usage - should handle errors properly" \
                    "high" "$project"
            done < <(grep -n "try!" "$file")
        fi

        # Check for empty catch blocks
        local empty_catches
        empty_catches=$(grep -n -A2 "catch" "$file" | grep -B2 "^[[:space:]]*}" | grep -c "catch" || echo "0")
        if [[ $empty_catches -gt 0 ]]; then
            create_todo "$relative_path" "1" "error_handling" \
                "Empty catch blocks detected (${empty_catches}) - should handle errors appropriately" \
                "medium" "$project"
        fi

        # Check for functions that can throw but don't have try-catch in callers
        local throwing_functions
        throwing_functions=$(grep -n "throws" "$file" | wc -l)
        if [[ $throwing_functions -gt 0 ]]; then
            # This is a simplified check - in practice would need more sophisticated analysis
            create_todo "$relative_path" "1" "error_handling" \
                "Throwing functions detected - ensure proper error propagation" \
                "low" "$project"
        fi

    done < <(find "$WORKSPACE_ROOT" -name "*.swift" -print0 2>/dev/null)
}

# Scan for performance bottlenecks
scan_performance_bottlenecks() {
    log_message "INFO" "Scanning for performance bottlenecks..."

    # Find all Swift files in the workspace
    while IFS= read -r -d '' file; do
        local relative_path="${file#${WORKSPACE_ROOT}/}"
        local project="tools-automation"

        # Check for inefficient array operations
        local array_operations
        array_operations=$(grep -n -E "\.filter\(\)\.map\(\)|\.map\(\)\.filter\(\)" "$file" | wc -l)
        if [[ $array_operations -gt 0 ]]; then
            create_todo "$relative_path" "1" "performance" \
                "Inefficient array operations detected (${array_operations}) - consider combining operations" \
                "medium" "$project"
        fi

        # Check for repeated computations in loops
        local loop_complexity
        loop_complexity=$(awk '/for.*in.*\{/ {in_loop=1; complexity=0} in_loop && /if |let |var / {complexity++} in_loop && /^\}/ {if (complexity > 10) print NR; in_loop=0}' "$file" | wc -l)
        if [[ $loop_complexity -gt 0 ]]; then
            create_todo "$relative_path" "1" "performance" \
                "Complex operations in loops detected - consider optimizing" \
                "high" "$project"
        fi

        # Check for large data structures
        local large_arrays
        large_arrays=$(grep -n -E "Array\(|Dictionary\(|Set\(" "$file" | grep -v -E "small|tiny|mini" | wc -l)
        if [[ $large_arrays -gt 10 ]]; then
            create_todo "$relative_path" "1" "performance" \
                "Large data structures detected - consider memory optimization" \
                "medium" "$project"
        fi

    done < <(find "$WORKSPACE_ROOT" -name "*.swift" -print0 2>/dev/null)
}

# Scan for security vulnerabilities
scan_security_vulnerabilities() {
    log_message "INFO" "Scanning for security vulnerabilities..."

    # Find all relevant files in the workspace
    while IFS= read -r -d '' file; do
        local relative_path="${file#${WORKSPACE_ROOT}/}"
        local project="tools-automation"

        # Check for hardcoded secrets
        local hardcoded_secrets
        hardcoded_secrets=$(grep -n -i -E "(password|secret|key|token).*[\"']" "$file" | grep -v -E "(test|Test|mock|fake)" | wc -l)
        if [[ $hardcoded_secrets -gt 0 ]]; then
            while IFS=':' read -r line_num content; do
                create_todo "$relative_path" "$line_num" "security" \
                    "Potential hardcoded secret detected" \
                    "high" "$project"
            done < <(grep -n -i -E "(password|secret|key|token).*[\"']" "$file" | grep -v -E "(test|Test|mock|fake)")
        fi

        # Check for SQL injection vulnerabilities
        local sql_injection
        sql_injection=$(grep -n -E "(\"|')SELECT.*\\+|.*WHERE.*\\+" "$file" | wc -l)
        if [[ $sql_injection -gt 0 ]]; then
            create_todo "$relative_path" "1" "security" \
                "Potential SQL injection vulnerability detected" \
                "high" "$project"
        fi

        # Check for weak encryption
        local weak_crypto
        weak_crypto=$(grep -n -E "(MD5|SHA1|DES|RC4)" "$file" | wc -l)
        if [[ $weak_crypto -gt 0 ]]; then
            create_todo "$relative_path" "1" "security" \
                "Weak cryptographic functions detected - consider upgrading to stronger algorithms" \
                "high" "$project"
        fi

        # Check for unsafe API usage
        local unsafe_api
        unsafe_api=$(grep -n -E "(strcpy|strcat|sprintf|gets)" "$file" | wc -l)
        if [[ $unsafe_api -gt 0 ]]; then
            create_todo "$relative_path" "1" "security" \
                "Unsafe API usage detected" \
                "high" "$project"
        fi

    done < <(find "$WORKSPACE_ROOT" \( -name "*.swift" -o -name "*.py" -o -name "*.js" \) -print0 2>/dev/null)
}

# Use AI for advanced code analysis
run_ai_code_analysis() {
    log_message "INFO" "Running AI-powered code analysis..."

    if [[ ! -f "$OLLAMA_CLIENT" ]]; then
        log_message "WARN" "Ollama client not found, skipping AI analysis"
        return
    fi

    # Get a sample of Swift files for AI analysis
    local sample_files
    sample_files=$(find "$WORKSPACE_ROOT" -name "*.swift" -type f | head -3)

    if [[ -z "$sample_files" ]]; then
        log_message "INFO" "No Swift files found for AI analysis"
        return
    fi

    local project="tools-automation"

    # Prepare AI prompt
    local prompt="Analyze these Swift code files for:
1. Code smells and anti-patterns
2. Missing error handling
3. Performance bottlenecks
4. Security vulnerabilities

Files to analyze:
$(echo "$sample_files" | sed "s|$WORKSPACE_ROOT/||g")

Provide specific, actionable findings as a JSON array with 'type', 'description', 'priority', and 'file' fields."

    # Run AI analysis
    local ai_response
    if ai_response=$("$OLLAMA_CLIENT" codeAnalysis "$prompt" 2>/dev/null); then
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
                finding_type=$(echo "$finding_json" | python3 -c "import json, sys; print(json.load(sys.stdin).get('type', 'code_smell'))" 2>/dev/null)
                local description
                description=$(echo "$finding_json" | python3 -c "import json, sys; print(json.load(sys.stdin).get('description', 'AI-detected issue'))" 2>/dev/null)
                local priority
                priority=$(echo "$finding_json" | python3 -c "import json, sys; print(json.load(sys.stdin).get('priority', 'medium'))" 2>/dev/null)
                local file_path
                file_path=$(echo "$finding_json" | python3 -c "import json, sys; print(json.load(sys.stdin).get('file', 'unknown'))" 2>/dev/null)

                if [[ "$file_path" != "unknown" ]]; then
                    create_todo "$file_path" "1" "$finding_type" "$description" "$priority" "$project"
                fi
            fi
        done
    fi
}

# Main agent loop
log_message "INFO" "Starting Code Analysis Agent..."

# Initialize counters
code_analysis_counter=0
security_scan_counter=0
performance_scan_counter=0

while true; do
    # Run code smell analysis
    ((code_analysis_counter++))
    if [[ $code_analysis_counter -ge $((CODE_ANALYSIS_INTERVAL / 60)) ]]; then
        code_analysis_counter=0
        scan_code_smells
        scan_error_handling
    fi

    # Run security scan
    ((security_scan_counter++))
    if [[ $security_scan_counter -ge $((SECURITY_SCAN_INTERVAL / 60)) ]]; then
        security_scan_counter=0
        scan_security_vulnerabilities
    fi

    # Run performance scan
    ((performance_scan_counter++))
    if [[ $performance_scan_counter -ge $((PERFORMANCE_SCAN_INTERVAL / 60)) ]]; then
        performance_scan_counter=0
        scan_performance_bottlenecks
    fi

    # Run AI analysis (less frequently)
    if [[ $((code_analysis_counter % 10)) -eq 0 ]]; then
        run_ai_code_analysis
    fi

    log_message "DEBUG" "Analysis cycle completed, sleeping for 60 seconds..."
    sleep 60
done

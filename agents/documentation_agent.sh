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

AGENT_NAME="documentation_agent.sh"
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
# Documentation Agent: Analyzes and improves documentation coverage

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

AGENT_NAME="documentation_agent.sh"
WORKSPACE="/Users/danielstevens/Desktop/Quantum-workspace"
LOG_FILE="${WORKSPACE}/Tools/Automation/agents/documentation_agent.log"
NOTIFICATION_FILE="${WORKSPACE}/Tools/Automation/agents/communication/${AGENT_NAME}_notification.txt"
AGENT_STATUS_FILE="${WORKSPACE}/Tools/Automation/agents/agent_status.json"
TASK_QUEUE_FILE="${WORKSPACE}/Tools/Automation/agents/task_queue.json"

# Update agent status to available when starting
update_status() {
    local status="$1"
    if command -v jq &>/dev/null; then
        jq ".agents[\"${AGENT_NAME}\"].status = \"${status}\" | .agents[\"${AGENT_NAME}\"].last_seen = $(date +%s)" "${AGENT_STATUS_FILE}" >"${AGENT_STATUS_FILE}.tmp" && mv "${AGENT_STATUS_FILE}.tmp" "${AGENT_STATUS_FILE}"
    fi
    echo "[$(date)] ${AGENT_NAME}: Status updated to ${status}" >>"${LOG_FILE}"
}

# Process a specific task
process_task() {
    local task_id="$1"
    echo "[$(date)] ${AGENT_NAME}: Processing task ${task_id}" >>"${LOG_FILE}"

    # Get task details
    if command -v jq &>/dev/null; then
        local task_desc
        task_desc=$(jq -r ".tasks[] | select(.id == \"${task_id}\") | .description" "${TASK_QUEUE_FILE}")
        local task_type
        task_type=$(jq -r ".tasks[] | select(.id == \"${task_id}\") | .type" "${TASK_QUEUE_FILE}")
        echo "[$(date)] ${AGENT_NAME}: Task description: ${task_desc}" >>"${LOG_FILE}"
        echo "[$(date)] ${AGENT_NAME}: Task type: ${task_type}" >>"${LOG_FILE}"

        # Process based on task type
        case "${task_type}" in
        "docs" | "documentation" | "comments")
            run_documentation_analysis "${task_desc}"
            ;;
        *)
            echo "[$(date)] ${AGENT_NAME}: Unknown task type: ${task_type}" >>"${LOG_FILE}"
            ;;
        esac

        # Mark task as completed
        update_task_status "${task_id}" "completed"
    increment_task_count "${AGENT_NAME}"
        echo "[$(date)] ${AGENT_NAME}: Task ${task_id} completed" >>"${LOG_FILE}"
    fi
}

# Update task status
update_task_status() {
    local task_id="$1"
    local status="$2"
    if command -v jq &>/dev/null; then
        jq "(.tasks[] | select(.id == \"${task_id}\") | .status) = \"${status}\"" "${TASK_QUEUE_FILE}" >"${TASK_QUEUE_FILE}.tmp" && mv "${TASK_QUEUE_FILE}.tmp" "${TASK_QUEUE_FILE}"
    fi
}

# Documentation analysis function with Ollama integration
run_documentation_analysis() {
    local task_desc="$1"
    echo "[$(date)] ${AGENT_NAME}: Running documentation analysis for: ${task_desc}" >>"${LOG_FILE}"

    # Extract project name from task description
    local projects=("CodingReviewer" "MomentumFinance" "HabitQuest" "PlannerApp" "AvoidObstaclesGame")

    for project in "${projects[@]}"; do
        if [[ -d "${WORKSPACE}/Projects/${project}" ]]; then
            echo "[$(date)] ${AGENT_NAME}: Analyzing documentation in ${project}..." >>"${LOG_FILE}"
            cd "${WORKSPACE}/Projects/${project}" || {
                echo "[$(date)] ${AGENT_NAME}: ERROR - Could not cd to ${WORKSPACE}/Projects/${project}" >>"${LOG_FILE}"
                continue
            }

            # Run Ollama-powered documentation analysis
            run_ollama_documentation_analysis "${project}" "${task_desc}"

            # Run traditional documentation metrics
            run_traditional_documentation_analysis "${project}"
        fi
    done

    echo "[$(date)] ${AGENT_NAME}: Documentation analysis completed" >>"${LOG_FILE}"
}

# Ollama-powered documentation analysis
run_ollama_documentation_analysis() {
    local project="$1"
    local task_desc="$2"

    echo "[$(date)] ${AGENT_NAME}: Running enhanced Ollama-powered documentation analysis for ${project}..." >>"${LOG_FILE}"

    # Check if Ollama is available
    if ! curl -s -m 5 http://localhost:11434/api/tags >/dev/null 2>&1; then
        echo "[$(date)] ${AGENT_NAME}: Ollama not available, skipping AI documentation analysis" >>"${LOG_FILE}"
        return 1
    fi

    # Collect code for documentation analysis with enhanced sampling
    local code_sample=""
    local swift_files
    swift_files=$(find . -name "*.swift" | head -10) # Analyze first 10 Swift files for better coverage

    # Prioritize important files (ViewModels, Models, Services)
    local priority_files=""
    priority_files+=$(find . -name "*ViewModel*.swift" | head -3)
    priority_files+=" "
    priority_files+=$(find . -name "*Model*.swift" | head -3)
    priority_files+=" "
    priority_files+=$(find . -name "*Service*.swift" | head -2)

    if [[ -n "${priority_files}" ]]; then
        swift_files="${priority_files} ${swift_files}"
    fi

    # Remove duplicates and limit
    swift_files=$(echo "${swift_files}" | tr ' ' '\n' | sort | uniq | head -10)

    for file in ${swift_files}; do
        if [[ -f ${file} ]]; then
            # Extract class/struct definitions and function signatures for better analysis
            local file_content=""
            file_content+=$(grep -A 5 "^class \|struct \|protocol \|enum " "${file}" 2>/dev/null || true)
            file_content+=$'\n'
            file_content+=$(grep -A 2 "^func " "${file}" 2>/dev/null | head -20 || true)
            file_content+=$'\n'
            file_content+=$(grep -A 1 "^/// " "${file}" 2>/dev/null | head -10 || true)

            if [[ -n "${file_content}" ]]; then
                code_sample+="// File: ${file}\n${file_content}\n\n"
            fi
        fi
    done

    if [[ -z ${code_sample} ]]; then
        echo "[$(date)] ${AGENT_NAME}: No code found for Ollama documentation analysis" >>"${LOG_FILE}"
        return 1
    fi

    # Create enhanced documentation analysis prompt
    local doc_prompt="Analyze this Swift iOS application code and generate comprehensive documentation recommendations:

${code_sample}

Please provide detailed analysis for:

1. **MISSING DOCUMENTATION IDENTIFICATION**
   - Public classes, structs, and protocols without documentation
   - Public functions and methods lacking comments
   - Properties and variables needing documentation
   - Complex business logic requiring explanation

2. **DOCUMENTATION QUALITY ASSESSMENT**
   - Evaluate existing documentation completeness
   - Check parameter and return value descriptions
   - Assess code example quality and usefulness
   - Review documentation formatting and style

3. **SPECIFIC DOCUMENTATION SUGGESTIONS**
   - Generate proper Swift documentation comments (///) for undocumented elements
   - Suggest documentation structure and organization
   - Recommend documentation for design patterns and architecture decisions
   - Propose usage examples and code samples

4. **API DOCUMENTATION NEEDS**
   - Identify public APIs requiring detailed documentation
   - Suggest documentation for integration points
   - Recommend error handling documentation
   - Propose migration guides for API changes

5. **MAINTENANCE DOCUMENTATION**
   - Suggest documentation for complex algorithms
   - Recommend documentation for configuration options
   - Propose troubleshooting guides
   - Suggest documentation for extension points

Format your response with actionable documentation improvements and specific examples."

    # Call Ollama API with enhanced model selection
    local ollama_response
    ollama_response=$(curl -s -X POST http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"codellama:latest\", \"prompt\": \"${doc_prompt}\", \"stream\": false}" 2>/dev/null)

    if [[ $? -eq 0 && -n ${ollama_response} ]]; then
        local analysis_result
        analysis_result=$(echo "${ollama_response}" | jq -r '.response' 2>/dev/null || echo "${ollama_response}")

        # Save enhanced Ollama documentation analysis
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        mkdir -p "${WORKSPACE}/Tools/Automation/results"
        local result_file="${WORKSPACE}/Tools/Automation/results/Doc_Analysis_${project}_${timestamp}.md"

        {
            echo "# Enhanced AI Documentation Analysis"
            echo "**Project:** ${project}"
            echo "**Analysis Date:** $(date)"
            echo "**AI Model:** CodeLlama (Ollama)"
            echo "**Files Analyzed:** ${swift_files}"
            echo ""
            echo "## Executive Summary"
            echo ""
            echo "Comprehensive documentation analysis and generation recommendations for ${project}."
            echo ""
            echo "## Detailed Analysis & Recommendations"
            echo ""
            echo "${analysis_result}"
            echo ""
            echo "## Implementation Priority"
            echo ""
            echo "### High Priority (Immediate - Next Sprint)"
            echo "- Document all public APIs and classes"
            echo "- Add parameter and return value descriptions"
            echo "- Create usage examples for complex functionality"
            echo ""
            echo "### Medium Priority (Next 2-3 Sprints)"
            echo "- Enhance existing documentation quality"
            echo "- Add architectural decision documentation"
            echo "- Create troubleshooting guides"
            echo ""
            echo "### Low Priority (Future Releases)"
            echo "- Generate API reference documentation"
            echo "- Create video tutorials and guides"
            echo "- Develop comprehensive integration guides"
            echo ""
            echo "---"
            echo "*Generated by Enhanced Documentation Agent using Ollama CodeLlama*"
        } >"${result_file}"

        echo "[$(date)] ${AGENT_NAME}: Enhanced Ollama documentation analysis saved to ${result_file}" >>"${LOG_FILE}"

        # Generate automated documentation fixes
        generate_documentation_fixes "${project}" "${analysis_result}" "${swift_files}"

    else
        echo "[$(date)] ${AGENT_NAME}: Failed to get enhanced Ollama documentation analysis" >>"${LOG_FILE}"
    fi
}

# Generate automated documentation fixes
generate_documentation_fixes() {
    local project="$1"
    local analysis_result="$2"
    local swift_files="$3"

    echo "[$(date)] ${AGENT_NAME}: Generating automated documentation fixes for ${project}" >>"${LOG_FILE}"

    local fix_prompt="Based on this documentation analysis, generate specific documentation fixes and additions:

Analysis Results:
${analysis_result}

Target Files: ${swift_files}

Please provide:
1. **SPECIFIC DOCUMENTATION COMMENTS** to add before classes, functions, and properties
2. **PARAMETER DESCRIPTIONS** for function parameters
3. **RETURN VALUE DESCRIPTIONS** for functions with return values
4. **USAGE EXAMPLES** for complex functionality
5. **ARCHITECTURAL DOCUMENTATION** for design patterns used

Format as ready-to-apply Swift documentation comments (///) with proper formatting."

    local fix_result
    fix_result=$(curl -s -X POST http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"codellama:latest\", \"prompt\": \"${fix_prompt}\", \"stream\": false}" | jq -r '.response' 2>/dev/null)

    if [[ $? -eq 0 && -n ${fix_result} ]]; then
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        local fix_file="${WORKSPACE}/Tools/Automation/results/Doc_Fixes_${project}_${timestamp}.md"

        {
            echo "# Automated Documentation Fixes"
            echo "**Project:** ${project}"
            echo "**Generated:** $(date)"
            echo "**Based on:** AI Documentation Analysis"
            echo ""
            echo "## Ready-to-Apply Documentation Comments"
            echo ""
            echo "\`\`\`swift"
            echo "${fix_result}"
            echo "\`\`\`"
            echo ""
            echo "## Implementation Instructions"
            echo ""
            echo "1. **Review Generated Comments**: Ensure accuracy and completeness"
            echo "2. **Apply to Code**: Add the documentation comments above the corresponding code elements"
            echo "3. **Test Documentation**: Use Xcode's documentation viewer to verify formatting"
            echo "4. **Update as Needed**: Modify comments based on actual implementation details"
            echo ""
            echo "## Documentation Standards Followed"
            echo ""
            echo "- Swift documentation comment syntax (///)"
            echo "- Parameter descriptions with - Parameter: name:"
            echo "- Return value descriptions with - Returns:"
            echo "- Throws descriptions with - Throws:"
            echo "- Usage examples where beneficial"
            echo ""
            echo "---"
            echo "*Generated by Enhanced Documentation Agent using Ollama CodeLlama*"
        } >"${fix_file}"

        echo "[$(date)] ${AGENT_NAME}: Automated documentation fixes generated and saved to ${fix_file}" >>"${LOG_FILE}"
    fi
}

# Traditional documentation metrics analysis
run_traditional_documentation_analysis() {
    local project="$1"

    # Documentation metrics
    echo "[$(date)] ${AGENT_NAME}: Calculating documentation metrics for ${project}..." >>"${LOG_FILE}"

    # Count Swift files
    local swift_files
    swift_files=$(find . -name "*.swift" | wc -l)
    echo "[$(date)] ${AGENT_NAME}: Total Swift files: ${swift_files}" >>"${LOG_FILE}"

    # Count documented files (files with /// or /** comments)
    local documented_files
    documented_files=$(find . -name "*.swift" -exec grep -l "///\|/\*\*" {} \; | wc -l)
    echo "[$(date)] ${AGENT_NAME}: Documented files: ${documented_files}" >>"${LOG_FILE}"

    # Calculate documentation coverage
    local doc_coverage=0
    if [[ ${swift_files} -gt 0 ]]; then
        doc_coverage=$((documented_files * 100 / swift_files))
    fi
    echo "[$(date)] ${AGENT_NAME}: Documentation coverage: ${doc_coverage}%" >>"${LOG_FILE}"

    # Analyze documentation quality
    echo "[$(date)] ${AGENT_NAME}: Analyzing documentation quality..." >>"${LOG_FILE}"

    if [[ ${documented_files} -gt 0 ]]; then
        # Check for different types of documentation
        local class_docs
        class_docs=$(find . -name "*.swift" -exec grep -l "/// A\|/// An\|/// The" {} \; | wc -l)
        local func_docs
        func_docs=$(find . -name "*.swift" -exec grep -l "/// -" {} \; | wc -l)
        local param_docs
        param_docs=$(find . -name "*.swift" -exec grep -l "/// - Parameter" {} \; | wc -l)
        local return_docs
        return_docs=$(find . -name "*.swift" -exec grep -l "/// - Returns" {} \; | wc -l)

        {
            echo "[$(date)] ${AGENT_NAME}: Class/struct docs: ${class_docs}"
            echo "[$(date)] ${AGENT_NAME}: Function docs: ${func_docs}"
            echo "[$(date)] ${AGENT_NAME}: Parameter docs: ${param_docs}"
            echo "[$(date)] ${AGENT_NAME}: Return docs: ${return_docs}"
        } >>"${LOG_FILE}"

        # Check for undocumented public functions
        local public_funcs
        public_funcs=$(find . -name "*.swift" -exec grep -h "public func" {} \; | wc -l)
        local documented_public_funcs
        documented_public_funcs=$(find . -name "*.swift" -exec grep -A 1 "public func" {} \; | grep -c "///")
        local undocumented_public=$((public_funcs - documented_public_funcs))

        {
            echo "[$(date)] ${AGENT_NAME}: Public functions: ${public_funcs}"
            echo "[$(date)] ${AGENT_NAME}: Documented public functions: ${documented_public_funcs}"
            echo "[$(date)] ${AGENT_NAME}: Undocumented public functions: ${undocumented_public}"
        } >>"${LOG_FILE}"

        # Calculate documentation quality score
        local quality_score=$((100 - (undocumented_public * 5)))
        if [[ ${quality_score} -lt 0 ]]; then
            quality_score=0
        fi
        echo "[$(date)] ${AGENT_NAME}: Documentation quality score: ${quality_score}%" >>"${LOG_FILE}"
    else
        echo "[$(date)] ${AGENT_NAME}: No documented files found - documentation coverage is 0%" >>"${LOG_FILE}"
    fi

    # Generate documentation recommendations
    echo "[$(date)] ${AGENT_NAME}: Generating documentation recommendations..." >>"${LOG_FILE}"

    if [[ ${doc_coverage} -eq 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: Recommendation: Start documenting public APIs with triple-slash comments" >>"${LOG_FILE}"
        echo "[$(date)] ${AGENT_NAME}: Recommendation: Add class/struct documentation for all public types" >>"${LOG_FILE}"
    fi

    if [[ ${doc_coverage} -lt 50 ]]; then
        echo "[$(date)] ${AGENT_NAME}: Recommendation: Increase documentation coverage to at least 50%" >>"${LOG_FILE}"
    fi

    if [[ ${undocumented_public} -gt 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: Recommendation: Document all public functions with descriptions, parameters, and return values" >>"${LOG_FILE}"
    fi

    if [[ ${param_docs} -eq 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: Recommendation: Add parameter documentation for all function parameters" >>"${LOG_FILE}"
    fi

    if [[ ${return_docs} -eq 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: Recommendation: Add return value documentation for functions that return values" >>"${LOG_FILE}"
    fi
}

# Main agent loop
echo "[$(date)] ${AGENT_NAME}: Starting documentation agent..." >>"${LOG_FILE}"
update_status "available"

# Track processed tasks to avoid duplicates
declare -A processed_tasks

while true; do
    # Check for new task notifications
    if [[ -f ${NOTIFICATION_FILE} ]]; then
        while IFS='|' read -r _timestamp action task_id; do
            if [[ ${action} == "execute_task" && -z ${processed_tasks[${task_id}]} ]]; then
                update_status "busy"
                process_task "${task_id}"
                update_status "available"
                processed_tasks[${task_id}]="completed"
                echo "[$(date)] ${AGENT_NAME}: Marked task ${task_id} as processed" >>"${LOG_FILE}"
            fi
        done <"${NOTIFICATION_FILE}"

        # Clear processed notifications to prevent re-processing
        true >"${NOTIFICATION_FILE}"
    fi

    # Update last seen timestamp
    update_status "available"

    sleep 30 # Check every 30 seconds
done

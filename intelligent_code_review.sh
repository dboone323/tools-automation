#!/bin/bash
# Enhanced Intelligent Code Review System
# Phase 4 Task 19: Implement Intelligent Code Review with project-specific context
# Uses Ollama with deep understanding of Quantum-workspace architecture and patterns

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
OLLAMA_MODEL="${OLLAMA_MODEL:-codellama:7b}"                            # Primary: local CodeLlama model
OLLAMA_FALLBACK_MODELS=("codellama:7b" "qwen:7b" "deepseek-coder:6.7b") # Fallback local models
WORKSPACE="/Users/danielstevens/Desktop/Quantum-workspace"
REVIEW_DIR="${REVIEW_DIR:-${WORKSPACE}/ai_reviews}"
MAX_DIFF_SIZE=50000 # Max characters to send to Ollama

# Project-specific architecture knowledge (using indexed arrays for compatibility)
PROJECT_NAMES=("CodingReviewer" "PlannerApp" "AvoidObstaclesGame" "MomentumFinance" "HabitQuest")
PROJECT_DESCRIPTIONS=(
    "Code review application with extensive automation tooling"
    "Planning and organization app with CloudKit integration and MVVM architecture"
    "SpriteKit-based iOS game with performance optimization"
    "Finance tracking app with data integrity and security"
    "Habit tracking application with user engagement features"
)

# Helper function to get project description
get_project_description() {
    local project_name="$1"
    local i=0
    for name in "${PROJECT_NAMES[@]}"; do
        if [[ "$name" == "$project_name" ]]; then
            echo "${PROJECT_DESCRIPTIONS[$i]}"
            return 0
        fi
        ((i++))
    done
    echo "Generic Swift project"
}

# Quality gates from quality-config.yaml
QUALITY_GATES='{
  "code_coverage": {"minimum": 70, "target": 85},
  "test_performance": {"max_duration_seconds": 30},
  "build_performance": {"max_duration_seconds": 120},
  "code_quality": {"max_warnings": 5, "max_errors": 0},
  "file_limits": {"max_file_size_kb": 1000, "max_lines_per_file": 500},
  "complexity": {"max_cyclomatic_complexity": 10, "max_cognitive_complexity": 15}
}'

# Architecture principles from workspace
ARCHITECTURE_RULES='[
  "Data models NEVER import SwiftUI - keep in SharedTypes/ folder",
  "Avoid Codable in complex data models - causes circular dependencies",
  "Use synchronous operations with background queues - not async/await everywhere",
  "Specific naming over generic - avoid Dashboard, Manager names",
  "Sendable for thread safety - prefer over complex async patterns",
  "Follow BaseViewModel protocol for MVVM pattern consistency",
  "Use @MainActor for UI-related code, avoid for data operations",
  "Implement proper error handling with AppError enum",
  "Use PerformanceMonitor for operation timing",
  "Follow StorageService protocol for data persistence"
]'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_architecture() {
    echo -e "${PURPLE}[ARCHITECTURE]${NC} $1"
}

log_quality() {
    echo -e "${CYAN}[QUALITY]${NC} $1"
}

# Check if Ollama server is running and select available model
check_ollama_health() {
    log_info "Checking Ollama server health at ${OLLAMA_URL}..."

    if ! curl -sf "${OLLAMA_URL}/api/tags" >/dev/null 2>&1; then
        log_error "Ollama server not running at ${OLLAMA_URL}"
        log_error "Start Ollama with: ollama serve"
        return 1
    fi

    # Try primary cloud model first
    if curl -sf "${OLLAMA_URL}/api/tags" | jq -r '.models[]?.name' 2>/dev/null | grep -qx "${OLLAMA_MODEL}"; then
        log_success "Primary model ${OLLAMA_MODEL} is available"
        return 0
    fi

    # Attempt to pull cloud model with error handling
    log_warning "Model ${OLLAMA_MODEL} not found, attempting to pull..."
    if curl -sf -X POST "${OLLAMA_URL}/api/pull" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"${OLLAMA_MODEL}\", \"stream\": false}" \
        --max-time 60 >/dev/null 2>&1; then
        log_success "Successfully pulled ${OLLAMA_MODEL}"
        return 0
    fi

    # Cloud model pull failed, try fallback models
    log_warning "Cloud model ${OLLAMA_MODEL} unavailable, checking fallback models..."
    local available_models
    if command -v jq >/dev/null 2>&1; then
        available_models=$(curl -sf "${OLLAMA_URL}/api/tags" | jq -r '.models[]?.name' 2>/dev/null || echo "")
    else
        # Fallback if jq not available - use grep on raw JSON
        available_models=$(curl -sf "${OLLAMA_URL}/api/tags" 2>/dev/null || echo "")
    fi

    for fallback_model in "${OLLAMA_FALLBACK_MODELS[@]}"; do
        if echo "$available_models" | grep -q "$fallback_model"; then
            log_warning "Using fallback model: $fallback_model"
            export OLLAMA_MODEL="$fallback_model"
            return 0
        fi
    done

    # Try to pull first fallback model
    log_warning "No fallback models available, attempting to pull ${OLLAMA_FALLBACK_MODELS[0]}..."
    if curl -sf -X POST "${OLLAMA_URL}/api/pull" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"${OLLAMA_FALLBACK_MODELS[0]}\", \"stream\": false}" \
        --max-time 300 >/dev/null 2>&1; then
        export OLLAMA_MODEL="${OLLAMA_FALLBACK_MODELS[0]}"
        log_success "Successfully pulled fallback model ${OLLAMA_MODEL}"
        return 0
    fi

    log_error "No models available and pull operations failed"
    return 1
}

# Load project-specific context
load_project_context() {
    local project_name="$1"
    local project_path="${WORKSPACE}/Projects/${project_name}"

    if [[ ! -d ${project_path} ]]; then
        log_error "Project path not found: ${project_path}"
        return 1
    fi

    log_info "Loading context for project: ${project_name}"

    # Extract project description
    local project_desc
    project_desc=$(get_project_description "${project_name}") # Analyze project structure
    local swift_files
    swift_files=$(find "${project_path}" -name "*.swift" -type f | wc -l)

    local test_files
    test_files=$(find "${project_path}" -name "*Test*.swift" -o -name "*Tests*.swift" | wc -l)

    local view_files
    view_files=$(find "${project_path}" -name "*View.swift" | wc -l)

    local model_files
    model_files=$(find "${project_path}" -name "*Model.swift" -o -name "*Entity.swift" | wc -l)

    local viewmodel_files
    viewmodel_files=$(find "${project_path}" -name "*ViewModel.swift" | wc -l)

    # Check for architecture compliance
    local architecture_score=0
    local total_checks=0

    # Check for BaseViewModel usage
    if grep -r "BaseViewModel" "${project_path}" --include="*.swift" >/dev/null 2>&1; then
        ((architecture_score++))
    fi
    ((total_checks++))

    # Check for proper MVVM structure
    if [[ ${viewmodel_files} -gt 0 && ${view_files} -gt 0 ]]; then
        ((architecture_score++))
    fi
    ((total_checks++))

    # Check for test coverage
    if [[ ${test_files} -gt 0 ]]; then
        ((architecture_score++))
    fi
    ((total_checks++))

    local architecture_compliance=$((architecture_score * 100 / total_checks))

    # Build project context
    cat <<EOF
Project: ${project_name}
Description: ${project_desc}
Swift Files: ${swift_files}
Test Files: ${test_files}
View Files: ${view_files}
Model Files: ${model_files}
ViewModel Files: ${viewmodel_files}
Architecture Compliance: ${architecture_compliance}%

Quality Gates: ${QUALITY_GATES}
Architecture Rules: ${ARCHITECTURE_RULES}
EOF
}

# Analyze code against architecture rules
analyze_architecture_compliance() {
    local diff_content="$1"
    local project_context="$2"

    log_architecture "Analyzing architecture compliance..."

    local architecture_prompt
    architecture_prompt="Analyze this Swift code diff for compliance with the Quantum-workspace architecture principles:

ARCHITECTURE PRINCIPLES:
$(echo "${ARCHITECTURE_RULES}" | jq -r '.[]')

PROJECT CONTEXT:
${project_context}

CODE DIFF TO ANALYZE:
${diff_content}

Provide a detailed architecture compliance analysis including:
1. **Architecture Violations**: Any violations of the above principles
2. **Pattern Compliance**: How well the code follows established patterns
3. **Improvement Suggestions**: Specific recommendations to align with architecture
4. **Risk Assessment**: Potential issues from architectural violations

Format as a structured analysis with clear findings and actionable recommendations."

    local analysis_result
    analysis_result=$(curl -sf -X POST "${OLLAMA_URL}/api/generate" \
        -H "Content-Type: application/json" \
        -d "$(jq -n \
            --arg model "${OLLAMA_MODEL}" \
            --arg prompt "${architecture_prompt}" \
            '{model: $model, prompt: $prompt, stream: false, temperature: 0.1}')" \
        2>/dev/null)

    if [[ $? -eq 0 && -n ${analysis_result} ]]; then
        local architecture_analysis
        architecture_analysis=$(echo "$analysis_result" | jq -r '.response // empty')
        if [[ -n ${architecture_analysis} ]]; then
            log_architecture "Architecture analysis completed"
            echo "$architecture_analysis"
            return 0
        fi
    fi

    log_warning "Architecture analysis failed, continuing with basic review"
    echo "Architecture analysis unavailable"
    return 1
}

# Analyze code quality against quality gates
analyze_quality_gates() {
    local diff_content="$1"
    local project_context="$2"

    log_quality "Analyzing quality gate compliance..."

    local quality_prompt
    quality_prompt="Analyze this Swift code diff against the quality gates:

QUALITY GATES:
$(echo "${QUALITY_GATES}" | jq '.')

PROJECT CONTEXT:
${project_context}

CODE DIFF TO ANALYZE:
${diff_content}

Provide a comprehensive quality assessment including:
1. **Quality Gate Compliance**: Which gates are met/violated
2. **Code Complexity Analysis**: Cyclomatic and cognitive complexity assessment
3. **Performance Impact**: Potential performance implications
4. **Testability Assessment**: How testable is the new code
5. **Maintainability Score**: Long-term maintainability evaluation

Format as a structured quality report with specific metrics and recommendations."

    local quality_result
    quality_result=$(curl -sf -X POST "${OLLAMA_URL}/api/generate" \
        -H "Content-Type: application/json" \
        -d "$(jq -n \
            --arg model "${OLLAMA_MODEL}" \
            --arg prompt "${quality_prompt}" \
            '{model: $model, prompt: $prompt, stream: false, temperature: 0.1}')" \
        2>/dev/null)

    if [[ $? -eq 0 && -n ${quality_result} ]]; then
        local quality_analysis
        quality_analysis=$(echo "$quality_result" | jq -r '.response // empty')
        if [[ -n ${quality_analysis} ]]; then
            log_quality "Quality analysis completed"
            echo "$quality_analysis"
            return 0
        fi
    fi

    log_warning "Quality analysis failed, continuing with basic review"
    echo "Quality analysis unavailable"
    return 1
}

# Generate intelligent code review
generate_intelligent_review() {
    local diff_content="$1"
    local project_context="$2"
    local architecture_analysis="$3"
    local quality_analysis="$4"

    log_info "Generating intelligent code review..."

    # Dynamic token allocation based on content size
    local num_tokens=2000 # Default for comprehensive analysis
    local total_content_size=${#diff_content}
    ((total_content_size += ${#project_context}))
    ((total_content_size += ${#architecture_analysis}))
    ((total_content_size += ${#quality_analysis}))

    if [ $total_content_size -lt 10000 ]; then
        num_tokens=2000 # Small analysis
    elif [ $total_content_size -lt 30000 ]; then
        num_tokens=3500 # Medium analysis
    else
        num_tokens=5000 # Large analysis
    fi

    log_info "Using $num_tokens tokens for comprehensive analysis (${total_content_size} chars)"

    # Truncate if too large
    if [ ${#diff_content} -gt $MAX_DIFF_SIZE ]; then
        log_warning "Diff too large (${#diff_content} chars), truncating to ${MAX_DIFF_SIZE}"
        diff_content="${diff_content:0:$MAX_DIFF_SIZE}... [truncated]"
    fi

    # Build comprehensive review prompt
    local review_prompt="You are an expert code reviewer for the Quantum-workspace, a sophisticated Swift development environment with specific architectural patterns and quality standards.

PROJECT CONTEXT:
${project_context}

ARCHITECTURE ANALYSIS:
${architecture_analysis}

QUALITY ANALYSIS:
${quality_analysis}

CODE DIFF TO REVIEW:
\`\`\`diff
${diff_content}
\`\`\`

Perform a comprehensive, intelligent code review that considers:

1. **ARCHITECTURE COMPLIANCE**
   - Adherence to Quantum-workspace architectural principles
   - Proper use of BaseViewModel, MVVM patterns, and shared protocols
   - Data model isolation (no SwiftUI imports in models)
   - Thread safety with Sendable and @MainActor usage

2. **QUALITY GATE COMPLIANCE**
   - Code coverage implications
   - Complexity limits (cyclomatic <10, cognitive <15)
   - File size and line count limits
   - Performance impact assessment

3. **PROJECT-SPECIFIC PATTERNS**
   - Consistency with project's established patterns
   - Proper use of shared utilities and extensions
   - CloudKit integration patterns (for applicable projects)
   - Game performance optimization (for AvoidObstaclesGame)

4. **BEST PRACTICES & STANDARDS**
   - Swift/iOS development best practices
   - Error handling with AppError enum
   - Performance monitoring integration
   - Test coverage considerations

5. **SECURITY & RELIABILITY**
   - Input validation and data sanitization
   - Memory management and leak prevention
   - Thread safety and concurrency issues
   - API security considerations

6. **MAINTAINABILITY & SCALABILITY**
   - Code readability and documentation
   - Future extensibility considerations
   - Dependency management
   - Refactoring opportunities

Provide your review in this structured format:

## Executive Summary
[2-3 sentence overview of changes and overall assessment]

## Architecture Compliance
### ✅ Compliant Areas
[List what's done well architecturally]

### ⚠️ Architecture Issues
[List any architectural violations or concerns]

### 🏗️ Architecture Recommendations
[Specific recommendations to improve architectural alignment]

## Quality Gate Assessment
### 📊 Quality Metrics
- Complexity Score: [assessment]
- Testability: [assessment]
- Performance Impact: [assessment]
- Maintainability: [score/10]

### 🎯 Quality Gate Status
[List compliance with each quality gate]

## Code Quality Analysis

### ✅ Strengths
[What the code does well]

### ⚠️ Issues & Concerns
[Specific problems found]

### 🔧 Recommended Fixes
[Actionable improvement suggestions]

## Security & Reliability Review

### 🔒 Security Assessment
[Security implications and recommendations]

### 🛡️ Reliability Concerns
[Potential failure points and robustness issues]

## Testing & Coverage

### 🧪 Testing Recommendations
[Specific test cases and coverage suggestions]

### 📈 Coverage Impact
[How this affects overall test coverage]

## Performance Analysis

### ⚡ Performance Assessment
[Performance implications and optimization opportunities]

### 📊 Resource Usage
[Memory, CPU, and other resource considerations]

## Recommendations Summary

### 🚨 Critical Issues
[Must-fix issues that block merging]

### ⚠️ High Priority
[Should-fix issues that impact quality]

### 📝 Medium Priority
[Nice-to-fix improvements]

### 💡 Low Priority
[Optional enhancements for future consideration]

## Approval Recommendation
[APPROVED / NEEDS_CHANGES / BLOCKED]

## Implementation Priority
[Timeline and priority for implementing recommendations]

---
*Intelligent Code Review powered by Ollama with Quantum-workspace context*
"

    # Get Ollama analysis with comprehensive context
    local review_json
    if ! review_json=$(curl -sf -X POST "${OLLAMA_URL}/api/generate" \
        -H "Content-Type: application/json" \
        -d "$(jq -n \
            --arg model "${OLLAMA_MODEL}" \
            --arg prompt "${review_prompt}" \
            --argjson num_tokens "$num_tokens" \
            '{model: $model, prompt: $prompt, stream: false, temperature: 0.2, num_predict: $num_tokens}')" \
        2>/dev/null) || [ -z "$review_json" ]; then
        log_error "Failed to generate intelligent review"
        return 1
    fi

    # Extract response
    local review_text
    review_text=$(echo "$review_json" | jq -r '.response // empty')

    if [ -z "$review_text" ]; then
        log_error "Empty review response from Ollama"
        return 1
    fi

    log_success "Intelligent code review generated (${#review_text} chars)"
    echo "$review_text"
    return 0
}

# Extract approval status from intelligent review
extract_intelligent_approval() {
    local review_text="$1"

    # Look for approval status in review
    if echo "$review_text" | grep -qi "BLOCKED"; then
        echo "BLOCKED"
    elif echo "$review_text" | grep -qi "NEEDS_CHANGES"; then
        echo "NEEDS_CHANGES"
    elif echo "$review_text" | grep -qi "APPROVED"; then
        echo "APPROVED"
    else
        # Default to needs changes if unclear
        echo "NEEDS_CHANGES"
    fi
}

# Count issues by priority from intelligent review
count_intelligent_issues() {
    local review_text="$1"
    local priority="$2"

    # Extract count from review (looking for "Critical Issues: X" format)
    local count
    count=$(echo "$review_text" | grep -i "${priority} Issues:" | grep -oE '[0-9]+' | head -1)
    echo "${count:-0}"
}

# Publish intelligent review to MCP with enhanced metadata
publish_intelligent_review() {
    local review_text="$1"
    local approval_status="$2"
    local project_name="$3"
    local base_ref="$4"
    local head_ref="$5"
    local architecture_score="$6"
    local quality_score="$7"

    log_info "Publishing intelligent review to MCP server..."

    # Determine alert level based on approval status
    local alert_level="info"
    case "$approval_status" in
    BLOCKED)
        alert_level="critical"
        ;;
    NEEDS_CHANGES)
        alert_level="warning"
        ;;
    APPROVED)
        alert_level="success"
        ;;
    esac

    # Count issues by priority
    local critical_count
    critical_count=$(count_intelligent_issues "$review_text" "Critical")
    local high_count
    high_count=$(count_intelligent_issues "$review_text" "High")
    local medium_count
    medium_count=$(count_intelligent_issues "$review_text" "Medium")
    local low_count
    low_count=$(count_intelligent_issues "$review_text" "Low")

    # Build enhanced message
    local message="Intelligent Code Review: ${approval_status} | Project: ${project_name} | Arch: ${architecture_score}% | Quality: ${quality_score}/10 | Critical: ${critical_count}, High: ${high_count}, Medium: ${medium_count}, Low: ${low_count}"

    # Publish to MCP with enhanced metadata
    local mcp_response
    if mcp_response=$(curl -sf -X POST "${OLLAMA_URL}/api/generate" \
        -H "Content-Type: application/json" \
        -d "$(jq -n \
            --arg msg "$message" \
            --arg level "$alert_level" \
            --arg component "intelligent-code-review" \
            --arg project "$project_name" \
            --arg status "$approval_status" \
            --arg arch_score "$architecture_score" \
            --arg quality_score "$quality_score" \
            --arg critical "$critical_count" \
            --arg high "$high_count" \
            --arg medium "$medium_count" \
            --arg low "$low_count" \
            --arg base "$base_ref" \
            --arg head "$head_ref" \
            '{message: $msg, level: $level, component: $component, metadata: {project: $project, approval_status: $status, architecture_score: $arch_score, quality_score: $quality_score, critical_issues: $critical, high_issues: $high, medium_issues: $medium, low_issues: $low, base_ref: $base, head_ref: $head}}')" \
        2>/dev/null) && [ -n "$mcp_response" ]; then
        log_success "Intelligent review published to MCP"
    else
        log_warning "Failed to publish to MCP (continuing anyway)"
    fi
}

# Save intelligent review with enhanced metadata
save_intelligent_review() {
    local review_text="$1"
    local project_name="$2"
    local base_ref="$3"
    local head_ref="$4"
    local architecture_analysis="$5"
    local quality_analysis="$6"

    mkdir -p "$REVIEW_DIR"

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local review_file="${REVIEW_DIR}/intelligent_review_${project_name}_${timestamp}.md"

    cat >"$review_file" <<EOF
# 🤖 Intelligent Code Review Report
**Project**: ${project_name}
**Review Date**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Base Reference**: ${base_ref}
**Head Reference**: ${head_ref}
**AI Model**: ${OLLAMA_MODEL} (Quantum-workspace Enhanced)
**Analysis Type**: Architecture + Quality + Best Practices

---

## 📋 Review Context

**Quantum-workspace Architecture Principles Applied:**
- MVVM pattern with BaseViewModel protocol
- Data model isolation (no SwiftUI imports)
- Thread safety with Sendable and @MainActor
- Performance monitoring integration
- Shared utility and extension usage

**Quality Gates Evaluated:**
- Code coverage requirements (70-85%)
- Complexity limits (cyclomatic <10, cognitive <15)
- File size constraints (max 500 lines, 1000KB)
- Performance benchmarks (<120s build, <30s tests)

---

## 🏗️ Architecture Analysis

${architecture_analysis}

---

## 📊 Quality Assessment

${quality_analysis}

---

## 🔍 Comprehensive Code Review

${review_text}

---

## 📈 Review Metadata

- **Analysis Depth**: Architecture + Quality + Security + Performance
- **Context Awareness**: Project-specific patterns and standards
- **Quality Gates**: Automated compliance checking
- **Best Practices**: Swift/iOS development standards
- **Security Review**: Input validation and data protection
- **Performance Analysis**: Resource usage and optimization opportunities

---

*Generated by Quantum-workspace Intelligent Code Review System*
*Powered by Ollama with deep architectural context and quality standards*
EOF

    log_success "Intelligent review saved to ${review_file}"
    echo "$review_file"
}

# Main intelligent review function
intelligent_review_changes() {
    local base_ref="${1:-HEAD~1}"
    local head_ref="${2:-HEAD}"
    local project_name="${3:-}"

    log_info "Starting Intelligent Code Review: ${base_ref}..${head_ref}"

    # Determine project if not specified
    if [[ -z ${project_name} ]]; then
        # Try to detect project from current directory or git context
        local current_dir
        current_dir=$(pwd)
        for project in "${PROJECT_NAMES[@]}"; do
            if [[ ${current_dir} == *"${project}"* ]]; then
                project_name="${project}"
                break
            fi
        done
        if [[ -z ${project_name} ]]; then
            log_warning "Could not auto-detect project, using generic analysis"
            project_name="Generic"
        fi
    fi

    log_info "Analyzing project: ${project_name}"

    # Check Ollama health
    if ! check_ollama_health; then
        log_error "Cannot proceed without Ollama"
        exit 1
    fi

    # Load project context
    local project_context
    if [[ ${project_name} != "Generic" ]]; then
        project_context=$(load_project_context "${project_name}")
    else
        project_context="Generic Swift project analysis"
    fi

    # Get git diff
    log_info "Extracting git diff..."
    local diff_content
    if ! diff_content=$(git diff "${base_ref}..${head_ref}" 2>&1); then
        log_error "Failed to get git diff for ${base_ref}..${head_ref}"
        log_error "$diff_content"
        exit 1
    fi

    if [ -z "$diff_content" ]; then
        log_warning "No changes detected between ${base_ref} and ${head_ref}"
        echo "NO_CHANGES"
        return 0
    fi

    log_info "Diff extracted (${#diff_content} chars)"

    # Perform architecture analysis
    local architecture_analysis
    architecture_analysis=$(analyze_architecture_compliance "$diff_content" "$project_context")

    # Perform quality analysis
    local quality_analysis
    quality_analysis=$(analyze_quality_gates "$diff_content" "$project_context")

    # Generate comprehensive intelligent review
    local review_text
    if ! review_text=$(generate_intelligent_review "$diff_content" "$project_context" "$architecture_analysis" "$quality_analysis") || [ -z "$review_text" ]; then
        log_error "Intelligent review generation failed"
        exit 1
    fi

    # Extract approval status
    local approval_status
    approval_status=$(extract_intelligent_approval "$review_text")
    log_info "Approval Status: ${approval_status}"

    # Extract scores from analyses
    local architecture_score=0
    local quality_score=0

    # Simple scoring based on content analysis
    if echo "$architecture_analysis" | grep -qi "compliant\|good\|excellent"; then
        architecture_score=85
    elif echo "$architecture_analysis" | grep -qi "issues\|violations"; then
        architecture_score=65
    else
        architecture_score=75
    fi

    if echo "$quality_analysis" | grep -qi "excellent\|good\|compliant"; then
        quality_score=8
    elif echo "$quality_analysis" | grep -qi "issues\|violations"; then
        quality_score=6
    else
        quality_score=7
    fi

    # Save intelligent review
    local review_file
    review_file=$(save_intelligent_review "$review_text" "$project_name" "$base_ref" "$head_ref" "$architecture_analysis" "$quality_analysis")

    # Publish to MCP
    publish_intelligent_review "$review_text" "$approval_status" "$project_name" "$base_ref" "$head_ref" "$architecture_score" "$quality_score"

    # Print comprehensive summary
    echo ""
    echo "=================================================="
    echo "🤖 QUANTUM-WORKSPACE INTELLIGENT CODE REVIEW"
    echo "=================================================="
    echo "Project: ${project_name}"
    echo "Status: ${approval_status}"
    echo "Architecture Score: ${architecture_score}%"
    echo "Quality Score: ${quality_score}/10"
    echo "Critical Issues: $(count_intelligent_issues "$review_text" "Critical")"
    echo "High Priority: $(count_intelligent_issues "$review_text" "High")"
    echo "Medium Priority: $(count_intelligent_issues "$review_text" "Medium")"
    echo "Low Priority: $(count_intelligent_issues "$review_text" "Low")"
    echo "Review File: ${review_file}"
    echo "=================================================="
    echo ""

    # Return appropriate exit code
    case "$approval_status" in
    APPROVED)
        log_success "🤖 Intelligent review APPROVED"
        return 0
        ;;
    NEEDS_CHANGES)
        log_warning "🤖 Intelligent review: NEEDS CHANGES"
        return 0 # Don't fail, but record the status
        ;;
    BLOCKED)
        log_error "🤖 Intelligent review: BLOCKED"
        return 1 # Fail the script
        ;;
    *)
        log_warning "🤖 Intelligent review: ${approval_status}"
        return 0
        ;;
    esac
}

# Usage information
usage() {
    cat <<EOF
Usage: $0 [OPTIONS] [BASE_REF] [HEAD_REF] [PROJECT]

Enhanced Intelligent Code Review for Quantum-workspace
Uses Ollama with deep architectural context and quality standards

OPTIONS:
    -h, --help          Show this help message
    -m, --model MODEL   Ollama model to use (default: codellama:7b)
    -u, --url URL       Ollama server URL (default: http://localhost:11434)
    -d, --dir DIR       Review output directory (default: ./ai_reviews)
    -p, --project NAME  Project name (auto-detected if not specified)

ARGUMENTS:
    BASE_REF            Base git reference (default: HEAD~1)
    HEAD_REF            Head git reference (default: HEAD)
    PROJECT             Project name (auto-detected from path)

PROJECTS SUPPORTED:
    CodingReviewer      Code review application
    PlannerApp         Planning app with CloudKit
    AvoidObstaclesGame SpriteKit game
    MomentumFinance    Finance tracking app
    HabitQuest         Habit tracking app

EXAMPLES:
    # Review latest commit in current project
    $0

    # Review specific changes
    $0 main feature/my-branch

    # Review with explicit project
    $0 -p PlannerApp HEAD~1 HEAD

    # Review for specific project
    $0 main develop CodingReviewer

EXIT CODES:
    0 - Review completed (APPROVED or NEEDS_CHANGES)
    1 - Review BLOCKED or error occurred

FEATURES:
    🏗️  Architecture compliance analysis
    📊 Quality gate assessment
    🔒 Security review
    ⚡ Performance analysis
    🧪 Testing recommendations
    📈 Maintainability scoring

EOF
}

# Parse command line arguments
BASE_REF="HEAD~1"
HEAD_REF="HEAD"
PROJECT_NAME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
        usage
        exit 0
        ;;
    -m | --model)
        OLLAMA_MODEL="$2"
        shift 2
        ;;
    -u | --url)
        OLLAMA_URL="$2"
        shift 2
        ;;
    -d | --dir)
        REVIEW_DIR="$2"
        shift 2
        ;;
    -p | --project)
        PROJECT_NAME="$2"
        shift 2
        ;;
    -*)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
    *)
        if [ "$BASE_REF" = "HEAD~1" ]; then
            BASE_REF="$1"
        elif [ "$HEAD_REF" = "HEAD" ]; then
            HEAD_REF="$1"
        elif [ -z "$PROJECT_NAME" ]; then
            PROJECT_NAME="$1"
        else
            log_error "Too many arguments"
            usage
            exit 1
        fi
        shift
        ;;
    esac
done

# Run intelligent review
intelligent_review_changes "$BASE_REF" "$HEAD_REF" "$PROJECT_NAME"

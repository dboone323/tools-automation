#!/bin/bash
# AI-Powered Code Review Script
# Part of OA-05: AI Review & Guarded Merge
# Uses Ollama for intelligent diff analysis and code quality assessment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
OLLAMA_MODEL="${OLLAMA_MODEL:-codellama}"
MCP_SERVER="${MCP_SERVER:-http://localhost:5005}"
REVIEW_DIR="${REVIEW_DIR:-./ai_reviews}"
MAX_DIFF_SIZE=50000  # Max characters to send to Ollama

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

# Check if Ollama server is running
check_ollama_health() {
    log_info "Checking Ollama server health at ${OLLAMA_URL}..."
    
    if ! curl -sf "${OLLAMA_URL}/api/tags" > /dev/null 2>&1; then
        log_error "Ollama server not running at ${OLLAMA_URL}"
        log_error "Start Ollama with: ollama serve"
        return 1
    fi
    
    # Check if model is available
    if ! curl -sf "${OLLAMA_URL}/api/tags" | grep -q "${OLLAMA_MODEL}"; then
        log_warning "Model ${OLLAMA_MODEL} not found, pulling it now..."
        curl -sf -X POST "${OLLAMA_URL}/api/pull" \
            -H "Content-Type: application/json" \
            -d "{\"name\": \"${OLLAMA_MODEL}\", \"stream\": false}" > /dev/null
    fi
    
    log_success "Ollama server healthy, model ${OLLAMA_MODEL} available"
    return 0
}

# Generate AI review using Ollama
generate_ai_review() {
    local diff_content="$1"
    local base_ref="${2:-HEAD~1}"
    local head_ref="${3:-HEAD}"
    
    log_info "Generating AI review for diff (${#diff_content} chars)..."
    
    # Truncate diff if too large
    if [ ${#diff_content} -gt $MAX_DIFF_SIZE ]; then
        log_warning "Diff too large (${#diff_content} chars), truncating to ${MAX_DIFF_SIZE}"
        diff_content="${diff_content:0:$MAX_DIFF_SIZE}... [truncated]"
    fi
    
    # Build prompt for code review
    local prompt="You are an expert code reviewer. Analyze the following git diff and provide a structured code review.

Focus on:
1. **Code Quality**: Identify style issues, naming problems, complexity concerns
2. **Bugs & Errors**: Spot potential bugs, logic errors, edge cases not handled
3. **Security**: Flag security vulnerabilities, unsafe operations, data exposure risks
4. **Performance**: Identify inefficient algorithms, unnecessary operations, memory leaks
5. **Best Practices**: Check for violations of language/framework best practices
6. **Maintainability**: Assess readability, documentation needs, test coverage

Provide your review in the following structured format:

## Summary
[One-sentence overview of changes]

## Severity Assessment
- Critical Issues: [count]
- Major Issues: [count]
- Minor Issues: [count]

## Detailed Findings

### Critical Issues
[List any critical issues or leave empty]

### Major Issues
[List any major issues or leave empty]

### Minor Issues / Suggestions
[List minor issues and suggestions]

## Recommendations
[Key actionable recommendations]

## Approval Status
[APPROVED / NEEDS_CHANGES / BLOCKED]

Here is the git diff to review:

\`\`\`diff
${diff_content}
\`\`\`

Provide the structured review now:"
    
    # Call Ollama API
    local review_json
    review_json=$(curl -sf -X POST "${OLLAMA_URL}/api/generate" \
        -H "Content-Type: application/json" \
        -d "$(jq -n \
            --arg model "${OLLAMA_MODEL}" \
            --arg prompt "${prompt}" \
            '{model: $model, prompt: $prompt, stream: false, temperature: 0.3, num_predict: 2000}')" \
        2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$review_json" ]; then
        log_error "Failed to generate AI review"
        return 1
    fi
    
    # Extract response
    local review_text
    review_text=$(echo "$review_json" | jq -r '.response // empty')
    
    if [ -z "$review_text" ]; then
        log_error "Empty review response from Ollama"
        return 1
    fi
    
    log_success "AI review generated (${#review_text} chars)"
    echo "$review_text"
    return 0
}

# Extract approval status from review
extract_approval_status() {
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

# Count issues by severity
count_issues() {
    local review_text="$1"
    local severity="$2"
    
    # Extract count from review (looking for "Critical Issues: X" format)
    local count
    count=$(echo "$review_text" | grep -i "${severity} Issues:" | grep -oE '[0-9]+' | head -1)
    echo "${count:-0}"
}

# Publish review to MCP
publish_to_mcp() {
    local review_text="$1"
    local approval_status="$2"
    local base_ref="$3"
    local head_ref="$4"
    
    log_info "Publishing review to MCP server..."
    
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
            alert_level="info"
            ;;
    esac
    
    # Count issues
    local critical_count=$(count_issues "$review_text" "Critical")
    local major_count=$(count_issues "$review_text" "Major")
    local minor_count=$(count_issues "$review_text" "Minor")
    
    # Build message
    local message="AI Code Review: ${approval_status} | Critical: ${critical_count}, Major: ${major_count}, Minor: ${minor_count}"
    
    # Publish to MCP
    local mcp_response
    mcp_response=$(curl -sf -X POST "${MCP_SERVER}/alerts" \
        -H "Content-Type: application/json" \
        -d "$(jq -n \
            --arg msg "$message" \
            --arg level "$alert_level" \
            --arg component "ai-code-review" \
            --argjson metadata "$(jq -n \
                --arg status "$approval_status" \
                --arg critical "$critical_count" \
                --arg major "$major_count" \
                --arg minor "$minor_count" \
                --arg base "$base_ref" \
                --arg head "$head_ref" \
                '{approval_status: $status, critical_issues: $critical, major_issues: $major, minor_issues: $minor, base_ref: $base, head_ref: $head}')" \
            '{message: $msg, level: $level, component: $component, metadata: $metadata}')" \
        2>/dev/null)
    
    if [ $? -eq 0 ]; then
        log_success "Review published to MCP"
    else
        log_warning "Failed to publish to MCP (continuing anyway)"
    fi
}

# Save review to file
save_review() {
    local review_text="$1"
    local base_ref="$2"
    local head_ref="$3"
    
    mkdir -p "$REVIEW_DIR"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local review_file="${REVIEW_DIR}/review_${timestamp}.md"
    
    cat > "$review_file" <<EOF
# AI Code Review
**Date**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Base**: ${base_ref}
**Head**: ${head_ref}
**Model**: ${OLLAMA_MODEL}

---

${review_text}
EOF
    
    log_success "Review saved to ${review_file}"
    echo "$review_file"
}

# Main review function
review_changes() {
    local base_ref="${1:-HEAD~1}"
    local head_ref="${2:-HEAD}"
    
    log_info "Starting AI code review: ${base_ref}..${head_ref}"
    
    # Check Ollama health
    if ! check_ollama_health; then
        log_error "Cannot proceed without Ollama"
        exit 1
    fi
    
    # Get git diff
    log_info "Extracting git diff..."
    local diff_content
    diff_content=$(git diff "${base_ref}..${head_ref}" 2>&1)
    
    if [ $? -ne 0 ]; then
        log_error "Failed to get git diff"
        log_error "$diff_content"
        exit 1
    fi
    
    if [ -z "$diff_content" ]; then
        log_warning "No changes detected between ${base_ref} and ${head_ref}"
        echo "NO_CHANGES"
        return 0
    fi
    
    log_info "Diff extracted (${#diff_content} chars)"
    
    # Generate review
    local review_text
    review_text=$(generate_ai_review "$diff_content" "$base_ref" "$head_ref")
    
    if [ $? -ne 0 ] || [ -z "$review_text" ]; then
        log_error "AI review generation failed"
        exit 1
    fi
    
    # Extract approval status
    local approval_status
    approval_status=$(extract_approval_status "$review_text")
    log_info "Approval Status: ${approval_status}"
    
    # Save review
    local review_file
    review_file=$(save_review "$review_text" "$base_ref" "$head_ref")
    
    # Publish to MCP
    publish_to_mcp "$review_text" "$approval_status" "$base_ref" "$head_ref"
    
    # Print summary
    echo ""
    echo "======================================"
    echo "AI CODE REVIEW SUMMARY"
    echo "======================================"
    echo "Status: ${approval_status}"
    echo "Critical Issues: $(count_issues "$review_text" "Critical")"
    echo "Major Issues: $(count_issues "$review_text" "Major")"
    echo "Minor Issues: $(count_issues "$review_text" "Minor")"
    echo "Review File: ${review_file}"
    echo "======================================"
    echo ""
    
    # Return appropriate exit code
    case "$approval_status" in
        APPROVED)
            log_success "Code review APPROVED"
            return 0
            ;;
        NEEDS_CHANGES)
            log_warning "Code review: NEEDS CHANGES"
            return 0  # Don't fail, but record the status
            ;;
        BLOCKED)
            log_error "Code review: BLOCKED"
            return 1  # Fail the script
            ;;
        *)
            log_warning "Code review: ${approval_status}"
            return 0
            ;;
    esac
}

# Usage information
usage() {
    cat <<EOF
Usage: $0 [OPTIONS] [BASE_REF] [HEAD_REF]

AI-powered code review using Ollama

OPTIONS:
    -h, --help          Show this help message
    -m, --model MODEL   Ollama model to use (default: codellama)
    -u, --url URL       Ollama server URL (default: http://localhost:11434)
    -s, --mcp URL       MCP server URL (default: http://localhost:5005)
    -d, --dir DIR       Review output directory (default: ./ai_reviews)

ARGUMENTS:
    BASE_REF            Base git reference (default: HEAD~1)
    HEAD_REF            Head git reference (default: HEAD)

EXAMPLES:
    # Review latest commit
    $0

    # Review changes between branches
    $0 main feature/my-branch

    # Review specific commits
    $0 abc123 def456

ENVIRONMENT VARIABLES:
    OLLAMA_URL          Ollama server URL
    OLLAMA_MODEL        Model name to use
    MCP_SERVER          MCP server URL
    REVIEW_DIR          Output directory for reviews

EXIT CODES:
    0 - Review completed (APPROVED or NEEDS_CHANGES)
    1 - Review BLOCKED or error occurred
EOF
}

# Parse command line arguments
BASE_REF="HEAD~1"
HEAD_REF="HEAD"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -m|--model)
            OLLAMA_MODEL="$2"
            shift 2
            ;;
        -u|--url)
            OLLAMA_URL="$2"
            shift 2
            ;;
        -s|--mcp)
            MCP_SERVER="$2"
            shift 2
            ;;
        -d|--dir)
            REVIEW_DIR="$2"
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
            else
                log_error "Too many arguments"
                usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Run review
review_changes "$BASE_REF" "$HEAD_REF"

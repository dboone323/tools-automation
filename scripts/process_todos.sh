#!/bin/bash
# Process TODOs - Automated TODO to Agent Task Conversion
# This script scans for TODOs and converts them to agent tasks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source agent configuration (optional - only for TASK_QUEUE)
if [[ -f "${WORKSPACE_ROOT}/agents/agent_config.sh" ]]; then
    # Save current SCRIPT_DIR before sourcing
    ORIGINAL_SCRIPT_DIR="${SCRIPT_DIR}"
    source "${WORKSPACE_ROOT}/agents/agent_config.sh"
    # Restore our SCRIPT_DIR
    SCRIPT_DIR="${ORIGINAL_SCRIPT_DIR}"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*" >&2
}

success() {
    echo -e "${GREEN}✅ $*${NC}" >&2
}

warning() {
    echo -e "${YELLOW}⚠️  $*${NC}" >&2
}

error() {
    echo -e "${RED}❌ $*${NC}" >&2
}

# Check if Python is available
check_python() {
    if ! command -v python3 &>/dev/null; then
        error "Python 3 is required but not found"
        return 1
    fi
    return 0
}

# Check if required files exist
check_dependencies() {
    local converter="${SCRIPT_DIR}/todo_task_converter.py"

    if [[ ! -f "${converter}" ]]; then
        error "TODO task converter not found: ${converter}"
        return 1
    fi

    if [[ ! -x "${converter}" ]]; then
        warning "TODO task converter is not executable, making it executable"
        chmod +x "${converter}" || {
            error "Failed to make converter executable"
            return 1
        }
    fi

    return 0
}

# Main processing function
process_todos() {
    log "Starting automated TODO processing..."

    # Check dependencies
    if ! check_python || ! check_dependencies; then
        error "Dependency check failed"
        return 1
    fi

    # Run the TODO task converter
    log "Running TODO task converter..."
    if python3 "${SCRIPT_DIR}/todo_task_converter.py"; then
        success "TODO processing completed successfully"
        return 0
    else
        error "TODO processing failed"
        return 1
    fi
}

# Show current task queue status
show_queue_status() {
    local queue_file="${TASK_QUEUE:-${WORKSPACE_ROOT}/config/task_queue.json}"

    if [[ ! -f "${queue_file}" ]]; then
        warning "Task queue file not found: ${queue_file}"
        return
    fi

    local task_count
    task_count=$(jq '.tasks | length' "${queue_file}" 2>/dev/null || echo "0")

    echo "📊 Current Task Queue Status:"
    echo "   📁 Queue file: ${queue_file}"
    echo "   📋 Total tasks: ${task_count}"

    if [[ ${task_count} -gt 0 ]]; then
        echo "   📝 Tasks by status:"
        jq -r '.tasks[] | "      - \(.id): \(.status) (\(.type))"' "${queue_file}" 2>/dev/null || true

        echo "   🤖 Tasks by assigned agent:"
        jq -r '.tasks[] | "      - \(.assigned_agent): \(.id)"' "${queue_file}" 2>/dev/null | sort | uniq -c | sort -nr | sed 's/^/      /' || true
    fi
}

# Show usage information
usage() {
    cat <<EOF
🚀 TODO Processing System

Usage: $0 [OPTIONS]

Options:
    -h, --help          Show this help message
    -s, --status        Show current task queue status
    -p, --process       Process TODOs and convert to tasks (default)
    -v, --verbose       Enable verbose output

Examples:
    $0                    # Process TODOs
    $0 --status          # Show queue status
    $0 --process         # Explicitly process TODOs

The system automatically:
1. Scans codebase for TODO/FIXME comments
2. Converts them to prioritized agent tasks
3. Adds tasks to the centralized task queue
4. Agents automatically pick up and process tasks

EOF
}

# Parse command line arguments
parse_args() {
    SHOW_STATUS=false
    PROCESS_TODOS=true
    VERBOSE=false

    while [[ $# -gt 0 ]]; do
        case $1 in
        -h | --help)
            usage
            exit 0
            ;;
        -s | --status)
            SHOW_STATUS=true
            PROCESS_TODOS=false
            shift
            ;;
        -p | --process)
            PROCESS_TODOS=true
            shift
            ;;
        -v | --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
        esac
    done
}

# Main execution
main() {
    parse_args "$@"

    if [[ "${VERBOSE}" == "true" ]]; then
        set -x
    fi

    echo "🚀 TODO Processing System"
    echo "=========================="

    if [[ "${SHOW_STATUS}" == "true" ]]; then
        show_queue_status
        exit 0
    fi

    if [[ "${PROCESS_TODOS}" == "true" ]]; then
        if process_todos; then
            echo ""
            show_queue_status
            success "TODO processing workflow completed!"
        else
            error "TODO processing failed"
            exit 1
        fi
    fi
}

# Run main function
main "$@"

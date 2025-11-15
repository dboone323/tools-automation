#!/bin/bash
# monitor_batch_processing.sh - Monitor TODO batch processing progress

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRESS_FILE="${WORKSPACE_ROOT}/todo_batch_progress.json"
LOG_FILE="${WORKSPACE_ROOT}/batch_processing.log"
PID_FILE="${WORKSPACE_ROOT}/batch_processor.pid"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if jq is available
if ! command -v jq >/dev/null 2>&1; then
    echo -e "${RED}Error: jq is required but not installed${NC}"
    exit 1
fi

# Function to show progress
show_progress() {
    if [[ ! -f "${PROGRESS_FILE}" ]]; then
        echo -e "${YELLOW}Progress file not found. Batch processing may not have started yet.${NC}"
        return
    fi

    echo -e "${PURPLE}📊 TODO Batch Processing Progress${NC}"
    echo "======================================"

    local total
    total=$(jq -r '.total_todos // 0' "${PROGRESS_FILE}")
    local processed
    processed=$(jq -r '.processed // 0' "${PROGRESS_FILE}")
    local successful
    successful=$(jq -r '.successful // 0' "${PROGRESS_FILE}")
    local failed
    failed=$(jq -r '.failed // 0' "${PROGRESS_FILE}")
    local batches
    batches=$(jq -r '.batches_completed // 0' "${PROGRESS_FILE}")
    local current_batch
    current_batch=$(jq -r '.current_batch // 0' "${PROGRESS_FILE}")
    local start_time
    start_time=$(jq -r '.start_time // "Unknown"' "${PROGRESS_FILE}")
    local last_update
    last_update=$(jq -r '.last_update // "Unknown"' "${PROGRESS_FILE}")

    echo -e "${BLUE}Total TODOs:${NC} ${total}"
    echo -e "${BLUE}Processed:${NC} ${processed}"
    echo -e "${BLUE}Successful:${NC} ${successful}"
    echo -e "${BLUE}Failed:${NC} ${failed}"
    echo -e "${BLUE}Batches completed:${NC} ${batches}"
    echo -e "${BLUE}Current batch:${NC} ${current_batch}"
    echo -e "${BLUE}Start time:${NC} ${start_time}"
    echo -e "${BLUE}Last update:${NC} ${last_update}"

    if [[ ${total} -gt 0 ]]; then
        local percent;
        percent=$((processed * 100 / total))
        echo -e "${BLUE}Completion:${NC} ${percent}%"

        # Progress bar
        local bar_width;
        bar_width=50
        local filled;
        filled=$((processed * bar_width / total))
        local empty;
        empty=$((bar_width - filled))

        printf "${GREEN}Progress: ["
        printf "%${filled}s" | tr ' ' '█'
        printf "%${empty}s" | tr ' ' '░'
        printf "] ${percent}%%\n${NC}"
    fi

    # Calculate ETA if we have progress
    if [[ ${processed} -gt 0 && ${batches} -gt 0 ]]; then
        local avg_batch_time
        avg_batch_time=$(jq -r '.batches_completed / ((now - (.start_time | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime)) / 60)' "${PROGRESS_FILE}" 2>/dev/null || echo "0")

        if [[ $(echo "${avg_batch_time} > 0" | bc -l 2>/dev/null) ]]; then
            local remaining_batches;
            remaining_batches=$(((total - processed + 9) / 10)) # Round up
            local eta_minutes;
            eta_minutes=$(echo "scale=1; ${remaining_batches} / ${avg_batch_time}" | bc -l 2>/dev/null || echo "0")
            echo -e "${BLUE}ETA:${NC} ~${eta_minutes} minutes remaining"
        fi
    fi
}

# Function to check if process is running
check_process() {
    if [[ -f "${PID_FILE}" ]]; then
        local pid
        pid=$(cat "${PID_FILE}")
        if kill -0 "${pid}" 2>/dev/null; then
            echo -e "${GREEN}✅ Batch processor is running (PID: ${pid})${NC}"
            return 0
        else
            echo -e "${RED}❌ Batch processor process not found (PID: ${pid})${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  No PID file found${NC}"
        return 1
    fi
}

# Function to show recent log entries
show_recent_logs() {
    if [[ -f "${LOG_FILE}" ]]; then
        echo -e "${CYAN}📝 Recent Log Entries:${NC}"
        echo "---------------------"
        tail -10 "${LOG_FILE}" | while IFS= read -r line; do
            echo -e "${CYAN}${line}${NC}"
        done
        echo ""
    fi
}

# Function to show summary
show_summary() {
    echo -e "${PURPLE}🎯 Batch Processing Summary${NC}"
    echo "============================"

    check_process
    echo ""

    show_progress
    echo ""

    show_recent_logs

    # Show time elapsed
    if [[ -f "${PROGRESS_FILE}" ]]; then
        local start_time
        start_time=$(jq -r '.start_time // empty' "${PROGRESS_FILE}")
        if [[ -n "${start_time}" ]]; then
            local elapsed_seconds;
            elapsed_seconds=$(($(date +%s) - $(date -d "${start_time}" +%s 2>/dev/null || echo "$(date +%s)")))
            local elapsed_minutes;
            elapsed_minutes=$((elapsed_seconds / 60))
            local elapsed_hours;
            elapsed_hours=$((elapsed_minutes / 60))
            local remaining_minutes;
            remaining_minutes=$((elapsed_minutes % 60))

            if [[ ${elapsed_hours} -gt 0 ]]; then
                echo -e "${BLUE}Time elapsed:${NC} ${elapsed_hours}h ${remaining_minutes}m"
            else
                echo -e "${BLUE}Time elapsed:${NC} ${elapsed_minutes}m"
            fi
        fi
    fi
}

# Main function
main() {
    local mode;
    mode="${1:-summary}"

    case "${mode}" in
    "progress")
        show_progress
        ;;
    "process")
        check_process
        ;;
    "logs")
        show_recent_logs
        ;;
    "summary" | *)
        show_summary
        ;;
    esac
}

# Run main function with arguments
main "$@"

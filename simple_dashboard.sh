#!/bin/bash

# Simple Dashboard Agent
# Basic dashboard display for agent status

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUS_DIR="${SCRIPT_DIR}/status"
LOG_FILE="${SCRIPT_DIR}/logs/simple_dashboard.log"
REFRESH_INTERVAL=${REFRESH_INTERVAL:-30}

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "${LOG_FILE}"
}

clear_screen() {
    echo -e "\033[2J\033[H"
}

print_header() {
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                     🤖 AGENT DASHBOARD                        ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_agent_status() {
    local agent_name="$1"
    local status_file="${STATUS_DIR}/${agent_name}.status"

    if [[ -f "${status_file}" ]]; then
        local status
        status=$(cat "${status_file}" 2>/dev/null || echo "UNKNOWN")

        case "${status}" in
        *"RUNNING"* | *"HEALTHY"*)
            echo -e "  ${GREEN}●${NC} ${agent_name}: ${GREEN}${status}${NC}"
            ;;
        *"WARNING"* | *"ERROR"*)
            echo -e "  ${YELLOW}●${NC} ${agent_name}: ${YELLOW}${status}${NC}"
            ;;
        *"STOPPED"* | *"FAILED"*)
            echo -e "  ${RED}●${NC} ${agent_name}: ${RED}${status}${NC}"
            ;;
        *)
            echo -e "  ${BLUE}●${NC} ${agent_name}: ${BLUE}${status}${NC}"
            ;;
        esac
    else
        echo -e "  ${CYAN}○${NC} ${agent_name}: ${CYAN}No status file${NC}"
    fi
}

print_system_info() {
    echo -e "${BLUE}📊 System Information${NC}"
    echo "   CPU Usage: $(top -l 1 | grep "CPU usage" | awk '{print $3}' 2>/dev/null || echo "N/A")"
    echo "   Memory: $(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.' 2>/dev/null || echo "N/A") pages free"
    echo "   Disk Usage: $(df -h / | tail -1 | awk '{print $5}' 2>/dev/null || echo "N/A")"
    echo "   Uptime: $(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}' 2>/dev/null || echo "N/A")"
    echo ""
}

print_recent_logs() {
    echo -e "${BLUE}📝 Recent Activity${NC}"

    # Check for recent log entries
    local recent_logs
    recent_logs=$(find "${SCRIPT_DIR}/logs" -name "*.log" -type f -mmin -5 2>/dev/null | head -3)

    if [[ -n "${recent_logs}" ]]; then
        echo "${recent_logs}" | while read -r log_file; do
            local log_name
            log_name=$(basename "${log_file}" .log)
            local last_entry
            last_entry=$(tail -1 "${log_file}" 2>/dev/null | cut -d' ' -f4- || echo "No recent activity")
            echo "   ${log_name}: ${last_entry}"
        done
    else
        echo "   No recent log activity"
    fi
    echo ""
}

display_dashboard() {
    clear_screen
    print_header
    print_system_info

    echo -e "${BLUE}🤖 Agent Status${NC}"

    # List of agents to monitor
    local agents=("monitoring_agent" "performance_agent" "dashboard_launcher" "launch_agent_dashboard" "minimal_dashboard" "backup_manager" "ai_client" "ai_code_review_agent")

    for agent in "${agents[@]}"; do
        print_agent_status "${agent}"
    done

    echo ""
    print_recent_logs

    echo -e "${CYAN}Last updated: $(date)${NC}"
    echo -e "${CYAN}Refresh interval: ${REFRESH_INTERVAL} seconds${NC}"
    echo -e "${CYAN}Press Ctrl+C to exit${NC}"
}

# Source shared functions
if [[ -f "${SCRIPT_DIR}/shared_functions.sh" ]]; then
    source "${SCRIPT_DIR}/shared_functions.sh"
fi

# Main
main() {
    log "Starting simple dashboard"

    # Create directories
    mkdir -p "${SCRIPT_DIR}/logs"
    mkdir -p "${STATUS_DIR}"

    if [[ "${1:-}" == "once" ]]; then
        display_dashboard
    else
        log "Dashboard running - press Ctrl+C to stop"
        while true; do
            display_dashboard
            sleep "${REFRESH_INTERVAL}"
        done
    fi
}

# If run directly, execute main
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    trap 'log "Dashboard stopped by user"; exit 0' INT
    main "$@"
fi

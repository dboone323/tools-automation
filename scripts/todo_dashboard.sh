#!/bin/bash
# TODO Dashboard
# Real-time monitoring dashboard for TODO task processing

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="$WORKSPACE_ROOT/config"
TASK_QUEUE_FILE="$CONFIG_DIR/task_queue.json"
AGENT_STATUS_FILE="$CONFIG_DIR/agent_status.json"
MONITORING_LOG_FILE="$CONFIG_DIR/todo_monitoring.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Dashboard functions
show_header() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                        TODO SYSTEM MONITORING DASHBOARD${CYAN}                      ║${NC}"
    echo -e "${CYAN}║${WHITE}                    Real-time Task Processing Overview${CYAN}                       ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

show_timestamp() {
    echo -e "${WHITE}📅 $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo
}

get_task_stats() {
    if [ ! -f "$TASK_QUEUE_FILE" ]; then
        echo "0|0|0|0|0"
        return
    fi

    # Count tasks by status
    total=$(jq '.tasks | length' "$TASK_QUEUE_FILE" 2>/dev/null || echo "0")
    pending=$(jq '.tasks | map(select(.status == "pending")) | length' "$TASK_QUEUE_FILE" 2>/dev/null || echo "0")
    in_progress=$(jq '.tasks | map(select(.status == "in_progress")) | length' "$TASK_QUEUE_FILE" 2>/dev/null || echo "0")
    completed=$(jq '.tasks | map(select(.status == "completed")) | length' "$TASK_QUEUE_FILE" 2>/dev/null || echo "0")
    failed=$(jq '.tasks | map(select(.status == "failed")) | length' "$TASK_QUEUE_FILE" 2>/dev/null || echo "0")

    echo "$total|$pending|$in_progress|$completed|$failed"
}

get_agent_workload() {
    if [ ! -f "$AGENT_STATUS_FILE" ]; then
        echo "{}"
        return
    fi

    jq '.agents // {}' "$AGENT_STATUS_FILE" 2>/dev/null || echo "{}"
}

get_priority_distribution() {
    if [ ! -f "$TASK_QUEUE_FILE" ]; then
        echo "0|0|0|0|0"
        return
    fi

    p1=$(jq '.tasks | map(select(.priority == 1)) | length' "$TASK_QUEUE_FILE" 2>/dev/null || echo "0")
    p5=$(jq '.tasks | map(select(.priority >= 2 and .priority <= 5)) | length' "$TASK_QUEUE_FILE" 2>/dev/null || echo "0")
    p7=$(jq '.tasks | map(select(.priority >= 6 and .priority <= 7)) | length' "$TASK_QUEUE_FILE" 2>/dev/null || echo "0")
    p9=$(jq '.tasks | map(select(.priority >= 8 and .priority <= 9)) | length' "$TASK_QUEUE_FILE" 2>/dev/null || echo "0")
    p10=$(jq '.tasks | map(select(.priority == 10)) | length' "$TASK_QUEUE_FILE" 2>/dev/null || echo "0")

    echo "$p1|$p5|$p7|$p9|$p10"
}

get_agent_distribution() {
    if [ ! -f "$TASK_QUEUE_FILE" ]; then
        echo "{}"
        return
    fi

    jq '.tasks | group_by(.assigned_agent) | map({(.[0].assigned_agent // "unassigned"): length}) | add // {}' "$TASK_QUEUE_FILE" 2>/dev/null || echo "{}"
}

show_task_overview() {
    echo -e "${BLUE}📊 TASK OVERVIEW${NC}"
    echo -e "${BLUE}────────────────${NC}"

    IFS='|' read -r total pending in_progress completed failed <<<"$(get_task_stats)"

    echo -e "Total Tasks:     ${WHITE}$total${NC}"
    echo -e "Pending:         ${YELLOW}$pending${NC}"
    echo -e "In Progress:     ${CYAN}$in_progress${NC}"
    echo -e "Completed:       ${GREEN}$completed${NC}"
    echo -e "Failed:          ${RED}$failed${NC}"

    if [ "$total" -gt 0 ]; then
        completion_rate=$((completed * 100 / total))
        echo -e "Completion Rate: ${GREEN}$completion_rate%${NC}"
    fi

    echo
}

show_priority_distribution() {
    echo -e "${MAGENTA}🎯 PRIORITY DISTRIBUTION${NC}"
    echo -e "${MAGENTA}───────────────────────${NC}"

    IFS='|' read -r p1 p5 p7 p9 p10 <<<"$(get_priority_distribution)"

    echo -e "Critical (10):   ${RED}$p10${NC}"
    echo -e "High (8-9):      ${YELLOW}$p9${NC}"
    echo -e "Medium (6-7):    ${BLUE}$p7${NC}"
    echo -e "Low (2-5):       ${CYAN}$p5${NC}"
    echo -e "Minimal (1):     ${WHITE}$p1${NC}"

    echo
}

show_agent_workload() {
    echo -e "${GREEN}🤖 AGENT WORKLOAD${NC}"
    echo -e "${GREEN}────────────────${NC}"

    agent_data=$(get_agent_workload)

    # Check if we have agent data
    if [ "$agent_data" = "{}" ]; then
        echo -e "${YELLOW}No agent status data available${NC}"
    else
        echo "$agent_data" | jq -r 'to_entries[] | "\(.key): \(.value.current_tasks // 0)/\(.value.capacity // 10) tasks (\(.value.utilization_percent // 0)%)"' 2>/dev/null || echo "Error parsing agent data"
    fi

    echo
}

show_agent_distribution() {
    echo -e "${CYAN}👥 AGENT DISTRIBUTION${NC}"
    echo -e "${CYAN}────────────────────${NC}"

    agent_dist=$(get_agent_distribution)

    if [ "$agent_dist" = "{}" ]; then
        echo -e "${YELLOW}No task distribution data available${NC}"
    else
        echo "$agent_dist" | jq -r 'to_entries[] | select(.value > 0) | "\(.key): \(.value) tasks"' 2>/dev/null | sort -t: -k2 -nr || echo "Error parsing distribution data"
    fi

    echo
}

show_recent_activity() {
    echo -e "${YELLOW}⚡ RECENT ACTIVITY${NC}"
    echo -e "${YELLOW}─────────────────${NC}"

    if [ -f "$MONITORING_LOG_FILE" ]; then
        # Get recent alerts from monitoring log
        recent_alerts=$(jq '.alerts[-5:] // []' "$MONITORING_LOG_FILE" 2>/dev/null)

        if [ "$recent_alerts" != "[]" ]; then
            echo "$recent_alerts" | jq -r '.[] | "[\(.timestamp | split(".")[0])] \(.message)"' 2>/dev/null || echo "Error parsing alerts"
        else
            echo -e "${WHITE}No recent activity${NC}"
        fi
    else
        echo -e "${WHITE}No monitoring data available${NC}"
    fi

    echo
}

show_system_health() {
    echo -e "${RED}🏥 SYSTEM HEALTH${NC}"
    echo -e "${RED}────────────────${NC}"

    # Basic health checks
    if [ -f "$TASK_QUEUE_FILE" ]; then
        echo -e "✅ Task queue:    ${GREEN}Available${NC}"
    else
        echo -e "❌ Task queue:    ${RED}Missing${NC}"
    fi

    if [ -f "$AGENT_STATUS_FILE" ]; then
        echo -e "✅ Agent status:  ${GREEN}Available${NC}"
    else
        echo -e "❌ Agent status:  ${RED}Missing${NC}"
    fi

    if [ -f "$MONITORING_LOG_FILE" ]; then
        echo -e "✅ Monitoring:    ${GREEN}Active${NC}"
    else
        echo -e "⚠️  Monitoring:    ${YELLOW}Inactive${NC}"
    fi

    echo
}

show_monitoring_status() {
    echo -e "${BLUE}🔍 MONITORING STATUS${NC}"
    echo -e "${BLUE}───────────────────${NC}"

    # Check if monitoring is running
    monitoring_pid=$(pgrep -f "todo_monitor.py.*--start" || echo "")

    if [ -n "$monitoring_pid" ]; then
        echo -e "Status: ${GREEN}Active${NC} (PID: $monitoring_pid)"
    else
        echo -e "Status: ${RED}Inactive${NC}"
    fi

    # Show monitoring stats if available
    if [ -f "$MONITORING_LOG_FILE" ]; then
        snapshot_count=$(jq '.snapshots | length' "$MONITORING_LOG_FILE" 2>/dev/null || echo "0")
        alert_count=$(jq '.alerts | length' "$MONITORING_LOG_FILE" 2>/dev/null || echo "0")

        echo -e "Snapshots: $snapshot_count"
        echo -e "Alerts: $alert_count"
    fi

    echo
}

show_menu() {
    echo -e "${WHITE}┌─────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}│${CYAN} COMMANDS:${WHITE}                                                            │${NC}"
    echo -e "${WHITE}│${GREEN}  r${WHITE}  Refresh dashboard                                              │${NC}"
    echo -e "${WHITE}│${GREEN}  m${WHITE}  Start monitoring                                              │${NC}"
    echo -e "${WHITE}│${GREEN}  s${WHITE}  Stop monitoring                                               │${NC}"
    echo -e "${WHITE}│${GREEN}  p${WHITE}  Process TODOs                                                 │${NC}"
    echo -e "${WHITE}│${GREEN}  t${WHITE}  Show task details                                             │${NC}"
    echo -e "${WHITE}│${GREEN}  q${WHITE}  Quit                                                           │${NC}"
    echo -e "${WHITE}└─────────────────────────────────────────────────────────────────────────┘${NC}"
}

start_monitoring() {
    echo -e "${GREEN}Starting monitoring system...${NC}"

    # Start monitoring in background
    nohup python3 "$SCRIPT_DIR/todo_monitor.py" --start >/dev/null 2>&1 &

    sleep 2

    # Check if it's running
    if pgrep -f "todo_monitor.py.*--start" >/dev/null; then
        echo -e "${GREEN}✅ Monitoring started successfully${NC}"
    else
        echo -e "${RED}❌ Failed to start monitoring${NC}"
    fi
}

stop_monitoring() {
    echo -e "${YELLOW}Stopping monitoring system...${NC}"

    # Kill monitoring process
    pkill -f "todo_monitor.py.*--start" || true

    sleep 1

    if pgrep -f "todo_monitor.py.*--start" >/dev/null; then
        echo -e "${RED}❌ Failed to stop monitoring${NC}"
    else
        echo -e "${GREEN}✅ Monitoring stopped${NC}"
    fi
}

process_todos() {
    echo -e "${BLUE}Processing TODOs...${NC}"
    "$SCRIPT_DIR/process_todos.sh"
}

show_task_details() {
    echo -e "${CYAN}Recent Tasks:${NC}"
    echo

    if [ -f "$TASK_QUEUE_FILE" ]; then
        # Show last 10 tasks
        jq '.tasks[-10:] | reverse[] | "[\(.status)] \(.id) -> \(.assigned_agent) (P\(.priority))"' "$TASK_QUEUE_FILE" 2>/dev/null || echo "Error reading tasks"
    else
        echo -e "${YELLOW}No task data available${NC}"
    fi

    echo
    read -p "Press Enter to continue..."
}

main_loop() {
    clear
    show_header
    show_timestamp

    while true; do
        show_task_overview
        show_priority_distribution
        show_agent_workload
        show_agent_distribution
        show_recent_activity
        show_system_health
        show_monitoring_status
        show_menu

        echo -n -e "${WHITE}Choose command: ${NC}"
        read -n 1 choice
        echo

        case $choice in
        r | R)
            clear
            show_header
            show_timestamp
            ;;
        m | M)
            start_monitoring
            sleep 2
            clear
            show_header
            show_timestamp
            ;;
        s | S)
            stop_monitoring
            sleep 2
            clear
            show_header
            show_timestamp
            ;;
        p | P)
            process_todos
            sleep 2
            clear
            show_header
            show_timestamp
            ;;
        t | T)
            show_task_details
            clear
            show_header
            show_timestamp
            ;;
        q | Q)
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice. Press 'r' to refresh.${NC}"
            sleep 1
            ;;
        esac
    done
}

# Check dependencies
check_dependencies() {
    if ! command -v jq &>/dev/null; then
        echo -e "${RED}Error: jq is required but not installed.${NC}"
        echo -e "${YELLOW}Please install jq to use the dashboard.${NC}"
        exit 1
    fi

    if ! command -v python3 &>/dev/null; then
        echo -e "${RED}Error: python3 is required but not installed.${NC}"
        exit 1
    fi
}

# Main execution
case "${1:-}" in
--help | -h)
    echo "TODO Dashboard - Real-time monitoring for TODO task processing"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --help, -h    Show this help message"
    echo "  --once        Show dashboard once and exit"
    echo
    echo "Interactive commands:"
    echo "  r             Refresh dashboard"
    echo "  m             Start monitoring"
    echo "  s             Stop monitoring"
    echo "  p             Process TODOs"
    echo "  t             Show task details"
    echo "  q             Quit"
    ;;
--once)
    check_dependencies
    show_header
    show_timestamp
    show_task_overview
    show_priority_distribution
    show_agent_workload
    show_agent_distribution
    show_recent_activity
    show_system_health
    show_monitoring_status
    ;;
*)
    check_dependencies
    main_loop
    ;;
esac

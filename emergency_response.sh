#!/bin/bash

# Emergency Response Agent
# Handles emergency situations and system recovery

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUS_DIR="${SCRIPT_DIR}/status"
LOG_FILE="${SCRIPT_DIR}/logs/emergency_response.log"
BACKUP_DIR="${SCRIPT_DIR}/backups/emergency"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "${LOG_FILE}"
}

clear_screen() {
    echo -e "\033[2J\033[H"
}

print_header() {
    echo -e "${RED}🚨 EMERGENCY RESPONSE SYSTEM${NC}"
    echo -e "${RED}═══════════════════════════════════════════════${NC}"
    echo ""
}

check_system_health() {
    local critical_issues=0

    log "Checking system health..."

    # Check disk space
    local disk_usage
    disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ ${disk_usage} -gt 90 ]]; then
        log "CRITICAL: Disk usage at ${disk_usage}%"
        ((critical_issues++))
    fi

    # Check memory usage
    local mem_usage
    mem_usage=$(vm_stat | grep "Pages active" | awk '{print $3}' | tr -d '.' 2>/dev/null || echo "0")
    if [[ ${mem_usage} -gt 1000000 ]]; then # Arbitrary high threshold
        log "WARNING: High memory usage detected"
    fi

    # Check for critical processes
    if ! pgrep -f "agent_supervisor" >/dev/null 2>&1; then
        log "CRITICAL: Agent supervisor not running"
        ((critical_issues++))
    fi

    # Check log file sizes
    find "${SCRIPT_DIR}/logs" -name "*.log" -size +100M 2>/dev/null | while read -r log_file; do
        log "WARNING: Large log file: ${log_file}"
    done

    return ${critical_issues}
}

create_emergency_backup() {
    log "Creating emergency backup..."

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="${BACKUP_DIR}/emergency_backup_${timestamp}"

    mkdir -p "${backup_path}"

    # Backup critical files
    cp -r "${STATUS_DIR}" "${backup_path}/" 2>/dev/null || true
    cp -r "${SCRIPT_DIR}/config" "${backup_path}/" 2>/dev/null || true

    # Create backup manifest
    echo "Emergency backup created: ${timestamp}" >"${backup_path}/MANIFEST.txt"
    echo "System state at backup time:" >>"${backup_path}/MANIFEST.txt"
    ps aux | head -20 >>"${backup_path}/MANIFEST.txt"

    log "Emergency backup created at: ${backup_path}"
}

kill_problematic_processes() {
    log "Checking for problematic processes..."

    # Kill runaway processes (example: processes using too much CPU)
    ps aux | awk '$3 > 90 {print $2}' | while read -r pid; do
        if [[ ${pid} -ne $$ ]]; then # Don't kill ourselves
            log "Killing high CPU process: ${pid}"
            kill -9 "${pid}" 2>/dev/null || true
        fi
    done

    # Kill processes that have been running too long
    find /proc -maxdepth 1 -type d -mtime +1 2>/dev/null | while read -r proc_dir; do
        local pid
        pid=$(basename "${proc_dir}")
        if [[ ${pid} =~ ^[0-9]+$ ]] && [[ ${pid} -ne $$ ]]; then
            local cmdline
            cmdline=$(cat "${proc_dir}/cmdline" 2>/dev/null | tr '\0' ' ' | head -c 100)
            if [[ -n "${cmdline}" ]]; then
                log "Found long-running process: ${pid} - ${cmdline}"
                # Only kill if it's an agent process
                if echo "${cmdline}" | grep -q "agent"; then
                    log "Terminating long-running agent process: ${pid}"
                    kill -TERM "${pid}" 2>/dev/null || true
                    sleep 2
                    if kill -0 "${pid}" 2>/dev/null; then
                        kill -9 "${pid}" 2>/dev/null || true
                    fi
                fi
            fi
        fi
    done
}

restart_critical_services() {
    log "Restarting critical services..."

    # Restart agent supervisor if not running
    if ! pgrep -f "agent_supervisor" >/dev/null 2>&1; then
        log "Starting agent supervisor..."
        nohup "${SCRIPT_DIR}/agent_supervisor.sh" >/dev/null 2>&1 &
    fi

    # Restart monitoring agents
    if ! pgrep -f "monitoring_agent" >/dev/null 2>&1; then
        log "Starting monitoring agent..."
        nohup "${SCRIPT_DIR}/monitoring_agent.sh" >/dev/null 2>&1 &
    fi

    # Clean up old log files
    find "${SCRIPT_DIR}/logs" -name "*.log" -mtime +7 -delete 2>/dev/null || true
}

send_emergency_alert() {
    local message="$1"
    log "Sending emergency alert: ${message}"

    # Create alert file
    echo "$(date): EMERGENCY - ${message}" >>"${SCRIPT_DIR}/alerts/emergency_alerts.log"

    # In a real system, this might send email, SMS, or trigger other alerts
    # For now, just log it
    echo "🚨 EMERGENCY ALERT: ${message}" >&2
}

perform_emergency_recovery() {
    log "Performing emergency recovery..."

    print_header
    echo -e "${YELLOW}🔄 Emergency Recovery in Progress...${NC}"
    echo ""

    # Step 1: Assess situation
    echo "1. Assessing system state..."
    if ! check_system_health; then
        echo -e "${RED}   ⚠️  Critical issues detected${NC}"
    else
        echo -e "${GREEN}   ✅ System health OK${NC}"
    fi

    # Step 2: Create backup
    echo "2. Creating emergency backup..."
    create_emergency_backup
    echo -e "${GREEN}   ✅ Emergency backup created${NC}"

    # Step 3: Kill problematic processes
    echo "3. Terminating problematic processes..."
    kill_problematic_processes
    echo -e "${GREEN}   ✅ Process cleanup completed${NC}"

    # Step 4: Restart critical services
    echo "4. Restarting critical services..."
    restart_critical_services
    echo -e "${GREEN}   ✅ Critical services restarted${NC}"

    # Step 5: Verify recovery
    echo "5. Verifying system recovery..."
    sleep 2
    if check_system_health; then
        echo -e "${GREEN}   ✅ System recovery successful${NC}"
        send_emergency_alert "System recovery completed successfully"
    else
        echo -e "${RED}   ❌ Recovery may have failed - manual intervention required${NC}"
        send_emergency_alert "System recovery failed - manual intervention required"
    fi

    echo ""
    echo -e "${BLUE}Emergency recovery process completed.${NC}"
    log "Emergency recovery process completed"
}

monitor_emergency_conditions() {
    log "Starting emergency monitoring..."

    while true; do
        if ! check_system_health; then
            log "Emergency condition detected - initiating recovery"
            send_emergency_alert "Emergency condition detected - recovery initiated"
            perform_emergency_recovery
        fi

        sleep 60 # Check every minute
    done
}

# Source shared functions
if [[ -f "${SCRIPT_DIR}/shared_functions.sh" ]]; then
    source "${SCRIPT_DIR}/shared_functions.sh"
fi

# Main
main() {
    log "Emergency Response Agent starting..."

    # Create directories
    mkdir -p "${SCRIPT_DIR}/logs"
    mkdir -p "${STATUS_DIR}"
    mkdir -p "${BACKUP_DIR}"
    mkdir -p "${SCRIPT_DIR}/alerts"

    case "${1:-}" in
    "check")
        log "Performing health check..."
        if check_system_health; then
            echo -e "${GREEN}✅ System health OK${NC}"
            exit 0
        else
            echo -e "${RED}❌ Critical issues detected${NC}"
            exit 1
        fi
        ;;
    "backup")
        log "Creating emergency backup..."
        create_emergency_backup
        echo -e "${GREEN}✅ Emergency backup created${NC}"
        ;;
    "recover")
        log "Performing emergency recovery..."
        perform_emergency_recovery
        ;;
    "monitor")
        log "Starting emergency monitoring..."
        monitor_emergency_conditions
        ;;
    *)
        echo "Usage: $0 {check|backup|recover|monitor}"
        echo "  check   - Check system health"
        echo "  backup  - Create emergency backup"
        echo "  recover - Perform emergency recovery"
        echo "  monitor - Monitor for emergency conditions"
        exit 1
        ;;
    esac
}

# If run directly, execute main
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    trap 'log "Emergency Response Agent stopped"; exit 0' INT TERM
    main "$@"
fi

#!/bin/bash
# Quantum Agent Integration - Launch and manage quantum-enhanced agents
# Integrates quantum agents with the existing automation system

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/agents"
QUANTUM_AGENTS=(
    "quantum_chemistry_agent.sh"
    "quantum_finance_agent.sh"
    "quantum_orchestrator_agent.sh"
    "quantum_learning_agent.sh"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] [QUANTUM INTEGRATION] $*" >&2; }
success() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [QUANTUM INTEGRATION] ✅ $*${NC}" >&2; }
warning() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [QUANTUM INTEGRATION] ⚠️  $*${NC}" >&2; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [QUANTUM INTEGRATION] ERROR: $*${NC}" >&2; }
quantum_log() { echo -e "${PURPLE}[$(date +'%Y-%m-%d %H:%M:%S')] [QUANTUM INTEGRATION] ⚛️  $*${NC}" >&2; }
info() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [QUANTUM INTEGRATION] ℹ️  $*${NC}" >&2; }

# Check if quantum agents exist and are executable
check_quantum_agents() {
    log "Checking quantum agent readiness"

    local ready_count=0
    for agent in "${QUANTUM_AGENTS[@]}"; do
        local agent_path="${AGENTS_DIR}/${agent}"
        if [[ -f "${agent_path}" && -x "${agent_path}" ]]; then
            success "${agent} is ready"
            ready_count=$((ready_count + 1))
        else
            warning "${agent} is missing or not executable"
        fi
    done

    if [[ ${ready_count} -eq ${#QUANTUM_AGENTS[@]} ]]; then
        quantum_log "All quantum agents are ready for integration"
        return 0
    else
        error "${ready_count}/${#QUANTUM_AGENTS[@]} quantum agents ready"
        return 1
    fi
}

# Start quantum agents
start_quantum_agents() {
    local background="${1:-true}"

    quantum_log "Starting quantum agents (background: ${background})"

    for agent in "${QUANTUM_AGENTS[@]}"; do
        local agent_path="${AGENTS_DIR}/${agent}"
        local agent_name="${agent%.sh}"

        if [[ ! -f "${agent_path}" || ! -x "${agent_path}" ]]; then
            warning "Skipping ${agent} - not found or not executable"
            continue
        fi

        # Check if agent is already running
        local pid_file="${AGENTS_DIR}/${agent_name}.pid"
        if [[ -f "${pid_file}" ]]; then
            local existing_pid
            existing_pid=$(cat "${pid_file}" 2>/dev/null || echo "")
            if [[ -n "${existing_pid}" ]] && kill -0 "${existing_pid}" 2>/dev/null; then
                info "${agent} is already running (PID: ${existing_pid})"
                continue
            else
                warning "Removing stale PID file for ${agent}"
                rm -f "${pid_file}"
            fi
        fi

        log "Starting ${agent}"

        if [[ "${background}" == "true" ]]; then
            # Start in background
            local log_file="${AGENTS_DIR}/${agent_name}.log"
            nohup "${agent_path}" &>"${log_file}" &
            local agent_pid=$!
            echo ${agent_pid} >"${pid_file}"
            success "Started ${agent} in background (PID: ${agent_pid})"
        else
            # Start in foreground (for testing)
            "${agent_path}"
        fi
    done
}

# Stop quantum agents
stop_quantum_agents() {
    quantum_log "Stopping quantum agents"

    for agent in "${QUANTUM_AGENTS[@]}"; do
        local agent_name="${agent%.sh}"
        local pid_file="${AGENTS_DIR}/${agent_name}.pid"

        if [[ -f "${pid_file}" ]]; then
            local agent_pid
            agent_pid=$(cat "${pid_file}" 2>/dev/null || echo "")
            if [[ -n "${agent_pid}" ]] && kill -0 "${agent_pid}" 2>/dev/null; then
                log "Stopping ${agent} (PID: ${agent_pid})"
                kill "${agent_pid}" 2>/dev/null || true
                # Wait a bit for graceful shutdown
                sleep 2
                # Force kill if still running
                if kill -0 "${agent_pid}" 2>/dev/null; then
                    warning "Force killing ${agent}"
                    kill -9 "${agent_pid}" 2>/dev/null || true
                fi
            fi
            rm -f "${pid_file}"
            success "Stopped ${agent}"
        else
            info "${agent} is not running"
        fi
    done
}

# Get quantum agent status
get_quantum_agent_status() {
    quantum_log "Checking quantum agent status"

    local status_file="${AGENTS_DIR}/agent_status.json"
    local running_count=0
    local total_count=0

    for agent in "${QUANTUM_AGENTS[@]}"; do
        local agent_name="${agent%.sh}"
        local pid_file="${AGENTS_DIR}/${agent_name}.pid"
        total_count=$((total_count + 1))

        if [[ -f "${pid_file}" ]]; then
            local agent_pid
            agent_pid=$(cat "${pid_file}" 2>/dev/null || echo "")
            if [[ -n "${agent_pid}" ]] && kill -0 "${agent_pid}" 2>/dev/null; then
                echo -e "${GREEN}${agent}: RUNNING (PID: ${agent_pid})${NC}"
                running_count=$((running_count + 1))
            else
                echo -e "${YELLOW}${agent}: STOPPED (stale PID file)${NC}"
                rm -f "${pid_file}"
            fi
        else
            echo -e "${RED}${agent}: STOPPED${NC}"
        fi
    done

    echo ""
    echo "Quantum agents: ${running_count}/${total_count} running"

    if [[ ${running_count} -eq ${total_count} ]]; then
        success "All quantum agents are operational"
    elif [[ ${running_count} -eq 0 ]]; then
        warning "No quantum agents are running"
    else
        warning "Some quantum agents are not running"
    fi
}

# Update agent assignment system to include quantum agents
update_agent_assignments() {
    log "Updating agent assignment system with quantum capabilities"

    local assign_script="${SCRIPT_DIR}/assign_agent.sh"

    if [[ ! -f "${assign_script}" ]]; then
        warning "Agent assignment script not found: ${assign_script}"
        return 1
    fi

    # Create backup
    cp "${assign_script}" "${assign_script}.backup"

    # Add quantum agent assignments (this would need to be integrated into the existing logic)
    cat >>"${assign_script}" <<'EOF'

# Quantum agent assignments
elif echo "${text}" | grep -iqE 'quantum|chemistry|molecular|simulation|vqe|qmc|qpe|vqd'; then
  agent="quantum_chemistry_agent.sh"
elif echo "${text}" | grep -iqE 'finance|portfolio|optimization|risk|trading|market'; then
  agent="quantum_finance_agent.sh"
elif echo "${text}" | grep -iqE 'orchestrat|coordinat|resource|job|queue|schedul'; then
  agent="quantum_orchestrator_agent.sh"
elif echo "${text}" | grep -iqE 'learn|ml|machine learning|pattern|classif|cluster|ai|intelligence'; then
  agent="quantum_learning_agent.sh"
EOF

    success "Updated agent assignment system with quantum capabilities"
}

# Create quantum agent dashboard
create_quantum_dashboard() {
    log "Creating quantum agent dashboard"

    local dashboard_script="${SCRIPT_DIR}/quantum_agents_dashboard.sh"

    cat >"${dashboard_script}" <<'EOF'
#!/bin/bash
# Quantum Agents Dashboard - Monitor and control quantum-enhanced agents

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INTEGRATION_SCRIPT="${SCRIPT_DIR}/quantum_agent_integration.sh"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

header() {
    echo -e "${WHITE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║                      ⚛️  QUANTUM AGENTS DASHBOARD                           ║${NC}"
    echo -e "${WHITE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_menu() {
    echo -e "${CYAN}Available Commands:${NC}"
    echo "  1) Start all quantum agents"
    echo "  2) Stop all quantum agents"
    echo "  3) Show quantum agent status"
    echo "  4) Check quantum agent readiness"
    echo "  5) View quantum metrics summary"
    echo "  6) Exit"
    echo ""
}

show_metrics_summary() {
    echo -e "${BLUE}Quantum Metrics Summary:${NC}"
    echo ""

    # Chemistry metrics
    local chem_sims=$(find "${SCRIPT_DIR}/../../.quantum_metrics/simulations" -name "*.json" -mtime -1 2>/dev/null | wc -l | tr -d ' ' 2>/dev/null || echo "0")
    echo -e "🧪 Chemistry Simulations (24h): ${GREEN}${chem_sims}${NC}"

    # Finance metrics
    local finance_portfolios=$(find "${SCRIPT_DIR}/../../.quantum_finance_metrics/portfolios" -name "*.json" -mtime -1 2>/dev/null | wc -l | tr -d ' ' 2>/dev/null || echo "0")
    echo -e "💰 Finance Portfolios (24h): ${GREEN}${finance_portfolios}${NC}"

    # Orchestrator metrics
    local orchestrator_jobs=$(find "${SCRIPT_DIR}/../../.quantum_orchestrator/jobs" -name "*.json" -mtime -1 2>/dev/null | wc -l | tr -d ' ' 2>/dev/null || echo "0")
    echo -e "🎯 Orchestrator Jobs (24h): ${GREEN}${orchestrator_jobs}${NC}"

    # Learning metrics
    local learning_experiments=$(find "${SCRIPT_DIR}/../../.quantum_learning/experiments" -name "*.json" -mtime -1 2>/dev/null | wc -l | tr -d ' ' 2>/dev/null || echo "0")
    echo -e "🧠 Learning Experiments (24h): ${GREEN}${learning_experiments}${NC}"

    echo ""
}

main() {
    header

    while true; do
        show_menu
        read -p "Enter your choice (1-6): " choice
        echo ""

        case $choice in
            1)
                echo "Starting quantum agents..."
                "${INTEGRATION_SCRIPT}" start
                echo ""
                ;;
            2)
                echo "Stopping quantum agents..."
                "${INTEGRATION_SCRIPT}" stop
                echo ""
                ;;
            3)
                "${INTEGRATION_SCRIPT}" status
                echo ""
                ;;
            4)
                "${INTEGRATION_SCRIPT}" check
                echo ""
                ;;
            5)
                show_metrics_summary
                ;;
            6)
                echo "Goodbye!"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please enter 1-6.${NC}"
                echo ""
                ;;
        esac

        read -p "Press Enter to continue..."
        clear
        header
    done
}

main "$@"
EOF

    chmod +x "${dashboard_script}"
    success "Created quantum agents dashboard: ${dashboard_script}"
}

# Main integration function
main() {
    local command="${1:-help}"

    case "${command}" in
    "check")
        check_quantum_agents
        ;;
    "start")
        if check_quantum_agents; then
            start_quantum_agents
        fi
        ;;
    "stop")
        stop_quantum_agents
        ;;
    "status")
        get_quantum_agent_status
        ;;
    "assignments")
        update_agent_assignments
        ;;
    "dashboard")
        create_quantum_dashboard
        ;;
    "setup")
        quantum_log "Setting up quantum agent integration"
        update_agent_assignments
        create_quantum_dashboard
        success "Quantum agent integration setup complete"
        ;;
    "help" | *)
        cat <<EOF
Quantum Agent Integration System

Usage: $0 <command>

Commands:
  check       Check if all quantum agents are ready
  start       Start all quantum agents in background
  stop        Stop all quantum agents
  status      Show quantum agent status
  assignments Update agent assignment system with quantum capabilities
  dashboard   Create quantum agents dashboard
  setup       Complete setup (assignments + dashboard)
  help        Show this help
EOF
        ;;
    esac
}

main "$@"

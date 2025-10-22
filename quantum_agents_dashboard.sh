#!/bin/bash
# Quantum Agents Dashboard - Monitor and control quantum-enhanced agents

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INTEGRATION_SCRIPT="${SCRIPT_DIR}/quantum_agent_integration.sh"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
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
    local chem_sims
    chem_sims=$(find "${SCRIPT_DIR}/../../.quantum_metrics/simulations" -name "*.json" -mtime -1 2>/dev/null | wc -l | tr -d ' ' 2>/dev/null || echo "0")
    echo -e "🧪 Chemistry Simulations (24h): ${GREEN}${chem_sims}${NC}"

    # Finance metrics
    local finance_portfolios
    finance_portfolios=$(find "${SCRIPT_DIR}/../../.quantum_finance_metrics/portfolios" -name "*.json" -mtime -1 2>/dev/null | wc -l | tr -d ' ' 2>/dev/null || echo "0")
    echo -e "💰 Finance Portfolios (24h): ${GREEN}${finance_portfolios}${NC}"

    # Orchestrator metrics
    local orchestrator_jobs
    orchestrator_jobs=$(find "${SCRIPT_DIR}/../../.quantum_orchestrator/jobs" -name "*.json" -mtime -1 2>/dev/null | wc -l | tr -d ' ' 2>/dev/null || echo "0")
    echo -e "🎯 Orchestrator Jobs (24h): ${GREEN}${orchestrator_jobs}${NC}"

    # Learning metrics
    local learning_experiments
    learning_experiments=$(find "${SCRIPT_DIR}/../../.quantum_learning/experiments" -name "*.json" -mtime -1 2>/dev/null | wc -l | tr -d ' ' 2>/dev/null || echo "0")
    echo -e "🧠 Learning Experiments (24h): ${GREEN}${learning_experiments}${NC}"

    echo ""
}

main() {
    header

    while true; do
        show_menu
        read -r -p "Enter your choice (1-6): " choice
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

        read -r -p "Press Enter to continue..."
        clear
        header
    done
}

main "$@"

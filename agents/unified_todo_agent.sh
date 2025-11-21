#!/usr/bin/env bash

# Dynamic configuration discovery
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./agent_config_discovery.sh
if [[ -f "${SCRIPT_DIR}/agent_config_discovery.sh" ]]; then
    source "${SCRIPT_DIR}/agent_config_discovery.sh"
    WORKSPACE_ROOT=$(get_workspace_root)
    AGENTS_DIR=$(get_agents_dir)
    MCP_URL=$(get_mcp_url)
else
    echo "ERROR: agent_config_discovery.sh not found"
    exit 1
fi
# Unified Todo Management Agent
# Integrates with MCP and AI systems for comprehensive todo management

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_NAME="unified_todo_agent.sh"
LOG_FILE="${LOG_FILE:-$DIR/${AGENT_NAME}.log}"
PID=$$

# Source shared functions
if [[ -f "$DIR/shared_functions.sh" ]]; then
    source "$DIR/shared_functions.sh"
fi

if [[ -f "$DIR/agent_helpers.sh" ]]; then
    source "$DIR/agent_helpers.sh"
fi

set -euo pipefail

# Agent capabilities for todo management
declare -a AGENT_CAPABILITIES=(
    "todo_creation"
    "todo_analysis"
    "todo_assignment"
    "todo_execution"
    "todo_monitoring"
    "project_analysis"
    "security"
    "performance"
    "maintenance"
    "features"
    "high_priority"
)

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [TODO_AGENT] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [TODO_AGENT] ERROR: $*" >&2 | tee -a "$LOG_FILE"
}

# Health check
if [[ "${1-}" == "--health" || "${1-}" == "health" || "${1-}" == "-h" ]]; then
    if type agent_health_check >/dev/null 2>&1; then
        agent_health_check
        exit $?
    fi

    # Basic health checks
    issues=()
    if ! command -v python3 >/dev/null 2>&1; then
        issues+=("python3_not_available")
    fi
    if ! [[ -f "$DIR/../unified_todo_manager.py" ]]; then
        issues+=("todo_manager_missing")
    fi
    if ! [[ -f "$DIR/../mcp_todo_integration.py" ]]; then
        issues+=("mcp_integration_missing")
    fi

    if [[ ${#issues[@]} -gt 0 ]]; then
        printf '{"ok":false,"issues":["%s"]}\n' "${issues[*]}"
        exit 2
    fi

    printf '{"ok":true,"capabilities":["%s"]}\n' "${AGENT_CAPABILITIES[*]}"
    exit 0
fi

# Register agent capabilities
register_capabilities() {
    log_info "Registering agent capabilities..."

    # Register with MCP if available
    if [[ -f "$DIR/../mcp_server.py" ]]; then
        python3 -c "
import sys
sys.path.insert(0, '$DIR/..')
try:
    from mcp_todo_integration import todo_mcp
    # Agent capabilities are handled by the todo manager
    print('Capabilities registered with MCP')
except Exception as e:
    print(f'MCP registration failed: {e}')
"
    fi
}

# Analyze project and create todos
analyze_project() {
    log_info "Analyzing project for todo opportunities..."

    python3 -c "
import sys
sys.path.insert(0, '$DIR/..')
from mcp_todo_integration import handle_mcp_todo_request

request = {
    'action': 'analyze_project_todos',
    'params': {}
}

result = handle_mcp_todo_request(request)
print(f'Analysis complete: {result}')
"
}

# Process pending todos
process_todos() {
    log_info "Processing pending todos..."

    python3 -c "
import sys
sys.path.insert(0, '$DIR/..')
from unified_todo_manager import todo_manager, TodoStatus

# Get pending todos
pending_todos = todo_manager.get_todos(status=TodoStatus.PENDING)
print(f'Found {len(pending_todos)} pending todos')

for todo in pending_todos[:5]:  # Process up to 5 at a time
    print(f'Processing: {todo.title}')
    # Auto-assign if possible
    agent = todo_manager.assign_todo_to_agent(todo.id)
    if agent:
        print(f'Assigned to: {agent}')
    else:
        print('No suitable agent found')
"
}

# Monitor todo progress
monitor_progress() {
    log_info "Monitoring todo progress..."

    python3 -c "
import sys
sys.path.insert(0, '$DIR/..')
from unified_todo_manager import todo_manager

dashboard = todo_manager.get_dashboard_data()
print('Todo Dashboard:')
print(f'  Total: {dashboard[\"total_todos\"]}')
print(f'  Pending: {dashboard[\"by_status\"][\"pending\"]}')
print(f'  In Progress: {dashboard[\"by_status\"][\"in_progress\"]}')
print(f'  Completed: {dashboard[\"by_status\"][\"completed\"]}')
print(f'  Overdue: {dashboard[\"overdue\"]}')
"
}

# Execute high-priority todos
execute_critical_todos() {
    log_info "Executing critical todos..."

    python3 -c "
import sys
sys.path.insert(0, '$DIR/..')
from unified_todo_manager import todo_manager, TodoStatus, TodoPriority

# Get critical todos
critical_todos = todo_manager.get_todos(
    status=TodoStatus.IN_PROGRESS,
    priority=TodoPriority.CRITICAL
)

for todo in critical_todos:
    print(f'Executing critical todo: {todo.title}')
    # Attempt MCP execution
    success = todo_manager.execute_todo_via_mcp(todo.id)
    if success:
        print(f'Successfully executed: {todo.title}')
    else:
        print(f'Failed to execute: {todo.title}')
"
}

# Generate todo reports
generate_reports() {
    log_info "Generating todo reports..."

    REPORT_DIR="$DIR/../reports"
    mkdir -p "$REPORT_DIR"

    python3 -c "
import sys
import json
from datetime import datetime
sys.path.insert(0, '$DIR/..')
from unified_todo_manager import todo_manager

dashboard = todo_manager.get_dashboard_data()

report = {
    'generated_at': datetime.now().isoformat(),
    'summary': dashboard,
    'recommendations': []
}

# Add recommendations based on data
if dashboard['overdue'] > 0:
    report['recommendations'].append(f'Address {dashboard[\"overdue\"]} overdue todos immediately')

if dashboard['by_status']['pending'] > 10:
    report['recommendations'].append('High pending todo count - consider prioritization')

pending_security = dashboard['by_category'].get('security', 0)
if pending_security > 0:
    report['recommendations'].append(f'Address {pending_security} pending security todos')

with open('$DIR/../reports/todo_report_$(date +%Y%m%d_%H%M%S).json', 'w') as f:
    json.dump(report, f, indent=2)

print('Todo report generated')
"
}

# Main agent loop
main() {
    log_info "Starting Unified Todo Management Agent"

    # Register capabilities
    register_capabilities

    while true; do
        log_info "Starting todo management cycle..."

        # Analyze project for new todos
        analyze_project

        # Process pending todos
        process_todos

        # Execute critical todos
        execute_critical_todos

        # Monitor progress
        monitor_progress

        # Generate reports
        generate_reports

        log_info "Todo management cycle complete. Sleeping for 300 seconds..."
        sleep 300
    done
}

# Handle different commands
case "${1-}" in
"analyze")
    analyze_project
    ;;
"process")
    process_todos
    ;;
"monitor")
    monitor_progress
    ;;
"execute")
    execute_critical_todos
    ;;
"report")
    generate_reports
    ;;
"register")
    register_capabilities
    ;;
*)
    main
    ;;
esac

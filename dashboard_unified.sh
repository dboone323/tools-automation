#!/usr/bin/env bash
# Unified Dashboard for Tools Automation System
# Provides comprehensive monitoring, metrics, and alerting interface

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MONITORING_DIR="${PROJECT_ROOT}/monitoring"
DASHBOARD_PORT="${DASHBOARD_PORT:-8080}"
METRICS_PORT="${METRICS_PORT:-8080}"
GRAFANA_PORT="${GRAFANA_PORT:-3000}"
PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}"
UPTIME_KUMA_PORT="${UPTIME_KUMA_PORT:-3001}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

log_header() {
    echo -e "${PURPLE}=== $1 ===${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Get system information
get_system_info() {
    echo "System Information:"
    echo "=================="
    echo "OS: $(uname -s) $(uname -r)"
    echo "Hostname: $(hostname)"
    echo "CPU Cores: $(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 'Unknown')"
    echo "Total Memory: $(free -h 2>/dev/null | awk 'NR==2{printf "%.0fGB\n", $2}' || echo 'Unknown')"
    echo "Disk Usage: $(df -h "${PROJECT_ROOT}" 2>/dev/null | tail -1 | awk '{print $5}' || echo 'Unknown')"
    echo ""
}

# Check service status
check_service_status() {
    local service_name="$1"
    local port="$2"
    local endpoint="${3:-/health}"

    if curl -s -f "http://localhost:${port}${endpoint}" >/dev/null 2>&1; then
        echo -e "${GREEN}✅${NC} ${service_name} - RUNNING (Port ${port})"
        return 0
    else
        echo -e "${RED}❌${NC} ${service_name} - NOT RUNNING (Port ${port})"
        return 1
    fi
}

# Get agent metrics summary
get_agent_metrics() {
    echo "Agent Metrics Summary:"
    echo "======================"

    # Try to get data from metrics exporter first
    if curl -s "http://localhost:8080/slo" >/dev/null 2>&1; then
        local slo_data=$(curl -s "http://localhost:8080/slo")
        local agent_count=$(echo "$slo_data" | jq '.agents | length' 2>/dev/null || echo "0")
        local healthy_count=$(echo "$slo_data" | jq '[.agents[] | select(.health_score >= 0.8)] | length' 2>/dev/null || echo "0")

        echo "Total Agents: ${agent_count}"
        echo "Healthy Agents: ${healthy_count}"

        if [[ ${agent_count} -gt 0 ]]; then
            local health_percentage=$(((healthy_count * 100) / agent_count))
            echo "Health Score: ${health_percentage}%"
        fi

        # Show individual agent status
        echo ""
        echo "Agent Status:"
        echo "$slo_data" | jq -r '.agents | to_entries[] | "\(.key): health=\(.value.health_score | . * 100 | floor)%, status=\(.value.status), tasks_completed=\(.value.tasks_completed), tasks_failed=\(.value.tasks_failed)"' 2>/dev/null || echo "Unable to parse agent data"
    else
        # Fallback to JSON file
        if [[ -f "${PROJECT_ROOT}/agent_status.json" ]]; then
            local total_agents=$(jq '. | length' "${PROJECT_ROOT}/agent_status.json" 2>/dev/null || echo "0")
            local running_agents=$(jq '[.[] | select(.status == "running")] | length' "${PROJECT_ROOT}/agent_status.json" 2>/dev/null || echo "0")
            local total_tasks=$(jq '[.[] | .tasks_completed // 0] | add' "${PROJECT_ROOT}/agent_status.json" 2>/dev/null || echo "0")
            local failed_tasks=$(jq '[.[] | .tasks_failed // 0] | add' "${PROJECT_ROOT}/agent_status.json" 2>/dev/null || echo "0")

            echo "Total Agents: ${total_agents}"
            echo "Running Agents: ${running_agents}"
            echo "Total Tasks Completed: ${total_tasks}"
            echo "Total Tasks Failed: ${failed_tasks}"

            if [[ ${total_agents} -gt 0 ]]; then
                local success_rate=$(((total_tasks * 100) / (total_tasks + failed_tasks)))
                echo "Success Rate: ${success_rate}%"
            fi
        else
            echo "No agent status data available"
        fi
    fi
    echo ""
}

# Get monitoring stack status
get_monitoring_status() {
    echo "Monitoring Stack Status:"
    echo "========================"

    # Check Docker containers
    if command_exists docker && docker ps | grep -q "tools-automation"; then
        echo "Docker Monitoring Stack:"
        docker ps --filter "name=tools-automation" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
    fi

    # Check individual services
    check_service_status "Metrics Exporter" "${METRICS_PORT}" "/health"
    check_service_status "Agent Dashboard API" "3002" "/health"
    check_service_status "Prometheus" "${PROMETHEUS_PORT}" "/-/healthy"
    check_service_status "Grafana" "${GRAFANA_PORT}" "/api/health"
    check_service_status "Uptime Kuma" "${UPTIME_KUMA_PORT}"
    echo ""
}

# Get recent alerts
get_recent_alerts() {
    echo "Recent Alerts:"
    echo "=============="

    if [[ -d "${PROJECT_ROOT}/alerts" ]]; then
        local alert_count=$(find "${PROJECT_ROOT}/alerts" -name "*.json" -type f 2>/dev/null | wc -l)
        if [[ ${alert_count} -gt 0 ]]; then
            echo "Total alerts in last 24h: ${alert_count}"
            # Show last 5 alerts
            find "${PROJECT_ROOT}/alerts" -name "*.json" -type f -mtime -1 2>/dev/null |
                head -5 | while read -r alert_file; do
                local alert_data=$(cat "${alert_file}")
                local level=$(echo "${alert_data}" | jq -r '.level // "unknown"' 2>/dev/null || echo "unknown")
                local message=$(echo "${alert_data}" | jq -r '.message // "No message"' 2>/dev/null || echo "No message")
                local timestamp=$(echo "${alert_data}" | jq -r '.timestamp // "unknown"' 2>/dev/null || echo "unknown")
                echo "[${level}] ${timestamp}: ${message}"
            done
        else
            echo "No recent alerts"
        fi
    else
        echo "No alerts directory found"
    fi
    echo ""
}

# Get performance metrics
get_performance_metrics() {
    echo "Performance Metrics:"
    echo "===================="

    # Get metrics from Prometheus if available
    if curl -s "http://localhost:${PROMETHEUS_PORT}/api/v1/query?query=up" >/dev/null 2>&1; then
        echo "Prometheus is responding"

        # Get system metrics
        local cpu_usage=$(curl -s "http://localhost:${PROMETHEUS_PORT}/api/v1/query?query=100%20-%20(avg%20by%20(instance)%20(irate(node_cpu_seconds_total%7Bmode%3D%22idle%22%7D%5B5m%5D))%20*%20100)" |
            jq -r '.data.result[0].value[1] // "N/A"' 2>/dev/null || echo "N/A")

        local mem_usage=$(curl -s "http://localhost:${PROMETHEUS_PORT}/api/v1/query?query=100%20-%20((node_memory_MemAvailable_bytes%20%2F%20node_memory_MemTotal_bytes)%20*%20100)" |
            jq -r '.data.result[0].value[1] // "N/A"' 2>/dev/null || echo "N/A")

        echo "System CPU Usage: ${cpu_usage}%"
        echo "System Memory Usage: ${mem_usage}%"
    else
        echo "Prometheus not available"
    fi

    # Get agent-specific metrics
    if curl -s "http://localhost:${METRICS_PORT}/metrics" >/dev/null 2>&1; then
        local agent_count=$(curl -s "http://localhost:${METRICS_PORT}/metrics" | grep "system_agents_total" | awk '{print $2}' || echo "N/A")
        local tasks_queued=$(curl -s "http://localhost:${METRICS_PORT}/metrics" | grep "system_tasks_queued" | awk '{print $2}' || echo "N/A")

        echo "Monitored Agents: ${agent_count}"
        echo "Queued Tasks: ${tasks_queued}"
    fi
    echo ""
}

# Display SLO status
get_slo_status() {
    echo "Service Level Objectives (SLOs):"
    echo "==============================="

    if [[ -f "${PROJECT_ROOT}/alert_config.json" ]]; then
        local environment=$(jq -r '.custom_thresholds.current_environment // "development"' "${PROJECT_ROOT}/alert_config.json" 2>/dev/null || echo "development")

        echo "Current Environment: ${environment}"
        echo ""

        # Display SLO targets
        echo "SLO Targets for ${environment}:"
        jq -r ".custom_thresholds.environments.${environment} | to_entries[] | \"  \(.key): \(.value)\"" "${PROJECT_ROOT}/alert_config.json" 2>/dev/null || echo "  Unable to parse SLO targets"
    else
        echo "No SLO configuration found"
    fi
    echo ""
}

# Main dashboard display
show_dashboard() {
    clear
    log_header "Tools Automation Unified Dashboard"
    echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo ""

    get_system_info
    get_agent_metrics
    get_monitoring_status
    get_performance_metrics
    get_slo_status
    get_recent_alerts

    echo "Quick Actions:"
    echo "=============="
    echo "1. View detailed agent status"
    echo "2. Check monitoring stack logs"
    echo "3. View Grafana dashboards"
    echo "4. View Prometheus metrics"
    echo "5. Check alert configuration"
    echo "6. Run health checks"
    echo "7. View recent logs"
    echo "q. Quit"
    echo ""
}

# Interactive menu
interactive_menu() {
    while true; do
        show_dashboard

        read -p "Select option (1-7, q to quit): " choice
        echo ""

        case $choice in
        1)
            log_header "Detailed Agent Status"
            if [[ -f "${PROJECT_ROOT}/agent_status.json" ]]; then
                jq '.' "${PROJECT_ROOT}/agent_status.json" | cat
            else
                echo "No agent status file found"
            fi
            echo ""
            read -p "Press Enter to continue..."
            ;;
        2)
            log_header "Monitoring Stack Logs"
            echo "Checking Docker container logs..."
            if command_exists docker; then
                docker ps --filter "name=tools-automation" --format "{{.Names}}" | while read -r container; do
                    echo "Logs for ${container}:"
                    docker logs --tail 20 "${container}" 2>/dev/null || echo "No logs available"
                    echo "---"
                done
            else
                echo "Docker not available"
            fi
            echo ""
            read -p "Press Enter to continue..."
            ;;
        3)
            log_header "Grafana Dashboards"
            echo "Grafana URL: http://localhost:${GRAFANA_PORT}"
            echo "Default credentials: admin / admin"
            if command_exists open; then
                open "http://localhost:${GRAFANA_PORT}"
            elif command_exists xdg-open; then
                xdg-open "http://localhost:${GRAFANA_PORT}"
            fi
            echo ""
            read -p "Press Enter to continue..."
            ;;
        4)
            log_header "Prometheus Metrics"
            echo "Prometheus URL: http://localhost:${PROMETHEUS_PORT}"
            if command_exists open; then
                open "http://localhost:${PROMETHEUS_PORT}"
            elif command_exists xdg-open; then
                xdg-open "http://localhost:${PROMETHEUS_PORT}"
            fi
            echo ""
            read -p "Press Enter to continue..."
            ;;
        5)
            log_header "Alert Configuration"
            if [[ -f "${PROJECT_ROOT}/alert_config.json" ]]; then
                jq '.' "${PROJECT_ROOT}/alert_config.json" | cat
            else
                echo "No alert configuration found"
            fi
            echo ""
            read -p "Press Enter to continue..."
            ;;
        6)
            log_header "Health Checks"
            echo "Running comprehensive health checks..."
            if [[ -f "${PROJECT_ROOT}/smoke_tests.sh" ]]; then
                bash "${PROJECT_ROOT}/smoke_tests.sh"
            else
                echo "Smoke tests script not found"
            fi
            echo ""
            read -p "Press Enter to continue..."
            ;;
        7)
            log_header "Recent Logs"
            echo "Showing recent monitoring logs..."
            if [[ -f "${PROJECT_ROOT}/monitoring/monitoring.log" ]]; then
                tail -50 "${PROJECT_ROOT}/monitoring/monitoring.log"
            else
                echo "No monitoring logs found"
            fi
            echo ""
            read -p "Press Enter to continue..."
            ;;
        q | Q)
            log_info "Exiting dashboard..."
            exit 0
            ;;
        *)
            log_warning "Invalid option. Please select 1-7 or q to quit."
            sleep 2
            ;;
        esac
    done
}

# Main function
main() {
    local mode="${1:-interactive}"

    case $mode in
    status)
        get_system_info
        get_agent_metrics
        get_monitoring_status
        ;;
    metrics)
        get_performance_metrics
        ;;
    alerts)
        get_recent_alerts
        ;;
    health)
        check_service_status "Metrics Exporter" "${METRICS_PORT}" "/health"
        check_service_status "Agent Dashboard API" "3002" "/health"
        check_service_status "Prometheus" "${PROMETHEUS_PORT}" "/-/healthy"
        check_service_status "Grafana" "${GRAFANA_PORT}" "/api/health"
        ;;
    interactive | *)
        interactive_menu
        ;;
    esac
}

# Run main function with all arguments
main "$@"

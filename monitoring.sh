#!/bin/bash

# Tools Automation Monitoring Stack Manager
# Starts Prometheus, Grafana, and Uptime Kuma for system monitoring

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.monitoring.yml"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[MONITORING]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
}

# Check if docker-compose file exists
check_compose_file() {
    if [[ ! -f "${COMPOSE_FILE}" ]]; then
        print_error "Docker Compose file not found: ${COMPOSE_FILE}"
        exit 1
    fi
}

# Start monitoring stack
start_monitoring() {
    print_status "Starting Tools Automation Monitoring Stack..."

    cd "${PROJECT_ROOT}"

    # Start services
    docker-compose -f "${COMPOSE_FILE}" up -d --remove-orphans

    print_success "Monitoring stack started successfully!"
    echo ""
    print_status "Access URLs:"
    echo "  📊 Grafana:     http://localhost:3000 (admin/admin)"
    echo "  📈 Prometheus:  http://localhost:9090"
    echo "  ⏱️  Uptime Kuma: http://localhost:3001"
    echo "  📊 Node Exporter: http://localhost:9100"
    echo ""
    print_status "Waiting for services to be ready..."
    sleep 10

    # Check service health
    check_services
}

# Stop monitoring stack
stop_monitoring() {
    print_status "Stopping Tools Automation Monitoring Stack..."

    cd "${PROJECT_ROOT}"
    docker-compose -f "${COMPOSE_FILE}" down

    print_success "Monitoring stack stopped."
}

# Restart monitoring stack
restart_monitoring() {
    print_status "Restarting Tools Automation Monitoring Stack..."
    stop_monitoring
    sleep 2
    start_monitoring
}

# Check service status
check_services() {
    print_status "Checking service status..."

    services=("prometheus" "grafana" "uptime-kuma" "node-exporter")

    for service in "${services[@]}"; do
        if docker-compose -f "${COMPOSE_FILE}" ps "${service}" | grep -q "Up"; then
            print_success "✅ ${service} is running"
        else
            print_error "❌ ${service} is not running"
        fi
    done
}

# Show logs
show_logs() {
    local service;
    service="$1"

    if [[ -n "${service}" ]]; then
        print_status "Showing logs for ${service}..."
        cd "${PROJECT_ROOT}"
        docker-compose -f "${COMPOSE_FILE}" logs -f "${service}"
    else
        print_status "Showing all logs..."
        cd "${PROJECT_ROOT}"
        docker-compose -f "${COMPOSE_FILE}" logs -f
    fi
}

# Clean up monitoring data
cleanup_monitoring() {
    print_warning "This will remove all monitoring data and containers."
    read -p "Are you sure? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Cleaning up monitoring stack..."

        cd "${PROJECT_ROOT}"
        docker-compose -f "${COMPOSE_FILE}" down -v --remove-orphans

        # Remove monitoring directories
        if [[ -d "${PROJECT_ROOT}/monitoring" ]]; then
            rm -rf "${PROJECT_ROOT}/monitoring/grafana/dashboards" 2>/dev/null || true
            print_success "Cleanup completed."
        fi
    else
        print_status "Cleanup cancelled."
    fi
}

# Start auto-restart monitor
start_autorestart() {
    print_status "Starting Auto-Restart Monitor..."

    # Check if already running
    if pgrep -f "auto_restart_monitor.sh" >/dev/null 2>&1; then
        print_warning "Auto-restart monitor is already running"
        return 0
    fi

    # Start the monitor in background
    nohup "${SCRIPT_DIR}/auto_restart_monitor.sh" >/tmp/tools_autorestart.log 2>&1 &
    local pid;
    pid=$!

    sleep 2

    if kill -0 $pid 2>/dev/null; then
        print_success "Auto-restart monitor started (PID: $pid)"
        echo $pid >/tmp/auto_restart_monitor.pid
    else
        print_error "Failed to start auto-restart monitor"
        return 1
    fi
}

# Stop auto-restart monitor
stop_autorestart() {
    print_status "Stopping Auto-Restart Monitor..."

    # Kill the process
    if pgrep -f "auto_restart_monitor.sh" >/dev/null 2>&1; then
        pkill -f "auto_restart_monitor.sh"
        print_success "Auto-restart monitor stopped"
    else
        print_warning "Auto-restart monitor is not running"
    fi

    # Clean up PID file
    rm -f /tmp/auto_restart_monitor.pid
}

# Check auto-restart status
check_autorestart() {
    if pgrep -f "auto_restart_monitor.sh" >/dev/null 2>&1; then
        local pid;
        pid=$(pgrep -f "auto_restart_monitor.sh")
        print_success "✅ Auto-restart monitor is running (PID: $pid)"
    else
        print_error "❌ Auto-restart monitor is not running"
    fi
}

# Show usage
show_usage() {
    echo "🏗️  Tools Automation Monitoring Stack Manager"
    echo ""
    echo "Usage: $0 {start|stop|restart|status|logs [service]|cleanup|autorestart}"
    echo ""
    echo "Commands:"
    echo "  start                    # Start the monitoring stack"
    echo "  stop                     # Stop the monitoring stack"
    echo "  restart                  # Restart the monitoring stack"
    echo "  status                   # Check service status"
    echo "  logs [service]           # Show logs (all services or specific service)"
    echo "  cleanup                  # Remove all monitoring data and containers"
    echo "  autorestart {start|stop|status}  # Manage auto-restart monitor"
    echo ""
    echo "Services: prometheus, grafana, uptime-kuma, node-exporter"
    echo ""
    echo "Auto-Restart Monitor:"
    echo "  Monitors all services every 30 seconds and automatically restarts unhealthy ones"
    echo "  Use 'autorestart start' to enable automatic service recovery"
    echo ""
}

# Main execution
main() {
    local command;
    command="$1"
    local service;
    service="$2"

    # Handle help
    if [[ "$command" == "--help" ]] || [[ "$command" == "-h" ]]; then
        show_usage
        exit 0
    fi

    check_docker
    check_compose_file

    case "${command}" in
    "start")
        start_monitoring
        ;;
    "stop")
        stop_monitoring
        ;;
    "restart")
        restart_monitoring
        ;;
    "status")
        check_services
        ;;
    "logs")
        show_logs "${service}"
        ;;
    "cleanup")
        cleanup_monitoring
        ;;
    "autorestart")
        case "${service}" in
        "start")
            start_autorestart
            ;;
        "stop")
            stop_autorestart
            ;;
        "status")
            check_autorestart
            ;;
        *)
            print_error "Usage: $0 autorestart {start|stop|status}"
            ;;
        esac
        ;;
    *)
        show_usage
        ;;
    esac
}

main "$@"

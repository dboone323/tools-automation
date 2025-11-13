#!/usr/bin/env bash
# Start Monitoring Stack for Tools Automation
# Launches Docker Compose monitoring stack and local services

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}" && pwd)"
MONITORING_DIR="${PROJECT_ROOT}/monitoring"
COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.monitoring.yml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Check if Docker is available
check_docker() {
    if ! command -v docker &>/dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi

    if ! command -v docker-compose &>/dev/null; then
        log_error "Docker Compose is not installed or not in PATH"
        exit 1
    fi

    log_info "Docker and Docker Compose are available"
}

# Start Docker monitoring stack
start_monitoring_stack() {
    log_info "Starting Docker monitoring stack..."

    cd "${PROJECT_ROOT}"

    if [[ -f "${COMPOSE_FILE}" ]]; then
        docker-compose -f "${COMPOSE_FILE}" up -d

        # Wait for services to be healthy
        log_info "Waiting for monitoring services to start..."
        sleep 10

        # Check service health
        check_service_health "prometheus" "9090"
        check_service_health "grafana" "3000"
        check_service_health "uptime-kuma" "3001"
        check_service_health "node-exporter" "9100"

        log_success "Docker monitoring stack started successfully"
    else
        log_error "Docker Compose file not found: ${COMPOSE_FILE}"
        exit 1
    fi
}

# Check if a service is healthy
check_service_health() {
    local service_name="$1"
    local port="$2"
    local max_attempts=30
    local attempt=1

    log_info "Checking ${service_name} health on port ${port}..."

    while [[ ${attempt} -le ${max_attempts} ]]; do
        if curl -s -f "http://localhost:${port}/" >/dev/null 2>&1; then
            log_success "${service_name} is healthy"
            return 0
        fi

        log_info "Waiting for ${service_name} to be healthy (attempt ${attempt}/${max_attempts})..."
        sleep 2
        ((attempt++))
    done

    log_warning "${service_name} health check failed after ${max_attempts} attempts"
    return 1
}

# Start local metrics exporter
start_metrics_exporter() {
    log_info "Starting metrics exporter..."

    # Check if already running
    if pgrep -f "metrics_exporter.py" >/dev/null; then
        log_warning "Metrics exporter is already running"
        return 0
    fi

    # Start in background
    cd "${PROJECT_ROOT}"
    if [[ -f ".venv/bin/activate" ]]; then
        nohup bash -c "source .venv/bin/activate && python3 metrics_exporter.py" >"${MONITORING_DIR}/metrics_exporter.log" 2>&1 &
    else
        nohup python3 metrics_exporter.py >"${MONITORING_DIR}/metrics_exporter.log" 2>&1 &
    fi
    local pid=$!

    log_info "Metrics exporter started with PID: ${pid}"

    # Wait for it to be ready
    local max_attempts=10
    local attempt=1
    while [[ ${attempt} -le ${max_attempts} ]]; do
        if curl -s -f "http://localhost:8080/health" >/dev/null 2>&1; then
            log_success "Metrics exporter is healthy"
            return 0
        fi
        sleep 2
        ((attempt++))
    done

    log_error "Metrics exporter failed to start properly"
    return 1
}

# Start agent monitoring
start_agent_monitoring() {
    log_info "Starting agent monitoring..."

    if [[ -f "${PROJECT_ROOT}/agent_monitoring.sh" ]]; then
        # Start background monitoring
        nohup "${PROJECT_ROOT}/agent_monitoring.sh" >"${MONITORING_DIR}/agent_monitoring.log" 2>&1 &
        log_success "Agent monitoring started in background"
    else
        log_warning "Agent monitoring script not found"
    fi
}

# Display access information
display_access_info() {
    echo ""
    log_success "Monitoring stack is running!"
    echo ""
    echo "Access URLs:"
    echo "============"
    echo "📊 Grafana:           http://localhost:3000 (admin/admin)"
    echo "📈 Prometheus:        http://localhost:9090"
    echo "⏱️  Uptime Kuma:       http://localhost:3001"
    echo "📏 Metrics Exporter:  http://localhost:8080/metrics"
    echo "🎛️  Unified Dashboard: ${PROJECT_ROOT}/dashboard_unified.sh"
    echo ""
    echo "Available dashboards:"
    echo "- System Overview"
    echo "- Agent Performance & SLO Dashboard"
    echo "- Service Level Objectives (SLO) Dashboard"
    echo ""
    echo "To stop monitoring: docker-compose -f ${COMPOSE_FILE} down"
    echo "To view logs: docker-compose -f ${COMPOSE_FILE} logs -f"
}

# Stop monitoring stack
stop_monitoring() {
    log_info "Stopping monitoring stack..."

    cd "${PROJECT_ROOT}"

    # Stop Docker services
    if [[ -f "${COMPOSE_FILE}" ]]; then
        docker-compose -f "${COMPOSE_FILE}" down
        log_success "Docker monitoring stack stopped"
    fi

    # Stop local services
    if pgrep -f "metrics_exporter.py" >/dev/null; then
        pkill -f "metrics_exporter.py"
        log_success "Metrics exporter stopped"
    fi

    if pgrep -f "agent_monitoring.sh" >/dev/null; then
        pkill -f "agent_monitoring.sh"
        log_success "Agent monitoring stopped"
    fi
}

# Main function
main() {
    local action="${1:-start}"

    case "${action}" in
    start)
        log_info "Starting Tools Automation monitoring stack..."
        check_docker
        start_monitoring_stack
        start_metrics_exporter
        start_agent_monitoring
        display_access_info
        ;;
    stop)
        stop_monitoring
        ;;
    restart)
        stop_monitoring
        sleep 2
        main start
        ;;
    status)
        echo "Monitoring Stack Status:"
        echo "========================"

        # Check Docker containers
        if command -v docker &>/dev/null && docker ps | grep -q "tools-automation"; then
            echo "Docker Services:"
            docker ps --filter "name=tools-automation" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
            echo ""
        fi

        # Check local services
        if pgrep -f "metrics_exporter.py" >/dev/null; then
            echo "✅ Metrics Exporter - RUNNING"
        else
            echo "❌ Metrics Exporter - NOT RUNNING"
        fi

        if pgrep -f "agent_monitoring.sh" >/dev/null; then
            echo "✅ Agent Monitoring - RUNNING"
        else
            echo "❌ Agent Monitoring - NOT RUNNING"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        echo ""
        echo "Commands:"
        echo "  start   - Start the monitoring stack"
        echo "  stop    - Stop the monitoring stack"
        echo "  restart - Restart the monitoring stack"
        echo "  status  - Show status of monitoring services"
        exit 1
        ;;
    esac
}

main "$@"

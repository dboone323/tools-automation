#!/bin/bash

# Unified startup script for all tools automation services
# This script manages both monitoring and quality tool stacks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="tools-automation"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to check if a service is healthy
check_service_health() {
    local service_name=$1
    local max_attempts=30
    local attempt=1

    log_info "Checking health of $service_name..."

    while [ $attempt -le $max_attempts ]; do
        if docker ps --filter "name=$service_name" --filter "health=healthy" --format "{{.Names}}" | grep -q "$service_name"; then
            log_success "$service_name is healthy"
            return 0
        fi

        log_info "Waiting for $service_name to be healthy (attempt $attempt/$max_attempts)..."
        sleep 10
        ((attempt++))
    done

    log_error "$service_name failed to become healthy within $(($max_attempts * 10)) seconds"
    return 1
}

# Function to start monitoring stack
start_monitoring() {
    log_info "Starting Tools Automation Monitoring Stack..."

    cd "$SCRIPT_DIR"
    docker-compose -f docker-compose.monitoring.yml -p "${PROJECT_NAME}-monitoring" up -d

    if [ $? -eq 0 ]; then
        log_success "Monitoring stack started successfully!"
        log_info "Access URLs:"
        log_info "  📊 Prometheus: http://localhost:9090"
        log_info "  📈 Grafana: http://localhost:3000 (admin/admin)"
        log_info "  ⏱️  Uptime Kuma: http://localhost:3001"
        log_info "  📊 Node Exporter: http://localhost:9100"

        # Check health of monitoring services
        check_service_health "${PROJECT_NAME}-monitoring-prometheus-1" || true
        check_service_health "${PROJECT_NAME}-monitoring-grafana-1" || true
        check_service_health "${PROJECT_NAME}-monitoring-uptime-kuma-1" || true
        check_service_health "${PROJECT_NAME}-monitoring-node-exporter-1" || true
    else
        log_error "Failed to start monitoring stack"
        return 1
    fi
}

# Function to start quality stack
start_quality() {
    log_info "Starting Tools Automation Quality Tools Stack..."

    cd "$SCRIPT_DIR"
    docker-compose -f docker-compose.quality.yml -p "${PROJECT_NAME}-quality" up -d

    if [ $? -eq 0 ]; then
        log_success "Quality tools stack started successfully!"
        log_info "Access URLs:"
        log_info "  📊 SonarQube: http://localhost:9000 (admin/admin)"

        log_warning "SonarQube may take 2-3 minutes to fully initialize on first startup."

        # Check health of quality services
        check_service_health "${PROJECT_NAME}-quality-db-1" || true
        check_service_health "${PROJECT_NAME}-quality-sonarqube-1" || true
    else
        log_error "Failed to start quality tools stack"
        return 1
    fi
}

# Function to stop all services
stop_all() {
    log_info "Stopping all Tools Automation services..."

    cd "$SCRIPT_DIR"

    # Stop monitoring stack
    docker-compose -f docker-compose.monitoring.yml -p "${PROJECT_NAME}-monitoring" down || true

    # Stop quality stack
    docker-compose -f docker-compose.quality.yml -p "${PROJECT_NAME}-quality" down || true

    log_success "All services stopped"
}

# Function to show status
show_status() {
    log_info "Tools Automation Services Status:"

    echo ""
    echo "Monitoring Stack:"
    docker-compose -f docker-compose.monitoring.yml -p "${PROJECT_NAME}-monitoring" ps

    echo ""
    echo "Quality Tools Stack:"
    docker-compose -f docker-compose.quality.yml -p "${PROJECT_NAME}-quality" ps

    echo ""
    echo "Auto-restart Monitor:"
    if pgrep -f "auto_restart_monitor.sh" >/dev/null; then
        log_success "Auto-restart monitor is running"
        ps aux | grep "auto_restart_monitor.sh" | grep -v grep
    else
        log_warning "Auto-restart monitor is not running"
    fi
}

# Main script logic
case "${1:-start}" in
"start")
    log_info "Starting all Tools Automation services..."
    start_monitoring
    start_quality
    log_success "All services started! Use './unified.sh status' to check status."
    ;;
"monitoring")
    start_monitoring
    ;;
"quality")
    start_quality
    ;;
"stop")
    stop_all
    ;;
"restart")
    log_info "Restarting all services..."
    stop_all
    sleep 5
    start_monitoring
    start_quality
    ;;
"status")
    show_status
    ;;
"logs")
    case "${2:-all}" in
    "monitoring")
        docker-compose -f docker-compose.monitoring.yml -p "${PROJECT_NAME}-monitoring" logs -f
        ;;
    "quality")
        docker-compose -f docker-compose.quality.yml -p "${PROJECT_NAME}-quality" logs -f
        ;;
    "all" | *)
        log_info "Showing logs for all services (Ctrl+C to exit):"
        docker-compose -f docker-compose.monitoring.yml -p "${PROJECT_NAME}-monitoring" logs -f &
        MONITORING_PID=$!
        docker-compose -f docker-compose.quality.yml -p "${PROJECT_NAME}-quality" logs -f &
        QUALITY_PID=$!
        trap "kill $MONITORING_PID $QUALITY_PID 2>/dev/null" EXIT
        wait
        ;;
    esac
    ;;
*)
    echo "Usage: $0 {start|monitoring|quality|stop|restart|status|logs [monitoring|quality|all]}"
    echo ""
    echo "Commands:"
    echo "  start      - Start all services (monitoring + quality)"
    echo "  monitoring - Start only monitoring stack"
    echo "  quality    - Start only quality tools stack"
    echo "  stop       - Stop all services"
    echo "  restart    - Restart all services"
    echo "  status     - Show status of all services"
    echo "  logs       - Show logs (optionally specify stack: monitoring/quality/all)"
    exit 1
    ;;
esac

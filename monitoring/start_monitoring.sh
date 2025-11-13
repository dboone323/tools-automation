#!/bin/bash
# System Health Monitoring Startup Script
# Initializes and starts all monitoring components

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Check if Python is available
check_python() {
    if ! command -v python3 &>/dev/null; then
        log_error "Python 3 is required but not found"
        exit 1
    fi

    # Check for required Python packages
    python3 -c "import flask, flask_cors, sklearn, numpy" 2>/dev/null || {
        log_warning "Installing required Python packages..."
        pip3 install flask flask-cors scikit-learn numpy requests
    }
}

# Initialize monitoring system
initialize_system() {
    log_info "Initializing system health monitoring..."

    # Create necessary directories
    mkdir -p "$SCRIPT_DIR/metrics"
    mkdir -p "$SCRIPT_DIR/alerts"
    mkdir -p "$SCRIPT_DIR/reports"
    mkdir -p "$SCRIPT_DIR/dashboard"
    mkdir -p "$SCRIPT_DIR/predictions"

    # Check configuration
    if [ ! -f "$SCRIPT_DIR/config.json" ]; then
        log_warning "Configuration file not found. Using defaults."
    fi

    log_success "System initialized"
}

# Start monitoring daemon
start_daemon() {
    log_info "Starting monitoring daemon..."

    # Check if already running
    if [ -f "$SCRIPT_DIR/monitoring.pid" ]; then
        if kill -0 "$(cat "$SCRIPT_DIR/monitoring.pid")" 2>/dev/null; then
            log_warning "Monitoring daemon already running (PID: $(cat "$SCRIPT_DIR/monitoring.pid"))"
            return
        else
            rm -f "$SCRIPT_DIR/monitoring.pid"
        fi
    fi

    # Start daemon in background
    nohup "$SCRIPT_DIR/health_monitor.sh" start >"$SCRIPT_DIR/monitoring.log" 2>&1 &
    echo $! >"$SCRIPT_DIR/monitoring.pid"

    log_success "Monitoring daemon started (PID: $(cat "$SCRIPT_DIR/monitoring.pid"))"
}

# Start API server
start_api_server() {
    log_info "Starting monitoring API server..."

    # Check if port is available
    if lsof -Pi :8081 -sTCP:LISTEN -t >/dev/null 2>&1; then
        log_warning "Port 8081 already in use"
        return
    fi

    # Start API server in background
    nohup python3 "$SCRIPT_DIR/monitoring_api.py" >"$SCRIPT_DIR/api.log" 2>&1 &
    echo $! >"$SCRIPT_DIR/api.pid"

    # Wait for server to start
    sleep 3

    # Check if server started successfully
    if kill -0 "$(cat "$SCRIPT_DIR/api.pid")" 2>/dev/null; then
        log_success "API server started on port 8081 (PID: $(cat "$SCRIPT_DIR/api.pid"))"
    else
        log_error "Failed to start API server"
        rm -f "$SCRIPT_DIR/api.pid"
        return 1
    fi
}

# Generate initial baselines
generate_baselines() {
    log_info "Generating initial performance baselines..."

    # Run baseline generation
    if "$SCRIPT_DIR/health_monitor.sh" baseline; then
        log_success "Baselines generated successfully"
    else
        log_warning "Baseline generation failed - will retry with more data"
    fi
}

# Create monitoring dashboard
create_dashboard() {
    log_info "Creating monitoring dashboard..."

    if "$SCRIPT_DIR/health_monitor.sh" dashboard; then
        log_success "Dashboard created successfully"
    else
        log_error "Failed to create dashboard"
        return 1
    fi
}

# Schedule automated tasks
schedule_tasks() {
    log_info "Setting up automated tasks..."

    # Create cron jobs for automated reporting
    CRON_JOBS="
# System Health Monitoring - Daily Report
0 6 * * * $SCRIPT_DIR/health_reporter.py send

# System Health Monitoring - Weekly Maintenance Analysis
0 7 * * 1 python3 $SCRIPT_DIR/predictive_maintenance.py analyze

# System Health Monitoring - Performance Regression Check
0 8 * * * python3 $SCRIPT_DIR/performance_regression.py analyze

# System Health Monitoring - Cleanup Old Data
0 2 * * * $SCRIPT_DIR/health_monitor.sh cleanup
"

    # Add to crontab if not already present
    if ! crontab -l 2>/dev/null | grep -q "System Health Monitoring"; then
        (
            crontab -l 2>/dev/null
            echo "$CRON_JOBS"
        ) | crontab -
        log_success "Automated tasks scheduled"
    else
        log_info "Automated tasks already scheduled"
    fi
}

# Start all monitoring components
start_all() {
    log_info "Starting complete system health monitoring suite..."

    check_python
    initialize_system

    # Start components
    start_daemon
    start_api_server
    create_dashboard
    generate_baselines
    schedule_tasks

    log_success "All monitoring components started successfully"
    echo ""
    echo "=== System Health Monitoring Status ==="
    echo "📊 Dashboard: http://localhost:8081"
    echo "🔧 API Endpoint: http://localhost:8081/api/health"
    echo "📋 Logs: $SCRIPT_DIR/*.log"
    echo "⚙️  Config: $SCRIPT_DIR/config.json"
    echo ""
    echo "Commands:"
    echo "  Status: $SCRIPT_DIR/health_monitor.sh status"
    echo "  Stop: $SCRIPT_DIR/stop_monitoring.sh"
    echo "  Reports: View $SCRIPT_DIR/reports/"
}

# Stop all monitoring components
stop_all() {
    log_info "Stopping all monitoring components..."

    # Stop daemon
    if [ -f "$SCRIPT_DIR/monitoring.pid" ]; then
        "$SCRIPT_DIR/health_monitor.sh" stop
    fi

    # Stop API server
    if [ -f "$SCRIPT_DIR/api.pid" ]; then
        if kill -0 "$(cat "$SCRIPT_DIR/api.pid")" 2>/dev/null; then
            kill "$(cat "$SCRIPT_DIR/api.pid")"
            log_success "API server stopped"
        fi
        rm -f "$SCRIPT_DIR/api.pid"
    fi

    log_success "All monitoring components stopped"
}

# Show status
show_status() {
    echo "=== System Health Monitoring Status ==="
    echo ""

    # Check daemon
    if [ -f "$SCRIPT_DIR/monitoring.pid" ] && kill -0 "$(cat "$SCRIPT_DIR/monitoring.pid")" 2>/dev/null; then
        echo "✅ Monitoring Daemon: RUNNING (PID: $(cat "$SCRIPT_DIR/monitoring.pid"))"
    else
        echo "❌ Monitoring Daemon: STOPPED"
    fi

    # Check API server
    if [ -f "$SCRIPT_DIR/api.pid" ] && kill -0 "$(cat "$SCRIPT_DIR/api.pid")" 2>/dev/null; then
        echo "✅ API Server: RUNNING (PID: $(cat "$SCRIPT_DIR/api.pid")) - http://localhost:8081"
    else
        echo "❌ API Server: STOPPED"
    fi

    echo ""

    # Show recent activity
    if [ -f "$SCRIPT_DIR/monitoring.log" ]; then
        echo "📊 Recent Activity:"
        tail -5 "$SCRIPT_DIR/monitoring.log" | while read -r line; do
            echo "  $line"
        done
    fi

    echo ""

    # Show data summary
    metrics_count=$(find "$SCRIPT_DIR/metrics" -name "*.json" 2>/dev/null | wc -l)
    alerts_count=$(find "$SCRIPT_DIR/alerts" -name "*.json" 2>/dev/null | wc -l)
    reports_count=$(find "$SCRIPT_DIR/reports" -name "*.md" 2>/dev/null | wc -l)

    echo "📈 Data Summary:"
    echo "  Metrics: $metrics_count files"
    echo "  Alerts: $alerts_count files"
    echo "  Reports: $reports_count files"
}

# Cleanup old data
cleanup_data() {
    log_info "Cleaning up old monitoring data..."

    # Default retention periods (days)
    METRICS_RETENTION=${METRICS_RETENTION:-30}
    ALERTS_RETENTION=${ALERTS_RETENTION:-7}
    REPORTS_RETENTION=${REPORTS_RETENTION:-90}

    # Cleanup metrics
    find "$SCRIPT_DIR/metrics" -name "*.json" -mtime +$METRICS_RETENTION -delete 2>/dev/null || true

    # Cleanup alerts
    find "$SCRIPT_DIR/alerts" -name "*.json" -mtime +$ALERTS_RETENTION -delete 2>/dev/null || true

    # Cleanup reports
    find "$SCRIPT_DIR/reports" -name "*.md" -mtime +$REPORTS_RETENTION -delete 2>/dev/null || true
    find "$SCRIPT_DIR/reports" -name "*.json" -mtime +$REPORTS_RETENTION -delete 2>/dev/null || true

    log_success "Old data cleaned up"
}

# Main function
main() {
    local command="$1"
    shift

    case "$command" in
    "start")
        start_all
        ;;
    "stop")
        stop_all
        ;;
    "restart")
        stop_all
        sleep 2
        start_all
        ;;
    "status")
        show_status
        ;;
    "cleanup")
        cleanup_data
        ;;
    "init")
        check_python
        initialize_system
        create_dashboard
        ;;
    "baseline")
        generate_baselines
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|cleanup|init|baseline}"
        echo ""
        echo "Commands:"
        echo "  start    - Start all monitoring components"
        echo "  stop     - Stop all monitoring components"
        echo "  restart  - Restart all monitoring components"
        echo "  status   - Show monitoring status"
        echo "  cleanup  - Clean up old monitoring data"
        echo "  init     - Initialize monitoring system"
        echo "  baseline - Generate performance baselines"
        exit 1
        ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

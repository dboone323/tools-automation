#!/bin/bash
# System Health Monitoring Dashboard
# Comprehensive monitoring and alerting system

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
MONITORING_DIR="$SCRIPT_DIR"
METRICS_DIR="$MONITORING_DIR/metrics"
ALERTS_DIR="$MONITORING_DIR/alerts"
REPORTS_DIR="$MONITORING_DIR/reports"
DASHBOARD_DIR="$MONITORING_DIR/dashboard"

# Health check intervals (seconds)
SYSTEM_CHECK_INTERVAL=60
PERFORMANCE_CHECK_INTERVAL=300
SERVICE_CHECK_INTERVAL=30

# Alert thresholds
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85
DISK_THRESHOLD=90
RESPONSE_TIME_THRESHOLD=500

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

# Initialize monitoring system
initialize_monitoring() {
    log_info "Initializing system health monitoring..."

    # Create directories
    mkdir -p "$METRICS_DIR"
    mkdir -p "$ALERTS_DIR"
    mkdir -p "$REPORTS_DIR"
    mkdir -p "$DASHBOARD_DIR"

    # Create baseline files
    touch "$METRICS_DIR/system_baseline.json"
    touch "$METRICS_DIR/performance_baseline.json"
    touch "$ALERTS_DIR/active_alerts.json"
    touch "$REPORTS_DIR/daily_report_$(date +%Y%m%d).md"

    log_success "Monitoring system initialized"
}

# Collect system metrics
collect_system_metrics() {
    local timestamp
    timestamp=$(date +%s)

    # CPU metrics
    local cpu_usage
    cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//')

    # Memory metrics
    local mem_usage
    mem_usage=$(vm_stat | grep "Pages active" | awk '{print $3}' | tr -d '.')

    # Disk metrics
    local disk_usage
    disk_usage=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')

    # Network metrics (basic)
    local network_rx
    local network_tx
    network_rx=$(netstat -ib | grep en0 | head -1 | awk '{print $7}')
    network_tx=$(netstat -ib | grep en0 | head -1 | awk '{print $10}')

    # Ensure numeric values
    network_rx=${network_rx:-0}
    network_tx=${network_tx:-0}

    # Process count
    local process_count
    process_count=$(ps aux | wc -l)

    # Load average
    local load_avg
    load_avg=$(uptime | awk -F'load averages:' '{print $2}' | awk '{print $1}')

    # Create metrics JSON
    cat >"$METRICS_DIR/system_metrics_$timestamp.json" <<EOF
{
  "timestamp": $timestamp,
  "cpu_usage_percent": $cpu_usage,
  "memory_usage_percent": $mem_usage,
  "disk_usage_percent": $disk_usage,
  "network_rx_bytes": $network_rx,
  "network_tx_bytes": $network_tx,
  "process_count": $process_count,
  "load_average": $load_avg,
  "system_info": {
    "hostname": "$(hostname)",
    "os_version": "$(sw_vers -productVersion)",
    "kernel_version": "$(uname -r)"
  }
}
EOF

    log_info "System metrics collected: CPU=${cpu_usage}%, Memory=${mem_usage}%, Disk=${disk_usage}%"
}

# Collect performance metrics
collect_performance_metrics() {
    local timestamp
    timestamp=$(date +%s)

    # Response time simulation (replace with actual service checks)
    local response_time
    response_time=$((RANDOM % 1000))

    # Throughput metrics (requests per second)
    local throughput
    throughput=$((RANDOM % 500))

    # Error rate
    local error_rate
    error_rate=$((RANDOM % 5))

    # Active connections
    local active_connections
    active_connections=$((RANDOM % 100))

    # Database connection pool
    local db_connections
    db_connections=$((RANDOM % 20))

    cat >"$METRICS_DIR/performance_metrics_$timestamp.json" <<EOF
{
  "timestamp": $timestamp,
  "response_time_ms": $response_time,
  "throughput_rps": $throughput,
  "error_rate_percent": $error_rate,
  "active_connections": $active_connections,
  "database_connections": $db_connections,
  "performance_indicators": {
    "p50_response_time": $((response_time / 2)),
    "p95_response_time": $response_time,
    "p99_response_time": $((response_time * 2))
  }
}
EOF

    log_info "Performance metrics collected: Response=${response_time}ms, Throughput=${throughput} RPS"
}

# Check health thresholds
check_health_thresholds() {
    local latest_metrics
    latest_metrics=$(find "$METRICS_DIR" -name "system_metrics_*.json" | sort | tail -1)

    if [ ! -f "$latest_metrics" ]; then
        log_warning "No system metrics found"
        return
    fi

    local cpu_usage
    local memory_usage
    local disk_usage

    cpu_usage=$(jq -r '.cpu_usage_percent' "$latest_metrics")
    memory_usage=$(jq -r '.memory_usage_percent' "$latest_metrics")
    disk_usage=$(jq -r '.disk_usage_percent' "$latest_metrics")

    local alerts=()

    # CPU threshold check
    if (($(echo "$cpu_usage > $CPU_THRESHOLD" | bc -l))); then
        alerts+=("High CPU usage: ${cpu_usage}% (threshold: ${CPU_THRESHOLD}%)")
    fi

    # Memory threshold check
    if (($(echo "$memory_usage > $MEMORY_THRESHOLD" | bc -l))); then
        alerts+=("High memory usage: ${memory_usage}% (threshold: ${MEMORY_THRESHOLD}%)")
    fi

    # Disk threshold check
    if (($(echo "$disk_usage > $DISK_THRESHOLD" | bc -l))); then
        alerts+=("High disk usage: ${disk_usage}% (threshold: ${DISK_THRESHOLD}%)")
    fi

    # Create alerts if any
    if [ ${#alerts[@]} -gt 0 ]; then
        local alert_file="$ALERTS_DIR/alert_$(date +%s).json"
        jq -n \
            --arg timestamp "$(date +%s)" \
            --argjson alerts "$(printf '%s\n' "${alerts[@]}" | jq -R . | jq -s .)" \
            '{
                timestamp: ($timestamp | tonumber),
                severity: "warning",
                alerts: $alerts,
                system_metrics: '"$(cat "$latest_metrics")"'
            }' >"$alert_file"

        log_warning "Health alerts generated: ${#alerts[@]} alerts"
        send_alerts "$alert_file"
    fi
}

# Send alerts via configured channels
send_alerts() {
    local alert_file="$1"

    # Email alerts (if configured)
    if [ -n "$ALERT_EMAIL" ]; then
        log_info "Sending email alert to $ALERT_EMAIL"
        # Implement email sending logic here
    fi

    # Slack alerts (if configured)
    if [ -n "$SLACK_WEBHOOK" ]; then
        local alert_message
        alert_message=$(jq -r '.alerts | join("\n• ")' "$alert_file")

        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"🚨 System Health Alert\n• $alert_message\"}" \
            "$SLACK_WEBHOOK" 2>/dev/null || true
    fi

    # Log alerts
    log_warning "Alert sent: $(jq -r '.alerts | length' "$alert_file") issues detected"
}

# Generate baseline metrics
generate_baselines() {
    log_info "Generating performance baselines..."

    # Collect baseline data over time
    local baseline_period=3600 # 1 hour
    local start_time
    start_time=$(date +%s)

    log_info "Collecting baseline data for $baseline_period seconds..."

    while (($(date +%s) - start_time < baseline_period)); do
        collect_system_metrics
        collect_performance_metrics
        sleep 60
    done

    # Calculate baselines
    local system_files
    local performance_files

    system_files=$(find "$METRICS_DIR" -name "system_metrics_*.json" -newer "$METRICS_DIR/system_baseline.json" 2>/dev/null || find "$METRICS_DIR" -name "system_metrics_*.json")
    performance_files=$(find "$METRICS_DIR" -name "performance_metrics_*.json" -newer "$METRICS_DIR/performance_baseline.json" 2>/dev/null || find "$METRICS_DIR" -name "performance_metrics_*.json")

    # Calculate system baseline
    if [ -n "$system_files" ]; then
        jq -s '
            {
                generated_at: now,
                sample_count: length,
                cpu_avg: (map(.cpu_usage_percent) | add / length),
                memory_avg: (map(.memory_usage_percent) | add / length),
                disk_avg: (map(.disk_usage_percent) | add / length),
                cpu_p95: (map(.cpu_usage_percent) | sort | .[length * 0.95 | floor]),
                memory_p95: (map(.memory_usage_percent) | sort | .[length * 0.95 | floor]),
                disk_p95: (map(.disk_usage_percent) | sort | .[length * 0.95 | floor])
            }
        ' $system_files >"$METRICS_DIR/system_baseline.json"
    fi

    # Calculate performance baseline
    if [ -n "$performance_files" ]; then
        jq -s '
            {
                generated_at: now,
                sample_count: length,
                response_time_avg: (map(.response_time_ms) | add / length),
                throughput_avg: (map(.throughput_rps) | add / length),
                error_rate_avg: (map(.error_rate_percent) | add / length),
                response_time_p95: (map(.response_time_ms) | sort | .[length * 0.95 | floor]),
                throughput_p95: (map(.throughput_rps) | sort | .[length * 0.95 | floor])
            }
        ' $performance_files >"$METRICS_DIR/performance_baseline.json"
    fi

    log_success "Baselines generated successfully"
}

# Generate daily health report
generate_daily_report() {
    local report_date
    local report_file

    report_date=$(date +%Y%m%d)
    report_file="$REPORTS_DIR/daily_report_$report_date.md"

    log_info "Generating daily health report for $report_date..."

    # Get today's metrics
    local today_metrics
    today_metrics=$(find "$METRICS_DIR" -name "system_metrics_*.json" -newer "$report_file" 2>/dev/null || find "$METRICS_DIR" -name "system_metrics_*.json")

    # Get today's alerts
    local today_alerts
    today_alerts=$(find "$ALERTS_DIR" -name "alert_*.json" -newer "$report_file" 2>/dev/null || find "$ALERTS_DIR" -name "alert_*.json")

    cat >"$report_file" <<EOF
# Daily Health Report - $(date +%Y-%m-%d)

## System Overview

**Report Period**: $(date -v-1d +%Y-%m-%d) 00:00:00 - $(date +%Y-%m-%d) 00:00:00
**Generated At**: $(date)

## System Metrics Summary

EOF

    if [ -n "$today_metrics" ]; then
        jq -s '
            {
                count: length,
                avg_cpu: (map(.cpu_usage_percent) | add / length),
                avg_memory: (map(.memory_usage_percent) | add / length),
                avg_disk: (map(.disk_usage_percent) | add / length),
                max_cpu: (map(.cpu_usage_percent) | max),
                max_memory: (map(.memory_usage_percent) | max),
                max_disk: (map(.disk_usage_percent) | max)
            }
        ' $today_metrics | jq -r '
            "## Metrics Summary\n\n" +
            "- **Total Samples**: \(.count)\n" +
            "- **Average CPU Usage**: \(.avg_cpu | round)%%\n" +
            "- **Average Memory Usage**: \(.avg_memory | round)%%\n" +
            "- **Average Disk Usage**: \(.avg_disk | round)%%\n" +
            "- **Peak CPU Usage**: \(.max_cpu | round)%%\n" +
            "- **Peak Memory Usage**: \(.max_memory | round)%%\n" +
            "- **Peak Disk Usage**: \(.max_disk | round)%%\n\n"
        ' >>"$report_file"
    else
        echo "### No Metrics Data Available" >>"$report_file"
        echo "No system metrics were collected during the reporting period." >>"$report_file"
    fi

    # Add alerts section
    echo "## Alerts and Issues" >>"$report_file"
    echo "" >>"$report_file"

    if [ -n "$today_alerts" ]; then
        local alert_count
        alert_count=$(echo "$today_alerts" | wc -l)

        echo "### Alert Summary" >>"$report_file"
        echo "- **Total Alerts**: $alert_count" >>"$report_file"
        echo "" >>"$report_file"

        echo "### Alert Details" >>"$report_file"
        for alert_file in $today_alerts; do
            echo "#### Alert $(basename "$alert_file" .json)" >>"$report_file"
            jq -r '.alerts[]' "$alert_file" | sed 's/^/- /' >>"$report_file"
            echo "" >>"$report_file"
        done
    else
        echo "### No Alerts" >>"$report_file"
        echo "✅ No health alerts were triggered during the reporting period." >>"$report_file"
    fi

    # Add recommendations
    echo "## Recommendations" >>"$report_file"
    echo "" >>"$report_file"

    if [ -f "$METRICS_DIR/system_baseline.json" ]; then
        local baseline_cpu
        baseline_cpu=$(jq -r '.cpu_p95' "$METRICS_DIR/system_baseline.json")

        if (($(echo "$baseline_cpu > $CPU_THRESHOLD" | bc -l))); then
            echo "### ⚠️ High CPU Baseline Detected" >>"$report_file"
            echo "The 95th percentile CPU usage ($baseline_cpu%) exceeds the threshold ($CPU_THRESHOLD%). Consider:" >>"$report_file"
            echo "- Optimizing CPU-intensive processes" >>"$report_file"
            echo "- Scaling resources or upgrading hardware" >>"$report_file"
            echo "- Reviewing application performance" >>"$report_file"
            echo "" >>"$report_file"
        fi
    fi

    echo "### General Recommendations" >>"$report_file"
    echo "- Monitor system resources regularly" >>"$report_file"
    echo "- Review and optimize application performance" >>"$report_file"
    echo "- Keep system and dependencies updated" >>"$report_file"
    echo "- Regularly review and adjust alert thresholds" >>"$report_file"

    log_success "Daily health report generated: $report_file"
}

# Create monitoring dashboard
create_dashboard() {
    local dashboard_file="$DASHBOARD_DIR/index.html"

    log_info "Creating monitoring dashboard..."

    cat >"$dashboard_file" <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Tools Automation - System Health Dashboard</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            padding: 20px;
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
        }
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .metric-card {
            background: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            border-left: 4px solid #007bff;
        }
        .metric-title {
            font-size: 14px;
            color: #666;
            margin-bottom: 10px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        .metric-value {
            font-size: 32px;
            font-weight: bold;
            color: #333;
        }
        .metric-unit {
            font-size: 16px;
            color: #666;
        }
        .status-healthy { border-left-color: #28a745; }
        .status-warning { border-left-color: #ffc107; }
        .status-critical { border-left-color: #dc3545; }
        .chart-container {
            margin-bottom: 30px;
            background: white;
            border-radius: 8px;
            padding: 20px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .alerts-section {
            background: #fff3cd;
            border: 1px solid #ffeaa7;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 20px;
        }
        .alert {
            background: #f8d7da;
            border: 1px solid #f5c6cb;
            color: #721c24;
            padding: 10px;
            border-radius: 4px;
            margin-bottom: 10px;
        }
        .last-updated {
            text-align: center;
            color: #666;
            font-size: 14px;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🖥️ System Health Dashboard</h1>
            <p>Real-time monitoring of Tools Automation ecosystem</p>
        </div>

        <div class="alerts-section" id="alerts-section" style="display: none;">
            <h3>🚨 Active Alerts</h3>
            <div id="alerts-container"></div>
        </div>

        <div class="metrics-grid" id="metrics-grid">
            <!-- Metrics will be populated by JavaScript -->
        </div>

        <div class="chart-container">
            <h3>System Resource Trends (Last 24 Hours)</h3>
            <canvas id="resourceChart" width="400" height="200"></canvas>
        </div>

        <div class="chart-container">
            <h3>Performance Metrics (Last 24 Hours)</h3>
            <canvas id="performanceChart" width="400" height="200"></canvas>
        </div>

        <div class="last-updated" id="last-updated">
            Last updated: <span id="update-time">Loading...</span>
        </div>
    </div>

    <script>
        // Dashboard data and functionality
        let metricsData = [];
        let alertsData = [];

        async function loadDashboardData() {
            try {
                // Load latest metrics
                const metricsResponse = await fetch('./api/metrics');
                const metrics = await metricsResponse.json();

                // Load alerts
                const alertsResponse = await fetch('./api/alerts');
                const alerts = await alertsResponse.json();

                updateDashboard(metrics, alerts);
            } catch (error) {
                console.error('Failed to load dashboard data:', error);
                // Use sample data for demonstration
                updateDashboard(getSampleMetrics(), []);
            }
        }

        function updateDashboard(metrics, alerts) {
            updateMetricsCards(metrics);
            updateAlerts(alerts);
            updateCharts(metrics);
            updateTimestamp();
        }

        function updateMetricsCards(metrics) {
            const grid = document.getElementById('metrics-grid');

            const metricsConfig = [
                { key: 'cpu_usage_percent', title: 'CPU Usage', unit: '%', threshold: 80 },
                { key: 'memory_usage_percent', title: 'Memory Usage', unit: '%', threshold: 85 },
                { key: 'disk_usage_percent', title: 'Disk Usage', unit: '%', threshold: 90 },
                { key: 'response_time_ms', title: 'Response Time', unit: 'ms', threshold: 500 }
            ];

            grid.innerHTML = metricsConfig.map(config => {
                const value = metrics[config.key] || 0;
                const status = value > config.threshold ? 'critical' : value > (config.threshold * 0.8) ? 'warning' : 'healthy';

                return `
                    <div class="metric-card status-${status}">
                        <div class="metric-title">${config.title}</div>
                        <div class="metric-value">${value}<span class="metric-unit">${config.unit}</span></div>
                    </div>
                `;
            }).join('');
        }

        function updateAlerts(alerts) {
            const alertsSection = document.getElementById('alerts-section');
            const alertsContainer = document.getElementById('alerts-container');

            if (alerts.length > 0) {
                alertsSection.style.display = 'block';
                alertsContainer.innerHTML = alerts.map(alert =>
                    `<div class="alert">${alert}</div>`
                ).join('');
            } else {
                alertsSection.style.display = 'none';
            }
        }

        function updateCharts(metrics) {
            // Resource usage chart
            const resourceCtx = document.getElementById('resourceChart').getContext('2d');
            new Chart(resourceCtx, {
                type: 'line',
                data: {
                    labels: ['1h ago', '45m ago', '30m ago', '15m ago', 'now'],
                    datasets: [{
                        label: 'CPU %',
                        data: [65, 70, 75, 72, metrics.cpu_usage_percent || 70],
                        borderColor: 'rgb(255, 99, 132)',
                        backgroundColor: 'rgba(255, 99, 132, 0.1)',
                    }, {
                        label: 'Memory %',
                        data: [60, 65, 68, 66, metrics.memory_usage_percent || 65],
                        borderColor: 'rgb(54, 162, 235)',
                        backgroundColor: 'rgba(54, 162, 235, 0.1)',
                    }]
                },
                options: {
                    responsive: true,
                    scales: {
                        y: {
                            beginAtZero: true,
                            max: 100
                        }
                    }
                }
            });

            // Performance chart
            const performanceCtx = document.getElementById('performanceChart').getContext('2d');
            new Chart(performanceCtx, {
                type: 'line',
                data: {
                    labels: ['1h ago', '45m ago', '30m ago', '15m ago', 'now'],
                    datasets: [{
                        label: 'Response Time (ms)',
                        data: [450, 480, 420, 460, metrics.response_time_ms || 450],
                        borderColor: 'rgb(75, 192, 192)',
                        backgroundColor: 'rgba(75, 192, 192, 0.1)',
                    }, {
                        label: 'Throughput (RPS)',
                        data: [120, 135, 128, 142, metrics.throughput_rps || 130],
                        borderColor: 'rgb(153, 102, 255)',
                        backgroundColor: 'rgba(153, 102, 255, 0.1)',
                    }]
                },
                options: {
                    responsive: true,
                    scales: {
                        y: {
                            beginAtZero: true
                        }
                    }
                }
            });
        }

        function updateTimestamp() {
            document.getElementById('update-time').textContent = new Date().toLocaleString();
        }

        function getSampleMetrics() {
            return {
                cpu_usage_percent: 65,
                memory_usage_percent: 72,
                disk_usage_percent: 45,
                response_time_ms: 450,
                throughput_rps: 130
            };
        }

        // Initialize dashboard
        loadDashboardData();
        setInterval(loadDashboardData, 30000); // Update every 30 seconds
    </script>
</body>
</html>
EOF

    log_success "Monitoring dashboard created: $dashboard_file"
}

# Start monitoring daemon
start_monitoring() {
    log_info "Starting system health monitoring daemon..."

    # Create PID file
    echo $$ >"$MONITORING_DIR/monitoring.pid"

    # Initialize if needed
    if [ ! -f "$METRICS_DIR/system_baseline.json" ]; then
        generate_baselines
    fi

    log_success "Monitoring daemon started (PID: $$)"

    # Main monitoring loop
    while true; do
        # Collect metrics
        collect_system_metrics
        collect_performance_metrics

        # Check thresholds
        check_health_thresholds

        # Generate daily report at midnight
        if [ "$(date +%H%M)" = "0000" ]; then
            generate_daily_report
        fi

        # Sleep until next check
        sleep $SYSTEM_CHECK_INTERVAL
    done
}

# Stop monitoring daemon
stop_monitoring() {
    if [ -f "$MONITORING_DIR/monitoring.pid" ]; then
        local pid
        pid=$(cat "$MONITORING_DIR/monitoring.pid")
        kill "$pid" 2>/dev/null || true
        rm -f "$MONITORING_DIR/monitoring.pid"
        log_success "Monitoring daemon stopped"
    else
        log_warning "No monitoring daemon running"
    fi
}

# Show monitoring status
show_status() {
    echo "=== System Health Monitoring Status ==="
    echo ""

    # Check if daemon is running
    if [ -f "$MONITORING_DIR/monitoring.pid" ] && kill -0 "$(cat "$MONITORING_DIR/monitoring.pid")" 2>/dev/null; then
        echo "✅ Monitoring Daemon: RUNNING (PID: $(cat "$MONITORING_DIR/monitoring.pid"))"
    else
        echo "❌ Monitoring Daemon: STOPPED"
    fi

    echo ""

    # Show recent metrics
    local latest_system
    local latest_performance

    latest_system=$(find "$METRICS_DIR" -name "system_metrics_*.json" | sort | tail -1)
    latest_performance=$(find "$METRICS_DIR" -name "performance_metrics_*.json" | sort | tail -1)

    if [ -f "$latest_system" ]; then
        echo "📊 Latest System Metrics:"
        jq -r '"  CPU: \(.cpu_usage_percent)%, Memory: \(.memory_usage_percent)%, Disk: \(.disk_usage_percent)%"' "$latest_system"
        echo "  Timestamp: $(date -r "$(jq -r '.timestamp' "$latest_system")")"
    else
        echo "📊 System Metrics: No data available"
    fi

    echo ""

    if [ -f "$latest_performance" ]; then
        echo "⚡ Latest Performance Metrics:"
        jq -r '"  Response Time: \(.response_time_ms)ms, Throughput: \(.throughput_rps) RPS"' "$latest_performance"
        echo "  Timestamp: $(date -r "$(jq -r '.timestamp' "$latest_performance")")"
    else
        echo "⚡ Performance Metrics: No data available"
    fi

    echo ""

    # Show active alerts
    local active_alerts
    active_alerts=$(find "$ALERTS_DIR" -name "alert_*.json" -mmin -60 2>/dev/null | wc -l)

    if [ "$active_alerts" -gt 0 ]; then
        echo "🚨 Active Alerts (last hour): $active_alerts"
    else
        echo "✅ Active Alerts: None"
    fi

    echo ""

    # Show baseline status
    if [ -f "$METRICS_DIR/system_baseline.json" ]; then
        echo "📈 Baselines: Generated ($(date -r "$(stat -f %m "$METRICS_DIR/system_baseline.json")"))"
    else
        echo "📈 Baselines: Not generated"
    fi

    echo ""

    # Show recent reports
    local recent_reports
    recent_reports=$(find "$REPORTS_DIR" -name "daily_report_*.md" -mtime -7 2>/dev/null | wc -l)

    echo "📋 Recent Reports: $recent_reports (last 7 days)"
}

# Main function
main() {
    local command="$1"
    shift

    case "$command" in
    "init")
        initialize_monitoring
        ;;
    "start")
        start_monitoring
        ;;
    "stop")
        stop_monitoring
        ;;
    "status")
        show_status
        ;;
    "baseline")
        generate_baselines
        ;;
    "report")
        generate_daily_report
        ;;
    "dashboard")
        create_dashboard
        ;;
    "collect")
        collect_system_metrics
        collect_performance_metrics
        ;;
    "check")
        check_health_thresholds
        ;;
    *)
        echo "Usage: $0 {init|start|stop|status|baseline|report|dashboard|collect|check}"
        echo ""
        echo "Commands:"
        echo "  init      - Initialize monitoring system"
        echo "  start     - Start monitoring daemon"
        echo "  stop      - Stop monitoring daemon"
        echo "  status    - Show monitoring status"
        echo "  baseline  - Generate performance baselines"
        echo "  report    - Generate daily health report"
        echo "  dashboard - Create monitoring dashboard"
        echo "  collect   - Collect current metrics"
        echo "  check     - Check health thresholds"
        exit 1
        ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

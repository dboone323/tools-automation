#!/bin/bash

# System Health Monitoring & Performance Baselines Script
# Part of Maintenance Phase - Tools Automation Ecosystem

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_ROOT/monitoring/health_monitor.log"
METRICS_FILE="$PROJECT_ROOT/monitoring/health_metrics.json"
BASELINE_FILE="$PROJECT_ROOT/monitoring/performance_baselines.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE" >&2
}

# Initialize monitoring
init_monitoring() {
    log "🔄 Initializing System Health Monitoring"

    # Create monitoring directories if they don't exist
    mkdir -p "$PROJECT_ROOT/monitoring"
    mkdir -p "$PROJECT_ROOT/monitoring/reports"
    mkdir -p "$PROJECT_ROOT/monitoring/baselines"

    # Initialize log file
    echo "=== System Health Monitoring Started - $(date) ===" >"$LOG_FILE"

    # Initialize metrics file
    if [ ! -f "$METRICS_FILE" ]; then
        echo '{"timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'", "metrics": {}}' >"$METRICS_FILE"
    fi

    log "✅ Monitoring initialization complete"
}

# Health check functions
check_system_resources() {
    log "📊 Checking system resources..."

    # CPU usage - macOS specific parsing
    CPU_USAGE=$(top -l 1 | grep "CPU usage" | awk -F'[:,%]' '{print $2}' | sed 's/ //g')
    CPU_CORES=$(sysctl -n hw.ncpu)

    # Memory usage - macOS specific
    MEM_TOTAL=$(echo "$(sysctl -n hw.memsize) / 1024 / 1024 / 1024" | bc 2>/dev/null || echo "16")
    MEM_USED=$(ps -A -o rss= | awk '{sum+=$1} END {print sum/1024/1024}' 2>/dev/null || echo "0")

    # Disk usage
    DISK_USAGE=$(df -h "$PROJECT_ROOT" | tail -1 | awk '{print $5}' | sed 's/%//' 2>/dev/null || echo "0")

    # Network connectivity
    NETWORK_CHECK=$(curl -s --max-time 5 http://httpbin.org/ip >/dev/null 2>&1 && echo "OK" || echo "FAIL")

    # Ensure numeric values are valid
    CPU_USAGE=$(echo "$CPU_USAGE" | sed 's/[^0-9.]//g' | awk '{if($1=="") print "0"; else print $1}')
    MEM_TOTAL=$(echo "$MEM_TOTAL" | sed 's/[^0-9.]//g' | awk '{if($1=="") print "16"; else print $1}')
    MEM_USED=$(echo "$MEM_USED" | sed 's/[^0-9.]//g' | awk '{if($1=="") print "0"; else print $1}')
    DISK_USAGE=$(echo "$DISK_USAGE" | sed 's/[^0-9.]//g' | awk '{if($1=="") print "0"; else print $1}')

    # Output JSON only (no log messages)
    cat <<EOF
{
    "cpu_usage_percent": $CPU_USAGE,
    "cpu_cores": $CPU_CORES,
    "memory_total_gb": $MEM_TOTAL,
    "memory_used_gb": $MEM_USED,
    "disk_usage_percent": $DISK_USAGE,
    "network_connectivity": "$NETWORK_CHECK"
}
EOF
}

check_application_health() {
    log "🏥 Checking application health..."

    cd "$PROJECT_ROOT" 2>/dev/null || true

    # MCP Server health check
    MCP_HEALTH="DOWN"
    if pgrep -f "python3 mcp_server.py" >/dev/null 2>&1; then
        MCP_HEALTH="UP"
    fi

    # Agent status check
    AGENT_COUNT=$(find agents -name "*.sh" -type f 2>/dev/null | wc -l | sed 's/ //g' || echo "0")
    AGENT_ACTIVE=$(ps aux 2>/dev/null | grep -E "agent.*\.sh" | grep -v grep | wc -l | sed 's/ //g' || echo "0")

    # Plugin system check
    PLUGIN_COUNT=$(find plugins -name "*.py" -type f 2>/dev/null | wc -l | sed 's/ //g' || echo "0")
    PLUGIN_HEALTH="UNKNOWN"
    if [ "$PLUGIN_COUNT" -gt 0 ]; then
        PLUGIN_HEALTH="AVAILABLE"
    fi

    # SDK status check
    PYTHON_SDK_EXISTS=$(test -d sdk/python && echo "true" || echo "false")
    TYPESCRIPT_SDK_EXISTS=$(test -d sdk/typescript && echo "true" || echo "false")
    GO_SDK_EXISTS=$(test -d sdk/go && echo "true" || echo "false")

    # Output JSON only (no log messages)
    cat <<EOF
{
    "mcp_server_status": "$MCP_HEALTH",
    "total_agents": $AGENT_COUNT,
    "active_agents": $AGENT_ACTIVE,
    "plugin_count": $PLUGIN_COUNT,
    "plugin_health": "$PLUGIN_HEALTH",
    "python_sdk_exists": $PYTHON_SDK_EXISTS,
    "typescript_sdk_exists": $TYPESCRIPT_SDK_EXISTS,
    "go_sdk_exists": $GO_SDK_EXISTS
}
EOF
}

check_performance_metrics() {
    log "⚡ Checking performance metrics..."

    cd "$PROJECT_ROOT" 2>/dev/null || true

    # Response time check (if MCP server is running)
    RESPONSE_TIME="N/A"
    if pgrep -f "python3 mcp_server.py" >/dev/null 2>&1; then
        START_TIME=$(date +%s%N 2>/dev/null || date +%s)
        curl -s --max-time 2 http://localhost:5005/health >/dev/null 2>&1
        END_TIME=$(date +%s%N 2>/dev/null || date +%s)
        if [ -n "$START_TIME" ] && [ -n "$END_TIME" ]; then
            RESPONSE_TIME=$(((END_TIME - START_TIME) / 1000000)) 2>/dev/null || RESPONSE_TIME="N/A"
        fi
    fi

    # Load test results (if available)
    LOAD_TEST_FILE=$(find . -name "load_test_results_*.json" -type f -mtime -1 2>/dev/null | head -1 || echo "")
    LOAD_TEST_STATUS="NO_RECENT_TESTS"
    if [ -n "$LOAD_TEST_FILE" ]; then
        LOAD_TEST_STATUS="RECENT_TESTS_AVAILABLE"
    fi

    # Error rate from logs
    ERROR_COUNT=$(grep -i "error\|exception" "$LOG_FILE" 2>/dev/null | wc -l 2>/dev/null | sed 's/ //g' || echo "0")

    # System uptime
    UPTIME_SECONDS=$(uptime 2>/dev/null | awk '{print $3}' | sed 's/,//' 2>/dev/null || echo "0")

    # Output JSON only (no log messages)
    cat <<EOF
{
    "response_time_ms": "$RESPONSE_TIME",
    "load_test_status": "$LOAD_TEST_STATUS",
    "error_count_today": $ERROR_COUNT,
    "uptime_seconds": "$UPTIME_SECONDS"
}
EOF
}

# Baseline management
establish_baselines() {
    log "📈 Establishing performance baselines..."

    if [ ! -f "$BASELINE_FILE" ]; then
        log "Creating initial performance baselines..."

        # Run initial health checks to establish baselines
        SYS_RESOURCES=$(check_system_resources)
        APP_HEALTH=$(check_application_health)
        PERF_METRICS=$(check_performance_metrics)

        cat >"$BASELINE_FILE" <<EOF
{
    "established_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "system_baselines": $SYS_RESOURCES,
    "application_baselines": $APP_HEALTH,
    "performance_baselines": $PERF_METRICS,
    "baseline_period_days": 7,
    "alert_thresholds": {
        "cpu_usage_percent": 80,
        "memory_usage_percent": 85,
        "disk_usage_percent": 90,
        "response_time_ms": 500,
        "error_rate_threshold": 10
    }
}
EOF

        log "✅ Initial baselines established"
    else
        log "Baselines already exist, checking for updates..."
    fi
}

# Alert system
check_alerts() {
    log "🚨 Checking for alerts..."

    if [ ! -f "$BASELINE_FILE" ]; then
        log "⚠️  No baselines established yet, skipping alert checks"
        return
    fi

    if [ ! -f "$METRICS_FILE" ]; then
        log "⚠️  No current metrics available yet, skipping alert checks"
        return
    fi

    # Load current metrics and baselines
    CURRENT_METRICS=$(cat "$METRICS_FILE" 2>/dev/null || echo "{}")
    BASELINES=$(cat "$BASELINE_FILE")

    # Extract alert thresholds
    CPU_THRESHOLD=$(echo "$BASELINES" | jq -r '.alert_thresholds.cpu_usage_percent // 80' 2>/dev/null || echo "80")
    MEM_THRESHOLD=$(echo "$BASELINES" | jq -r '.alert_thresholds.memory_usage_percent // 85' 2>/dev/null || echo "85")
    DISK_THRESHOLD=$(echo "$BASELINES" | jq -r '.alert_thresholds.disk_usage_percent // 90' 2>/dev/null || echo "90")
    RESPONSE_THRESHOLD=$(echo "$BASELINES" | jq -r '.alert_thresholds.response_time_ms // 500' 2>/dev/null || echo "500")

    # Check current values against thresholds
    ALERTS=()

    CURRENT_CPU=$(echo "$CURRENT_METRICS" | jq -r '.metrics.system_resources.cpu_usage_percent // 0' 2>/dev/null || echo "0")
    if (($(echo "$CURRENT_CPU > $CPU_THRESHOLD" | bc -l 2>/dev/null || echo "0"))); then
        ALERTS+=("HIGH_CPU_USAGE: $CURRENT_CPU% (threshold: $CPU_THRESHOLD%)")
    fi

    CURRENT_DISK=$(echo "$CURRENT_METRICS" | jq -r '.metrics.system_resources.disk_usage_percent // 0' 2>/dev/null || echo "0")
    if (($(echo "$CURRENT_DISK > $DISK_THRESHOLD" | bc -l 2>/dev/null || echo "0"))); then
        ALERTS+=("HIGH_DISK_USAGE: $CURRENT_DISK% (threshold: $DISK_THRESHOLD%)")
    fi

    # Report alerts
    if [ ${#ALERTS[@]} -gt 0 ]; then
        log "🚨 ALERTS DETECTED:"
        for alert in "${ALERTS[@]}"; do
            echo -e "${RED}⚠️  $alert${NC}" | tee -a "$LOG_FILE"
        done
    else
        log "✅ No alerts detected - system within normal parameters"
    fi
}

# Generate health report
generate_report() {
    log "📋 Generating health report..."

    REPORT_FILE="$PROJECT_ROOT/monitoring/reports/health_report_$(date +%Y%m%d_%H%M%S).md"

    # Get system resources info safely
    SYS_INFO="Unable to retrieve system information"
    if SYS_RESOURCES=$(check_system_resources 2>/dev/null) && echo "$SYS_RESOURCES" | jq . >/dev/null 2>&1; then
        SYS_INFO=$(echo "$SYS_RESOURCES" | jq -r '
            "### CPU Usage: \(.cpu_usage_percent)% (\(.cpu_cores) cores)\n" +
            "### Memory: \(.memory_used_gb | tostring)GB / \(.memory_total_gb | tostring)GB used\n" +
            "### Disk Usage: \(.disk_usage_percent)%\n" +
            "### Network: \(.network_connectivity)"
        ' 2>/dev/null || echo "Error parsing system resources")
    fi

    # Get application health info safely
    APP_INFO="Unable to retrieve application information"
    if APP_HEALTH=$(check_application_health 2>/dev/null) && echo "$APP_HEALTH" | jq . >/dev/null 2>&1; then
        APP_INFO=$(echo "$APP_HEALTH" | jq -r '
            "### MCP Server: \(.mcp_server_status)\n" +
            "### Agents: \(.active_agents)/\(.total_agents) active\n" +
            "### Plugins: \(.plugin_count) available (\(.plugin_health))\n" +
            "### SDKs: Python: \(.python_sdk_exists), TypeScript: \(.typescript_sdk_exists), Go: \(.go_sdk_exists)"
        ' 2>/dev/null || echo "Error parsing application health")
    fi

    # Get performance metrics info safely
    PERF_INFO="Unable to retrieve performance information"
    if PERF_METRICS=$(check_performance_metrics 2>/dev/null) && echo "$PERF_METRICS" | jq . >/dev/null 2>&1; then
        PERF_INFO=$(echo "$PERF_METRICS" | jq -r '
            "### Response Time: \(.response_time_ms)ms\n" +
            "### Load Tests: \(.load_test_status)\n" +
            "### Errors Today: \(.error_count_today)\n" +
            "### System Uptime: \(.uptime_seconds) seconds"
        ' 2>/dev/null || echo "Error parsing performance metrics")
    fi

    cat >"$REPORT_FILE" <<EOF
# System Health Report
**Generated:** $(date)
**Report Period:** Last 24 hours

## Executive Summary

$(if [ -f "$METRICS_FILE" ] && [ -s "$METRICS_FILE" ]; then
        echo "✅ Health monitoring active"
    else
        echo "⚠️  Health monitoring not yet initialized"
    fi)

## System Resources

    $SYS_INFO

## Application Health

    $APP_INFO

## Performance Metrics

    $PERF_INFO

## Recent Alerts

$(tail -20 "$LOG_FILE" 2>/dev/null | grep -i "alert\|warning\|error" | tail -5 2>/dev/null || echo "No recent alerts")

---
*This report is automatically generated by the health monitoring system*
EOF

    log "✅ Health report generated: $REPORT_FILE"
}

# Main execution
main() {
    echo -e "${BLUE}🔄 Starting System Health Monitoring${NC}"

    # Initialize monitoring
    init_monitoring

    # Run health checks
    echo -e "${YELLOW}📊 Running health checks...${NC}"

    SYS_RESOURCES=$(check_system_resources)
    APP_HEALTH=$(check_application_health)
    PERF_METRICS=$(check_performance_metrics)

    # Update metrics file
    cat >"$METRICS_FILE" <<EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "metrics": {
        "system_resources": $SYS_RESOURCES,
        "application_health": $APP_HEALTH,
        "performance_metrics": $PERF_METRICS
    }
}
EOF

    # Establish baselines if needed
    establish_baselines

    # Check for alerts
    check_alerts

    # Generate report
    generate_report

    echo -e "${GREEN}✅ Health monitoring cycle complete${NC}"
    log "✅ Health monitoring cycle complete"
}

# Run main function
main "$@"

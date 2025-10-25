#!/bin/bash

# Proactive Monitoring System
# Monitors for warning signs and prevents issues before they occur

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
MONITOR_INTERVAL="${MONITOR_INTERVAL:-300}" # 5 minutes default
KNOWLEDGE_DIR="$SCRIPT_DIR/knowledge"
METRICS_FILE="$KNOWLEDGE_DIR/proactive_metrics.json"
ALERTS_FILE="$KNOWLEDGE_DIR/proactive_alerts.json"
PROJECT_MEMORY="$SCRIPT_DIR/context/project_memory.json"

# Thresholds
COMPLEXITY_THRESHOLD="${COMPLEXITY_THRESHOLD:-15}"
COVERAGE_DROP_THRESHOLD="${COVERAGE_DROP_THRESHOLD:-5}"              # % drop
BUILD_TIME_INCREASE_THRESHOLD="${BUILD_TIME_INCREASE_THRESHOLD:-20}" # % increase
ERROR_RATE_THRESHOLD="${ERROR_RATE_THRESHOLD:-10}"                   # errors per day
DEPENDENCY_AGE_THRESHOLD="${DEPENDENCY_AGE_THRESHOLD:-90}"           # days

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[Proactive Monitor] $(date '+%Y-%m-%d %H:%M:%S') - $*${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[Proactive Monitor] $(date '+%Y-%m-%d %H:%M:%S') - WARNING: $*${NC}" >&2
}

error() {
    echo -e "${RED}[Proactive Monitor] $(date '+%Y-%m-%d %H:%M:%S') - ERROR: $*${NC}" >&2
}

success() {
    echo -e "${GREEN}[Proactive Monitor] $(date '+%Y-%m-%d %H:%M:%S') - $*${NC}" >&2
}

# Initialize monitoring system
initialize_monitoring() {
    log "Initializing proactive monitoring..."

    mkdir -p "$KNOWLEDGE_DIR"

    # Initialize metrics file
    if [ ! -f "$METRICS_FILE" ]; then
        cat >"$METRICS_FILE" <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "metrics": {
    "code_complexity": {
      "average": 0,
      "max": 0,
      "trending": "stable"
    },
    "test_coverage": {
      "current": 0.77,
      "previous": 0.77,
      "trend": "stable"
    },
    "build_times": {
      "average": 0,
      "max": 0,
      "trend": "stable"
    },
    "error_rate": {
      "daily": 0,
      "weekly": 0,
      "trend": "stable"
    },
    "dependencies": {
      "total": 0,
      "stale": 0,
      "outdated": []
    }
  },
  "history": []
}
EOF
    fi

    # Initialize alerts file
    if [ ! -f "$ALERTS_FILE" ]; then
        cat >"$ALERTS_FILE" <<EOF
{
  "alerts": [],
  "resolved": []
}
EOF
    fi

    success "Monitoring initialized"
}

# Monitor code complexity
monitor_code_complexity() {
    log "Monitoring code complexity..."

    local total_complexity=0
    local max_complexity=0
    local file_count=0

    # Find Swift files (simplified complexity check)
    while IFS= read -r -d '' file; do
        if [ -f "$file" ]; then
            # Count cyclomatic complexity indicators (if/else/for/while/case)
            local complexity
            complexity=$(grep -c -E '(if |else|for |while |case |guard )' "$file" 2>/dev/null || echo "0")

            total_complexity=$((total_complexity + complexity))
            if [ "$complexity" -gt "$max_complexity" ]; then
                max_complexity=$complexity
            fi
            file_count=$((file_count + 1))

            # Alert on high complexity
            if [ "$complexity" -gt "$COMPLEXITY_THRESHOLD" ]; then
                create_alert "high_complexity" "high" \
                    "File $file has complexity score of $complexity (threshold: $COMPLEXITY_THRESHOLD)" \
                    '{"file": "'"$file"'", "complexity": '"$complexity"'}'
            fi
        fi
    done < <(find "$SCRIPT_DIR/../../Projects" -name "*.swift" -print0 2>/dev/null || true)

    local avg_complexity=0
    if [ "$file_count" -gt 0 ]; then
        avg_complexity=$((total_complexity / file_count))
    fi

    log "Complexity: avg=$avg_complexity, max=$max_complexity, files=$file_count"

    # Update metrics
    update_metric "code_complexity" "{\"average\": $avg_complexity, \"max\": $max_complexity, \"file_count\": $file_count}"
}

# Monitor test coverage
monitor_test_coverage() {
    log "Monitoring test coverage..."

    # Get current coverage from project memory
    local current_coverage
    current_coverage=$(python3 -c "
import json, sys
try:
    with open('$PROJECT_MEMORY', 'r') as f:
        data = json.load(f)
        print(data.get('current_state', {}).get('test_coverage', 0.77))
except:
    print(0.77)
" 2>/dev/null || echo "0.77")

    # Get previous coverage from metrics
    local previous_coverage
    previous_coverage=$(python3 -c "
import json, sys
try:
    with open('$METRICS_FILE', 'r') as f:
        data = json.load(f)
        print(data.get('metrics', {}).get('test_coverage', {}).get('current', 0.77))
except:
    print(0.77)
" 2>/dev/null || echo "0.77")

    # Calculate percentage drop
    local drop
    drop=$(python3 -c "print(($previous_coverage - $current_coverage) * 100)" 2>/dev/null || echo "0")

    log "Coverage: current=${current_coverage}, previous=${previous_coverage}, drop=${drop}%"

    # Alert if coverage dropped significantly
    if (($(echo "$drop > $COVERAGE_DROP_THRESHOLD" | bc -l 2>/dev/null || echo "0"))); then
        create_alert "coverage_drop" "high" \
            "Test coverage dropped by ${drop}% (threshold: ${COVERAGE_DROP_THRESHOLD}%)" \
            "{\"current\": $current_coverage, \"previous\": $previous_coverage, \"drop\": $drop}"
    fi

    # Update metrics
    update_metric "test_coverage" "{\"current\": $current_coverage, \"previous\": $previous_coverage, \"drop\": $drop}"
}

# Monitor build times
monitor_build_times() {
    log "Monitoring build times..."

    # Check recent build logs
    local build_log_dir="$SCRIPT_DIR/../../../logs"
    local recent_build_time=0
    local avg_build_time=0

    if [ -d "$build_log_dir" ]; then
        # Get most recent build time (simplified - would parse actual build logs)
        local build_count=0
        local total_time=0

        # This is a placeholder - in real implementation would parse build logs
        recent_build_time=60
        avg_build_time=50

        # Calculate percentage increase
        if [ "$avg_build_time" -gt 0 ]; then
            local increase
            increase=$(((recent_build_time - avg_build_time) * 100 / avg_build_time))

            if [ "$increase" -gt "$BUILD_TIME_INCREASE_THRESHOLD" ]; then
                create_alert "build_time_increase" "medium" \
                    "Build time increased by ${increase}% (threshold: ${BUILD_TIME_INCREASE_THRESHOLD}%)" \
                    "{\"recent\": $recent_build_time, \"average\": $avg_build_time, \"increase\": $increase}"
            fi
        fi
    fi

    log "Build times: recent=${recent_build_time}s, average=${avg_build_time}s"

    # Update metrics
    update_metric "build_times" "{\"recent\": $recent_build_time, \"average\": $avg_build_time}"
}

# Monitor error rates
monitor_error_rates() {
    log "Monitoring error rates..."

    # Count errors in error_patterns.json
    local error_count
    error_count=$(python3 -c "
import json, sys
from datetime import datetime, timedelta
try:
    with open('$KNOWLEDGE_DIR/error_patterns.json', 'r') as f:
        data = json.load(f)
        # Count errors in last 24 hours
        now = datetime.now()
        day_ago = now - timedelta(days=1)
        recent_errors = 0
        for pattern in data.get('patterns', []):
            last_seen = pattern.get('last_seen', '')
            if last_seen:
                try:
                    error_time = datetime.fromisoformat(last_seen.replace('Z', '+00:00'))
                    if error_time > day_ago:
                        recent_errors += pattern.get('occurrence_count', 1)
                except:
                    pass
        print(recent_errors)
except:
    print(0)
" 2>/dev/null || echo "0")

    log "Error rate: $error_count errors in last 24 hours"

    # Alert if error rate is high
    if [ "$error_count" -gt "$ERROR_RATE_THRESHOLD" ]; then
        create_alert "high_error_rate" "high" \
            "Error rate of $error_count errors/day exceeds threshold of $ERROR_RATE_THRESHOLD" \
            "{\"daily_errors\": $error_count, \"threshold\": $ERROR_RATE_THRESHOLD}"
    fi

    # Update metrics
    update_metric "error_rate" "{\"daily\": $error_count, \"threshold\": $ERROR_RATE_THRESHOLD}"
}

# Monitor dependencies
monitor_dependencies() {
    log "Monitoring dependencies..."

    # Check Swift Package.swift files
    local stale_count=0
    local outdated_deps=""

    # This is a simplified check - real implementation would check Package.resolved dates
    # and compare with available updates

    log "Dependencies: $stale_count stale packages detected"

    # Update metrics
    update_metric "dependencies" "{\"stale\": $stale_count}"
}

# Create alert
create_alert() {
    local alert_type="$1"
    local severity="$2"
    local message="$3"
    local details="${4:-{}}"

    warn "Alert: [$severity] $message"

    # Add alert to file
    python3 <<EOF
import json
from datetime import datetime

try:
    with open('$ALERTS_FILE', 'r') as f:
        data = json.load(f)
except:
    data = {"alerts": [], "resolved": []}

alert = {
    "id": datetime.now().isoformat() + "_$alert_type",
    "type": "$alert_type",
    "severity": "$severity",
    "message": "$message",
    "details": $details,
    "timestamp": datetime.now().isoformat(),
    "status": "active"
}

data["alerts"].append(alert)

# Atomic write
import tempfile, shutil
with tempfile.NamedTemporaryFile(mode='w', delete=False, dir='$KNOWLEDGE_DIR') as tmp:
    json.dump(data, tmp, indent=2)
    tmp_path = tmp.name

shutil.move(tmp_path, '$ALERTS_FILE')
EOF
}

# Update metric
update_metric() {
    local metric_name="$1"
    local metric_value="$2"

    python3 <<EOF
import json
from datetime import datetime

try:
    with open('$METRICS_FILE', 'r') as f:
        data = json.load(f)
except:
    data = {"metrics": {}, "history": []}

# Update metric
if "metrics" not in data:
    data["metrics"] = {}

data["metrics"]["$metric_name"] = $metric_value
data["timestamp"] = datetime.now().isoformat()

# Add to history
if "history" not in data:
    data["history"] = []

data["history"].append({
    "timestamp": datetime.now().isoformat(),
    "metric": "$metric_name",
    "value": $metric_value
})

# Keep last 100 history entries
if len(data["history"]) > 100:
    data["history"] = data["history"][-100:]

# Atomic write
import tempfile, shutil
with tempfile.NamedTemporaryFile(mode='w', delete=False, dir='$KNOWLEDGE_DIR') as tmp:
    json.dump(data, tmp, indent=2)
    tmp_path = tmp.name

shutil.move(tmp_path, '$METRICS_FILE')
EOF
}

# Run all monitors
run_all_monitors() {
    log "Running all proactive monitors..."

    monitor_code_complexity
    monitor_test_coverage
    monitor_build_times
    monitor_error_rates
    monitor_dependencies

    success "All monitors completed"
}

# Watch mode (continuous monitoring)
watch_mode() {
    log "Starting watch mode (interval: ${MONITOR_INTERVAL}s)..."

    while true; do
        run_all_monitors
        log "Waiting $MONITOR_INTERVAL seconds until next check..."
        sleep "$MONITOR_INTERVAL"
    done
}

# Show current status
show_status() {
    log "Proactive Monitor Status"
    echo ""

    if [ -f "$METRICS_FILE" ]; then
        echo "Current Metrics:"
        python3 -c "
import json
with open('$METRICS_FILE', 'r') as f:
    data = json.load(f)
    print('  Timestamp:', data.get('timestamp', 'N/A'))
    metrics = data.get('metrics', {})
    for name, value in metrics.items():
        print(f'  {name}:', value)
"
    fi

    echo ""

    if [ -f "$ALERTS_FILE" ]; then
        local alert_count
        alert_count=$(python3 -c "import json; data=json.load(open('$ALERTS_FILE')); print(len([a for a in data.get('alerts', []) if a.get('status') == 'active']))")

        if [ "$alert_count" -gt 0 ]; then
            warn "$alert_count active alert(s):"
            python3 -c "
import json
with open('$ALERTS_FILE', 'r') as f:
    data = json.load(f)
    for alert in data.get('alerts', []):
        if alert.get('status') == 'active':
            print(f\"  [{alert['severity']}] {alert['message']}\")
"
        else
            success "No active alerts"
        fi
    fi
}

# List alerts
list_alerts() {
    if [ ! -f "$ALERTS_FILE" ]; then
        echo "No alerts file found"
        return
    fi

    python3 -c "
import json
with open('$ALERTS_FILE', 'r') as f:
    data = json.load(f)
    active = [a for a in data.get('alerts', []) if a.get('status') == 'active']
    print(f'Active Alerts: {len(active)}')
    for alert in active:
        print(f\"  ID: {alert['id']}\")
        print(f\"  Type: {alert['type']}\")
        print(f\"  Severity: {alert['severity']}\")
        print(f\"  Message: {alert['message']}\")
        print(f\"  Time: {alert['timestamp']}\")
        print()
"
}

# Resolve alert
resolve_alert() {
    local alert_id="$1"

    log "Resolving alert: $alert_id"

    python3 <<EOF
import json

with open('$ALERTS_FILE', 'r') as f:
    data = json.load(f)

found = False
for alert in data.get('alerts', []):
    if alert.get('id') == '$alert_id':
        alert['status'] = 'resolved'
        data['resolved'].append(alert)
        found = True
        break

if found:
    # Remove from active alerts
    data['alerts'] = [a for a in data['alerts'] if a.get('id') != '$alert_id']
    
    # Save
    import tempfile, shutil
    with tempfile.NamedTemporaryFile(mode='w', delete=False, dir='$KNOWLEDGE_DIR') as tmp:
        json.dump(data, tmp, indent=2)
        tmp_path = tmp.name
    shutil.move(tmp_path, '$ALERTS_FILE')
    print('Alert resolved')
else:
    print('Alert not found')
EOF
}

# Main command dispatcher
case "${1:-help}" in
init)
    initialize_monitoring
    ;;
run)
    run_all_monitors
    ;;
watch)
    watch_mode
    ;;
status)
    show_status
    ;;
alerts)
    list_alerts
    ;;
resolve)
    if [ $# -lt 2 ]; then
        error "Usage: proactive_monitor.sh resolve <alert_id>"
        exit 1
    fi
    resolve_alert "$2"
    ;;
help | --help | -h)
    cat <<EOF
Proactive Monitoring System - Prevent Issues Before They Occur

Usage: proactive_monitor.sh <command> [arguments]

Commands:
  init       Initialize monitoring system
  run        Run all monitors once
  watch      Continuous monitoring (every ${MONITOR_INTERVAL}s)
  status     Show current status and metrics
  alerts     List active alerts
  resolve    Resolve an alert by ID
  help       Show this help message

Examples:
  # Initialize
  proactive_monitor.sh init
  
  # Run once
  proactive_monitor.sh run
  
  # Continuous monitoring
  proactive_monitor.sh watch
  
  # Check status
  proactive_monitor.sh status
  
  # Resolve alert
  proactive_monitor.sh resolve alert_id

Environment Variables:
  MONITOR_INTERVAL               Monitoring interval in seconds (default: 300)
  COMPLEXITY_THRESHOLD           Complexity alert threshold (default: 15)
  COVERAGE_DROP_THRESHOLD        Coverage drop % threshold (default: 5)
  BUILD_TIME_INCREASE_THRESHOLD  Build time increase % (default: 20)
  ERROR_RATE_THRESHOLD           Daily error count threshold (default: 10)
  DEPENDENCY_AGE_THRESHOLD       Dependency age in days (default: 90)
EOF
    ;;
*)
    error "Unknown command: $1"
    echo "Run 'proactive_monitor.sh help' for usage information"
    exit 1
    ;;
esac

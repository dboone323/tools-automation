#!/usr/bin/env bash
# Monitoring Daemon - Continuous metrics collection for agent system
# Runs as background service collecting metrics at regular intervals

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METRICS_COLLECTOR="${SCRIPT_DIR}/metrics_collector.py"
AGENT_STATUS_FILE="${SCRIPT_DIR}/../config/agent_status.json"
PID_FILE="${SCRIPT_DIR}/monitoring_daemon.pid"
LOG_FILE="${SCRIPT_DIR}/monitoring_daemon.log"

# Configuration
COLLECTION_INTERVAL="${MONITORING_INTERVAL:-60}"  # Default: collect every 60 seconds
ANOMALY_CHECK_INTERVAL="${ANOMALY_INTERVAL:-300}" # Default: check anomalies every 5 minutes

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Check if daemon is already running
if [[ -f "$PID_FILE" ]]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        log "⚠️  Monitoring daemon already running (PID: $OLD_PID)"
        exit 1
    else
        log "🔄 Removing stale PID file"
        rm -f "$PID_FILE"
    fi
fi

# Trap to handle shutdown
cleanup() {
    log "🛑 Shutting down monitoring daemon (PID: $$)"
    rm -f "$PID_FILE"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Write PID file
echo $$ > "$PID_FILE"
log "🚀 Starting monitoring daemon (PID: $$, interval: ${COLLECTION_INTERVAL}s)"

# Counter for anomaly checks
anomaly_check_counter=0

# Main monitoring loop
while true; do
    # Collect metrics
    if [[ -f "$METRICS_COLLECTOR" ]]; then
        if python3 "$METRICS_COLLECTOR" --agent-status "$AGENT_STATUS_FILE" --collect >> "$LOG_FILE" 2>&1; then
            log "✅ Metrics collected"
        else
            log "❌ Failed to collect metrics"
        fi
    else
        log "⚠️  Metrics collector not found: $METRICS_COLLECTOR"
    fi
    
    # Check for anomalies periodically
    ((anomaly_check_counter += COLLECTION_INTERVAL))
    if [[ $anomaly_check_counter -ge $ANOMALY_CHECK_INTERVAL ]]; then
        log "🔍 Checking for anomalies..."
        if python3 "$METRICS_COLLECTOR" --detect-anomalies >> "$LOG_FILE" 2>&1; then
            log "✅ Anomaly detection complete"
        else
            log "⚠️  Anomaly detection failed"
        fi
        anomaly_check_counter=0
    fi
    
    # Sleep until next collection
    sleep "$COLLECTION_INTERVAL"
done

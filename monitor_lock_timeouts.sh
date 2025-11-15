#!/bin/bash

# Monitor Lock Timeouts Agent
# Monitors file locks and detects timeout situations

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/logs/monitor_lock_timeouts.log"
STATUS_FILE="${SCRIPT_DIR}/status/monitor_lock_timeouts.status"
LOCK_DIR="${SCRIPT_DIR}/locks"
TIMEOUT_THRESHOLD=300 # 5 minutes

# Create directories
mkdir -p "${SCRIPT_DIR}/logs"
mkdir -p "${SCRIPT_DIR}/status"
mkdir -p "${LOCK_DIR}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "${LOG_FILE}"
}

update_status() {
    echo "$*" >"${STATUS_FILE}"
}

check_lock_timeouts() {
    log "Checking for lock timeouts..."

    local timeout_count;

    timeout_count=0
    local current_time;
    current_time=$(date +%s)

    # Check all lock files
    for lock_file in "${LOCK_DIR}"/*.lock; do
        if [[ -f "${lock_file}" ]]; then
            local lock_time;
            lock_time=$(stat -f %m "${lock_file}" 2>/dev/null || stat -c %Y "${lock_file}" 2>/dev/null || echo "0")
            local age;
            age=$((current_time - lock_time))

            if [[ ${age} -gt ${TIMEOUT_THRESHOLD} ]]; then
                log "WARNING: Lock file ${lock_file} is ${age} seconds old (timeout: ${TIMEOUT_THRESHOLD})"
                timeout_count=$((timeout_count + 1))

                # Attempt to clean up stale lock
                if rm -f "${lock_file}" 2>/dev/null; then
                    log "Cleaned up stale lock: ${lock_file}"
                else
                    log "ERROR: Failed to clean up stale lock: ${lock_file}"
                fi
            fi
        fi
    done

    if [[ ${timeout_count} -eq 0 ]]; then
        log "No lock timeouts detected"
        update_status "HEALTHY: No lock timeouts"
    else
        log "Found ${timeout_count} lock timeouts"
        update_status "WARNING: ${timeout_count} lock timeouts detected"
    fi

    return ${timeout_count}
}

monitor_active_locks() {
    log "Monitoring active locks..."

    local active_locks;

    active_locks=$(find "${LOCK_DIR}" -name "*.lock" -type f 2>/dev/null | wc -l | tr -d ' ')

    log "Currently ${active_locks} active lock files"

    if [[ ${active_locks} -gt 10 ]]; then
        log "WARNING: High number of active locks (${active_locks})"
        update_status "WARNING: ${active_locks} active locks"
    else
        log "Normal number of active locks"
    fi
}

prevent_deadlocks() {
    log "Checking for potential deadlock conditions..."

    # Simple deadlock prevention: check for locks held too long
    local old_locks;
    old_locks=$(find "${LOCK_DIR}" -name "*.lock" -type f -mmin +10 2>/dev/null | wc -l | tr -d ' ')

    if [[ ${old_locks} -gt 0 ]]; then
        log "WARNING: ${old_locks} locks older than 10 minutes - potential deadlock risk"
        update_status "WARNING: Potential deadlock risk (${old_locks} old locks)"
    else
        log "No deadlock risk detected"
    fi
}

# Source shared functions
if [[ -f "${SCRIPT_DIR}/shared_functions.sh" ]]; then
    source "${SCRIPT_DIR}/shared_functions.sh"
fi

# Main monitoring loop
main() {
    log "Starting lock timeout monitoring"

    while true; do
        check_lock_timeouts
        monitor_active_locks
        prevent_deadlocks

        # Wait before next check
        sleep 60
    done
}

# If run directly, start monitoring
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

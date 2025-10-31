#!/bin/bash

# 🧠 Simplified Error Learning Agent - Learns from every error without complex dependencies
# This agent monitors all other agents and builds an error knowledge base

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_NAME="error_learning_agent"
LOG_FILE="${SCRIPT_DIR}/${AGENT_NAME}.log"
KNOWLEDGE_DIR="${SCRIPT_DIR}/knowledge"
ERROR_DB="${KNOWLEDGE_DIR}/error_patterns.json"
LEARNING_MODEL="${KNOWLEDGE_DIR}/learning_model.json"

# Create knowledge directory structure
mkdir -p "${KNOWLEDGE_DIR}"/{patterns,fixes,analysis,predictions}

# Simple log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] $*" | tee -a "${LOG_FILE}"
}

# Initialize knowledge base
initialize() {
    log "Initializing knowledge base..."

    if [[ ! -f "${ERROR_DB}" ]]; then
        echo '{"version":"1.0","error_patterns":[],"last_updated":""}' >"${ERROR_DB}"
    fi

    if [[ ! -f "${LEARNING_MODEL}" ]]; then
        echo '{"version":"1.0","model_stats":{"total_errors_learned":0,"total_fixes_recorded":0},"last_trained":""}' >"${LEARNING_MODEL}"
    fi

    log "Knowledge base ready"
}

# Extract error from log line
extract_error() {
    local line="$1"

    # Simple pattern matching for errors
    if echo "${line}" | grep -qiE '(ERROR|FAILED|exception|fatal)'; then
        # Extract basic info using Python
        python3 <<EOF
import re, json, hashlib, sys
from datetime import datetime

line = '''${line}'''

# Extract timestamp
ts = re.search(r'\[([\d\-:\s]+)\]', line)
timestamp = ts.group(1) if ts else datetime.now().isoformat()

# Extract agent name
agent = re.search(r'\[([\w_]+)\]', line)
agent_name = agent.group(1) if agent else "unknown"

# Extract message
msg = line.split(']')[-1].strip() if ']' in line else line

# Generate hash
error_hash = hashlib.md5(f"{agent_name}:{msg}".encode()).hexdigest()[:12]

error_pattern = {
    "timestamp": timestamp,
    "agent": agent_name,
    "message": msg[:200],
    "hash": error_hash,
    "first_seen": datetime.now().isoformat(),
    "frequency": 1
}

print(json.dumps(error_pattern))
EOF
    fi
}

# Record error to database
record_error() {
    local error_json="$1"

    python3 <<EOF
import json
from datetime import datetime

error = json.loads('''${error_json}''')
db_path = "${ERROR_DB}"
model_path = "${LEARNING_MODEL}"

# Load database
try:
    with open(db_path, 'r') as f:
        db = json.load(f)
except:
    db = {"version":"1.0","error_patterns":[],"last_updated":""}

# Check for existing pattern
error_hash = error.get("hash")
existing = [e for e in db["error_patterns"] if e.get("hash") == error_hash]

if existing:
    existing[0]["frequency"] = existing[0].get("frequency", 1) + 1
    existing[0]["last_seen"] = datetime.now().isoformat()
    print(f"Updated: {error_hash}")
else:
    error["first_seen"] = datetime.now().isoformat()
    error["frequency"] = 1
    db["error_patterns"].append(error)
    print(f"New: {error_hash}")

db["last_updated"] = datetime.now().isoformat()

# Save database
with open(db_path, 'w') as f:
    json.dump(db, f, indent=2)

# Update learning model
try:
    with open(model_path, 'r') as f:
        model = json.load(f)
except:
    model = {"version":"1.0","model_stats":{"total_errors_learned":0},"last_trained":""}

model["model_stats"]["total_errors_learned"] = len(db["error_patterns"])
model["last_trained"] = datetime.now().isoformat()

with open(model_path, 'w') as f:
    json.dump(model, f, indent=2)
EOF
}

# Monitor a single log file
monitor_log() {
    local log_file="$1"
    local pos_file
    pos_file="${KNOWLEDGE_DIR}/.pos_$(basename "${log_file}")"

    # Get last position
    local last_pos=0
    if [[ -f "${pos_file}" ]]; then
        last_pos=$(cat "${pos_file}")
    fi

    # Get current size
    local current_size
    current_size=$(wc -c <"${log_file}" 2>/dev/null || echo "0")

    if [[ ${current_size} -gt ${last_pos} ]]; then
        # Read new content
        tail -c "+$((last_pos + 1))" "${log_file}" 2>/dev/null | while IFS= read -r line; do
            local error_json
            error_json=$(extract_error "${line}")

            if [[ -n "${error_json}" ]] && [[ "${error_json}" != "null" ]]; then
                log "Detected error in $(basename "${log_file}")"
                record_error "${error_json}"
            fi
        done

        # Update position
        echo "${current_size}" >"${pos_file}"
    fi
}

# Scan all logs
scan_logs() {
    local scanned=0

    for log_file in "${SCRIPT_DIR}"/*.log; do
        if [[ -f "${log_file}" ]] && [[ "${log_file}" != "${LOG_FILE}" ]]; then
            monitor_log "${log_file}"
            ((scanned++))
        fi
    done

    # Report stats every 10 iterations
    if ((iteration % 10 == 0)); then
        local total_errors
        total_errors=$(python3 -c "import json; print(len(json.load(open('${ERROR_DB}'))['error_patterns']))" 2>/dev/null || echo "0")
        log "Status: Scanned ${scanned} logs, learned ${total_errors} unique errors"
    fi
}

# Main loop
main() {
    log "Error Learning Agent started (simple mode)"

    initialize

    # Create PID file
    echo $$ >"${SCRIPT_DIR}/.error_learning_agent.pid"

    iteration=0

    while true; do
        ((iteration++))

        # Scan logs
        scan_logs

        # Sleep
        sleep 30
    done
}

# Cleanup on exit
cleanup() {
    log "Shutting down gracefully"
    rm -f "${SCRIPT_DIR}/.error_learning_agent.pid"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Run
main

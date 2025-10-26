#!/bin/bash

# 🧠 Error Learning Agent v2 - Production Ready
# Monitors agent logs and learns from errors without repeating them

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_NAME="error_learning_agent"
LOG_FILE="${SCRIPT_DIR}/${AGENT_NAME}.log"
KNOWLEDGE_DIR="${SCRIPT_DIR}/knowledge"
ERROR_DB="${KNOWLEDGE_DIR}/error_patterns.json"
LEARNING_MODEL="${KNOWLEDGE_DIR}/learning_model.json"

# Create directories
mkdir -p "${KNOWLEDGE_DIR}"

# Simple log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] $*" | tee -a "${LOG_FILE}"
}

# Initialize knowledge base
initialize() {
    log "Initializing knowledge base..."

    if [[ ! -f "${ERROR_DB}" ]]; then
        cat >"${ERROR_DB}" <<'JSONEOF'
{
  "version": "1.0",
  "error_patterns": [],
  "last_updated": ""
}
JSONEOF
    fi

    if [[ ! -f "${LEARNING_MODEL}" ]]; then
        cat >"${LEARNING_MODEL}" <<'JSONEOF'
{
  "version": "1.0",
  "model_stats": {
    "total_errors_learned": 0,
    "scans_completed": 0
  },
  "last_trained": ""
}
JSONEOF
    fi

    log "Knowledge base ready"
}

# Simple error detection and recording (avoiding JSON parsing in bash)
record_error_simple() {
    local agent_name="$1"
    local error_msg="$2"
    local timestamp="$3"

    # Use Python to safely handle JSON
    python3 - <<PYEOF
import json
import hashlib
from datetime import datetime

agent = "${agent_name}"
message = """${error_msg}"""
timestamp = "${timestamp}"

# Sanitize message
message = message.replace('"', "'").replace('\\n', ' ').replace('\\t', ' ')[:200]

# Generate hash
error_hash = hashlib.md5(f"{agent}:{message}".encode()).hexdigest()[:12]

# Load database
try:
    with open("${ERROR_DB}", 'r') as f:
        db = json.load(f)
except:
    db = {"version":"1.0","error_patterns":[],"last_updated":""}

# Check for existing
existing = None
for pattern in db["error_patterns"]:
    if pattern.get("hash") == error_hash:
        existing = pattern
        break

if existing:
    existing["frequency"] = existing.get("frequency", 1) + 1
    existing["last_seen"] = datetime.now().isoformat()
else:
    new_pattern = {
        "hash": error_hash,
        "agent": agent,
        "message": message,
        "timestamp": timestamp,
        "first_seen": datetime.now().isoformat(),
        "frequency": 1
    }
    db["error_patterns"].append(new_pattern)

db["last_updated"] = datetime.now().isoformat()

# Save
with open("${ERROR_DB}", 'w') as f:
    json.dump(db, f, indent=2)

# Update model
try:
    with open("${LEARNING_MODEL}", 'r') as f:
        model = json.load(f)
except:
    model = {"version":"1.0","model_stats":{"total_errors_learned":0,"scans_completed":0},"last_trained":""}

model["model_stats"]["total_errors_learned"] = len(db["error_patterns"])
model["last_trained"] = datetime.now().isoformat()

with open("${LEARNING_MODEL}", 'w') as f:
    json.dump(model, f, indent=2)

print(f"Recorded: {error_hash}")
PYEOF
}

# Monitor logs
scan_logs() {
    local scanned=0
    local new_errors=0

    for log_file in "${SCRIPT_DIR}"/*.log; do
        # Skip our own log and non-existent files
        if [[ ! -f "${log_file}" ]] || [[ "${log_file}" == "${LOG_FILE}" ]]; then
            continue
        fi

        # Track position
        local pos_file="${KNOWLEDGE_DIR}/.pos_$(basename "${log_file}" .log)"
        local last_pos=0
        if [[ -f "${pos_file}" ]]; then
            last_pos=$(cat "${pos_file}" 2>/dev/null || echo "0")
        fi

        # Get current size
        local current_size
        current_size=$(stat -f%z "${log_file}" 2>/dev/null || echo "0")

        if [[ ${current_size} -gt ${last_pos} ]]; then
            # Read new lines
            tail -c "+$((last_pos + 1))" "${log_file}" 2>/dev/null | grep -iE '(ERROR|FAILED|exception|fatal|critical)' | while IFS= read -r line; do
                # Extract agent name from filename
                local agent_from_file
                agent_from_file=$(basename "${log_file}" .log)

                # Extract timestamp (or use current)
                local ts
                ts=$(echo "${line}" | grep -oE '\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\]' | tr -d '[]' || date '+%Y-%m-%d %H:%M:%S')

                # Extract message (everything after last ])
                local msg
                msg=$(echo "${line}" | awk -F']' '{print $NF}' | sed 's/^[ \t]*//')

                if [[ -n "${msg}" ]]; then
                    record_error_simple "${agent_from_file}" "${msg}" "${ts}"
                    ((new_errors++))
                fi
            done

            # Update position
            echo "${current_size}" >"${pos_file}"
        fi

        ((scanned++))
    done

    # Update scan count
    python3 - <<PYEOF
import json
try:
    with open("${LEARNING_MODEL}", 'r') as f:
        model = json.load(f)
    model["model_stats"]["scans_completed"] = model["model_stats"].get("scans_completed", 0) + 1
    with open("${LEARNING_MODEL}", 'w') as f:
        json.dump(model, f, indent=2)
except:
    pass
PYEOF

    return 0
}

# Main loop
main() {
    log "Error Learning Agent v2 started"

    initialize

    # Create PID file
    echo $$ >"${SCRIPT_DIR}/.error_learning_agent.pid"

    local iteration=0

    while true; do
        ((iteration++))

        # Scan logs
        scan_logs

        # Report stats every 10 iterations
        if ((iteration % 10 == 0)); then
            local total_errors
            total_errors=$(python3 -c "import json; print(len(json.load(open('${ERROR_DB}'))['error_patterns']))" 2>/dev/null || echo "0")
            local scans
            scans=$(python3 -c "import json; print(json.load(open('${LEARNING_MODEL}'))['model_stats']['scans_completed'])" 2>/dev/null || echo "0")
            log "Stats: ${scans} scans, ${total_errors} unique errors learned"
        fi

        # Sleep
        sleep 30
    done
}

# Cleanup
cleanup() {
    log "Shutting down"
    rm -f "${SCRIPT_DIR}/.error_learning_agent.pid"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Run
main

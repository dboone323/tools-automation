#!/bin/bash

# 🧠 Error Learning Agent - Learns from every error to prevent recurrence
# This agent monitors all other agents and builds an error knowledge base

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Source shared functions
source "${SCRIPT_DIR}/shared_functions.sh"

# Configuration
AGENT_NAME="error_learning_agent"
LOG_FILE="${SCRIPT_DIR}/${AGENT_NAME}.log"
KNOWLEDGE_DIR="${SCRIPT_DIR}/knowledge"
ERROR_DB="${KNOWLEDGE_DIR}/error_patterns.json"
FIX_HISTORY="${KNOWLEDGE_DIR}/fix_history.json"
CORRELATION_MATRIX="${KNOWLEDGE_DIR}/correlation_matrix.json"
LEARNING_MODEL="${KNOWLEDGE_DIR}/learning_model.json"

# Create knowledge directory structure
mkdir -p "${KNOWLEDGE_DIR}"/{patterns,fixes,analysis,predictions}

# Initialize knowledge base if not exists
initialize_knowledge_base() {
    if [[ ! -f "${ERROR_DB}" ]]; then
        cat >"${ERROR_DB}" <<'EOF'
{
  "version": "1.0",
  "error_patterns": [],
  "categories": {
    "build": [],
    "test": [],
    "deploy": [],
    "code_quality": [],
    "dependency": [],
    "runtime": []
  },
  "severity_index": {},
  "frequency_tracker": {},
  "last_updated": ""
}
EOF
    fi

    if [[ ! -f "${FIX_HISTORY}" ]]; then
        cat >"${FIX_HISTORY}" <<'EOF'
{
  "version": "1.0",
  "successful_fixes": [],
  "failed_attempts": [],
  "fix_strategies": {},
  "success_rates": {},
  "avg_resolution_times": {},
  "last_updated": ""
}
EOF
    fi

    if [[ ! -f "${CORRELATION_MATRIX}" ]]; then
        cat >"${CORRELATION_MATRIX}" <<'EOF'
{
  "version": "1.0",
  "error_to_fix": {},
  "agent_to_error": {},
  "context_correlations": {},
  "temporal_patterns": {},
  "last_updated": ""
}
EOF
    fi

    if [[ ! -f "${LEARNING_MODEL}" ]]; then
        cat >"${LEARNING_MODEL}" <<'EOF'
{
  "version": "1.0",
  "model_stats": {
    "total_errors_learned": 0,
    "total_fixes_recorded": 0,
    "accuracy_rate": 0.0,
    "learning_velocity": 0.0
  },
  "predictions": {
    "enabled": true,
    "confidence_threshold": 0.7
  },
  "last_trained": ""
}
EOF
    fi
}

# Log with structured format
log_learning() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] [${level}] ${message}" >>"${LOG_FILE}"
}

# Extract error from log entry
extract_error_pattern() {
    local log_entry="$1"

    # Use Python for robust extraction
    python3 <<EOF
import re
import json
import sys

log_entry = """$log_entry"""

# Extract error patterns
error_pattern = {
    "timestamp": "",
    "agent": "",
    "error_type": "",
    "error_message": "",
    "context": "",
    "severity": "unknown",
    "hash": ""
}

# Extract timestamp
ts_match = re.search(r'\[([\d\-:\s]+)\]', log_entry)
if ts_match:
    error_pattern["timestamp"] = ts_match.group(1)

# Extract agent name
agent_match = re.search(r'\[([\w_]+_agent)\]', log_entry)
if agent_match:
    error_pattern["agent"] = agent_match.group(1)

# Extract error type and message
if "ERROR" in log_entry or "FAILED" in log_entry:
    error_pattern["severity"] = "high"
    error_pattern["error_type"] = "execution_failure"
    
    # Extract message after ERROR tag
    msg_match = re.search(r'\[ERROR\]\s+(.+?)(?:\s*$)', log_entry)
    if msg_match:
        error_pattern["error_message"] = msg_match.group(1).strip()

elif "WARN" in log_entry:
    error_pattern["severity"] = "medium"
    error_pattern["error_type"] = "warning"
    msg_match = re.search(r'\[WARN\]\s+(.+?)(?:\s*$)', log_entry)
    if msg_match:
        error_pattern["error_message"] = msg_match.group(1).strip()

# Generate hash for deduplication
import hashlib
hash_str = f"{error_pattern['agent']}:{error_pattern['error_type']}:{error_pattern['error_message']}"
error_pattern["hash"] = hashlib.md5(hash_str.encode()).hexdigest()[:12]

print(json.dumps(error_pattern, indent=2))
EOF
}

# Record error pattern to knowledge base
record_error() {
    local error_json="$1"

    # Use Python to safely update JSON
    python3 <<EOF
import json
import sys
from datetime import datetime

error_pattern = json.loads('''${error_json}''')
error_db_path = "${ERROR_DB}"

# Load existing database
with open(error_db_path, 'r') as f:
    db = json.load(f)

# Check if we've seen this error before
error_hash = error_pattern.get("hash", "")
existing = [e for e in db["error_patterns"] if e.get("hash") == error_hash]

if existing:
    # Update frequency
    existing[0]["frequency"] = existing[0].get("frequency", 1) + 1
    existing[0]["last_seen"] = datetime.now().isoformat()
    print(f"Updated existing pattern: {error_hash}")
else:
    # Add new pattern
    error_pattern["first_seen"] = datetime.now().isoformat()
    error_pattern["frequency"] = 1
    db["error_patterns"].append(error_pattern)
    print(f"Recorded new pattern: {error_hash}")

# Update category index
category = error_pattern.get("error_type", "unknown")
if category not in db["categories"]:
    db["categories"][category] = []
if error_hash not in db["categories"][category]:
    db["categories"][category].append(error_hash)

# Update frequency tracker
db["frequency_tracker"][error_hash] = error_pattern.get("frequency", 1)

# Update timestamp
db["last_updated"] = datetime.now().isoformat()

# Save updated database
with open(error_db_path, 'w') as f:
    json.dump(db, f, indent=2)

# Update learning stats
model_path = "${LEARNING_MODEL}"
with open(model_path, 'r') as f:
    model = json.load(f)

model["model_stats"]["total_errors_learned"] += 1
model["last_trained"] = datetime.now().isoformat()

with open(model_path, 'w') as f:
    json.dump(model, f, indent=2)

sys.exit(0)
EOF
}

# Monitor agent logs for errors
monitor_agent_logs() {
    local agent_log="$1"

    if [[ ! -f "${agent_log}" ]]; then
        return 0
    fi

    # Get new entries since last check
    local last_pos_file="${KNOWLEDGE_DIR}/.monitor_pos_$(basename "${agent_log}")"
    local last_pos=0

    if [[ -f "${last_pos_file}" ]]; then
        last_pos=$(cat "${last_pos_file}")
    fi

    local current_size
    current_size=$(wc -c <"${agent_log}")

    if [[ ${current_size} -gt ${last_pos} ]]; then
        # Read new content
        tail -c "+$((last_pos + 1))" "${agent_log}" | while IFS= read -r line; do
            # Check for error indicators
            if echo "${line}" | grep -qiE '(ERROR|FAILED|exception|fatal|critical)'; then
                log_learning "INFO" "Detected error in $(basename "${agent_log}")"

                # Extract and record error pattern
                local error_pattern
                error_pattern=$(extract_error_pattern "${line}")

                if [[ -n "${error_pattern}" ]]; then
                    record_error "${error_pattern}"
                    log_learning "SUCCESS" "Learned new error pattern"
                fi
            fi
        done

        # Update position
        echo "${current_size}" >"${last_pos_file}"
    fi
}

# Scan all agent logs
scan_all_logs() {
    log_learning "INFO" "Scanning all agent logs for errors..."

    local logs_scanned=0
    local errors_found=0

    for log_file in "${SCRIPT_DIR}"/*.log; do
        if [[ -f "${log_file}" ]] && [[ "${log_file}" != "${LOG_FILE}" ]]; then
            monitor_agent_logs "${log_file}"
            ((logs_scanned++))
        fi
    done

    log_learning "INFO" "Scanned ${logs_scanned} agent logs"
}

# Analyze error patterns and suggest improvements
analyze_patterns() {
    log_learning "INFO" "Analyzing error patterns..."

    python3 <<'ANALYSIS_SCRIPT'
import json
from collections import Counter
from datetime import datetime, timedelta

error_db_path = "${ERROR_DB}"
fix_history_path = "${FIX_HISTORY}"

with open(error_db_path, 'r') as f:
    error_db = json.load(f)

# Find most frequent errors
patterns = error_db.get("error_patterns", [])
if not patterns:
    print("No error patterns yet")
    exit(0)

# Analyze frequency
freq_dist = Counter()
for pattern in patterns:
    error_hash = pattern.get("hash", "unknown")
    freq = pattern.get("frequency", 0)
    freq_dist[error_hash] = freq

print("\n=== Top 5 Most Frequent Errors ===")
for error_hash, count in freq_dist.most_common(5):
    # Find pattern details
    pattern = next((p for p in patterns if p.get("hash") == error_hash), None)
    if pattern:
        print(f"  {count}x - {pattern.get('agent', 'unknown')}: {pattern.get('error_message', 'N/A')[:60]}")

# Analyze by agent
agent_errors = Counter()
for pattern in patterns:
    agent = pattern.get("agent", "unknown")
    agent_errors[agent] += 1

print("\n=== Errors by Agent ===")
for agent, count in agent_errors.most_common(10):
    print(f"  {agent}: {count} errors")

# Find recurring issues (errors seen in last hour)
recent_threshold = datetime.now() - timedelta(hours=1)
recent_errors = []
for pattern in patterns:
    last_seen_str = pattern.get("last_seen", "")
    if last_seen_str:
        try:
            last_seen = datetime.fromisoformat(last_seen_str)
            if last_seen >= recent_threshold:
                recent_errors.append(pattern)
        except:
            pass

if recent_errors:
    print(f"\n=== Recent Errors (last hour): {len(recent_errors)} ===")
    for err in recent_errors[:5]:
        print(f"  [{err.get('agent')}] {err.get('error_message', 'N/A')[:60]}")

ANALYSIS_SCRIPT
}

# Generate insights and recommendations
generate_insights() {
    log_learning "INFO" "Generating insights..."

    local insight_file="${KNOWLEDGE_DIR}/analysis/insights_$(date +%Y%m%d_%H%M%S).txt"

    cat >"${insight_file}" <<EOF
# Error Learning Insights - $(date)

## Knowledge Base Status
$(python3 -c "
import json
with open('${ERROR_DB}', 'r') as f:
    db = json.load(f)
print(f'Total Patterns: {len(db.get(\"error_patterns\", []))}')
print(f'Categories: {len(db.get(\"categories\", {}))}')
")

## Pattern Analysis
$(analyze_patterns)

## Recommendations
- Review top recurring errors for systematic fixes
- Update agent error handling for frequent patterns
- Consider automated prevention strategies
- Share learnings across similar agents

EOF

    log_learning "SUCCESS" "Generated insights: ${insight_file}"
}

# Main learning loop
main() {
    log_learning "INFO" "Error Learning Agent started"

    # Initialize knowledge base
    initialize_knowledge_base

    # Update agent status
    update_agent_status "${AGENT_NAME}" "active" "$$"

    local iteration=0

    while true; do
        ((iteration++))
        log_learning "INFO" "Learning iteration ${iteration}"

        # Scan all agent logs
        scan_all_logs

        # Every 10 iterations, do deep analysis
        if ((iteration % 10 == 0)); then
            analyze_patterns
            generate_insights
        fi

        # Sleep for 30 seconds
        sleep 30
    done
}

# Signal handlers
trap 'log_learning "INFO" "Shutting down gracefully"; update_agent_status "${AGENT_NAME}" "stopped" "$$"; exit 0' SIGTERM SIGINT

# Run main loop
main

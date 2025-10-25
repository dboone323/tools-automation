#!/bin/bash

# Emergency Response System
# Handles critical failures with escalation and safe-mode protocols

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
KNOWLEDGE_DIR="$SCRIPT_DIR/knowledge"
EMERGENCIES_FILE="$KNOWLEDGE_DIR/emergencies.json"
ESCALATIONS_FILE="$KNOWLEDGE_DIR/escalations.json"
SAFE_MODE_FLAG="$SCRIPT_DIR/.safe_mode"

# Escalation timing (seconds)
LEVEL1_TIMEOUT="${LEVEL1_TIMEOUT:-120}" # 2 minutes
LEVEL2_TIMEOUT="${LEVEL2_TIMEOUT:-300}" # 5 minutes
LEVEL3_TIMEOUT="${LEVEL3_TIMEOUT:-600}" # 10 minutes
LEVEL4_TIMEOUT="${LEVEL4_TIMEOUT:-900}" # 15 minutes

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[Emergency Response] $(date '+%Y-%m-%d %H:%M:%S') - $*${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[Emergency Response] $(date '+%Y-%m-%d %H:%M:%S') - WARNING: $*${NC}" >&2
}

error() {
    echo -e "${RED}[Emergency Response] $(date '+%Y-%m-%d %H:%M:%S') - ERROR: $*${NC}" >&2
}

critical() {
    echo -e "${MAGENTA}[Emergency Response] $(date '+%Y-%m-%d %H:%M:%S') - CRITICAL: $*${NC}" >&2
}

success() {
    echo -e "${GREEN}[Emergency Response] $(date '+%Y-%m-%d %H:%M:%S') - $*${NC}" >&2
}

# Initialize emergency response system
initialize_emergency_system() {
    log "Initializing emergency response system..."

    mkdir -p "$KNOWLEDGE_DIR"

    # Initialize emergencies file
    if [ ! -f "$EMERGENCIES_FILE" ]; then
        cat >"$EMERGENCIES_FILE" <<EOF
{
  "active_emergencies": [],
  "resolved_emergencies": [],
  "severity_levels": {
    "critical": {
      "description": "System down, data loss risk",
      "max_duration": 120,
      "requires_human": true
    },
    "high": {
      "description": "Feature broken, blocking development",
      "max_duration": 600,
      "requires_human": false
    },
    "medium": {
      "description": "Degraded performance, workarounds exist",
      "max_duration": 1800,
      "requires_human": false
    },
    "low": {
      "description": "Minor issue, scheduled fix acceptable",
      "max_duration": 86400,
      "requires_human": false
    }
  }
}
EOF
    fi

    # Initialize escalations file
    if [ ! -f "$ESCALATIONS_FILE" ]; then
        cat >"$ESCALATIONS_FILE" <<EOF
{
  "escalations": [],
  "escalation_ladder": {
    "level1": {
      "name": "Agent Auto-Fix",
      "timeout": $LEVEL1_TIMEOUT,
      "actions": ["auto_fix", "retry", "alternative_strategy"]
    },
    "level2": {
      "name": "Alternative Strategy",
      "timeout": $LEVEL2_TIMEOUT,
      "actions": ["try_alternative", "rollback", "clean_environment"]
    },
    "level3": {
      "name": "Cross-Agent Consultation",
      "timeout": $LEVEL3_TIMEOUT,
      "actions": ["query_knowledge_base", "check_similar_issues", "coordinate_agents"]
    },
    "level4": {
      "name": "Human Notification",
      "timeout": $LEVEL4_TIMEOUT,
      "actions": ["notify_human", "create_ticket", "document_issue"]
    },
    "level5": {
      "name": "System Safe-Mode",
      "timeout": 0,
      "actions": ["enable_safe_mode", "halt_operations", "preserve_state"]
    }
  }
}
EOF
    fi

    success "Emergency response system initialized"
}

# Classify failure severity
classify_severity() {
    local error_message="$1"
    local context="${2:-}"

    # Critical keywords
    if echo "$error_message" | grep -qiE '(crash|segfault|data loss|corruption|security|breach)'; then
        echo "critical"
        return
    fi

    # High severity keywords
    if echo "$error_message" | grep -qiE '(build failed|compile error|blocking|cannot proceed)'; then
        echo "high"
        return
    fi

    # Medium severity keywords
    if echo "$error_message" | grep -qiE '(warning|deprecat|slow|timeout)'; then
        echo "medium"
        return
    fi

    # Default to low
    echo "low"
}

# Declare emergency
declare_emergency() {
    local error_message="$1"
    local severity="$2"
    local context="${3:-{}}"

    critical "Declaring $severity severity emergency: $error_message"

    local emergency_id="emerg_$(date +%Y%m%d%H%M%S)"

    # Record emergency
    python3 <<EOF
import json
from datetime import datetime

try:
    with open('$EMERGENCIES_FILE', 'r') as f:
        data = json.load(f)
except:
    data = {"active_emergencies": [], "resolved_emergencies": []}

emergency = {
    "id": "$emergency_id",
    "error": "$error_message",
    "severity": "$severity",
    "context": $context,
    "declared_at": datetime.now().isoformat(),
    "status": "active",
    "current_escalation_level": 1,
    "attempts": [],
    "resolution": None
}

data["active_emergencies"].append(emergency)

# Atomic write
import tempfile, shutil
with tempfile.NamedTemporaryFile(mode='w', delete=False, dir='$KNOWLEDGE_DIR') as tmp:
    json.dump(data, tmp, indent=2)
    tmp_path = tmp.name

shutil.move(tmp_path, '$EMERGENCIES_FILE')
print('$emergency_id')
EOF
}

# Handle emergency with escalation
handle_emergency() {
    local emergency_id="$1"

    log "Handling emergency: $emergency_id"

    # Get emergency details
    local emergency_json
    emergency_json=$(python3 -c "
import json
with open('$EMERGENCIES_FILE', 'r') as f:
    data = json.load(f)
    for e in data['active_emergencies']:
        if e['id'] == '$emergency_id':
            print(json.dumps(e))
            break
")

    if [ -z "$emergency_json" ]; then
        error "Emergency $emergency_id not found"
        return 1
    fi

    local severity
    severity=$(echo "$emergency_json" | python3 -c "import sys, json; print(json.load(sys.stdin)['severity'])")

    log "Emergency severity: $severity"

    # Start escalation ladder
    escalate_level "$emergency_id" 1
}

# Escalate to specific level
escalate_level() {
    local emergency_id="$1"
    local level="$2"

    log "Escalating to Level $level..."

    # Update emergency escalation level
    python3 <<EOF
import json
from datetime import datetime

with open('$EMERGENCIES_FILE', 'r') as f:
    data = json.load(f)

for emergency in data['active_emergencies']:
    if emergency['id'] == '$emergency_id':
        emergency['current_escalation_level'] = $level
        emergency['escalation_history'] = emergency.get('escalation_history', [])
        emergency['escalation_history'].append({
            'level': $level,
            'timestamp': datetime.now().isoformat()
        })
        break

# Save
import tempfile, shutil
with tempfile.NamedTemporaryFile(mode='w', delete=False, dir='$KNOWLEDGE_DIR') as tmp:
    json.dump(data, tmp, indent=2)
    tmp_path = tmp.name

shutil.move(tmp_path, '$EMERGENCIES_FILE')
EOF

    # Execute level actions
    case $level in
    1)
        escalate_level1 "$emergency_id"
        ;;
    2)
        escalate_level2 "$emergency_id"
        ;;
    3)
        escalate_level3 "$emergency_id"
        ;;
    4)
        escalate_level4 "$emergency_id"
        ;;
    5)
        escalate_level5 "$emergency_id"
        ;;
    *)
        error "Unknown escalation level: $level"
        ;;
    esac
}

# Level 1: Agent auto-fix
escalate_level1() {
    local emergency_id="$1"

    log "Level 1: Agent Auto-Fix (timeout: ${LEVEL1_TIMEOUT}s)"

    # Try automated fix
    log "Attempting automated fix..."

    # This would integrate with fix_suggester.py
    if [ -f "$SCRIPT_DIR/fix_suggester.py" ]; then
        local emergency_error
        emergency_error=$(python3 -c "
import json
with open('$EMERGENCIES_FILE', 'r') as f:
    data = json.load(f)
    for e in data['active_emergencies']:
        if e['id'] == '$emergency_id':
            print(e['error'])
            break
" 2>/dev/null || echo "Unknown error")

        # Try to get fix suggestion
        timeout ${LEVEL1_TIMEOUT} python3 "$SCRIPT_DIR/fix_suggester.py" suggest "$emergency_error" 2>&1 || true
    fi

    # Check if resolved
    if check_emergency_resolved "$emergency_id"; then
        success "Level 1 resolved emergency"
        return 0
    fi

    warn "Level 1 failed, escalating to Level 2"
    escalate_level "$emergency_id" 2
}

# Level 2: Alternative strategy
escalate_level2() {
    local emergency_id="$1"

    warn "Level 2: Alternative Strategy (timeout: ${LEVEL2_TIMEOUT}s)"

    log "Trying alternative approaches..."

    # Try rollback if checkpoint exists
    if [ -f "$SCRIPT_DIR/auto_rollback.sh" ]; then
        log "Attempting rollback..."
        "$SCRIPT_DIR/auto_rollback.sh" list | head -1 | grep -o 'checkpoint_[0-9_]*' | head -1 |
            xargs -I {} "$SCRIPT_DIR/auto_rollback.sh" restore {} 2>&1 || true
    fi

    # Check if resolved
    if check_emergency_resolved "$emergency_id"; then
        success "Level 2 resolved emergency"
        return 0
    fi

    warn "Level 2 failed, escalating to Level 3"
    escalate_level "$emergency_id" 3
}

# Level 3: Cross-agent consultation
escalate_level3() {
    local emergency_id="$1"

    warn "Level 3: Cross-Agent Consultation (timeout: ${LEVEL3_TIMEOUT}s)"

    log "Querying knowledge base and consulting other agents..."

    # Query knowledge sync
    if [ -f "$SCRIPT_DIR/knowledge_sync.sh" ]; then
        "$SCRIPT_DIR/knowledge_sync.sh" query global_patterns 2>&1 || true
    fi

    # Check context
    if [ -f "$SCRIPT_DIR/context_loader.sh" ]; then
        "$SCRIPT_DIR/context_loader.sh" summary 2>&1 || true
    fi

    # Check if resolved
    if check_emergency_resolved "$emergency_id"; then
        success "Level 3 resolved emergency"
        return 0
    fi

    warn "Level 3 failed, escalating to Level 4"
    escalate_level "$emergency_id" 4
}

# Level 4: Human notification
escalate_level4() {
    local emergency_id="$1"

    error "Level 4: Human Notification (timeout: ${LEVEL4_TIMEOUT}s)"

    log "Notifying human operator..."

    # Get emergency details
    python3 -c "
import json
with open('$EMERGENCIES_FILE', 'r') as f:
    data = json.load(f)
    for e in data['active_emergencies']:
        if e['id'] == '$emergency_id':
            print('=' * 60)
            print('EMERGENCY NOTIFICATION')
            print('=' * 60)
            print(f\"ID: {e['id']}\")
            print(f\"Severity: {e['severity']}\")
            print(f\"Error: {e['error']}\")
            print(f\"Time: {e['declared_at']}\")
            print(f\"Escalation Level: {e['current_escalation_level']}\")
            print('=' * 60)
            break
"

    # Create notification file
    local notification_file="$KNOWLEDGE_DIR/emergency_${emergency_id}.txt"
    python3 -c "
import json
with open('$EMERGENCIES_FILE', 'r') as f:
    data = json.load(f)
    for e in data['active_emergencies']:
        if e['id'] == '$emergency_id':
            with open('$notification_file', 'w') as nf:
                nf.write('EMERGENCY NOTIFICATION\\n')
                nf.write('=' * 60 + '\\n')
                nf.write(f\"ID: {e['id']}\\n\")
                nf.write(f\"Severity: {e['severity']}\\n\")
                nf.write(f\"Error: {e['error']}\\n\")
                nf.write(f\"Time: {e['declared_at']}\\n\")
                nf.write(f\"Attempts: {len(e.get('attempts', []))}\\n\")
                nf.write('=' * 60 + '\\n')
            break
"

    warn "Human notification created: $notification_file"
    warn "Waiting for human intervention or timeout..."

    # Wait for timeout
    sleep "$LEVEL4_TIMEOUT"

    # Check if resolved by human
    if check_emergency_resolved "$emergency_id"; then
        success "Level 4: Human resolved emergency"
        return 0
    fi

    critical "Level 4 timeout, escalating to Level 5 (Safe-Mode)"
    escalate_level "$emergency_id" 5
}

# Level 5: System safe-mode
escalate_level5() {
    local emergency_id="$1"

    critical "Level 5: System Safe-Mode - CRITICAL FAILURE"

    log "Enabling safe-mode..."

    # Enable safe mode flag
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" >"$SAFE_MODE_FLAG"

    # Halt all agent operations
    log "Halting agent operations..."

    # Preserve system state
    log "Preserving system state..."
    local state_snapshot="$KNOWLEDGE_DIR/safe_mode_snapshot_$(date +%Y%m%d%H%M%S).json"

    python3 <<EOF
import json
from datetime import datetime

state = {
    "timestamp": datetime.now().isoformat(),
    "emergency_id": "$emergency_id",
    "safe_mode_reason": "Emergency escalation to Level 5",
    "preserved_files": []
}

# List important files to preserve
import os
for root, dirs, files in os.walk('$KNOWLEDGE_DIR'):
    for file in files:
        if file.endswith('.json'):
            state["preserved_files"].append(os.path.join(root, file))

with open('$state_snapshot', 'w') as f:
    json.dump(state, f, indent=2)
EOF

    critical "System is now in SAFE-MODE"
    critical "State snapshot: $state_snapshot"
    critical "Manual intervention required to exit safe-mode"

    # Mark emergency as requiring human intervention
    python3 <<EOF
import json
from datetime import datetime

with open('$EMERGENCIES_FILE', 'r') as f:
    data = json.load(f)

for emergency in data['active_emergencies']:
    if emergency['id'] == '$emergency_id':
        emergency['safe_mode_enabled'] = True
        emergency['safe_mode_at'] = datetime.now().isoformat()
        break

# Save
import tempfile, shutil
with tempfile.NamedTemporaryFile(mode='w', delete=False, dir='$KNOWLEDGE_DIR') as tmp:
    json.dump(data, tmp, indent=2)
    tmp_path = tmp.name

shutil.move(tmp_path, '$EMERGENCIES_FILE')
EOF
}

# Check if emergency is resolved
check_emergency_resolved() {
    local emergency_id="$1"

    # This would integrate with actual system checks
    # For now, simplified check
    return 1
}

# Resolve emergency
resolve_emergency() {
    local emergency_id="$1"
    local resolution="${2:-Manual resolution}"

    success "Resolving emergency: $emergency_id"

    python3 <<EOF
import json
from datetime import datetime

with open('$EMERGENCIES_FILE', 'r') as f:
    data = json.load(f)

found = False
for emergency in data['active_emergencies']:
    if emergency['id'] == '$emergency_id':
        emergency['status'] = 'resolved'
        emergency['resolved_at'] = datetime.now().isoformat()
        emergency['resolution'] = '$resolution'
        data['resolved_emergencies'].append(emergency)
        found = True
        break

if found:
    data['active_emergencies'] = [e for e in data['active_emergencies'] if e['id'] != '$emergency_id']
    
    # Save
    import tempfile, shutil
    with tempfile.NamedTemporaryFile(mode='w', delete=False, dir='$KNOWLEDGE_DIR') as tmp:
        json.dump(data, tmp, indent=2)
        tmp_path = tmp.name
    shutil.move(tmp_path, '$EMERGENCIES_FILE')
    print('Resolved')
else:
    print('Not found')
EOF
}

# Check safe mode status
check_safe_mode() {
    if [ -f "$SAFE_MODE_FLAG" ]; then
        echo "enabled"
    else
        echo "disabled"
    fi
}

# Disable safe mode
disable_safe_mode() {
    if [ -f "$SAFE_MODE_FLAG" ]; then
        log "Disabling safe-mode..."
        rm -f "$SAFE_MODE_FLAG"
        success "Safe-mode disabled"
    else
        log "Safe-mode is not enabled"
    fi
}

# List active emergencies
list_emergencies() {
    if [ ! -f "$EMERGENCIES_FILE" ]; then
        echo "No emergencies file found"
        return
    fi

    python3 -c "
import json
with open('$EMERGENCIES_FILE', 'r') as f:
    data = json.load(f)
    active = data.get('active_emergencies', [])
    print(f'Active Emergencies: {len(active)}')
    for emergency in active:
        print(f\"  ID: {emergency['id']}\")
        print(f\"  Severity: {emergency['severity']}\")
        print(f\"  Error: {emergency['error']}\")
        print(f\"  Level: {emergency.get('current_escalation_level', 1)}\")
        print(f\"  Time: {emergency['declared_at']}\")
        print()
"
}

# Main command dispatcher
case "${1:-help}" in
init)
    initialize_emergency_system
    ;;
classify)
    if [ $# -lt 2 ]; then
        error "Usage: emergency_response.sh classify <error_message>"
        exit 1
    fi
    classify_severity "$2" "${3:-}"
    ;;
declare)
    if [ $# -lt 3 ]; then
        error "Usage: emergency_response.sh declare <error_message> <severity> [context_json]"
        exit 1
    fi
    declare_emergency "$2" "$3" "${4:-{}}"
    ;;
handle)
    if [ $# -lt 2 ]; then
        error "Usage: emergency_response.sh handle <emergency_id>"
        exit 1
    fi
    handle_emergency "$2"
    ;;
resolve)
    if [ $# -lt 2 ]; then
        error "Usage: emergency_response.sh resolve <emergency_id> [resolution]"
        exit 1
    fi
    resolve_emergency "$2" "${3:-Manual resolution}"
    ;;
list)
    list_emergencies
    ;;
safe-mode)
    check_safe_mode
    ;;
disable-safe-mode)
    disable_safe_mode
    ;;
help | --help | -h)
    cat <<EOF
Emergency Response System - Handle Critical Failures

Usage: emergency_response.sh <command> [arguments]

Commands:
  init                                  Initialize emergency response system
  classify <error> [context]            Classify failure severity
  declare <error> <severity> [context]  Declare an emergency
  handle <emergency_id>                 Handle emergency with escalation
  resolve <emergency_id> [resolution]   Resolve an emergency
  list                                  List active emergencies
  safe-mode                             Check if safe-mode is enabled
  disable-safe-mode                     Disable safe-mode
  help                                  Show this help message

Severity Levels:
  critical  - System down, data loss risk
  high      - Feature broken, blocking development
  medium    - Degraded performance, workarounds exist
  low       - Minor issue, scheduled fix acceptable

Escalation Ladder:
  Level 1: Agent Auto-Fix (0-2 minutes)
  Level 2: Alternative Strategy (2-5 minutes)
  Level 3: Cross-Agent Consultation (5-10 minutes)
  Level 4: Human Notification (10-15 minutes)
  Level 5: System Safe-Mode (critical failures)

Examples:
  # Initialize system
  emergency_response.sh init
  
  # Classify error severity
  emergency_response.sh classify "Build failed"
  
  # Declare emergency
  emergency_id=\$(emergency_response.sh declare "Critical build failure" "high")
  
  # Handle with escalation
  emergency_response.sh handle \$emergency_id
  
  # Resolve emergency
  emergency_response.sh resolve \$emergency_id "Fixed by rebuilding"

Environment Variables:
  LEVEL1_TIMEOUT  Level 1 timeout in seconds (default: 120)
  LEVEL2_TIMEOUT  Level 2 timeout in seconds (default: 300)
  LEVEL3_TIMEOUT  Level 3 timeout in seconds (default: 600)
  LEVEL4_TIMEOUT  Level 4 timeout in seconds (default: 900)
EOF
    ;;
*)
    error "Unknown command: $1"
    echo "Run 'emergency_response.sh help' for usage information"
    exit 1
    ;;
esac

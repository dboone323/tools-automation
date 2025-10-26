#!/bin/bash

# Context Loader - Project History and Context Awareness
# Loads project context before agent operations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTEXT_DIR="$SCRIPT_DIR/context"
PROJECT_MEMORY="$CONTEXT_DIR/project_memory.json"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Logging
log() {
    echo "[Context Loader] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

# Initialize context directory
init_context() {
    mkdir -p "$CONTEXT_DIR"

    if [ ! -f "$PROJECT_MEMORY" ]; then
        log "Initializing project memory..."
        cat >"$PROJECT_MEMORY" <<'EOF'
{
  "project_name": "Quantum-workspace",
  "history": {
    "common_errors": [],
    "successful_patterns": [],
    "team_preferences": {},
    "architecture_decisions": [],
    "recurring_issues": []
  },
  "current_state": {
    "active_features": [],
    "technical_debt": [],
    "dependencies": {},
    "test_coverage": 0,
    "build_status": "unknown"
  },
  "metadata": {
    "created": "",
    "last_updated": ""
  }
}
EOF
        python3 -c "
import json
from datetime import datetime
from pathlib import Path

memory_file = Path('$PROJECT_MEMORY')
data = json.loads(memory_file.read_text())
data['metadata']['created'] = datetime.now().isoformat()
data['metadata']['last_updated'] = datetime.now().isoformat()
memory_file.write_text(json.dumps(data, indent=2))
"
    fi
}

# Load project memory
load_memory() {
    if [ ! -f "$PROJECT_MEMORY" ]; then
        init_context
    fi

    cat "$PROJECT_MEMORY"
}

# Get recent changes from git
get_recent_changes() {
    local count="${1:-10}"

    if ! git -C "$ROOT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
        echo "[]"
        return
    fi

    python3 <<PYEOF
import json
import subprocess
from datetime import datetime

try:
    result = subprocess.run(
        ['git', '-C', '$ROOT_DIR', 'log', '--oneline', '-$count'],
        capture_output=True,
        text=True,
        timeout=5
    )
    
    if result.returncode == 0:
        commits = []
        for line in result.stdout.strip().split('\n'):
            if line:
                parts = line.split(' ', 1)
                if len(parts) == 2:
                    commits.append({
                        'hash': parts[0],
                        'message': parts[1]
                    })
        print(json.dumps(commits, indent=2))
    else:
        print("[]")
except Exception:
    print("[]")
PYEOF
}

# Check related issues (from knowledge base)
check_related_issues() {
    local query="$1"

    if [ ! -f "$SCRIPT_DIR/knowledge/error_patterns.json" ]; then
        echo "[]"
        return
    fi

    python3 <<PYEOF
import json
from pathlib import Path

query = '$query'.lower()
patterns_file = Path('$SCRIPT_DIR/knowledge/error_patterns.json')
patterns = json.loads(patterns_file.read_text())

related = []
for hash_key, pattern in patterns.items():
    pattern_text = pattern.get('pattern', '').lower()
    if any(word in pattern_text for word in query.split() if len(word) > 3):
        related.append({
            'pattern': pattern['pattern'],
            'category': pattern.get('category', 'unknown'),
            'severity': pattern.get('severity', 'medium'),
            'count': pattern.get('count', 0)
        })

# Sort by count (most common first)
related.sort(key=lambda x: x['count'], reverse=True)
print(json.dumps(related[:5], indent=2))
PYEOF
}

# Get current sprint goals (from project memory)
get_sprint_goals() {
    python3 -c "
import json
from pathlib import Path

memory = json.loads(Path('$PROJECT_MEMORY').read_text())
features = memory.get('current_state', {}).get('active_features', [])
print(json.dumps(features, indent=2))
"
}

# Load full context for operation
load_context() {
    local operation="${1:-general}"
    local query="${2:-}"

    log "Loading context for: $operation"

    # Build context object
    python3 <<PYEOF
import json
import sys
from pathlib import Path
from datetime import datetime

# Load project memory
memory_file = Path('$PROJECT_MEMORY')
memory = json.loads(memory_file.read_text())

# Get recent changes
recent_changes = $(get_recent_changes 5)

# Get related issues
related_issues = $(check_related_issues "$query")

# Get sprint goals
sprint_goals = $(get_sprint_goals)

# Build full context
context = {
    'operation': '$operation',
    'query': '$query',
    'timestamp': datetime.now().isoformat(),
    'project_memory': memory,
    'recent_changes': recent_changes,
    'related_issues': related_issues,
    'sprint_goals': sprint_goals,
    'architecture_rules': memory.get('history', {}).get('architecture_decisions', []),
    'team_preferences': memory.get('history', {}).get('team_preferences', {}),
    'current_state': memory.get('current_state', {})
}

print(json.dumps(context, indent=2))
PYEOF
}

# Update project memory with new information
update_memory() {
    local key="$1"
    local value="$2"

    log "Updating project memory: $key"

    python3 <<PYEOF
import json
from pathlib import Path
from datetime import datetime

memory_file = Path('$PROJECT_MEMORY')
memory = json.loads(memory_file.read_text())

key = '$key'
value_json = '$value'

# Parse value as JSON if possible
try:
    value = json.loads(value_json)
except:
    value = value_json

# Update nested key
keys = key.split('.')
current = memory
for k in keys[:-1]:
    if k not in current:
        current[k] = {}
    current = current[k]

# Handle list appending
if isinstance(current.get(keys[-1]), list):
    if value not in current[keys[-1]]:
        current[keys[-1]].append(value)
else:
    current[keys[-1]] = value

# Update timestamp
memory['metadata']['last_updated'] = datetime.now().isoformat()

# Save
tmp_file = memory_file.with_suffix('.tmp')
tmp_file.write_text(json.dumps(memory, indent=2))
tmp_file.replace(memory_file)

print("Updated successfully")
PYEOF
}

# Record successful pattern
record_success() {
    local pattern="$1"
    local description="${2:-}"

    log "Recording successful pattern: $pattern"

    python3 <<PYEOF
import json
from pathlib import Path
from datetime import datetime

memory_file = Path('$PROJECT_MEMORY')
memory = json.loads(memory_file.read_text())

pattern_entry = {
    'pattern': '$pattern',
    'description': '$description',
    'recorded': datetime.now().isoformat()
}

if 'successful_patterns' not in memory['history']:
    memory['history']['successful_patterns'] = []

# Check if pattern already exists
existing = [p for p in memory['history']['successful_patterns'] if p.get('pattern') == '$pattern']
if not existing:
    memory['history']['successful_patterns'].append(pattern_entry)
    memory['metadata']['last_updated'] = datetime.now().isoformat()
    
    tmp_file = memory_file.with_suffix('.tmp')
    tmp_file.write_text(json.dumps(memory, indent=2))
    tmp_file.replace(memory_file)
    
    print("Pattern recorded")
else:
    print("Pattern already exists")
PYEOF
}

# Record common error
record_error() {
    local error="$1"
    local frequency="${2:-1}"

    log "Recording common error: $error"

    python3 <<PYEOF
import json
from pathlib import Path
from datetime import datetime

memory_file = Path('$PROJECT_MEMORY')
memory = json.loads(memory_file.read_text())

if 'common_errors' not in memory['history']:
    memory['history']['common_errors'] = []

# Find existing or create new
existing = None
for err in memory['history']['common_errors']:
    if err.get('error') == '$error':
        existing = err
        break

if existing:
    existing['frequency'] = existing.get('frequency', 1) + int('$frequency')
    existing['last_seen'] = datetime.now().isoformat()
else:
    memory['history']['common_errors'].append({
        'error': '$error',
        'frequency': int('$frequency'),
        'first_seen': datetime.now().isoformat(),
        'last_seen': datetime.now().isoformat()
    })

memory['metadata']['last_updated'] = datetime.now().isoformat()

tmp_file = memory_file.with_suffix('.tmp')
tmp_file.write_text(json.dumps(memory, indent=2))
tmp_file.replace(memory_file)

print("Error recorded")
PYEOF
}

# Get context summary
get_summary() {
    python3 -c "
import json
from pathlib import Path

memory = json.loads(Path('$PROJECT_MEMORY').read_text())

print('Project Context Summary')
print('=' * 50)
print(f\"Project: {memory.get('project_name', 'Unknown')}\")
print(f\"Last Updated: {memory.get('metadata', {}).get('last_updated', 'Unknown')}\")
print()
print(f\"Common Errors: {len(memory.get('history', {}).get('common_errors', []))}\")
print(f\"Successful Patterns: {len(memory.get('history', {}).get('successful_patterns', []))}\")
print(f\"Architecture Rules: {len(memory.get('history', {}).get('architecture_decisions', []))}\")
print()
print(f\"Test Coverage: {memory.get('current_state', {}).get('test_coverage', 0)*100:.1f}%\")
print(f\"Build Status: {memory.get('current_state', {}).get('build_status', 'unknown')}\")
"
}

# Main entry point
main() {
    local command="${1:-load}"
    shift || true

    case "$command" in
    init)
        init_context
        log "Context initialized"
        ;;
    load)
        load_context "${1:-general}" "${2:-}"
        ;;
    memory)
        load_memory
        ;;
    changes)
        get_recent_changes "${1:-10}"
        ;;
    issues)
        if [ $# -lt 1 ]; then
            echo "Usage: context_loader.sh issues <query>"
            exit 1
        fi
        check_related_issues "$1"
        ;;
    goals)
        get_sprint_goals
        ;;
    update)
        if [ $# -lt 2 ]; then
            echo "Usage: context_loader.sh update <key> <value>"
            exit 1
        fi
        update_memory "$1" "$2"
        ;;
    record-success)
        if [ $# -lt 1 ]; then
            echo "Usage: context_loader.sh record-success <pattern> [description]"
            exit 1
        fi
        record_success "$1" "${2:-}"
        ;;
    record-error)
        if [ $# -lt 1 ]; then
            echo "Usage: context_loader.sh record-error <error> [frequency]"
            exit 1
        fi
        record_error "$1" "${2:-1}"
        ;;
    summary)
        get_summary
        ;;
    help | --help | -h)
        cat <<EOF
Context Loader - Project History and Context Awareness

Usage: context_loader.sh <command> [arguments]

Commands:
  init                              Initialize context system
  load [operation] [query]          Load full context for operation
  memory                            Show project memory
  changes [count]                   Get recent git changes (default: 10)
  issues <query>                    Find related issues
  goals                             Get current sprint goals
  update <key> <value>              Update project memory
  record-success <pattern> [desc]   Record successful pattern
  record-error <error> [frequency]  Record common error
  summary                           Show context summary
  help                              Show this help message

Examples:
  context_loader.sh load build "fix SharedKit import"
  context_loader.sh record-success "rebuild after clean"
  context_loader.sh record-error "Build failed: No such module"
  context_loader.sh summary
EOF
        ;;
    *)
        echo "Unknown command: $command (try 'help')"
        exit 1
        ;;
    esac
}

main "$@"

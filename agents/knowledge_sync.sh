#!/bin/bash

# Knowledge Sync - Cross-Agent Knowledge Sharing System
# Aggregates learnings from all agents and broadcasts relevant insights

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KNOWLEDGE_DIR="$SCRIPT_DIR/knowledge"
CENTRAL_HUB="$KNOWLEDGE_DIR/central_hub.json"
AGENT_LOGS_DIR="$SCRIPT_DIR/../logs"
SYNC_INTERVAL="${SYNC_INTERVAL:-300}" # 5 minutes

# Logging
log() {
    echo "[Knowledge Sync] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

error() {
    log "ERROR: $*"
    exit 1
}

# Initialize central hub if needed
init_central_hub() {
    if [ ! -f "$CENTRAL_HUB" ]; then
        log "Initializing central knowledge hub..."
        cat >"$CENTRAL_HUB" <<'EOF'
{
  "global_patterns": {},
  "best_practices": {},
  "anti_patterns": {},
  "success_strategies": {},
  "agent_specializations": {},
  "cross_agent_insights": [],
  "metadata": {
    "created": "",
    "last_updated": "",
    "total_insights": 0,
    "active_agents": 0
  }
}
EOF
        python3 -c "
import json
from datetime import datetime
from pathlib import Path

hub_file = Path('$CENTRAL_HUB')
data = json.loads(hub_file.read_text())
data['metadata']['created'] = datetime.now().isoformat()
data['metadata']['last_updated'] = datetime.now().isoformat()
hub_file.write_text(json.dumps(data, indent=2))
"
    fi
}

# Collect insights from individual agents
collect_agent_insights() {
    local insights_collected=0

    log "Collecting insights from agent knowledge bases..."

    # Collect from error patterns
    if [ -f "$KNOWLEDGE_DIR/error_patterns.json" ]; then
        local pattern_count
        pattern_count=$(python3 -c "
import json
from pathlib import Path

patterns = json.loads(Path('$KNOWLEDGE_DIR/error_patterns.json').read_text())
print(len(patterns))
" 2>/dev/null || echo "0")

        if [ "$pattern_count" -gt 0 ]; then
            log "Found $pattern_count error patterns"
            insights_collected=$((insights_collected + pattern_count))
        fi
    fi

    # Collect from fix history
    if [ -f "$KNOWLEDGE_DIR/fix_history.json" ]; then
        local fix_count
        fix_count=$(python3 -c "
import json
from pathlib import Path

fixes = json.loads(Path('$KNOWLEDGE_DIR/fix_history.json').read_text())
successful_fixes = [f for f in fixes.values() if f.get('success_rate', 0) > 0.7]
print(len(successful_fixes))
" 2>/dev/null || echo "0")

        if [ "$fix_count" -gt 0 ]; then
            log "Found $fix_count successful fix strategies"
            insights_collected=$((insights_collected + fix_count))
        fi
    fi

    echo "$insights_collected"
}

# Aggregate insights into central hub
aggregate_insights() {
    log "Aggregating insights into central hub..."

    python3 <<'PYEOF'
import json
import sys
from pathlib import Path
from datetime import datetime
from typing import Dict, List

KNOWLEDGE_DIR = Path("${KNOWLEDGE_DIR}")
CENTRAL_HUB = KNOWLEDGE_DIR / "central_hub.json"

def load_json(filepath: Path) -> dict:
    if not filepath.exists():
        return {}
    try:
        return json.loads(filepath.read_text())
    except json.JSONDecodeError:
        return {}

def save_json(filepath: Path, data: dict):
    filepath.parent.mkdir(parents=True, exist_ok=True)
    tmp_file = filepath.with_suffix('.tmp')
    tmp_file.write_text(json.dumps(data, indent=2))
    tmp_file.replace(filepath)

# Load data
central_hub = load_json(CENTRAL_HUB)
error_patterns = load_json(KNOWLEDGE_DIR / "error_patterns.json")
fix_history = load_json(KNOWLEDGE_DIR / "fix_history.json")
correlation_matrix = load_json(KNOWLEDGE_DIR / "correlation_matrix.json")

# Extract global patterns (high frequency, high severity)
global_patterns = {}
for hash_key, pattern in error_patterns.items():
    if pattern.get('count', 0) >= 3 and pattern.get('severity') in ['high', 'medium']:
        global_patterns[hash_key] = {
            'pattern': pattern['pattern'],
            'category': pattern['category'],
            'severity': pattern['severity'],
            'occurrences': pattern['count'],
            'agents_affected': 'multiple'  # Could track which agents see this
        }

# Extract best practices (high success rate fixes)
best_practices = {}
for fix_id, fix in fix_history.items():
    if fix.get('success_rate', 0) >= 0.8 and fix.get('times_used', 0) >= 3:
        action = fix.get('action', 'unknown')
        if action not in best_practices:
            best_practices[action] = {
                'action': action,
                'success_rate': fix['success_rate'],
                'times_used': fix['times_used'],
                'avg_duration': fix.get('avg_duration', 0),
                'applicable_errors': []
            }
        best_practices[action]['applicable_errors'].append(fix.get('error_hash', 'unknown'))

# Extract anti-patterns (low success rate fixes)
anti_patterns = {}
for fix_id, fix in fix_history.items():
    if fix.get('success_rate', 0) < 0.3 and fix.get('times_used', 0) >= 2:
        key = f"{fix.get('error_hash', 'unknown')}:{fix.get('action', 'unknown')}"
        anti_patterns[key] = {
            'error_hash': fix.get('error_hash'),
            'action': fix.get('action'),
            'success_rate': fix['success_rate'],
            'times_failed': fix.get('failures', 0),
            'recommendation': 'avoid'
        }

# Extract success strategies (high correlation)
success_strategies = {}
for key, corr in correlation_matrix.items():
    if corr.get('correlation_score', 0) >= 0.7 and corr.get('total_attempts', 0) >= 3:
        success_strategies[key] = {
            'error_hash': corr['error_hash'],
            'action': corr['action'],
            'correlation_score': corr['correlation_score'],
            'success_count': corr['successes'],
            'total_attempts': corr['total_attempts']
        }

# Generate cross-agent insights
cross_agent_insights = []

# Insight: Common build failures
build_errors = [p for p in error_patterns.values() if p.get('category') == 'build']
if len(build_errors) >= 3:
    cross_agent_insights.append({
        'id': f"insight_{datetime.now().strftime('%Y%m%d_%H%M%S')}_build",
        'type': 'common_pattern',
        'category': 'build',
        'title': 'Common Build Failures Detected',
        'description': f'{len(build_errors)} build-related errors identified across agents',
        'recommendation': 'Build agents should share error resolution strategies',
        'affected_agents': ['agent_build.sh', 'agent_build_enhanced.sh'],
        'created': datetime.now().isoformat()
    })

# Insight: Successful fix strategies
if len(best_practices) > 0:
    cross_agent_insights.append({
        'id': f"insight_{datetime.now().strftime('%Y%m%d_%H%M%S')}_strategies",
        'type': 'best_practice',
        'category': 'general',
        'title': 'Successful Fix Strategies Available',
        'description': f'{len(best_practices)} proven fix strategies with >80% success rate',
        'recommendation': 'All agents should consider these strategies first',
        'strategies': list(best_practices.keys()),
        'created': datetime.now().isoformat()
    })

# Update central hub
central_hub['global_patterns'] = global_patterns
central_hub['best_practices'] = best_practices
central_hub['anti_patterns'] = anti_patterns
central_hub['success_strategies'] = success_strategies
central_hub['cross_agent_insights'] = cross_agent_insights

# Update metadata (handle both old and new format)
if 'metadata' not in central_hub:
    central_hub['metadata'] = {}

central_hub['metadata']['last_updated'] = datetime.now().isoformat()
central_hub['metadata']['total_insights'] = len(cross_agent_insights)
central_hub['metadata']['global_patterns_count'] = len(global_patterns)
central_hub['metadata']['best_practices_count'] = len(best_practices)
central_hub['metadata']['anti_patterns_count'] = len(anti_patterns)

# Save
save_json(CENTRAL_HUB, central_hub)

print(f"Aggregated {len(global_patterns)} global patterns")
print(f"Identified {len(best_practices)} best practices")
print(f"Found {len(anti_patterns)} anti-patterns")
print(f"Generated {len(cross_agent_insights)} cross-agent insights")

PYEOF
}

# Broadcast relevant insights to agents
broadcast_insights() {
    log "Broadcasting insights to agents..."

    # Create insights directory for agent consumption
    local insights_dir="$SCRIPT_DIR/shared_insights"
    mkdir -p "$insights_dir"

    # Extract insights for different agent types
    python3 <<'PYEOF'
import json
from pathlib import Path
from datetime import datetime

KNOWLEDGE_DIR = Path("${KNOWLEDGE_DIR}")
CENTRAL_HUB = KNOWLEDGE_DIR / "central_hub.json"
INSIGHTS_DIR = Path("${SCRIPT_DIR}/shared_insights")

# Ensure insights directory exists
INSIGHTS_DIR.mkdir(parents=True, exist_ok=True)

hub = json.loads(CENTRAL_HUB.read_text())

# Create agent-specific insight files
agent_types = {
    'build': ['agent_build.sh', 'agent_build_enhanced.sh'],
    'debug': ['agent_debug.sh', 'agent_debug_enhanced.sh'],
    'codegen': ['agent_codegen.sh'],
    'test': ['agent_test.sh']
}

for agent_type, agents in agent_types.items():
    insights_file = INSIGHTS_DIR / f"{agent_type}_insights.json"
    
    relevant_insights = {
        'for_agent_type': agent_type,
        'agents': agents,
        'global_patterns': {},
        'best_practices': {},
        'anti_patterns': {},
        'insights': [],
        'updated': datetime.now().isoformat()
    }
    
    # Filter relevant patterns
    for key, pattern in hub.get('global_patterns', {}).items():
        if pattern.get('category') == agent_type or pattern.get('category') == 'general':
            relevant_insights['global_patterns'][key] = pattern
    
    # Filter relevant best practices
    for key, practice in hub.get('best_practices', {}).items():
        relevant_insights['best_practices'][key] = practice
    
    # Filter relevant insights
    for insight in hub.get('cross_agent_insights', []):
        if agent_type in insight.get('category', '') or 'general' in insight.get('category', ''):
            relevant_insights['insights'].append(insight)
    
    insights_file.write_text(json.dumps(relevant_insights, indent=2))
    print(f"Created insights for {agent_type}: {len(relevant_insights['global_patterns'])} patterns, {len(relevant_insights['insights'])} insights")

PYEOF
}

# Sync once
sync_once() {
    init_central_hub

    local insights
    insights=$(collect_agent_insights)

    if [ "$insights" -gt 0 ]; then
        aggregate_insights
        broadcast_insights
        log "Sync complete: $insights insights processed"
    else
        log "No new insights to sync"
    fi
}

# Continuous sync mode
sync_watch() {
    log "Starting continuous knowledge sync (interval: ${SYNC_INTERVAL}s)"

    while true; do
        sync_once
        sleep "$SYNC_INTERVAL"
    done
}

# Query insights
query_insights() {
    local query_type="$1"
    local query_value="${2:-}"

    python3 -c "
import json
from pathlib import Path

hub = json.loads(Path('$CENTRAL_HUB').read_text())

query_type = '$query_type'
query_value = '$query_value'

if query_type == 'best_practices':
    print(json.dumps(hub.get('best_practices', {}), indent=2))
elif query_type == 'anti_patterns':
    print(json.dumps(hub.get('anti_patterns', {}), indent=2))
elif query_type == 'insights':
    print(json.dumps(hub.get('cross_agent_insights', []), indent=2))
elif query_type == 'global_patterns':
    print(json.dumps(hub.get('global_patterns', {}), indent=2))
elif query_type == 'stats':
    print(json.dumps(hub.get('metadata', {}), indent=2))
else:
    print(json.dumps(hub, indent=2))
"
}

# Main entry point
main() {
    local command="${1:-sync}"
    shift || true

    case "$command" in
    sync)
        sync_once
        ;;
    watch)
        sync_watch
        ;;
    query)
        if [ $# -lt 1 ]; then
            error "Usage: knowledge_sync.sh query <type> [value]"
        fi
        query_insights "$@"
        ;;
    init)
        init_central_hub
        log "Central hub initialized"
        ;;
    help | --help | -h)
        cat <<EOF
Knowledge Sync - Cross-Agent Knowledge Sharing

Usage: knowledge_sync.sh <command> [arguments]

Commands:
  sync              Run sync once (collect, aggregate, broadcast)
  watch             Continuous sync mode (every ${SYNC_INTERVAL}s)
  query <type>      Query insights (best_practices, anti_patterns, insights, stats)
  init              Initialize central hub
  help              Show this help message

Examples:
  knowledge_sync.sh sync
  knowledge_sync.sh watch
  knowledge_sync.sh query best_practices
  knowledge_sync.sh query insights

Environment Variables:
  SYNC_INTERVAL     Sync interval in seconds (default: 300)
EOF
        ;;
    *)
        error "Unknown command: $command (try 'help')"
        ;;
    esac
}

main "$@"

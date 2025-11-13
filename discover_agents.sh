#!/bin/bash
# Agent Discovery and Registration Script
# Automatically discovers all agent scripts and registers them for monitoring

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
AGENTS_DIR="$PROJECT_ROOT/agents"
STATUS_FILE="$PROJECT_ROOT/agent_status.json"

echo "🔍 Discovering all agent scripts..."

# Find all agent scripts
AGENT_SCRIPTS=$(find "$PROJECT_ROOT" -type f \( -name "*agent*.sh" -o -name "*agent*.py" \) | grep -v "/\." | sort)

echo "📊 Found $(echo "$AGENT_SCRIPTS" | wc -l) agent scripts"

# Create agents directory if it doesn't exist
mkdir -p "$AGENTS_DIR"

# Initialize or load existing status
if [ -f "$STATUS_FILE" ]; then
    echo "📁 Loading existing agent status..."
    EXISTING_STATUS=$(cat "$STATUS_FILE")
else
    echo "📁 Creating new agent status file..."
    EXISTING_STATUS="{}"
fi

# Process each agent script and collect new agents
NEW_AGENTS_FILE=$(mktemp)
echo "{}" >"$NEW_AGENTS_FILE"
echo "$AGENT_SCRIPTS" | while read -r agent_script; do
    # Extract agent name from path
    agent_name=$(basename "$agent_script" | sed 's/\.sh$//' | sed 's/\.py$//' | sed 's/_agent$//' | sed 's/^agent_//')

    # Skip if already exists in status
    if echo "$EXISTING_STATUS" | jq -e ".\"$agent_name\"" >/dev/null 2>&1; then
        echo "⏭️  Skipping existing agent: $agent_name"
        continue
    fi

    echo "➕ Registering agent: $agent_name"

    # Determine agent type based on path/name
    if [[ "$agent_script" == *"/tests/"* ]]; then
        agent_type="testing"
    elif [[ "$agent_script" == *"/ci/"* ]] || [[ "$agent_script" == *"/.ci/"* ]]; then
        agent_type="ci_cd"
    elif [[ "$agent_script" == *"dashboard"* ]]; then
        agent_type="monitoring"
    elif [[ "$agent_script" == *"code"* ]] || [[ "$agent_script" == *"review"* ]]; then
        agent_type="code_quality"
    elif [[ "$agent_script" == *"deploy"* ]] || [[ "$agent_script" == *"infrastructure"* ]]; then
        agent_type="infrastructure"
    elif [[ "$agent_script" == *"workflow"* ]] || [[ "$agent_script" == *"orchestrator"* ]]; then
        agent_type="workflow"
    elif [[ "$agent_script" == *"quantum"* ]]; then
        agent_type="ai_ml"
    elif [[ "$agent_script" == *"encrypt"* ]] || [[ "$agent_script" == *"security"* ]]; then
        agent_type="security"
    else
        agent_type="automation"
    fi

    # Create agent status entry
    agent_status=$(
        cat <<EOF
{
  "name": "$agent_name",
  "type": "$agent_type",
  "status": "unknown",
  "script_path": "$agent_script",
  "tasks_completed": 0,
  "tasks_failed": 0,
  "tasks_queued": 0,
  "tasks_processing": 0,
  "memory_usage": 0,
  "cpu_usage": 0,
  "last_seen": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "registered_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    )

    # Add to new agents file
    temp_file=$(mktemp)
    cat "$NEW_AGENTS_FILE" | jq ". + {\"$agent_name\": $agent_status}" >"$temp_file"
    mv "$temp_file" "$NEW_AGENTS_FILE"

    # Create individual status file
    echo "$agent_status" >"$AGENTS_DIR/${agent_name}_status.json"

done

# Read new agents and merge
NEW_AGENTS=$(cat "$NEW_AGENTS_FILE")
rm "$NEW_AGENTS_FILE"
EXISTING_STATUS=$(echo "$EXISTING_STATUS" | jq ". + $NEW_AGENTS")

# Save updated status file
echo "$EXISTING_STATUS" >"$STATUS_FILE"

echo "✅ Agent discovery and registration complete!"
echo "📊 Total agents registered: $(echo "$EXISTING_STATUS" | jq 'length')"
echo "📁 Status file: $STATUS_FILE"
echo "📁 Individual status files: $AGENTS_DIR/"

# Display summary by type
echo ""
echo "📈 Agent Summary by Type:"
echo "$EXISTING_STATUS" | jq -r 'to_entries | group_by(.value.type) | map({type: .[0].value.type, count: length}) | sort_by(.count) | reverse | .[] | "  \(.type): \(.count)"'

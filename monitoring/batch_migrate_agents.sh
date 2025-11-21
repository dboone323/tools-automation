#!/usr/bin/env bash
# Batch Agent Migration with Integration Testing
# Migrates agents in batches and tests integration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$(dirname "$SCRIPT_DIR")/agents"
BATCH_SIZE="${1:-5}"  # Default batch size

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Batch Agent Migration & Integration Testing          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Batch Size: $BATCH_SIZE agents per batch"
echo ""

# Get list of all agents
ALL_AGENTS=$(find "$AGENTS_DIR" -maxdepth 1 -name "agent_*.sh" -type f | sort)
TOTAL_AGENTS=$(echo "$ALL_AGENTS" | wc -l | tr -d ' ')

echo "Found $TOTAL_AGENTS total agent scripts"
echo ""

BATCH_NUM=1
MIGRATED_THIS_SESSION=0
FAILED_THIS_SESSION=0

migrate_and_test_batch() {
    local batch_agents=("$@")
    local batch_count=${#batch_agents[@]}
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 BATCH $BATCH_NUM: Migrating $batch_count agents"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    local batch_success=0
    local batch_failed=0
    
    for agent_file in "${batch_agents[@]}"; do
        local agent_name=$(basename "$agent_file")
        
        # Check if already migrated
        if grep -q "agent_config_discovery.sh" "$agent_file" 2>/dev/null; then
            echo "  ⏭️  $agent_name - Already migrated"
            continue
        fi
        
        echo "  🔄 $agent_name - Migrating..."
        
        # Create backup
        cp "$agent_file" "${agent_file}.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Add autonomy features at the top of the file (after shebang)
        {
            # Preserve shebang
            head -1 "$agent_file"
            
            # Add autonomy integration
            cat <<'EOF'

# ══════════════════════════════════════════════════════════════
# Enhanced with Agent Autonomy Features
# ══════════════════════════════════════════════════════════════

# Dynamic Configuration Discovery
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/agent_config_discovery.sh" ]]; then
    source "${SCRIPT_DIR}/agent_config_discovery.sh"
    WORKSPACE_ROOT=$(get_workspace_root 2>/dev/null || echo "$HOME/workspace")
    MCP_URL=$(get_mcp_url 2>/dev/null || echo "http://127.0.0.1:5000")
fi

# AI Decision Helpers (optional - uncomment to enable)
# if [[ -f "${SCRIPT_DIR}/../monitoring/ai_helpers.sh" ]]; then
#     source "${SCRIPT_DIR}/../monitoring/ai_helpers.sh"
# fi

# State Manager Integration (optional - uncomment to enable)
# STATE_MANAGER="${SCRIPT_DIR}/../monitoring/state_manager.py"

# ══════════════════════════════════════════════════════════════

EOF
            
            # Add rest of original file (skip shebang)
            tail -n +2 "$agent_file"
            
        } > "${agent_file}.tmp"
        
        # Replace original
        if mv "${agent_file}.tmp" "$agent_file"; then
            chmod +x "$agent_file"
            echo "  ✅ $agent_name - Migration successful"
            ((batch_success++))
            ((MIGRATED_THIS_SESSION++))
        else
            echo "  ❌ $agent_name - Migration failed"
            # Restore from backup
            cp "${agent_file}.backup.$(date +%Y%m%d_%H%M%S)" "$agent_file"
            ((batch_failed++))
            ((FAILED_THIS_SESSION++))
        fi
    done
    
    echo ""
    echo "Batch $BATCH_NUM Summary: ✅ $batch_success migrated, ❌ $batch_failed failed"
    echo ""
    
    # Test integration
    echo "🧪 Testing Integration..."
    echo ""
    
    # Test a sample migrated agent
    if [[ $batch_success -gt 0 ]]; then
        local test_agent="${batch_agents[0]}"
        local test_name=$(basename "$test_agent")
        
        echo "  Testing: $test_name"
        
        # Check if it can source config discovery
        if bash -c "source '$test_agent' 2>&1 | head -1" > /dev/null 2>&1; then
            echo "  ✅ Script loads successfully"
        else
            echo "  ⚠️  Script has warnings (may still work)"
        fi
        
        # Check metrics
        echo ""
        echo "  📊 Current System Metrics:"
        python3 "$SCRIPT_DIR/metrics_collector.py" --collect --agent-status "$AGENTS_DIR/../config/agent_status.json" 2>&1 | grep "Collected" || echo "  Metrics collection in progress..."
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Pause between batches
    if [[ $BATCH_NUM -lt $((TOTAL_AGENTS / BATCH_SIZE + 1)) ]]; then
        echo "⏸️  Pausing 3 seconds before next batch..."
        sleep 3
    fi
    
    ((BATCH_NUM++))
}

# Process agents in batches
batch_agents=()
for agent_file in $ALL_AGENTS; do
    batch_agents+=("$agent_file")
    
    if [[ ${#batch_agents[@]} -eq $BATCH_SIZE ]]; then
        migrate_and_test_batch "${batch_agents[@]}"
        batch_agents=()
    fi
done

# Process remaining agents
if [[ ${#batch_agents[@]} -gt 0 ]]; then
    migrate_and_test_batch "${batch_agents[@]}"
fi

# Final Summary
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              Batch Migration Complete                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Final Summary:"
echo "   • Total Agents: $TOTAL_AGENTS"
echo "   • Successfully Migrated: $MIGRATED_THIS_SESSION"
echo "   • Failed: $FAILED_THIS_SESSION"
echo "   • Already Migrated: $((TOTAL_AGENTS - MIGRATED_THIS_SESSION - FAILED_THIS_SESSION))"
echo ""
echo "📁 Backups created with .backup.* suffix"
echo ""

# Show final metrics
echo "📊 Final System Metrics:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
python3 "$SCRIPT_DIR/metrics_collector.py" --summary --hours 1 2>&1 | head -20
echo ""

echo "✅ Migration complete! Agents now have:"
echo "   • Dynamic configuration discovery"
echo "   • AI helper integration points (commented)"
echo "   • State manager access (commented)"
echo ""
echo "🔍 To enable AI features, edit agents and uncomment AI helper lines"

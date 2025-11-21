#!/usr/bin/env bash
# Robust Agent Migration - Handles edge cases and validates thoroughly
# Skips problematic agents automatically

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$(dirname "$SCRIPT_DIR")/agents"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       Robust Agent Migration - Remaining Agents              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

SUCCESS_COUNT=0
SKIP_COUNT=0
ERROR_COUNT=0

migrate_agent_safe() {
    local agent_file="$1"
    local agent_name=$(basename "$agent_file")
    
    # Skip if already migrated
    if grep -q "Enhanced with Agent Autonomy" "$agent_file" 2>/dev/null; then
        echo "  ⏭️  $agent_name - Already migrated"
        ((SKIP_COUNT++))
        return 0
    fi
    
    # Validate original syntax first
    if ! bash -n "$agent_file" 2>/dev/null; then
        echo "  ⚠️  $agent_name - Original has syntax errors, skipping"
        ((SKIP_COUNT++))
        return 0
    fi
    
    echo "  🔄 $agent_name - Migrating..."
    
    # Create backup
    local backup_file="${agent_file}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$agent_file" "$backup_file"
    
    # Create migrated version
    local temp_file="${agent_file}.migrating"
    
    {
        # Preserve shebang and any header comments
        head -10 "$agent_file" | grep -E "^#!"
        
        # Add autonomy features
        cat <<'EOF'

# ══════════════════════════════════════════════════════════════
# Enhanced with Agent Autonomy Features
# ══════════════════════════════════════════════════════════════

# Dynamic Configuration Discovery
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/agent_config_discovery.sh" ]]; then
    source "${SCRIPT_DIR}/agent_config_discovery.sh" 2>/dev/null || true
    WORKSPACE_ROOT=$(get_workspace_root 2>/dev/null || echo "${WORKSPACE_ROOT:-$HOME/workspace}")
    MCP_URL=$(get_mcp_url 2>/dev/null || echo "${MCP_URL:-http://127.0.0.1:5000}")
fi

# AI Decision Helpers (uncomment to enable)
# if [[ -f "${SCRIPT_DIR}/../monitoring/ai_helpers.sh" ]]; then
#     source "${SCRIPT_DIR}/../monitoring/ai_helpers.sh"
# fi

# ══════════════════════════════════════════════════════════════

EOF
        
        # Add rest of original file (skip shebang)
        tail -n +2 "$agent_file"
        
    } > "$temp_file"
    
    # Validate new version
    if bash -n "$temp_file" 2>/dev/null; then
        # Replace original
        mv "$temp_file" "$agent_file"
        chmod +x "$agent_file"
        echo "  ✅ $agent_name - Success"
        ((SUCCESS_COUNT++))
        return 0
    else
        # Validation failed - restore backup
        echo "  ❌ $agent_name - Syntax error after migration, rolling back"
        rm -f "$temp_file"
        cp "$backup_file" "$agent_file"
        ((ERROR_COUNT++))
        return 1
    fi
}

# Get list of all unmigrated agents
echo "Scanning for unmigrated agents..."
UNMIGRATED_AGENTS=()

for agent in "$AGENTS_DIR"/agent_*.sh; do
    if [[ -f "$agent" ]]; then
        if ! grep -q "Enhanced with Agent Autonomy" "$agent" 2>/dev/null; then
            UNMIGRATED_AGENTS+=("$agent")
        fi
    fi
done

TOTAL_TO_MIGRATE=${#UNMIGRATED_AGENTS[@]}
echo "Found $TOTAL_TO_MIGRATE agents to migrate"
echo ""

if [[ $TOTAL_TO_MIGRATE -eq 0 ]]; then
    echo "✅ All agents already migrated!"
    exit 0
fi

# Migrate each agent
COUNTER=1
for agent in "${UNMIGRATED_AGENTS[@]}"; do
    echo "[$COUNTER/$TOTAL_TO_MIGRATE]"
    migrate_agent_safe "$agent"
    ((COUNTER++))
done

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                Migration Complete                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Results:"
echo "  ✅ Successfully Migrated: $SUCCESS_COUNT"
echo "  ⏭️  Skipped: $SKIP_COUNT"
echo "  ❌ Errors (rolled back): $ERROR_COUNT"
echo ""

# Final validation
echo "🔍 Final Validation:"
MIGRATED_TOTAL=$(grep -l "Enhanced with Agent Autonomy" "$AGENTS_DIR"/agent_*.sh 2>/dev/null | wc -l | tr -d ' ')
echo "  Total migrated agents: $MIGRATED_TOTAL"

SYNTAX_ERRORS=0
for agent in "$AGENTS_DIR"/agent_*.sh; do
    if grep -q "Enhanced with Agent Autonomy" "$agent" 2>/dev/null; then
        if ! bash -n "$agent" 2>/dev/null; then
            ((SYNTAX_ERRORS++))
        fi
    fi
done

if [[ $SYNTAX_ERRORS -eq 0 ]]; then
    echo "  ✅ All migrated agents have valid syntax"
else
    echo "  ⚠️  $SYNTAX_ERRORS agents have syntax errors"
fi

echo ""
echo "✅ Migration process complete!"

#!/usr/bin/env bash
# Agent Migration Script
# Migrates existing agents to use new autonomy capabilities

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$(dirname "$SCRIPT_DIR")/agents"
MONITORING_DIR="$SCRIPT_DIR"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║           Agent Migration - Autonomy Features            ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

MIGRATED_COUNT=0
SKIPPED_COUNT=0

migrate_agent() {
    local agent_file="$1"
    local agent_name=$(basename "$agent_file")
    
    echo "📝 Migrating: $agent_name"
    
    # Check if already migrated
    if grep -q "agent_config_discovery.sh" "$agent_file" 2>/dev/null; then
        echo "   ⏭️  Already migrated (has config discovery)"
        ((SKIPPED_COUNT++))
        return 0
    fi
    
    # Create backup
    cp "$agent_file" "${agent_file}.pre-migration.$(date +%Y%m%d)"
    
    # Create temporary file with migration
    local temp_file="${agent_file}.migrating"
    
    {
        # Preserve shebang and header
        head -1 "$agent_file"
        echo "# Enhanced with autonomy features - $(date +%Y-%m-%d)"
        echo ""
        
        # Add configuration discovery
        cat <<'EOF'
# Dynamic configuration discovery
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/agent_config_discovery.sh" ]]; then
    source "${SCRIPT_DIR}/agent_config_discovery.sh"
    WORKSPACE_ROOT=$(get_workspace_root)
    MCP_URL=$(get_mcp_url)
fi

EOF
        
        # Add AI helpers (optional, commented out)
        cat <<'EOF'
# AI decision making (uncomment to enable)
# source "${SCRIPT_DIR}/../monitoring/ai_helpers.sh"

EOF
        
        # Copy rest of original file (skip first line)
        tail -n +2 "$agent_file"
        
    } > "$temp_file"
    
    # Replace original
    mv "$temp_file" "$agent_file"
    chmod +x "$agent_file"
    
    echo "   ✅ Migrated successfully"
    ((MIGRATED_COUNT++))
}

# Main migration
echo "🔍 Scanning agents directory: $AGENTS_DIR"
echo ""

AGENT_FILES=$(find "$AGENTS_DIR" -maxdepth 1 -name "agent_*.sh" -type f | head -10)

if [[ -z "$AGENT_FILES" ]]; then
    echo "⚠️  No agent files found to migrate"
    exit 0
fi

echo "Found $(echo "$AGENT_FILES" | wc -l | tr -d ' ') agent files (processing first 10)"
echo ""

for agent_file in $AGENT_FILES; do
    migrate_agent "$agent_file"
done

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║              Migration Complete                          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Summary:"
echo "   • Migrated: $MIGRATED_COUNT agents"
echo "   • Skipped: $SKIPPED_COUNT agents (already migrated)"
echo ""
echo "📁 Backups created with .pre-migration suffix"
echo ""
echo "🔄 Next Steps:"
echo "   1. Test migrated agents"
echo "   2. Review AI helper integration points"
echo "   3. Enable AI features as needed (uncomment in agent files)"
echo ""
echo "✅ Agents now use dynamic configuration!"

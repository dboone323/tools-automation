#!/usr/bin/env bash

# robust_migrate_agents.sh
# Robustly migrates agents to use dynamic configuration discovery.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/migration_$(date +%Y%m%d_%H%M%S).log"

log() {
    echo "[$(date)] $*" | tee -a "$LOG_FILE"
}

migrate_agent_to_dynamic_config() {
    local agent_file="$1"
    
    if [[ ! -f "$agent_file" ]]; then
        log "ERROR: Agent file not found: $agent_file"
        return 1
    fi
    
    # Skip if already migrated
    if grep -q "agent_config_discovery.sh" "$agent_file"; then
        log "INFO: Agent already migrated: $agent_file"
        return 0
    fi

    log "INFO: Migrating $agent_file..."
    
    # Create backup
    cp "$agent_file" "${agent_file}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Create temporary file
    local temp_file="${agent_file}.migrating"
    
    # Add configuration discovery after shebang/header
    {
        # Copy shebang and header comments (lines starting with # until first non-comment or empty line)
        # Actually, just take the first few lines if they are comments
        awk 'NR==1, /^[^#]/' "$agent_file" | grep "^#" || true
        
        # Add config discovery
        cat <<'EOF'

# Dynamic configuration discovery
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./agent_config_discovery.sh
if [[ -f "${SCRIPT_DIR}/agent_config_discovery.sh" ]]; then
    source "${SCRIPT_DIR}/agent_config_discovery.sh"
    WORKSPACE_ROOT=$(get_workspace_root)
    AGENTS_DIR=$(get_agents_dir)
    MCP_URL=$(get_mcp_url)
else
    echo "ERROR: agent_config_discovery.sh not found"
    exit 1
fi

EOF
        
        # Copy rest of file, skipping the header we already copied (roughly)
        # And replacing hardcoded paths
        # We need to be careful not to duplicate the header.
        # Simpler approach: Read the whole file, remove shebang, insert config, replace paths.
        
        # Actually, let's use sed to insert after line 2 (usually after shebang and maybe a comment)
        # But we need to replace paths throughout the file.
        
        tail -n +2 "$agent_file" | \
            sed 's|WORKSPACE_ROOT="/[^"]*"|WORKSPACE_ROOT=$(get_workspace_root)|g' | \
            sed 's|AGENTS_DIR="/[^"]*"|AGENTS_DIR=$(get_agents_dir)|g' | \
            sed 's|MCP_URL="http://127.0.0.1:[0-9]*"|MCP_URL=$(get_mcp_url)|g'
        
    } > "$temp_file"
    
    # Restore shebang
    local shebang
    shebang=$(head -n 1 "$agent_file")
    
    # Combine shebang + temp file content (which has config + rest of file)
    # Wait, my logic above with awk/tail was a bit mixed.
    
    # Let's try a cleaner approach:
    # 1. Get shebang
    # 2. Get body (lines 2+)
    # 3. Apply replacements to body
    # 4. Construct new file: Shebang + Config Block + Modified Body
    
    local body_file="${temp_file}.body"
    tail -n +2 "$agent_file" | \
        sed 's|WORKSPACE_ROOT="/[^"]*"|WORKSPACE_ROOT=$(get_workspace_root)|g' | \
        sed 's|AGENTS_DIR="/[^"]*"|AGENTS_DIR=$(get_agents_dir)|g' | \
        sed 's|MCP_URL="http://127.0.0.1:[0-9]*"|MCP_URL=$(get_mcp_url)|g' > "$body_file"
        
    {
        echo "$shebang"
        cat <<'EOF'

# Dynamic configuration discovery
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./agent_config_discovery.sh
if [[ -f "${SCRIPT_DIR}/agent_config_discovery.sh" ]]; then
    source "${SCRIPT_DIR}/agent_config_discovery.sh"
    WORKSPACE_ROOT=$(get_workspace_root)
    AGENTS_DIR=$(get_agents_dir)
    MCP_URL=$(get_mcp_url)
else
    echo "ERROR: agent_config_discovery.sh not found"
    exit 1
fi
EOF
        cat "$body_file"
    } > "$temp_file"

    # Replace original with migrated version
    mv "$temp_file" "$agent_file"
    chmod +x "$agent_file"
    rm -f "$body_file"
    
    log "✅ Migrated: $agent_file"
}

migrate_all_agents() {
    local agents_dir="${1:-$(pwd)}"
    
    log "🔄 Migrating agents to dynamic configuration in $agents_dir..."
    
    find "$agents_dir" -maxdepth 1 -name "agent_*.sh" -o -name "*_agent.sh" | while read -r agent_file; do
        # Skip the config discovery script itself and this script
        if [[ "$(basename "$agent_file")" == "agent_config_discovery.sh" ]] || \
           [[ "$(basename "$agent_file")" == "robust_migrate_agents.sh" ]] || \
           [[ "$(basename "$agent_file")" == "agent_config_migration_template.sh" ]]; then
            continue
        fi
        
        migrate_agent_to_dynamic_config "$agent_file" || log "⚠️  Failed to migrate: $agent_file"
    done
    
    log "✅ Migration complete!"
}

migrate_all_agents "$SCRIPT_DIR"

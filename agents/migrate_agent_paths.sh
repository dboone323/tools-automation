#!/usr/bin/env bash
# Automated script to migrate agents from hardcoded paths to dynamic config discovery
# This script updates all agent files that reference the old /Quantum-workspace path

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}"
BACKUP_DIR="${SCRIPT_DIR}/../backups/path_migration_$(date +%Y%m%d_%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Create backup directory
mkdir -p "$BACKUP_DIR"
log_info "Created backup directory: $BACKUP_DIR"

# Find all agent files with hardcoded Quantum-workspace paths
log_info "Scanning for agents with hardcoded paths..."
AFFECTED_FILES=$(grep -l "/Users/danielstevens/Desktop/Quantum-workspace" "${AGENTS_DIR}"/*.sh 2>/dev/null || true)

if [[ -z "$AFFECTED_FILES" ]]; then
    log_info "No files found with hardcoded paths. Migration complete!"
    exit 0
fi

# Count affected files
FILE_COUNT=$(echo "$AFFECTED_FILES" | wc -l | tr -d ' ')
log_warn "Found $FILE_COUNT files with hardcoded paths"

# Process each file
MIGRATED_COUNT=0
FAILED_COUNT=0

for file in $AFFECTED_FILES; do
    filename=$(basename "$file")
    log_info "Processing: $filename"
    
    # Create backup
    cp "$file" "${BACKUP_DIR}/${filename}" || {
        log_error "Failed to backup $filename"
        ((FAILED_COUNT++))
        continue
    }
    
    # Check if file already uses agent_config_discovery.sh
    if grep -q "source.*agent_config_discovery.sh" "$file"; then
        log_info "  ✓ Already sources agent_config_discovery.sh"
        
        # Just replace hardcoded paths with variable references
        sed -i '' \
            -e 's|/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation|${TOOLS_DIR:-$(get_tools_automation_dir)}|g' \
            -e 's|/Users/danielstevens/Desktop/Quantum-workspace/Projects|${WORKSPACE_ROOT:-$(get_workspace_root)}/Projects|g' \
            -e 's|/Users/danielstevens/Desktop/Quantum-workspace|${WORKSPACE_ROOT:-$(get_workspace_root)}|g' \
            "$file" 2>/dev/null || {
            log_error "  ✗ Sed replacement failed for $filename"
            cp "${BACKUP_DIR}/${filename}" "$file"
            ((FAILED_COUNT++))
            continue
        }
        
        ((MIGRATED_COUNT++))
        log_info "  ✓ Migrated paths to use variables"
    else
        log_info "  Adding agent_config_discovery.sh sourcing"
        
        # Find where to insert the source statement (after shebang and before first actual code)
        # Create a temporary file with the config discovery added
        {
            # Keep shebang
            head -n 1 "$file"
            
            # Add config discovery
            cat <<'EOF'

# Dynamic configuration discovery
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./agent_config_discovery.sh
if [[ -f "${SCRIPT_DIR}/agent_config_discovery.sh" ]]; then
    source "${SCRIPT_DIR}/agent_config_discovery.sh"
    WORKSPACE_ROOT=$(get_workspace_root)
    AGENTS_DIR=$(get_agents_dir)
    TOOLS_DIR=$(get_tools_automation_dir)
    MCP_URL=$(get_mcp_url)
else
    echo "ERROR: agent_config_discovery.sh not found"
    exit 1
fi
EOF
            
            # Add rest of file (skip shebang)
            tail -n +2 "$file"
        } > "${file}.tmp" || {
            log_error "  ✗ Failed to create temporary file for $filename"
            ((FAILED_COUNT++))
            continue
        }
        
        # Replace hardcoded paths
        sed -i '' \
            -e 's|/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation|${TOOLS_DIR}|g' \
            -e 's|/Users/danielstevens/Desktop/Quantum-workspace/Projects|${WORKSPACE_ROOT}/Projects|g' \
            -e 's|/Users/danielstevens/Desktop/Quantum-workspace|${WORKSPACE_ROOT}|g' \
            "${file}.tmp" 2>/dev/null || {
            log_error "  ✗ Sed replacement failed for $filename"
            rm -f "${file}.tmp"
            ((FAILED_COUNT++))
            continue
        }
        
        # Move temp file to original
        mv "${file}.tmp" "$file" || {
            log_error "  ✗ Failed to move temporary file for $filename"
            rm -f "${file}.tmp"
            cp "${BACKUP_DIR}/${filename}" "$file"
            ((FAILED_COUNT++))
            continue
        }
        
        ((MIGRATED_COUNT++))
        log_info "  ✓ Migrated and added config discovery"
    fi
done

echo ""
log_info "=========================================="
log_info "Migration Summary:"
log_info "  Total files scanned: $FILE_COUNT"
log_info "  Successfully migrated: $MIGRATED_COUNT"
if [[ $FAILED_COUNT -gt 0 ]]; then
    log_error "  Failed: $FAILED_COUNT"
else
    log_info "  Failed: 0"
fi
log_info "  Backup location: $BACKUP_DIR"
log_info "=========================================="

if [[ $MIGRATED_COUNT -gt 0 ]]; then
    log_info ""
    log_info "Next steps:"
    log_info "1. Review changes: git diff agents/"
    log_info "2. Test a few agents to verify they still work"
    log_info "3. If issues occur, restore from: $BACKUP_DIR"
fi

exit 0

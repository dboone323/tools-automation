#!/bin/bash
# Resource monitoring script for Quantum Workspace

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Colors
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}[RESOURCE-MONITOR]${NC} $(date)"

# Check disk usage
echo "Disk Usage:"
df -h "$WORKSPACE_DIR" | tail -1
echo ""

# Check memory usage of key processes
echo "Key Process Memory Usage:"
# shellcheck disable=SC2009  # ps is more appropriate for getting process details (PID, memory, command)
ps aux | grep -E "(mcp_server|ollama|python.*mcp)" | grep -v grep | awk '{print $2, $4"%", $11}' || echo "No MCP/Ollama processes found"
echo ""

# Check backup directory sizes
echo "Backup Directory Sizes:"
du -sh "$WORKSPACE_DIR/.autofix_backups" "$WORKSPACE_DIR/Tools/Automation/agents/backups" "$WORKSPACE_DIR/.backups" 2>/dev/null || echo "Some backup directories not found"
echo ""

# Check for large files
echo "Largest Files (>100MB):"
find "$WORKSPACE_DIR" -type f -size +100M -exec ls -lh {} \; 2>/dev/null | head -5 || echo "No large files found"

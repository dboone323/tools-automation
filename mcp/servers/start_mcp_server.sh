#!/bin/bash

# MCP Server Startup Script
# Starts the MCP (Model Context Protocol) server for agent coordination

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="${WORKSPACE_ROOT}/Tools/Automation"
LOG_FILE="${SCRIPT_DIR}/logs/mcp_server.log"
PID_FILE="${SCRIPT_DIR}/services/mcp.pid"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_status() { echo -e "${BLUE}🔄 $1${NC}"; }

# Check if already running
if [[ -f "$PID_FILE" ]]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        print_success "MCP server already running (PID: $PID)"
        exit 0
    else
        print_warning "Removing stale PID file"
        rm -f "$PID_FILE"
    fi
fi

# Create log directory
mkdir -p "${SCRIPT_DIR}/logs"
mkdir -p "${SCRIPT_DIR}/services"

print_status "Starting MCP server..."

# Check if virtual environment exists
if [[ ! -f "${WORKSPACE_ROOT}/.venv/bin/activate" ]]; then
    print_error "Virtual environment not found at ${WORKSPACE_ROOT}/.venv"
    print_info "Run: python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt"
    exit 1
fi

# Check if MCP server script exists
if [[ ! -f "${WORKSPACE_ROOT}/mcp_server.py" ]]; then
    print_error "MCP server script not found at ${WORKSPACE_ROOT}/mcp_server.py"
    exit 1
fi

# Start MCP server in background
print_info "Starting MCP server on http://127.0.0.1:5005"
source "${WORKSPACE_ROOT}/.venv/bin/activate"
python3 "${WORKSPACE_ROOT}/mcp_server.py" >"$LOG_FILE" 2>&1 &
MCP_PID=$!

# Save PID
echo "$MCP_PID" >"$PID_FILE"

# Wait for server to start
print_info "Waiting for MCP server to start..."
attempts=0
while [[ $attempts -lt 10 ]]; do
    if curl -sf --max-time 2 "http://127.0.0.1:5005/health" &>/dev/null; then
        print_success "MCP server started successfully (PID: $MCP_PID)"
        print_info "Server running at: http://127.0.0.1:5005"
        exit 0
    fi
    sleep 1
    ((attempts++))
done

print_error "MCP server failed to start within 10 seconds"
print_info "Check logs at: $LOG_FILE"
exit 1

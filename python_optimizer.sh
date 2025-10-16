#!/bin/bash

# Python Environment Optimizer for Quantum Workspace
# Ensures all Python scripts use the virtual environment

set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VENV_PYTHON="${WORKSPACE_DIR}/.venv/bin/python3"
VENV_PIP="${WORKSPACE_DIR}/.venv/bin/pip"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[PYTHON-OPTIMIZE]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Ensure virtual environment exists and is up to date
setup_venv() {
    print_status "Setting up Python virtual environment"

    if [[ ! -d "${WORKSPACE_DIR}/.venv" ]]; then
        print_status "Creating virtual environment"
        python3 -m venv "${WORKSPACE_DIR}/.venv"
    fi

    if [[ ! -x "$VENV_PYTHON" ]]; then
        print_error "Virtual environment Python not found"
        return 1
    fi

    # Check if basic packages are installed, install if missing
    print_status "Checking and installing basic packages"
    if ! "$VENV_PYTHON" -c "import flask, requests" 2>/dev/null; then
        print_status "Installing missing packages"
        "$VENV_PIP" install --quiet flask requests python-dotenv || {
            print_warning "Some packages may not have installed correctly"
        }
    else
        print_success "Basic packages already installed"
    fi

    print_success "Virtual environment ready"
}

# Create wrapper scripts for Python tools
create_python_wrappers() {
    print_status "Creating Python wrapper scripts"

    # MCP Server wrapper
    cat >"${WORKSPACE_DIR}/Tools/Automation/mcp_server_venv.sh" <<EOF
#!/bin/bash
# MCP Server wrapper using virtual environment

WORKSPACE_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/../.." && pwd)"
source "\${WORKSPACE_DIR}/.venv/bin/activate"
exec python3 "\${WORKSPACE_DIR}/Tools/Automation/mcp_server.py" "\$@"
EOF

    # MCP Controller wrapper
    cat >"${WORKSPACE_DIR}/Tools/Automation/mcp_controller_venv.sh" <<EOF
#!/bin/bash
# MCP Controller wrapper using virtual environment

WORKSPACE_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/../.." && pwd)"
source "\${WORKSPACE_DIR}/.venv/bin/activate"
exec python3 "\${WORKSPACE_DIR}/Tools/Automation/mcp_controller.py" "\$@"
EOF

    # MCP Dashboard wrapper
    cat >"${WORKSPACE_DIR}/Tools/Automation/mcp_dashboard_venv.sh" <<EOF
#!/bin/bash
# MCP Dashboard wrapper using virtual environment

WORKSPACE_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/../.." && pwd)"
source "\${WORKSPACE_DIR}/.venv/bin/activate"
exec python3 "\${WORKSPACE_DIR}/Tools/Automation/mcp_dashboard_flask.py" "\$@"
EOF

    # Make wrappers executable
    chmod +x "${WORKSPACE_DIR}/Tools/Automation/mcp_server_venv.sh"
    chmod +x "${WORKSPACE_DIR}/Tools/Automation/mcp_controller_venv.sh"
    chmod +x "${WORKSPACE_DIR}/Tools/Automation/mcp_dashboard_venv.sh"

    print_success "Python wrappers created"
}

# Optimize MCP server for lower memory usage
optimize_mcp_server() {
    print_status "Optimizing MCP server for lower memory usage"

    local mcp_server="${WORKSPACE_DIR}/Tools/Automation/mcp_server.py"

    if [[ ! -f "$mcp_server" ]]; then
        print_warning "MCP server not found"
        return
    fi

    # Add memory optimization settings
    # Reduce task history retention
    sed -i.bak 's/TASK_TTL_DAYS = int(os.environ.get("TASK_TTL_DAYS", "30"))/TASK_TTL_DAYS = int(os.environ.get("TASK_TTL_DAYS", "7"))/' "$mcp_server"

    # Reduce rate limits for lower resource usage
    sed -i.bak 's/RATE_LIMIT_MAX_REQS = int(os.environ.get("RATE_LIMIT_MAX_REQS", "600"))/RATE_LIMIT_MAX_REQS = int(os.environ.get("RATE_LIMIT_MAX_REQS", "100"))/' "$mcp_server"

    # Clean up backup files
    rm -f "${mcp_server}.bak"

    print_success "MCP server optimized for lower memory usage"
}

# Create resource monitoring script
create_resource_monitor() {
    print_status "Creating resource monitoring script"

    cat >"${WORKSPACE_DIR}/Tools/Automation/resource_monitor.sh" <<'EOF'
#!/bin/bash
# Resource monitoring script for Quantum Workspace

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}[RESOURCE-MONITOR]${NC} $(date)"

# Check disk usage
echo "Disk Usage:"
df -h "$WORKSPACE_DIR" | tail -1
echo ""

# Check memory usage of key processes
echo "Key Process Memory Usage:"
ps aux | grep -E "(mcp_server|ollama|python.*mcp)" | grep -v grep | awk '{print $2, $4"%", $11}' || echo "No MCP/Ollama processes found"
echo ""

# Check backup directory sizes
echo "Backup Directory Sizes:"
du -sh "$WORKSPACE_DIR/.autofix_backups" "$WORKSPACE_DIR/Tools/Automation/agents/backups" "$WORKSPACE_DIR/.backups" 2>/dev/null || echo "Some backup directories not found"
echo ""

# Check for large files
echo "Largest Files (>100MB):"
find "$WORKSPACE_DIR" -type f -size +100M -exec ls -lh {} \; 2>/dev/null | head -5 || echo "No large files found"
EOF

    chmod +x "${WORKSPACE_DIR}/Tools/Automation/resource_monitor.sh"

    print_success "Resource monitoring script created"
}

# Create on-demand Ollama service
create_ollama_ondemand() {
    print_status "Creating on-demand Ollama service"

    cat >"${WORKSPACE_DIR}/Tools/Automation/ollama_service.sh" <<'EOF'
#!/bin/bash
# On-demand Ollama service manager

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

start_ollama() {
    if ! pgrep -f "ollama serve" >/dev/null; then
        echo "Starting Ollama service..."
        nohup ollama serve >/dev/null 2>&1 &
        sleep 3
        echo "Ollama started"
    else
        echo "Ollama already running"
    fi
}

stop_ollama() {
    if pgrep -f "ollama serve" >/dev/null; then
        echo "Stopping Ollama service..."
        pkill -f "ollama serve"
        sleep 2
        echo "Ollama stopped"
    else
        echo "Ollama not running"
    fi
}

case "${1:-status}" in
    start)
        start_ollama
        ;;
    stop)
        stop_ollama
        ;;
    restart)
        stop_ollama
        sleep 2
        start_ollama
        ;;
    status)
        if pgrep -f "ollama serve" >/dev/null; then
            echo "Ollama is running"
        else
            echo "Ollama is not running"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
EOF

    chmod +x "${WORKSPACE_DIR}/Tools/Automation/ollama_service.sh"

    print_success "On-demand Ollama service created"
}

# Main function
main() {
    print_status "Quantum Workspace Python Environment Optimization"
    echo "=================================================="

    setup_venv
    echo ""

    create_python_wrappers
    echo ""

    optimize_mcp_server
    echo ""

    create_resource_monitor
    echo ""

    create_ollama_ondemand
    echo ""

    print_success "Python environment optimization complete!"
    echo ""
    echo "Next steps:"
    echo "1. Use mcp_server_venv.sh instead of python3 mcp_server.py"
    echo "2. Use mcp_controller_venv.sh instead of python3 mcp_controller.py"
    echo "3. Use ollama_service.sh to control Ollama on-demand"
    echo "4. Run resource_monitor.sh periodically to check resource usage"
}

main "$@"
EOF

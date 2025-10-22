#!/bin/bash
# Unified Dashboard Agent - Advanced Web Interface for Agent Management
# Provides real-time monitoring, control, and visualization of all agents

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
AGENTS_DIR="${SCRIPT_DIR}"
AGENT_NAME="unified_dashboard_agent"
MCP_URL="${MCP_URL:-http://127.0.0.1:5005}"
LOG_FILE="${AGENTS_DIR}/${AGENT_NAME}.log"
STATUS_FILE="${AGENTS_DIR}/agent_status.json"
DASHBOARD_DIR="${WORKSPACE_ROOT}/.dashboard"
DASHBOARD_DATA="${DASHBOARD_DIR}/dashboard_data.json"
DASHBOARD_CONFIG="${DASHBOARD_DIR}/config.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Logging functions
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] $*" >&2
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] ERROR: $*${NC}" >&2
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] ✅ $*${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] ⚠️  $*${NC}" >&2
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] ℹ️  $*${NC}" >&2
}

quantum_log() {
    echo -e "${PURPLE}[$(date +'%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] 🌀 $*${NC}" >&2
}

# Initialize dashboard directories
mkdir -p "${DASHBOARD_DIR}"
mkdir -p "${DASHBOARD_DIR}/static"
mkdir -p "${DASHBOARD_DIR}/templates"
mkdir -p "${DASHBOARD_DIR}/api"

# Update agent status
update_agent_status() {
    local agent_script="$1"
    local status="$2"
    local pid="$3"
    local task="$4"

    if [[ ! -f "${STATUS_FILE}" ]]; then
        echo "{}" >"${STATUS_FILE}"
    fi

    python3 -c "
import json
import time
try:
    with open('${STATUS_FILE}', 'r') as f:
        data = json.load(f)
except:
    data = {}

if 'agents' not in data:
    data['agents'] = {}

data['agents']['${agent_script}'] = {
    'status': '${status}',
    'pid': ${pid},
    'last_seen': int(time.time()),
    'task': '${task}',
    'capabilities': ['dashboard', 'monitoring', 'visualization', 'quantum-interface']
}

with open('${STATUS_FILE}', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null || true
}

# Generate dashboard configuration
generate_dashboard_config() {
    cat >"${DASHBOARD_CONFIG}" <<EOF
{
  "dashboard": {
    "title": "Quantum Workspace Dashboard",
    "version": "3.0",
    "theme": "quantum",
    "port": 8080,
    "host": "127.0.0.1",
    "auto_refresh": 30,
    "quantum_enabled": true
  },
  "widgets": {
    "agent_status": {
      "enabled": true,
      "position": "top-left",
      "size": "large"
    },
    "system_metrics": {
      "enabled": true,
      "position": "top-right",
      "size": "medium"
    },
    "task_queue": {
      "enabled": true,
      "position": "middle-left",
      "size": "large"
    },
    "quantum_monitor": {
      "enabled": true,
      "position": "middle-right",
      "size": "medium"
    },
    "performance_charts": {
      "enabled": true,
      "position": "bottom",
      "size": "full"
    }
  },
  "alerts": {
    "enabled": true,
    "email_notifications": false,
    "desktop_notifications": true,
    "quantum_anomalies": true
  }
}
EOF
}

# Collect real-time agent data
collect_agent_data() {
    local data_file="$1"

    if [[ ! -f "${STATUS_FILE}" ]]; then
        echo '{"agents": {}, "timestamp": 0}' >"${data_file}"
        return
    fi

    python3 -c "
import json
import time
import psutil
import os

try:
    with open('${STATUS_FILE}', 'r') as f:
        status_data = json.load(f)

    # Get system metrics
    system_metrics = {
        'cpu_percent': psutil.cpu_percent(interval=1),
        'memory_percent': psutil.virtual_memory().percent,
        'disk_usage': psutil.disk_usage('/').percent,
        'network_connections': 0  # Skip due to macOS permissions
    }

    # Process agent data
    agents = {}
    for agent_name, agent_info in status_data.get('agents', {}).items():
        # Check if process is actually running
        pid = agent_info.get('pid', 0)
        is_running = False
        if pid > 0:
            try:
                os.kill(pid, 0)  # Check if process exists
                is_running = True
            except OSError:
                is_running = False

        agents[agent_name] = {
            'name': agent_name,
            'status': agent_info.get('status', 'unknown'),
            'pid': pid,
            'last_seen': agent_info.get('last_seen', 0),
            'is_running': is_running,
            'capabilities': agent_info.get('capabilities', []),
            'tasks_completed': agent_info.get('tasks_completed', 0),
            'uptime': time.time() - agent_info.get('last_seen', time.time())
        }

    dashboard_data = {
        'timestamp': int(time.time()),
        'date': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        'agents': agents,
        'system_metrics': system_metrics,
        'agent_summary': {
            'total': len(agents),
            'running': sum(1 for a in agents.values() if a['is_running']),
            'stopped': sum(1 for a in agents.values() if not a['is_running']),
            'tasks_completed': sum(a.get('tasks_completed', 0) for a in agents.values())
        }
    }

    with open('${data_file}', 'w') as f:
        json.dump(dashboard_data, f, indent=2)

except Exception as e:
    print(f'Error collecting agent data: {e}', file=__import__('sys').stderr)
    exit(1)
" 2>/dev/null || {
        warning "Failed to collect agent data"
        return 1
    }

    success "Agent data collected: ${data_file}"
}

# Generate HTML dashboard
generate_html_dashboard() {
    local html_file="${DASHBOARD_DIR}/index.html"

    cat >"${html_file}" <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Quantum Workspace Dashboard</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #0f0f23 0%, #1a1a2e 100%);
            color: #ffffff;
            overflow-x: hidden;
        }

        .header {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            padding: 1rem 2rem;
            border-bottom: 1px solid rgba(255, 255, 255, 0.2);
            position: sticky;
            top: 0;
            z-index: 100;
        }

        .header h1 {
            color: #00ffff;
            text-shadow: 0 0 20px #00ffff;
        }

        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
            gap: 1.5rem;
            padding: 2rem;
        }

        .card {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
            border-radius: 15px;
            padding: 1.5rem;
            transition: all 0.3s ease;
        }

        .card:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 30px rgba(0, 255, 255, 0.3);
        }

        .card-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 1rem;
        }

        .card-title {
            color: #00ffff;
            font-size: 1.2rem;
            font-weight: bold;
        }

        .status-indicator {
            width: 12px;
            height: 12px;
            border-radius: 50%;
            display: inline-block;
        }

        .status-running { background-color: #00ff00; }
        .status-stopped { background-color: #ff4444; }
        .status-unknown { background-color: #ffff00; }

        .metric {
            display: flex;
            justify-content: space-between;
            margin-bottom: 0.5rem;
        }

        .metric-label { opacity: 0.8; }
        .metric-value { font-weight: bold; color: #00ffff; }

        .progress-bar {
            width: 100%;
            height: 8px;
            background: rgba(255, 255, 255, 0.2);
            border-radius: 4px;
            overflow: hidden;
            margin-top: 0.5rem;
        }

        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #00ffff, #0080ff);
            transition: width 0.3s ease;
        }

        .agent-list {
            max-height: 300px;
            overflow-y: auto;
        }

        .agent-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 0.5rem;
            margin-bottom: 0.5rem;
            background: rgba(255, 255, 255, 0.05);
            border-radius: 8px;
        }

        .agent-name { font-weight: bold; }
        .agent-status { font-size: 0.8rem; }

        .quantum-effect {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            pointer-events: none;
            z-index: -1;
        }

        .quantum-effect::before {
            content: '';
            position: absolute;
            top: 10%;
            left: 10%;
            width: 200px;
            height: 200px;
            background: radial-gradient(circle, rgba(0, 255, 255, 0.1) 0%, transparent 70%);
            border-radius: 50%;
            animation: quantum-pulse 4s ease-in-out infinite;
        }

        @keyframes quantum-pulse {
            0%, 100% { transform: scale(1); opacity: 0.3; }
            50% { transform: scale(1.2); opacity: 0.6; }
        }

        .refresh-btn {
            background: linear-gradient(45deg, #00ffff, #0080ff);
            border: none;
            color: white;
            padding: 0.5rem 1rem;
            border-radius: 8px;
            cursor: pointer;
            font-weight: bold;
            transition: all 0.3s ease;
        }

        .refresh-btn:hover {
            transform: scale(1.05);
            box-shadow: 0 5px 15px rgba(0, 255, 255, 0.4);
        }
    </style>
</head>
<body>
    <div class="quantum-effect"></div>

    <header class="header">
        <h1>🌀 Quantum Workspace Dashboard</h1>
        <button class="refresh-btn" onclick="refreshData()">🔄 Refresh</button>
    </header>

    <div class="grid">
        <div class="card">
            <div class="card-header">
                <h2 class="card-title">📊 Agent Status</h2>
                <span class="status-indicator status-running" id="overall-status"></span>
            </div>
            <div id="agent-summary">
                <div class="metric">
                    <span class="metric-label">Total Agents:</span>
                    <span class="metric-value" id="total-agents">0</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Running:</span>
                    <span class="metric-value" id="running-agents">0</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Stopped:</span>
                    <span class="metric-value" id="stopped-agents">0</span>
                </div>
            </div>
        </div>

        <div class="card">
            <div class="card-header">
                <h2 class="card-title">⚡ System Metrics</h2>
            </div>
            <div id="system-metrics">
                <div class="metric">
                    <span class="metric-label">CPU Usage:</span>
                    <span class="metric-value" id="cpu-usage">0%</span>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" id="cpu-bar" style="width: 0%"></div>
                </div>
                <div class="metric">
                    <span class="metric-label">Memory Usage:</span>
                    <span class="metric-value" id="memory-usage">0%</span>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" id="memory-bar" style="width: 0%"></div>
                </div>
            </div>
        </div>

        <div class="card">
            <div class="card-header">
                <h2 class="card-title">🎯 Active Agents</h2>
            </div>
            <div class="agent-list" id="active-agents">
                <p>Loading agents...</p>
            </div>
        </div>

        <div class="card">
            <div class="card-header">
                <h2 class="card-title">🌀 Quantum Status</h2>
            </div>
            <div id="quantum-status">
                <div class="metric">
                    <span class="metric-label">Entanglement:</span>
                    <span class="metric-value">Active</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Multiverse:</span>
                    <span class="metric-value">Stable</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Consciousness:</span>
                    <span class="metric-value">Evolving</span>
                </div>
            </div>
        </div>
    </div>

    <script>
        let dashboardData = {};

        async function loadData() {
            try {
                const response = await fetch('./api/dashboard-data.json');
                dashboardData = await response.json();
                updateDashboard();
            } catch (error) {
                console.error('Failed to load dashboard data:', error);
            }
        }

        function updateDashboard() {
            // Update agent summary
            const summary = dashboardData.agent_summary || {};
            document.getElementById('total-agents').textContent = summary.total || 0;
            document.getElementById('running-agents').textContent = summary.running || 0;
            document.getElementById('stopped-agents').textContent = summary.stopped || 0;

            // Update overall status
            const overallStatus = document.getElementById('overall-status');
            if ((summary.running || 0) > (summary.total || 0) * 0.8) {
                overallStatus.className = 'status-indicator status-running';
            } else if ((summary.running || 0) > 0) {
                overallStatus.className = 'status-indicator status-unknown';
            } else {
                overallStatus.className = 'status-indicator status-stopped';
            }

            // Update system metrics
            const metrics = dashboardData.system_metrics || {};
            const cpuUsage = metrics.cpu_percent || 0;
            const memoryUsage = metrics.memory_percent || 0;

            document.getElementById('cpu-usage').textContent = cpuUsage.toFixed(1) + '%';
            document.getElementById('cpu-bar').style.width = cpuUsage + '%';

            document.getElementById('memory-usage').textContent = memoryUsage.toFixed(1) + '%';
            document.getElementById('memory-bar').style.width = memoryUsage + '%';

            // Update active agents list
            const agents = dashboardData.agents || {};
            const activeAgentsDiv = document.getElementById('active-agents');
            activeAgentsDiv.innerHTML = '';

            Object.values(agents).forEach(agent => {
                if (agent.is_running) {
                    const agentDiv = document.createElement('div');
                    agentDiv.className = 'agent-item';

                    const nameSpan = document.createElement('span');
                    nameSpan.className = 'agent-name';
                    nameSpan.textContent = agent.name.replace('_', ' ').replace('.sh', '');

                    const statusSpan = document.createElement('span');
                    statusSpan.className = 'agent-status';
                    statusSpan.textContent = agent.status;

                    agentDiv.appendChild(nameSpan);
                    agentDiv.appendChild(statusSpan);
                    activeAgentsDiv.appendChild(agentDiv);
                }
            });

            if (activeAgentsDiv.children.length === 0) {
                activeAgentsDiv.innerHTML = '<p>No active agents</p>';
            }
        }

        function refreshData() {
            loadData();
        }

        // Auto-refresh every 30 seconds
        setInterval(refreshData, 30000);

        // Initial load
        loadData();
    </script>
</body>
</html>
EOF

    success "HTML dashboard generated: ${html_file}"
}

# Start dashboard server
start_dashboard_server() {
    local port=8080
    local server_pid_file="${DASHBOARD_DIR}/server.pid"

    # Check if server is already running
    if [[ -f "${server_pid_file}" ]]; then
        local existing_pid
        existing_pid=$(cat "${server_pid_file}")
        if kill -0 "${existing_pid}" 2>/dev/null; then
            warning "Dashboard server already running (PID: ${existing_pid})"
            return 0
        fi
    fi

    info "Starting dashboard server on port ${port}..."

    # Start simple HTTP server
    cd "${DASHBOARD_DIR}" && python3 -m http.server "${port}" >"${LOG_FILE}" 2>&1 &
    local server_pid=$!
    echo "${server_pid}" >"${server_pid_file}"

    success "Dashboard server started (PID: ${server_pid}) on http://127.0.0.1:${port}"

    # Wait a moment for server to start
    sleep 2

    # Open browser (macOS)
    if command -v open &>/dev/null; then
        open "http://127.0.0.1:${port}" 2>/dev/null || true
    fi
}

# Stop dashboard server
stop_dashboard_server() {
    local server_pid_file="${DASHBOARD_DIR}/server.pid"

    if [[ -f "${server_pid_file}" ]]; then
        local server_pid
        server_pid=$(cat "${server_pid_file}")
        if kill -0 "${server_pid}" 2>/dev/null; then
            kill "${server_pid}" 2>/dev/null || true
            success "Dashboard server stopped (PID: ${server_pid})"
        fi
        rm -f "${server_pid_file}"
    fi
}

# Generate API endpoints
generate_api_endpoints() {
    local api_dir="${DASHBOARD_DIR}/api"

    # Create API data files
    collect_agent_data "${api_dir}/dashboard-data.json"
    collect_agent_data "${api_dir}/agents.json"

    # Create API index
    cat >"${api_dir}/index.json" <<EOF
{
  "api_version": "1.0",
  "endpoints": {
    "dashboard-data": "/api/dashboard-data.json",
    "agents": "/api/agents.json",
    "config": "/api/config.json"
  },
  "quantum_features": {
    "entanglement_monitoring": true,
    "multiverse_navigation": true,
    "consciousness_tracking": true
  }
}
EOF

    success "API endpoints generated in: ${api_dir}"
}

# Main agent loop
main() {
    log "Unified Dashboard Agent starting..."
    update_agent_status "unified_dashboard_agent.sh" "starting" $$ ""

    # Create PID file
    echo $$ >"${AGENTS_DIR}/${AGENT_NAME}.pid"

    # Generate dashboard configuration
    generate_dashboard_config

    # Register with MCP
    if command -v curl &>/dev/null; then
        curl -s -X POST "${MCP_URL}/register" \
            -H "Content-Type: application/json" \
            -d "{\"agent\": \"${AGENT_NAME}\", \"capabilities\": [\"dashboard\", \"monitoring\", \"visualization\", \"quantum-interface\"]}" \
            &>/dev/null || warning "Failed to register with MCP"
    fi

    update_agent_status "unified_dashboard_agent.sh" "available" $$ ""
    success "Unified Dashboard Agent ready"

    # Generate initial dashboard
    generate_html_dashboard
    generate_api_endpoints
    start_dashboard_server

    # Main loop - update dashboard every 30 seconds
    while true; do
        update_agent_status "unified_dashboard_agent.sh" "running" $$ ""

        # Update dashboard data
        collect_agent_data "${DASHBOARD_DATA}"
        generate_api_endpoints

        update_agent_status "unified_dashboard_agent.sh" "available" $$ ""
        success "Dashboard updated. Next refresh in 30 seconds."

        # Send heartbeat to MCP
        if command -v curl &>/dev/null; then
            curl -s -X POST "${MCP_URL}/heartbeat" \
                -H "Content-Type: application/json" \
                -d "{\"agent\": \"${AGENT_NAME}\", \"status\": \"available\", \"dashboard_active\": true}" \
                &>/dev/null || true
        fi

        # Sleep for 30 seconds
        sleep 30
    done
}

# Handle CLI commands
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-daemon}" in
    start)
        main
        ;;
    stop)
        stop_dashboard_server
        update_agent_status "unified_dashboard_agent.sh" "stopped" $$ ""
        exit 0
        ;;
    generate)
        generate_html_dashboard
        generate_api_endpoints
        ;;
    server)
        start_dashboard_server
        ;;
    daemon)
        trap 'stop_dashboard_server; update_agent_status "unified_dashboard_agent.sh" "stopped" $$ ""; log "Unified Dashboard Agent stopping..."; exit 0' SIGTERM SIGINT
        main "$@"
        ;;
    *)
        echo "Usage: $0 {start|stop|generate|server|daemon}"
        echo ""
        echo "Commands:"
        echo "  start    - Start dashboard and agent"
        echo "  stop     - Stop dashboard server"
        echo "  generate - Generate dashboard files"
        echo "  server   - Start only the dashboard server"
        echo "  daemon   - Run as daemon (default)"
        exit 1
        ;;
    esac
fi

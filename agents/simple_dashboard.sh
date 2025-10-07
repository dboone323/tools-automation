#!/bin/bash
# Simplified Unified Dashboard Agent

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_NAME="UnifiedDashboard"
LOG_FILE="${SCRIPT_DIR}/simple_dashboard.log"
DASHBOARD_HTML_FILE="${SCRIPT_DIR}/simple_dashboard.html"
DASHBOARD_DATA_FILE="${SCRIPT_DIR}/simple_dashboard_data.json"

# Simple configuration
DASHBOARD_PORT=8080
UPDATE_INTERVAL=30

log_message() {
  local level="$1"
  local message="$2"
  echo "[$(date)] [${AGENT_NAME}] [${level}] ${message}" >>"${LOG_FILE}"
}

# Create basic dashboard data
create_basic_data() {
  cat >"${DASHBOARD_DATA_FILE}" <<'EOF'
{
  "agents": {
    "task_orchestrator_agent": {"status": "available", "last_seen": "2025-08-29T12:00:00Z", "tasks_completed": 0},
    "pull_request_agent": {"status": "available", "last_seen": "2025-08-29T12:00:00Z", "tasks_completed": 0},
    "auto_update_agent": {"status": "available", "last_seen": "2025-08-29T12:00:00Z", "tasks_completed": 0},
    "knowledge_base_agent": {"status": "available", "last_seen": "2025-08-29T12:00:00Z", "tasks_completed": 0},
    "public_api_agent": {"status": "available", "last_seen": "2025-08-29T12:00:00Z", "tasks_completed": 0},
    "unified_dashboard_agent": {"status": "running", "last_seen": "2025-08-29T12:00:00Z", "tasks_completed": 0}
  },
  "system": {
    "cpu_usage": "25%",
    "memory_usage": "2.1GB",
    "disk_usage": "45%",
    "network_connections": "12",
    "process_count": "89"
  },
  "tasks": {
    "active": [],
    "completed": [],
    "failed": [],
    "queued": []
  },
  "last_update": 0
}
EOF
}

# Generate simple dashboard HTML
generate_simple_html() {
  cat >"${DASHBOARD_HTML_FILE}" <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Quantum Workspace Dashboard</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { text-align: center; margin-bottom: 30px; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .card { background: rgba(255,255,255,0.1); border-radius: 10px; padding: 20px; backdrop-filter: blur(10px); }
        .agent-item { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid rgba(255,255,255,0.2); }
        .status-healthy { color: #28a745; }
        .status-available { color: #28a745; }
        .metric { display: flex; justify-content: space-between; padding: 10px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Quantum Workspace Agent Dashboard</h1>
            <p>Real-time monitoring of your AI agent ecosystem</p>
        </div>

        <div class="grid">
            <div class="card">
                <h3>🤖 Agent Status</h3>
                <div id="agentList">
                    <div class="agent-item">
                        <span>Loading agents...</span>
                    </div>
                </div>
            </div>

            <div class="card">
                <h3>📊 System Metrics</h3>
                <div id="systemMetrics">
                    <div class="metric">
                        <span>Loading metrics...</span>
                    </div>
                </div>
            </div>

            <div class="card">
                <h3>📋 Task Queue</h3>
                <div id="taskQueue">
                    <p>No active tasks</p>
                </div>
            </div>
        </div>

        <div style="text-align: center; margin-top: 30px; opacity: 0.8;">
            <p>Dashboard last updated: <span id="lastUpdate">Loading...</span></p>
        </div>
    </div>

    <script>
        let dashboardData = {};

        async function loadDashboardData() {
            try {
                const response = await fetch('./simple_dashboard_data.json');
                dashboardData = await response.json();
                return true;
            } catch (error) {
                console.error('Error loading data:', error);
                return false;
            }
        }

        function updateAgentList() {
            const container = document.getElementById('agentList');
            if (dashboardData.agents) {
                let html = '';
                Object.entries(dashboardData.agents).forEach(([name, data]) => {
                    const statusClass = data.status === 'running' ? 'status-healthy' : 'status-available';
                    html += `
                        <div class="agent-item">
                            <span>${name.replace(/_/g, ' ')}</span>
                            <span class="${statusClass}">${data.status}</span>
                        </div>
                    `;
                });
                container.innerHTML = html;
            }
        }

        function updateSystemMetrics() {
            const container = document.getElementById('systemMetrics');
            if (dashboardData.system) {
                let html = '';
                Object.entries(dashboardData.system).forEach(([key, value]) => {
                    const displayName = key.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
                    html += `
                        <div class="metric">
                            <span>${displayName}</span>
                            <span>${value}</span>
                        </div>
                    `;
                });
                container.innerHTML = html;
            }
        }

        function updateLastUpdate() {
            document.getElementById('lastUpdate').textContent = new Date().toLocaleString();
        }

        // Initialize
        document.addEventListener('DOMContentLoaded', async function() {
            const loaded = await loadDashboardData();
            if (loaded) {
                updateAgentList();
                updateSystemMetrics();
            }
            updateLastUpdate();
        });

        // Auto-refresh every 30 seconds
        setInterval(async function() {
            const loaded = await loadDashboardData();
            if (loaded) {
                updateAgentList();
                updateSystemMetrics();
            }
            updateLastUpdate();
        }, 30000);
    </script>
</body>
</html>
EOF
}

# Start simple web server
start_server() {
  log_message "INFO" "Starting dashboard server on port ${DASHBOARD_PORT}"

  cd "${SCRIPT_DIR}" || exit 1
  python3 -m http.server "${DASHBOARD_PORT}" >>"${LOG_FILE}" 2>&1 &
  server_pid=$!
  echo "${server_pid}" >"${SCRIPT_DIR}/simple_server.pid"
  log_message "INFO" "Server started with PID ${server_pid}"
}

# Stop server
stop_server() {
  if [[ -f "${SCRIPT_DIR}/simple_server.pid" ]]; then
    local pid
    pid=$(<"${SCRIPT_DIR}/simple_server.pid")
    kill "${pid}" 2>/dev/null
    rm -f "${SCRIPT_DIR}/simple_server.pid"
    log_message "INFO" "Server stopped"
  fi
}

# Main execution
log_message "INFO" "Simple Dashboard Agent starting..."

# Create data and HTML
create_basic_data
generate_simple_html

# Start server
start_server

# Keep running and update data periodically
while true; do
  # Update timestamp in data
  current_timestamp=$(date +%s)
  sed -i '' -e "s/\"last_update\": [0-9]*/\"last_update\": ${current_timestamp}/" "${DASHBOARD_DATA_FILE}"

  sleep "${UPDATE_INTERVAL}"
done

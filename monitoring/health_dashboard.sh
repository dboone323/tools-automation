#!/usr/bin/env bash
#
# health_dashboard.sh - Web-based health dashboard for agent monitoring
#
# Provides a simple HTTP server with JSON API and HTML dashboard
# for monitoring agent status, health, and performance metrics.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
AGENTS_DIR="${REPO_ROOT}/agents"

# Configuration
PORT=${DASHBOARD_PORT:-5555}
LOG_FILE="${AGENTS_DIR}/logs/health_dashboard.log"

# Load configuration
if [[ -f "${REPO_ROOT}/.agent-system.conf" ]]; then
    PORT=$(grep "dashboard_port" "${REPO_ROOT}/.agent-system.conf" | cut -d= -f2 || echo "5555")
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Generate JSON status
get_agent_status() {
    local status_json="{"
    status_json+="\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    status_json+="\"agents\":["
    
    local first=true
    for agent_script in "${AGENTS_DIR}"/agent_*.sh "${AGENTS_DIR}"/*_agent.sh; do
        [[ ! -f "$agent_script" ]] && continue
        
        local agent_name=$(basename "$agent_script")
        [[ "$agent_name" == "agent_config_discovery.sh" ]] && continue
        
        local pid=$(pgrep -f "$agent_name" | head -1 || echo "0")
        local status="stopped"
        local uptime="0"
        local memory="0"
        local cpu="0.0"
        
        if [[ $pid -gt 0 ]]; then
            status="running"
            # Get uptime (seconds)
            uptime=$(ps -p "$pid" -o etimes= 2>/dev/null | tr -d ' ' || echo "0")
            # Get memory (KB)
            memory=$(ps -p "$pid" -o rss= 2>/dev/null | tr -d ' ' || echo "0")
            # Get CPU percentage
            cpu=$(ps -p "$pid" -o %cpu= 2>/dev/null | tr -d ' ' || echo "0.0")
        fi
        
        [[ "$first" == "false" ]] && status_json+=","
        first=false
        
        status_json+="{"
        status_json+="\"name\":\"$agent_name\","
        status_json+="\"pid\":$pid,"
        status_json+="\"status\":\"$status\","
        status_json+="\"uptime\":$uptime,"
        status_json+="\"memory_kb\":$memory,"
        status_json+="\"cpu_percent\":$cpu"
        status_json+="}"
    done
    
    status_json+="],"
    
    # System summary
    local running_count=$(pgrep -f "agent.*\.sh" 2>/dev/null | wc -l | tr -d ' ')
    status_json+="\"summary\":{"
    status_json+="\"total_running\":$running_count,"
    status_json+="\"supervisor_active\":$(launchctl list | grep -q agent-supervisor && echo "true" || echo "false"),"
    status_json+="\"daily_restart_scheduled\":$(launchctl list | grep -q daily-restart && echo "true" || echo "false")"
    status_json+="}"
    
    status_json+="}"
    echo "$status_json"
}

# Generate HTML dashboard
get_dashboard_html() {
    cat <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Agent Health Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0f172a; color: #e2e8f0; padding: 20px; }
        .container { max-width: 1200px; margin: 0 auto; }
        h1 { margin-bottom: 30px; font-size: 2rem; color: #60a5fa; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .card { background: #1e293b; padding: 20px; border-radius: 8px; border-left: 4px solid #60a5fa; }
        .card-title { font-size: 0.875rem; color: #94a3b8; margin-bottom: 8px; }
        .card-value { font-size: 2rem; font-weight: bold; color: #60a5fa; }
        .agents-grid { display: grid; gap: 12px; }
        .agent { background: #1e293b; padding: 16px; border-radius: 8px; display: grid; grid-template-columns: 1fr auto; align-items: center; }
        .agent.running { border-left: 4px solid #10b981; }
        .agent.stopped { border-left: 4px solid #ef4444; }
        .agent-name { font-weight: 500; color: #e2e8f0; }
        .agent-meta { font-size: 0.875rem; color: #94a3b8; margin-top: 4px; }
        .status { padding: 4px 12px; border-radius: 4px; font-size: 0.75rem; font-weight: 600; text-transform: uppercase; }
        .status.running { background: #10b98133; color: #10b981; }
        .status.stopped { background: #ef444433; color: #ef4444; }
        .refresh { position: fixed; bottom: 30px; right: 30px; background: #60a5fa; color: white; border: none; padding: 12px 24px; border-radius: 6px; cursor: pointer; font-weight: 600; box-shadow: 0 4px 6px rgba(0,0,0,0.3); }
        .refresh:hover { background: #3b82f6; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Agent Health Dashboard</h1>
        <div class="summary" id="summary"></div>
        <div class="agents-grid" id="agents"></div>
    </div>
    <button class="refresh" onclick="loadData()">Refresh</button>
    
    <script>
        async function loadData() {
            try {
                const response = await fetch('/api/status');
                const data = await response.json();
                
                // Update summary
                document.getElementById('summary').innerHTML = `
                    <div class="card">
                        <div class="card-title">Running Agents</div>
                        <div class="card-value">${data.summary.total_running}</div>
                    </div>
                    <div class="card">
                        <div class="card-title">Supervisor</div>
                        <div class="card-value">${data.summary.supervisor_active ? '✅' : '❌'}</div>
                    </div>
                    <div class="card">
                        <div class="card-title">Daily Restart</div>
                        <div class="card-value">${data.summary.daily_restart_scheduled ? '✅' : '❌'}</div>
                    </div>
                `;
                
                // Update agents
                const agentsHtml = data.agents.map(agent => {
                    const uptimeMin = Math.floor(agent.uptime / 60);
                    const memoryMB = (agent.memory_kb / 1024).toFixed(1);
                    return `
                        <div class="agent ${agent.status}">
                            <div>
                                <div class="agent-name">${agent.name}</div>
                                <div class="agent-meta">
                                    ${agent.status === 'running' ? 
                                        `PID: ${agent.pid} | Uptime: ${uptimeMin}m | Memory: ${memoryMB}MB | CPU: ${agent.cpu_percent}%` :
                                        'Not running'
                                    }
                                </div>
                            </div>
                            <span class="status ${agent.status}">${agent.status}</span>
                        </div>
                    `;
                }).join('');
                
                document.getElementById('agents').innerHTML = agentsHtml;
            } catch (error) {
                console.error('Failed to load data:', error);
            }
        }
        
        // Auto-refresh every 5 seconds
        loadData();
        setInterval(loadData, 5000);
    </script>
</body>
</html>
EOF
}

# Start HTTP server using Python
start_server() {
    log "Starting health dashboard on port $PORT..."
    
    # Create temporary Python server script
    cat > /tmp/dashboard_server.py <<PYEOF
#!/usr/bin/env python3
import http.server
import socketserver
import subprocess
import json

PORT = $PORT

class DashboardHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            html = subprocess.check_output(['bash', '${SCRIPT_DIR}/health_dashboard.sh', 'html'])
            self.wfile.write(html)
        elif self.path == '/api/status':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            status = subprocess.check_output(['bash', '${SCRIPT_DIR}/health_dashboard.sh', 'status'])
            self.wfile.write(status)
        else:
            self.send_error(404)
    
    def log_message(self, format, *args):
        pass  # Suppress log output

with socketserver.TCPServer(("", PORT), DashboardHandler) as httpd:
    print(f"Dashboard running at http://localhost:{PORT}")
    httpd.serve_forever()
PYEOF
    
    chmod +x /tmp/dashboard_server.py
    python3 /tmp/dashboard_server.py &
    local server_pid=$!
    
    echo "$server_pid" > /tmp/health_dashboard.pid
    log "Dashboard started (PID: $server_pid) at http://localhost:$PORT"
}

# Handle commands
case "${1:-serve}" in
    status)
        get_agent_status
        ;;
    html)
        get_dashboard_html
        ;;
    serve)
        start_server
        ;;
    stop)
        if [[ -f /tmp/health_dashboard.pid ]]; then
            kill $(cat /tmp/health_dashboard.pid) 2>/dev/null || true
            rm -f /tmp/health_dashboard.pid
            log "Dashboard stopped"
        fi
        ;;
    *)
        echo "Usage: $0 {status|html|serve|stop}"
        exit 1
        ;;
esac

#!/bin/bash
# Simplified Dashboard Agent Test

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/test_dashboard.log"
DASHBOARD_HTML_FILE="${SCRIPT_DIR}/test_dashboard.html"

echo "[$(date)] Starting simplified dashboard test..." >>"${LOG_FILE}"

# Create a simple HTML dashboard
cat >"${DASHBOARD_HTML_FILE}" <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Quantum Workspace Dashboard</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f0f0f0; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; }
        h1 { color: #333; text-align: center; }
        .status { padding: 10px; margin: 10px 0; border-radius: 5px; }
        .healthy { background: #d4edda; color: #155724; }
        .warning { background: #fff3cd; color: #856404; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Quantum Workspace Agent Dashboard</h1>
        <p>Dashboard loaded successfully at: <span id="timestamp"></span></p>

        <div class="status healthy">
            <h3>✅ System Status: Operational</h3>
            <p>All core agents are configured and ready.</p>
        </div>

        <div class="status warning">
            <h3>⚠️  Note</h3>
            <p>This is a simplified test dashboard. Full functionality will be available soon.</p>
        </div>

        <h3>Agent Overview:</h3>
        <ul>
            <li>✅ Task Orchestrator Agent</li>
            <li>✅ Pull Request Agent</li>
            <li>✅ Auto-Update Agent</li>
            <li>✅ Knowledge Base Agent</li>
            <li>✅ Public API Agent</li>
            <li>✅ Dashboard Agent (Current)</li>
        </ul>
    </div>

    <script>
        document.getElementById('timestamp').textContent = new Date().toLocaleString();
    </script>
</body>
</html>
EOF

echo "[$(date)] Created test dashboard HTML" >>"${LOG_FILE}"

# Start simple Python server
if command -v python3 &>/dev/null; then
  echo "[$(date)] Starting Python HTTP server on port 8080" >>"${LOG_FILE}"
  cd "$(dirname "${DASHBOARD_HTML_FILE}")" || exit
  python3 -m http.server 8080 >>"${LOG_FILE}" 2>&1 &
  server_pid=$!
  echo "${server_pid}" >"${SCRIPT_DIR}/test_server.pid"
  echo "[$(date)] Server started with PID ${server_pid}" >>"${LOG_FILE}"

  # Keep running for a short time
  sleep 30

  # Cleanup
  kill "${server_pid}" 2>/dev/null
  rm -f "${SCRIPT_DIR}/test_server.pid"
  echo "[$(date)] Test completed" >>"${LOG_FILE}"
else
  echo "[$(date)] ERROR: Python3 not available" >>"${LOG_FILE}"
fi

#!/bin/bash
# Minimal Dashboard Agent Test

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/minimal_dashboard.log"
DASHBOARD_HTML_FILE="${SCRIPT_DIR}/minimal_dashboard.html"

echo "[$(date)] Starting minimal dashboard..." >>"${LOG_FILE}"

# Create minimal HTML
cat >"${DASHBOARD_HTML_FILE}" <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Dashboard Test</title>
</head>
<body>
    <h1>Dashboard Working!</h1>
    <p>Loaded at: <span id="time"></span></p>
    <script>document.getElementById('time').textContent = new Date().toISOString();</script>
</body>
</html>
EOF

echo "[$(date)] HTML created" >>"${LOG_FILE}"

# Start server
cd "${SCRIPT_DIR}" || exit 1
python3 -m http.server 8080 >>"${LOG_FILE}" 2>&1 &
server_pid=$!
echo "${server_pid}" >"${SCRIPT_DIR}/minimal_server.pid"
echo "[$(date)] Server started with PID ${server_pid}" >>"${LOG_FILE}"

# Wait a bit
sleep 10

# Cleanup
kill "${server_pid}" 2>/dev/null || true
rm -f "${SCRIPT_DIR}/minimal_server.pid"
echo "[$(date)] Minimal test completed" >>"${LOG_FILE}"

#!/bin/bash
# Minimal Dashboard Agent Test (small, self-contained)

set -euo pipefail

# Source shared functions if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/shared_functions.sh" ]]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/shared_functions.sh"
fi

LOG_FILE="${LOG_FILE:-${SCRIPT_DIR}/minimal_dashboard.log}"
DASHBOARD_HTML_FILE="${DASHBOARD_HTML_FILE:-${SCRIPT_DIR}/minimal_dashboard.html}"

echo "[$(date)] Starting minimal dashboard..." >>"${LOG_FILE}"

# Create minimal HTML
cat >"${DASHBOARD_HTML_FILE}" <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Dashboard Test</title>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1" />
    <style>body{font-family:system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif;padding:2rem}</style>
</head>
<body>
    <h1>Dashboard Working!</h1>
    <p>Loaded at: <span id="time"></span></p>
    <script>document.getElementById('time').textContent = new Date().toISOString();</script>
</body>
</html>
EOF

echo "[$(date)] HTML created" >>"${LOG_FILE}"

# Start a temporary server for the test then exit (kept minimal for tests)
cd "${SCRIPT_DIR}" || exit 1
python3 -m http.server 8080 >>"${LOG_FILE}" 2>&1 &
server_pid=$!
echo "${server_pid}" >"${SCRIPT_DIR}/minimal_server.pid"
echo "[$(date)] Server started with PID ${server_pid}" >>"${LOG_FILE}"

# Wait briefly (test harness may query) then cleanup
sleep 3

# Cleanup
kill "${server_pid}" 2>/dev/null || true
rm -f "${SCRIPT_DIR}/minimal_server.pid"
echo "[$(date)] Minimal test completed" >>"${LOG_FILE}"

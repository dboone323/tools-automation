#!/bin/bash
# Simple HTTP server for AI Agent Dashboard and logs

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

SCRIPT_DIR="$(dirname "$0")"
cd "${SCRIPT_DIR}" || exit 1

PORT=8080
python3 -m http.server "${PORT}" &
echo "Dashboard available at http://localhost:${PORT}/agents/dashboard.html"

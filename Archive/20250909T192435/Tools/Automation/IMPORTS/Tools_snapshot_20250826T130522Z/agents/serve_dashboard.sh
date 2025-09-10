#!/bin/bash
# Simple HTTP server for AI Agent Dashboard and logs
cd "$(dirname "$0")"
PORT=8080
python3 -m http.server $PORT &
echo "Dashboard available at http://localhost:$PORT/agents/dashboard.html"

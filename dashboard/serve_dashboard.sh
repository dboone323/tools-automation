#!/bin/bash
# serve_dashboard.sh - Serve the dashboard over HTTP to avoid CORS issues

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DASHBOARD_DIR="$SCRIPT_DIR"
PORT=8080

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting Dashboard Server...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}📊 Dashboard URL:${NC} http://localhost:${PORT}/dashboard.html"
echo -e "${GREEN}📁 Serving from:${NC} ${DASHBOARD_DIR}"
echo -e "${GREEN}📄 Data file:${NC} ${ROOT_DIR}/Tools/dashboard_data.json"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop the server${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if port is available
if lsof -Pi :${PORT} -sTCP:LISTEN -t >/dev/null 2>&1; then
  echo -e "${YELLOW}⚠️  Port ${PORT} is already in use${NC}"
  echo -e "${YELLOW}Trying to open existing dashboard...${NC}"
  sleep 1
  open "http://localhost:${PORT}/dashboard.html" 2>/dev/null || true
  exit 0
fi

# Change to root directory so relative paths work
cd "$ROOT_DIR"

# Start Python HTTP server
if command -v python3 &>/dev/null; then
  echo "Starting server with Python 3..."
  echo ""

  # Open browser after 2 seconds
  (sleep 2 && open "http://localhost:${PORT}/Tools/Automation/dashboard/dashboard.html") &

  # Start server (will block until Ctrl+C)
  python3 -m http.server ${PORT}
elif command -v python &>/dev/null; then
  echo "Starting server with Python 2..."
  echo ""

  # Open browser after 2 seconds
  (sleep 2 && open "http://localhost:${PORT}/Tools/Automation/dashboard/dashboard.html") &

  # Start server (will block until Ctrl+C)
  python -m SimpleHTTPServer ${PORT}
else
  echo -e "${YELLOW}⚠️  Python not found. Please install Python to run the dashboard server.${NC}"
  echo ""
  echo -e "${BLUE}Alternative: Use VS Code Live Server extension${NC}"
  echo "  1. Install 'Live Server' extension in VS Code"
  echo "  2. Right-click dashboard.html → 'Open with Live Server'"
  exit 1
fi

#!/bin/bash
# generate_standalone_dashboard.sh - Generate dashboard with embedded data (no CORS issues)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DATA_FILE="${ROOT_DIR}/Tools/dashboard_data.json"
DASHBOARD_TEMPLATE="${SCRIPT_DIR}/dashboard.html"
OUTPUT_FILE="${ROOT_DIR}/Tools/dashboard_standalone.html"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}📊 Generating standalone dashboard with embedded data...${NC}"

# Check if data file exists
if [[ ! -f "$DATA_FILE" ]]; then
  echo -e "${YELLOW}⚠️  Data file not found, generating...${NC}"
  "$SCRIPT_DIR/generate_dashboard_data.sh"
fi

# Read the data file and escape it for JavaScript
DATA_JSON=$(cat "$DATA_FILE" | jq -c '.')

# Create standalone HTML with embedded data
cat >"$OUTPUT_FILE" <<'EOF_START'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard - Standalone (No CORS)</title>
    <style>
    /* Copy styles from main dashboard */
EOF_START

# Extract and include styles from main dashboard
sed -n '/<style>/,/<\/style>/p' "$DASHBOARD_TEMPLATE" | sed '1d;$d' >>"$OUTPUT_FILE"

cat >>"$OUTPUT_FILE" <<'EOF_STYLE'
    </style>
</head>
<body>
    <!-- Dashboard Header -->
    <header class="header">
      <div class="header-content">
        <h1>🎯 Quantum Workspace Dashboard</h1>
        <p class="subtitle">Real-time Monitoring & Observability</p>
      </div>
      <div class="header-actions">
        <span class="timestamp">Last Update: <span id="lastUpdate">--</span></span>
        <button class="btn btn-success" onclick="location.reload()">🔄 Refresh</button>
      </div>
    </header>

    <!-- Status Bar -->
    <div id="statusBar" class="status-bar">
      <div class="status-card loading"><h4>Agents</h4><div class="status-card-value">--</div><div class="status-card-label">Loading...</div><div class="status-indicator"></div></div>
      <div class="status-card loading"><h4>MCP Server</h4><div class="status-card-value">--</div><div class="status-card-label">Loading...</div><div class="status-indicator"></div></div>
      <div class="status-card loading"><h4>Ollama</h4><div class="status-card-value">--</div><div class="status-card-label">Loading...</div><div class="status-indicator"></div></div>
      <div class="status-card loading"><h4>Disk Usage</h4><div class="status-card-value">--</div><div class="status-card-label">Loading...</div><div class="status-indicator"></div></div>
      <div class="status-card loading"><h4>Tasks</h4><div class="status-card-value">--</div><div class="status-card-label">Loading...</div><div class="status-indicator"></div></div>
    </div>

    <!-- Main Dashboard Grid -->
    <div class="dashboard-grid">
      <!-- Workflows Card -->
      <div class="card">
        <div class="card-header">
          <h3>⚙️ Recent Workflows</h3>
          <span class="badge" id="workflowCount">0</span>
        </div>
        <div class="card-content">
          <div id="workflowList" class="loading">Loading workflows...</div>
        </div>
      </div>

      <!-- MCP Alerts Card -->
      <div class="card">
        <div class="card-header">
          <h3>🚨 MCP Alerts (24h)</h3>
          <span class="badge" id="alertCount">0</span>
        </div>
        <div class="card-content">
          <div id="mcpAlerts" class="loading">Loading alerts...</div>
        </div>
      </div>

      <!-- System Health Card -->
      <div class="card">
        <div class="card-header">
          <h3>💊 System Health</h3>
        </div>
        <div class="card-content">
          <div id="systemHealth" class="loading">Loading system health...</div>
        </div>
      </div>

      <!-- Latest Metrics Card -->
      <div class="card">
        <div class="card-header">
          <h3>� Daily Metrics</h3>
        </div>
        <div class="card-content">
          <div id="latestMetrics" class="loading">Loading metrics...</div>
        </div>
      </div>

      <!-- Task Summary Card -->
      <div class="card">
        <div class="card-header">
          <h3>📋 Task Summary</h3>
        </div>
        <div class="card-content">
          <div id="taskSummary" class="loading">Loading tasks...</div>
        </div>
      </div>

      <!-- Agents List (full width) -->
      <div class="card card-full-width">
        <div class="card-header">
          <h3>🤖 Agent Status</h3>
          <span class="badge" id="agentCount">0</span>
        </div>
        <div class="card-content">
          <div id="agentList" class="loading">Loading agents...</div>
        </div>
      </div>
    </div>

    <!-- Footer -->
    <footer class="footer">
      <div class="footer-content">
        <p>Data Generated: <span id="dataGenerated">--</span></p>
        <p style="margin-top: 5px; font-size: 0.9em; opacity: 0.8;">✅ Standalone version (embedded data, no CORS issues)</p>
      </div>
    </footer>

    <script>
EOF_STYLE

# Embed the data
echo "      // Embedded dashboard data (no CORS issues)" >>"$OUTPUT_FILE"
echo "      const dashboardData = $DATA_JSON;" >>"$OUTPUT_FILE"
echo "" >>"$OUTPUT_FILE"

# Extract JavaScript functions - get everything between "// Update status bar" and "// Initialize dashboard"
echo "      // Update Functions" >>"$OUTPUT_FILE"
sed -n '/\/\/ Update status bar/,/\/\/ Initialize dashboard/p' "$DASHBOARD_TEMPLATE" |
  sed '$d' >>"$OUTPUT_FILE" # Remove the last line (// Initialize dashboard)
echo "" >>"$OUTPUT_FILE"

cat >>"$OUTPUT_FILE" <<'EOF_END'

      // Initialize dashboard with embedded data
      document.addEventListener('DOMContentLoaded', function() {
        console.log('✅ Standalone dashboard initializing with embedded data...');
        console.log('📊 Data summary:', {
          generated: dashboardData.generated_at,
          workflows: dashboardData.workflows?.length || 0,
          disk: (dashboardData.system?.disk_usage?.percent || 0) + '%',
          ollama: dashboardData.ollama?.available ? 'available' : 'unavailable',
          mcp: dashboardData.mcp?.available ? 'online' : 'offline',
          agents: Object.keys(dashboardData.agents || {}).length
        });

        // Update all cards
        updateStatusBar();
        updateAgentList();
        updateWorkflows();
        updateMCPAlerts();
        updateSystemHealth();
        updateLatestMetrics();
        updateTaskSummary();
        updateTimestamps();

        console.log('✅ Dashboard initialized successfully');
        console.log('ℹ️  To refresh data: run generate_standalone_dashboard.sh and reload page');
      });
    </script>
</body>
</html>
EOF_END

echo -e "${GREEN}✅ Standalone dashboard generated: ${OUTPUT_FILE}${NC}"
echo -e "${BLUE}📊 Open with: open ${OUTPUT_FILE}${NC}"
echo -e "${YELLOW}ℹ️  Note: To refresh data, regenerate this file${NC}"

# Open in browser
if [[ "${1:-}" == "--open" ]]; then
  open "$OUTPUT_FILE"
  echo -e "${GREEN}✅ Opened in browser${NC}"
fi

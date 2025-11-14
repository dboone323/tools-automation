import { useState, useEffect } from "react";
import { invoke } from "@tauri-apps/api/core";
import "./App.css";

interface SystemStatus {
  autonomous_running: boolean;
  mcp_server_running: boolean;
  health_monitor_active: boolean;
  web_dashboards_available: boolean;
  last_health_check: string;
  autonomous_uptime?: string;
  mcp_uptime?: string;
}

function App() {
  const [systemStatus, setSystemStatus] = useState<SystemStatus>({
    autonomous_running: false,
    mcp_server_running: false,
    health_monitor_active: false,
    web_dashboards_available: false,
    last_health_check: ""
  });
  const [commandOutput, setCommandOutput] = useState("");
  const [activeTab, setActiveTab] = useState("dashboard");

  // Check system status on component mount and periodically
  useEffect(() => {
    checkSystemStatus();
    const interval = setInterval(checkSystemStatus, 5000); // Check every 5 seconds
    return () => clearInterval(interval);
  }, []);

  async function checkSystemStatus() {
    try {
      const status = await invoke("get_detailed_status") as SystemStatus;
      setSystemStatus(status);
    } catch (error) {
      console.error("Failed to get system status:", error);
    }
  }

  async function runSystemCommand(command: string) {
    try {
      const result = await invoke("run_system_command", { command }) as string;
      setCommandOutput(result);
    } catch (error) {
      setCommandOutput(`Error: ${error}`);
    }
  }

  async function startAutonomousSystem() {
    await runSystemCommand("start_autonomous");
    await checkSystemStatus();
  }

  async function stopAutonomousSystem() {
    await runSystemCommand("stop_autonomous");
    await checkSystemStatus();
  }

  async function startDashboardServer() {
    try {
      const result = await invoke("start_dashboard_server") as string;
      setCommandOutput(result);
      await checkSystemStatus(); // Refresh status after starting
    } catch (error) {
      setCommandOutput(`Error starting dashboard server: ${error}`);
    }
  }

  async function restartMcpServer() {
    await runSystemCommand("restart_mcp");
    await checkSystemStatus();
  }

  return (
    <div className="app">
      <header className="app-header">
        <h1>🚀 Hybrid Autonomy Control Center</h1>
        <div className="status-bar">
          <span className={`status-indicator ${systemStatus.autonomous_running ? 'active' : 'inactive'}`}>
            Autonomous: {systemStatus.autonomous_running ? 'Running' : 'Stopped'}
          </span>
          <span className={`status-indicator ${systemStatus.mcp_server_running ? 'active' : 'inactive'}`}>
            MCP Server: {systemStatus.mcp_server_running ? 'Active' : 'Inactive'}
          </span>
          <span className={`status-indicator ${systemStatus.health_monitor_active ? 'active' : 'inactive'}`}>
            Health Monitor: {systemStatus.health_monitor_active ? 'Active' : 'Inactive'}
          </span>
        </div>
      </header>

      <nav className="app-nav">
        <button
          className={activeTab === 'dashboard' ? 'active' : ''}
          onClick={() => setActiveTab('dashboard')}
        >
          📊 Dashboard
        </button>
        <button
          className={activeTab === 'controls' ? 'active' : ''}
          onClick={() => setActiveTab('controls')}
        >
          🎛️ Controls
        </button>
        <button
          className={activeTab === 'dashboards' ? 'active' : ''}
          onClick={() => setActiveTab('dashboards')}
        >
          🌐 Web Dashboards
        </button>
        <button
          className={activeTab === 'commands' ? 'active' : ''}
          onClick={() => setActiveTab('commands')}
        >
          💻 Commands
        </button>
      </nav>

      <main className="app-main">
        {activeTab === 'dashboard' && (
          <div className="dashboard">
            <h2>System Overview</h2>
            <div className="dashboard-grid">
              <div className="dashboard-card">
                <h3>🤖 Autonomous System</h3>
                <p>Status: {systemStatus.autonomous_running ? '🟢 Running' : '🔴 Stopped'}</p>
                {systemStatus.autonomous_uptime && <p>Uptime: {systemStatus.autonomous_uptime}</p>}
                <p>Last Check: {systemStatus.last_health_check || 'Never'}</p>
                <div className="card-actions">
                  <button onClick={startAutonomousSystem} disabled={systemStatus.autonomous_running}>
                    Start
                  </button>
                  <button onClick={stopAutonomousSystem} disabled={!systemStatus.autonomous_running}>
                    Stop
                  </button>
                </div>
              </div>

              <div className="dashboard-card">
                <h3>🔧 MCP Server</h3>
                <p>Status: {systemStatus.mcp_server_running ? '🟢 Active' : '🔴 Inactive'}</p>
                {systemStatus.mcp_uptime && <p>Uptime: {systemStatus.mcp_uptime}</p>}
                <div className="card-actions">
                  <button onClick={restartMcpServer}>
                    Restart
                  </button>
                </div>
              </div>

              <div className="dashboard-card">
                <h3>📊 Health Monitor</h3>
                <p>Status: {systemStatus.health_monitor_active ? '🟢 Active' : '🔴 Inactive'}</p>
                <div className="card-actions">
                  <button onClick={() => runSystemCommand("run_health_check")}>
                    Run Check
                  </button>
                </div>
              </div>

              <div className="dashboard-card">
                <h3>🌐 Web Dashboards</h3>
                <p>Status: {systemStatus.web_dashboards_available ? '🟢 Available' : '🔴 Unavailable'}</p>
                <div className="card-actions">
                  <button onClick={startDashboardServer} disabled={systemStatus.web_dashboards_available}>
                    Start Server
                  </button>
                  <button onClick={() => window.open('http://localhost:8085/todo_dashboard.html', '_blank')}>
                    Todo Dashboard
                  </button>
                  <button onClick={() => window.open('http://localhost:8085/agent_dashboard.html', '_blank')}>
                    Agent Dashboard
                  </button>
                </div>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'controls' && (
          <div className="controls">
            <h2>System Controls</h2>
            <div className="control-grid">
              <button className="control-btn primary" onClick={startAutonomousSystem}>
                🚀 Start Full System
              </button>
              <button className="control-btn danger" onClick={stopAutonomousSystem}>
                🛑 Stop Full System
              </button>
              <button className="control-btn secondary" onClick={() => runSystemCommand("restart_all")}>
                🔄 Restart All Services
              </button>
              <button className="control-btn info" onClick={() => runSystemCommand("system_backup")}>
                💾 Create Backup
              </button>
            </div>
          </div>
        )}

        {activeTab === 'dashboards' && (
          <div className="dashboards">
            <h2>Web Dashboards</h2>
            <div className="dashboard-controls">
              <button className="dashboard-btn" onClick={() => runSystemCommand("analyze_project")}>
                🔍 Analyze Project
              </button>
              <button className="dashboard-btn" onClick={() => runSystemCommand("process_todos")}>
                ⚙️ Process Todos
              </button>
              <button className="dashboard-btn" onClick={() => runSystemCommand("execute_critical")}>
                🚀 Execute Critical
              </button>
              <button className="dashboard-btn" onClick={() => runSystemCommand("generate_report")}>
                📊 Generate Report
              </button>
              <button className="dashboard-btn secondary" onClick={() => window.open('http://localhost:8085/todo_dashboard.html', '_blank')}>
                🌐 Open Full Dashboard
              </button>
            </div>
            <div className="dashboard-status">
              <h3>Dashboard Status</h3>
              <p>Todo API: {systemStatus.web_dashboards_available ? '🟢 Connected' : '🔴 Disconnected'}</p>
              <p>Last Command Output:</p>
              <pre className="status-output">{commandOutput || 'No recent commands'}</pre>
            </div>
          </div>
        )}

        {activeTab === 'commands' && (
          <div className="commands">
            <h2>System Commands</h2>
            <div className="command-section">
              <h3>Quick Commands</h3>
              <div className="command-buttons">
                <button onClick={() => runSystemCommand("list_processes")}>
                  📋 List Processes
                </button>
                <button onClick={() => runSystemCommand("check_logs")}>
                  📄 Check Logs
                </button>
                <button onClick={() => runSystemCommand("clean_temp")}>
                  🧹 Clean Temp Files
                </button>
                <button onClick={() => runSystemCommand("update_system")}>
                  🔄 Update System
                </button>
              </div>
            </div>

            <div className="command-output">
              <h3>Command Output</h3>
              <pre>{commandOutput || "No output yet. Run a command to see results."}</pre>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}

export default App;

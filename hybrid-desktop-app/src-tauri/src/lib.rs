// Learn more about Tauri commands at https://tauri.app/develop/calling-rust/
#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}! You've been greeted from Rust!", name)
}

#[tauri::command]
fn get_system_status() -> Result<serde_json::Value, String> {
    use std::process::Command;

    // Check if autonomous system is running
    let autonomous_running = Command::new("pgrep")
        .args(&["-f", "autonomous"])
        .output()
        .map(|output| output.status.success())
        .unwrap_or(false);

    // Check if MCP server is running
    let mcp_server_running = Command::new("pgrep")
        .args(&["-f", "mcp_server.py"])
        .output()
        .map(|output| output.status.success())
        .unwrap_or(false);

    // Check if health monitor is active
    let health_monitor_active = Command::new("pgrep")
        .args(&["-f", "health_monitor"])
        .output()
        .map(|output| output.status.success())
        .unwrap_or(false);

    // Check if web dashboards are available
    let web_dashboards_available = Command::new("curl")
        .args(&["-s", "--max-time", "2", "http://localhost:8000"])
        .output()
        .map(|output| output.status.success())
        .unwrap_or(false);

    let status = serde_json::json!({
        "autonomous_running": autonomous_running,
        "mcp_server_running": mcp_server_running,
        "health_monitor_active": health_monitor_active,
        "web_dashboards_available": web_dashboards_available,
        "last_health_check": chrono::Utc::now().to_rfc3339()
    });

    Ok(status)
}

#[tauri::command]
fn run_system_command(command: &str) -> Result<String, String> {
    use std::process::Command;
    use std::env;

    let project_root = env::current_dir()
        .map_err(|e| format!("Failed to get current directory: {}", e))?
        .parent()
        .ok_or("Failed to get project root")?
        .to_path_buf();

    let output = match command {
        "start_autonomous" => {
            Command::new("bash")
                .args(&["-c", "source autonomous_launcher.sh && start_autonomous_system"])
                .current_dir(&project_root)
                .output()
        }
        "stop_autonomous" => {
            Command::new("bash")
                .args(&["-c", "source autonomous_launcher.sh && stop_autonomous_system"])
                .current_dir(&project_root)
                .output()
        }
        "restart_mcp" => {
            Command::new("bash")
                .args(&["-c", "source mcp_auto_restart.sh && restart_mcp_server"])
                .current_dir(&project_root)
                .output()
        }
        "restart_all" => {
            Command::new("bash")
                .args(&["-c", "source autonomous_launcher.sh && restart_all_services"])
                .current_dir(&project_root)
                .output()
        }
        "run_health_check" => {
            Command::new("bash")
                .args(&["health_monitor.sh", "--quick"])
                .current_dir(&project_root)
                .output()
        }
        "list_processes" => {
            Command::new("ps")
                .args(&["aux", "|", "grep", "-E", "(autonomous|mcp|monitor)", "|", "grep", "-v", "grep"])
                .output()
        }
        "check_logs" => {
            Command::new("bash")
                .args(&["-c", "find logs agents -name '*.log' -mtime -1 -exec tail -5 {} \\; | head -20"])
                .current_dir(&project_root)
                .output()
        }
        "clean_temp" => {
            Command::new("bash")
                .args(&["-c", "find . -name '*.tmp' -o -name '*.log.*' -mtime +7 -delete 2>/dev/null && echo 'Cleanup completed'"])
                .current_dir(&project_root)
                .output()
        }
        "update_system" => {
            Command::new("bash")
                .args(&["-c", "git pull && echo 'System updated successfully'"])
                .current_dir(&project_root)
                .output()
        }
        "analyze_project" => {
            Command::new("curl")
                .args(&["-X", "POST", "-H", "Content-Type: application/json", "-d", "{}", "http://localhost:5001/analyze"])
                .output()
        }
        "process_todos" => {
            Command::new("curl")
                .args(&["-X", "POST", "-H", "Content-Type: application/json", "-d", "{}", "http://localhost:5001/process"])
                .output()
        }
        "execute_critical" => {
            Command::new("curl")
                .args(&["-X", "POST", "-H", "Content-Type: application/json", "-d", "{}", "http://localhost:5001/execute"])
                .output()
        }
        "generate_report" => {
            Command::new("curl")
                .args(&["-X", "POST", "-H", "Content-Type: application/json", "-d", "{}", "http://localhost:5001/report"])
                .output()
        }
        _ => return Err(format!("Unknown command: {}", command))
    };

    match output {
        Ok(result) => {
            let stdout = String::from_utf8_lossy(&result.stdout);
            let stderr = String::from_utf8_lossy(&result.stderr);
            if result.status.success() {
                Ok(format!("✅ Success:\n{}", stdout))
            } else {
                Ok(format!("⚠️  Warning:\nStdout: {}\nStderr: {}", stdout, stderr))
            }
        }
        Err(e) => Err(format!("❌ Failed to execute command: {}", e))
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![greet, get_system_status, run_system_command])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

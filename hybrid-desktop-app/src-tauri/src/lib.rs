// Learn more about Tauri commands at https://tauri.app/develop/calling-rust/
#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}! You've been greeted from Rust!", name)
}

#[tauri::command]
fn get_system_status() -> Result<serde_json::Value, String> {
    use std::process::Command;

    // Check if autonomous system is running via PID file
    let autonomous_running = std::path::Path::new("logs/autonomous_launcher.pid")
        .exists() && {
            if let Ok(pid_str) = std::fs::read_to_string("logs/autonomous_launcher.pid") {
                if let Ok(pid) = pid_str.trim().parse::<i32>() {
                    Command::new("kill")
                        .args(&["-0", &pid.to_string()])
                        .output()
                        .map(|o| o.status.success())
                        .unwrap_or(false)
                } else { false }
            } else { false }
        };

    // Check if MCP auto-restart is running via PID file
    let mcp_server_running = std::path::Path::new("logs/mcp_auto_restart.pid")
        .exists() && {
            if let Ok(pid_str) = std::fs::read_to_string("logs/mcp_auto_restart.pid") {
                if let Ok(pid) = pid_str.trim().parse::<i32>() {
                    Command::new("kill")
                        .args(&["-0", &pid.to_string()])
                        .output()
                        .map(|o| o.status.success())
                        .unwrap_or(false)
                } else { false }
            } else { false }
        };

    // Check if health monitor is active
    let health_monitor_active = Command::new("pgrep")
        .args(&["-f", "health_monitor.sh"])
        .output()
        .map(|output| output.status.success())
        .unwrap_or(false);

    // Check if web dashboards are available (corrected port to 8085)
    let web_dashboards_available = Command::new("curl")
        .args(&["-s", "--max-time", "2", "http://localhost:8085"])
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
fn get_detailed_status() -> Result<serde_json::Value, String> {
    use std::process::Command;
    use std::fs;

    let mut status = get_system_status()?;

    // Add uptime information for running services
    if let Some(autonomous_running) = status.get("autonomous_running").and_then(|v| v.as_bool()) {
        if autonomous_running {
            if let Ok(pid_str) = fs::read_to_string("logs/autonomous_launcher.pid") {
                if let Ok(pid) = pid_str.trim().parse::<i32>() {
                    let uptime_output = Command::new("ps")
                        .args(&["-p", &pid.to_string(), "-o", "etime="])
                        .output()
                        .ok()
                        .and_then(|o| String::from_utf8(o.stdout).ok())
                        .unwrap_or_default()
                        .trim()
                        .to_string();
                    status["autonomous_uptime"] = serde_json::Value::String(uptime_output);
                }
            }
        }
    }

    if let Some(mcp_running) = status.get("mcp_server_running").and_then(|v| v.as_bool()) {
        if mcp_running {
            if let Ok(pid_str) = fs::read_to_string("logs/mcp_auto_restart.pid") {
                if let Ok(pid) = pid_str.trim().parse::<i32>() {
                    let uptime_output = Command::new("ps")
                        .args(&["-p", &pid.to_string(), "-o", "etime="])
                        .output()
                        .ok()
                        .and_then(|o| String::from_utf8(o.stdout).ok())
                        .unwrap_or_default()
                        .trim()
                        .to_string();
                    status["mcp_uptime"] = serde_json::Value::String(uptime_output);
                }
            }
        }
    }

    Ok(status)
}
    use std::process::{Command, Stdio};
    use std::env;

    let project_root = env::current_dir()
        .map_err(|e| format!("Failed to get current directory: {}", e))?
        .parent()
        .ok_or("Failed to get project root")?
        .to_path_buf();

    // Check if dashboard server is already running
    let check_output = Command::new("curl")
        .args(&["-s", "--max-time", "2", "http://localhost:8085"])
        .output();

    if check_output.map(|o| o.status.success()).unwrap_or(false) {
        return Ok("✅ Dashboard server is already running".to_string());
    }

    // Start dashboard server in background
    let child = Command::new("python3")
        .args(&[&format!("{}/dashboard_server.py", project_root.display())])
        .current_dir(&project_root)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn();

    match child {
        Ok(_) => {
            // Give it a moment to start up
            std::thread::sleep(std::time::Duration::from_secs(2));

            // Verify it started
            let verify_output = Command::new("curl")
                .args(&["-s", "--max-time", "2", "http://localhost:8085"])
                .output();

            if verify_output.map(|o| o.status.success()).unwrap_or(false) {
                Ok("✅ Dashboard server started successfully".to_string())
            } else {
                Ok("⚠️ Dashboard server may have started but is not responding yet".to_string())
            }
        }
        Err(e) => Err(format!("❌ Failed to start dashboard server: {}", e))
    }
}

#[tauri::command]
fn get_detailed_status() -> Result<serde_json::Value, String> {
    use std::process::Command;
    use std::fs;

    let mut status = get_system_status()?;

    // Add uptime information for running services
    if let Some(autonomous_running) = status.get("autonomous_running").and_then(|v| v.as_bool()) {
        if autonomous_running {
            if let Ok(pid_str) = fs::read_to_string("logs/autonomous_launcher.pid") {
                if let Ok(pid) = pid_str.trim().parse::<i32>() {
                    let uptime_output = Command::new("ps")
                        .args(&["-p", &pid.to_string(), "-o", "etime="])
                        .output()
                        .ok()
                        .and_then(|o| String::from_utf8(o.stdout).ok())
                        .unwrap_or_default()
                        .trim()
                        .to_string();
                    status["autonomous_uptime"] = serde_json::Value::String(uptime_output);
                }
            }
        }
    }

    if let Some(mcp_running) = status.get("mcp_server_running").and_then(|v| v.as_bool()) {
        if mcp_running {
            if let Ok(pid_str) = fs::read_to_string("logs/mcp_auto_restart.pid") {
                if let Ok(pid) = pid_str.trim().parse::<i32>() {
                    let uptime_output = Command::new("ps")
                        .args(&["-p", &pid.to_string(), "-o", "etime="])
                        .output()
                        .ok()
                        .and_then(|o| String::from_utf8(o.stdout).ok())
                        .unwrap_or_default()
                        .trim()
                        .to_string();
                    status["mcp_uptime"] = serde_json::Value::String(uptime_output);
                }
            }
        }
    }

    Ok(status)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![greet, get_system_status, run_system_command, start_dashboard_server, get_detailed_status])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

#!/bin/bash

# AI Dashboard and Monitoring System
# Comprehensive monitoring and visualization for Ollama usage across Quantum workspace
# Provides real-time insights into AI operations and performance

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_DIR="${WORKSPACE_ROOT}/Tools/Automation/dashboard"
MONITORING_DIR="${WORKSPACE_ROOT}/Tools/Automation/monitoring"
PROJECTS_DIR="${WORKSPACE_ROOT}/Projects"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_dashboard() {
    echo -e "${CYAN}[🤖 AI-DASHBOARD]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_ai() {
    echo -e "${PURPLE}[🤖 AI-MONITOR]${NC} $1"
}

# Initialize dashboard directories
init_dashboard() {
    print_dashboard "Initializing AI Dashboard and Monitoring System..."

    mkdir -p "${DASHBOARD_DIR}"
    mkdir -p "${MONITORING_DIR}"
    mkdir -p "${MONITORING_DIR}/logs"
    mkdir -p "${MONITORING_DIR}/metrics"
    mkdir -p "${MONITORING_DIR}/reports"

    print_success "Dashboard directories initialized"
}

# Generate comprehensive AI usage dashboard
generate_ai_dashboard() {
    print_dashboard "Generating comprehensive AI usage dashboard..."

    local dashboard_file="${DASHBOARD_DIR}/ai_dashboard.html"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)

    # Collect workspace metrics
    local workspace_metrics
    workspace_metrics=$(collect_workspace_metrics)

    # Collect AI usage statistics
    local ai_metrics
    ai_metrics=$(collect_ai_usage_metrics)

    # Collect project-specific AI data
    local project_data
    project_data=$(collect_project_ai_data)

    # Generate HTML dashboard
    generate_html_dashboard "${dashboard_file}" "${timestamp}" "${workspace_metrics}" "${ai_metrics}" "${project_data}"

    print_success "AI dashboard generated: ${dashboard_file}"

    # Open dashboard in browser if possible
    if command -v open &>/dev/null; then
        open "${dashboard_file}" || true
    fi
}

# Collect workspace-wide metrics
collect_workspace_metrics() {
    print_ai "Collecting workspace metrics..."

    local total_projects
    total_projects=$(find "${PROJECTS_DIR}" -maxdepth 1 -type d | wc -l)
    total_projects=$((total_projects - 1)) # Subtract the Projects directory itself

    local total_swift_files
    total_swift_files=$(find "${PROJECTS_DIR}" -name "*.swift" | wc -l)

    local total_lines
    total_lines=$(find "${PROJECTS_DIR}" -name "*.swift" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")

    local ai_enhanced_projects
    ai_enhanced_projects=$(find "${PROJECTS_DIR}" -name "AI_*" -type f | wc -l)

    local quality_reports
    quality_reports=$(find "${PROJECTS_DIR}" -name "*QUALITY_REPORT*" -type f | wc -l)

    local test_files
    test_files=$(find "${PROJECTS_DIR}" -name "*Tests.swift" | wc -l)

    echo "{
        \"total_projects\": ${total_projects},
        \"total_swift_files\": ${total_swift_files},
        \"total_lines\": ${total_lines},
        \"ai_enhanced_projects\": ${ai_enhanced_projects},
        \"quality_reports\": ${quality_reports},
        \"test_files\": ${test_files},
        \"last_updated\": \"$(date)\"
    }"
}

# Collect AI usage metrics
collect_ai_usage_metrics() {
    print_ai "Collecting AI usage metrics..."

    if [[ ${TEST_MODE:-0} == "1" ]]; then
        echo '{
            "ollama_status": "online",
            "model_count": 5,
            "cloud_models": 2,
            "ai_generated_files": 15,
            "automation_runs": 8,
            "quality_reports": 12,
            "estimated_ai_time_seconds": 2400
        }'
        return 0
    fi

    # Check Ollama status
    local ollama_status="offline"
    local model_count=0
    local cloud_models=0

    if command -v ollama &>/dev/null; then
        if ollama list &>/dev/null; then
            ollama_status="online"
            model_count=$(ollama list | tail -n +2 | wc -l)
            cloud_models=$(ollama list | grep -c "cloud" || echo "0")
        fi
    fi

    # Count AI-generated files
    local ai_generated_files
    ai_generated_files=$(find "${WORKSPACE_ROOT}" -name "AI_*" -o -name "*ai_*" | wc -l)

    # Count automation runs
    local automation_runs
    automation_runs=$(find "${WORKSPACE_ROOT}" -name "*AUTOMATION_SUMMARY*" | wc -l)

    # Count quality reports
    local quality_reports
    quality_reports=$(find "${WORKSPACE_ROOT}" -name "*QUALITY_REPORT*" | wc -l)

    # Estimate AI processing time (rough calculation)
    local estimated_ai_time
    estimated_ai_time=$((automation_runs * 120 + quality_reports * 60)) # Rough estimate in seconds

    echo "{
        \"ollama_status\": \"${ollama_status}\",
        \"model_count\": ${model_count},
        \"cloud_models\": ${cloud_models},
        \"ai_generated_files\": ${ai_generated_files},
        \"automation_runs\": ${automation_runs},
        \"quality_reports\": ${quality_reports},
        \"estimated_ai_time_seconds\": ${estimated_ai_time}
    }"
}

# Collect project-specific AI data
collect_project_ai_data() {
    print_ai "Collecting project-specific AI data..."

    local project_data="[]"

    for project in "${PROJECTS_DIR}"/*; do
        if [[ -d ${project} ]]; then
            local project_name
            project_name=$(basename "${project}")
            local swift_files
            swift_files=$(find "${project}" -name "*.swift" | wc -l)

            if [[ ${swift_files} -gt 0 ]]; then
                local ai_files
                ai_files=$(find "${project}" -name "AI_*" -o -name "*ai_*" | wc -l)

                local quality_reports
                quality_reports=$(find "${project}" -name "*QUALITY*" | wc -l)

                local test_files
                test_files=$(find "${project}" -name "*Tests.swift" | wc -l)

                local ai_enhanced
                ai_enhanced=$(find "${project}" -name "*AIEnhanced*" | wc -l)

                local project_json="{
                    \"name\": \"${project_name}\",
                    \"swift_files\": ${swift_files},
                    \"ai_files\": ${ai_files},
                    \"quality_reports\": ${quality_reports},
                    \"test_files\": ${test_files},
                    \"ai_enhanced\": ${ai_enhanced}
                }"

                if [[ ${project_data} == "[]" ]]; then
                    project_data="[${project_json}"
                else
                    project_data="${project_data},${project_json}"
                fi
            fi
        fi
    done

    project_data="${project_data}]"
    echo "${project_data}"
}

# Generate HTML dashboard
generate_html_dashboard() {
    local dashboard_file="$1"
    local timestamp="$2"
    local workspace_metrics="$3"
    local ai_metrics="$4"
    local project_data="$5"

    print_dashboard "Generating HTML dashboard..."

    cat >"${dashboard_file}" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Quantum Workspace AI Dashboard</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: #333;
            min-height: 100vh;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }

        .header {
            text-align: center;
            color: white;
            margin-bottom: 30px;
        }

        .header h1 {
            font-size: 3rem;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }

        .header p {
            font-size: 1.2rem;
            opacity: 0.9;
        }

        .dashboard-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }

        .card {
            background: white;
            border-radius: 12px;
            padding: 20px;
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
            transition: transform 0.3s ease;
        }

        .card:hover {
            transform: translateY(-5px);
        }

        .card h3 {
            color: #667eea;
            margin-bottom: 15px;
            font-size: 1.3rem;
        }

        .metric {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 10px;
            padding: 8px 0;
            border-bottom: 1px solid #f0f0f0;
        }

        .metric:last-child {
            border-bottom: none;
        }

        .metric-value {
            font-size: 1.5rem;
            font-weight: bold;
            color: #667eea;
        }

        .status-indicator {
            display: inline-block;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            margin-right: 8px;
        }

        .status-online {
            background: #4CAF50;
        }

        .status-offline {
            background: #f44336;
        }

        .charts-container {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }

        .chart-card {
            background: white;
            border-radius: 12px;
            padding: 20px;
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
        }

        .projects-table {
            background: white;
            border-radius: 12px;
            padding: 20px;
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
            overflow-x: auto;
        }

        table {
            width: 100%;
            border-collapse: collapse;
        }

        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #f0f0f0;
        }

        th {
            background: #f8f9fa;
            font-weight: 600;
            color: #667eea;
        }

        .progress-bar {
            width: 100%;
            height: 8px;
            background: #f0f0f0;
            border-radius: 4px;
            overflow: hidden;
            margin-top: 5px;
        }

        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #667eea, #764ba2);
            border-radius: 4px;
            transition: width 0.3s ease;
        }

        .footer {
            text-align: center;
            color: white;
            margin-top: 30px;
            opacity: 0.8;
        }

        @media (max-width: 768px) {
            .dashboard-grid {
                grid-template-columns: 1fr;
            }

            .charts-container {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🤖 Quantum Workspace AI Dashboard</h1>
            <p>Real-time monitoring and insights for AI-enhanced development</p>
            <p style="font-size: 0.9rem; margin-top: 5px;">Last updated: ${timestamp}</p>
        </div>

        <div class="dashboard-grid" id="metrics-container">
            <!-- Metrics will be populated by JavaScript -->
        </div>

        <div class="charts-container">
            <div class="chart-card">
                <h3>📊 AI Enhancement Progress</h3>
                <canvas id="enhancementChart" width="400" height="300"></canvas>
            </div>

            <div class="chart-card">
                <h3>🔧 Quality Metrics</h3>
                <canvas id="qualityChart" width="400" height="300"></canvas>
            </div>
        </div>

        <div class="projects-table">
            <h3>📁 Project AI Status</h3>
            <table id="projects-table">
                <thead>
                    <tr>
                        <th>Project</th>
                        <th>Swift Files</th>
                        <th>AI Files</th>
                        <th>Quality Reports</th>
                        <th>Test Files</th>
                        <th>AI Enhanced</th>
                        <th>Progress</th>
                    </tr>
                </thead>
                <tbody id="projects-tbody">
                    <!-- Project data will be populated by JavaScript -->
                </tbody>
            </table>
        </div>

        <div class="footer">
            <p>Generated by Quantum Workspace AI Enhancement System</p>
        </div>
    </div>

    <script>
        // Parse JSON data from shell script
        const workspaceMetrics = ${workspace_metrics};
        const aiMetrics = ${ai_metrics};
        const projectData = ${project_data};

        // Populate metrics cards
        function populateMetrics() {
            const container = document.getElementById('metrics-container');

            const metrics = [
                {
                    title: '🏗️ Workspace Overview',
                    items: [
                        { label: 'Total Projects', value: workspaceMetrics.total_projects },
                        { label: 'Swift Files', value: workspaceMetrics.total_swift_files },
                        { label: 'Lines of Code', value: workspaceMetrics.total_lines.toLocaleString() }
                    ]
                },
                {
                    title: '🤖 AI Integration',
                    items: [
                        {
                            label: 'Ollama Status',
                            value: '<span class="status-indicator ' + (aiMetrics.ollama_status === 'online' ? 'status-online' : 'status-offline') + '"></span>' + aiMetrics.ollama_status
                        },
                        { label: 'Available Models', value: aiMetrics.model_count },
                        { label: 'Cloud Models', value: aiMetrics.cloud_models },
                        { label: 'AI Generated Files', value: aiMetrics.ai_generated_files }
                    ]
                },
                {
                    title: '📈 AI Activity',
                    items: [
                        { label: 'Automation Runs', value: aiMetrics.automation_runs },
                        { label: 'Quality Reports', value: aiMetrics.quality_reports },
                        { label: 'AI Processing Time', value: Math.round(aiMetrics.estimated_ai_time_seconds / 60) + ' min' }
                    ]
                }
            ];

            metrics.forEach(metric => {
                const card = document.createElement('div');
                card.className = 'card';

                let html = '<h3>' + metric.title + '</h3>';
                metric.items.forEach(item => {
                    html += '<div class="metric"><span>' + item.label + '</span><span class="metric-value">' + item.value + '</span></div>';
                });

                card.innerHTML = html;
                container.appendChild(card);
            });
        }

        // Populate projects table
        function populateProjectsTable() {
            const tbody = document.getElementById('projects-tbody');

            projectData.forEach(project => {
                const row = document.createElement('tr');

                const maxFiles = Math.max(...projectData.map(p => p.swift_files));
                const progressPercent = Math.round((project.ai_files / Math.max(project.swift_files * 0.5, 1)) * 100);

                row.innerHTML =
                    '<td>' + project.name + '</td>' +
                    '<td>' + project.swift_files + '</td>' +
                    '<td>' + project.ai_files + '</td>' +
                    '<td>' + project.quality_reports + '</td>' +
                    '<td>' + project.test_files + '</td>' +
                    '<td>' + (project.ai_enhanced > 0 ? '✅' : '❌') + '</td>' +
                    '<td><div class="progress-bar"><div class="progress-fill" style="width: ' + Math.min(progressPercent, 100) + '%"></div></div></td>';

                tbody.appendChild(row);
            });
        }

        // Create charts
        function createCharts() {
            // Enhancement Progress Chart
            const enhancementCtx = document.getElementById('enhancementChart').getContext('2d');
            new Chart(enhancementCtx, {
                type: 'doughnut',
                data: {
                    labels: ['AI Enhanced', 'Not Enhanced'],
                    datasets: [{
                        data: [workspaceMetrics.ai_enhanced_projects, workspaceMetrics.total_projects - workspaceMetrics.ai_enhanced_projects],
                        backgroundColor: ['#4CAF50', '#f44336'],
                        borderWidth: 0
                    }]
                },
                options: {
                    responsive: true,
                    plugins: {
                        legend: {
                            position: 'bottom'
                        }
                    }
                }
            });

            // Quality Metrics Chart
            const qualityCtx = document.getElementById('qualityChart').getContext('2d');
            new Chart(qualityCtx, {
                type: 'bar',
                data: {
                    labels: ['Quality Reports', 'Test Files', 'AI Files'],
                    datasets: [{
                        label: 'Count',
                        data: [workspaceMetrics.quality_reports, workspaceMetrics.test_files, workspaceMetrics.ai_enhanced_projects],
                        backgroundColor: ['#667eea', '#764ba2', '#f093fb'],
                        borderWidth: 0,
                        borderRadius: 4
                    }]
                },
                options: {
                    responsive: true,
                    scales: {
                        y: {
                            beginAtZero: true
                        }
                    }
                }
            });
        }

        // Initialize dashboard
        document.addEventListener('DOMContentLoaded', function() {
            populateMetrics();
            populateProjectsTable();
            createCharts();
        });

        // Auto-refresh every 30 seconds
        setInterval(function() {
            // In a real implementation, this would fetch fresh data
            console.log('Dashboard auto-refresh would happen here');
        }, 30000);
    </script>
</body>
</html>
EOF

    print_success "HTML dashboard generated successfully"
}

# Start real-time monitoring
start_monitoring() {
    print_dashboard "Starting real-time AI monitoring with autorestart..."

    local monitor_script="${MONITORING_DIR}/ai_monitor.sh"

    cat >"${monitor_script}" <<'EOF'
#!/bin/bash

# Real-time AI monitoring script with autorestart
MONITORING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${MONITORING_DIR}/../../.." && pwd)"
LOG_FILE="${MONITORING_DIR}/logs/ai_monitor_$(date +%Y%m%d).log"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "${LOG_FILE}"
    echo -e "${BLUE}[MONITOR]${NC} $1"
}

check_ollama_health() {
    if [[ ${TEST_MODE:-0} == "1" ]]; then
        log "✅ (TEST_MODE) Ollama assumed healthy"
        return 0
    fi
    if command -v ollama &> /dev/null; then
        if ollama list &> /dev/null; then
            local model_count=$(ollama list | tail -n +2 | wc -l)
            log "✅ Ollama healthy: ${model_count} models available"
            return 0
        else
            log "❌ Ollama server not responding"
            return 1
        fi
    else
        log "❌ Ollama not installed"
        return 1
    fi
}

monitor_ai_activity() {
    local ai_files_before=$(find "${WORKSPACE_ROOT}" -name "AI_*" -o -name "*ai_*" | wc -l)
    sleep 300  # Check every 5 minutes
    local ai_files_after=$(find "${WORKSPACE_ROOT}" -name "AI_*" -o -name "*ai_*" | wc -l)

    if [[ ${ai_files_after} -gt ${ai_files_before} ]]; then
        local new_files=$((ai_files_after - ai_files_before))
        log "📈 AI activity detected: ${new_files} new AI-generated files"
    fi
}

monitor_disk_usage() {
    local ai_dir_size=$(du -sh "${WORKSPACE_ROOT}/Tools/Automation" 2>/dev/null | cut -f1 || echo "0")
    log "💾 AI tools directory size: ${ai_dir_size}"
}

main_monitoring_loop() {
    log "Starting AI monitoring loop with autorestart..."

    local restart_count=0
    local max_restarts=10
    
    while [[ ${restart_count} -lt ${max_restarts} ]]; do
        log "Monitoring cycle ${restart_count}/${max_restarts} started"
        
        # Run monitoring tasks
        if check_ollama_health && monitor_ai_activity && monitor_disk_usage; then
            # Check for automation processes
            local running_automations=$(pgrep -f "ai_enhanced_automation\|ai_quality_gates" | wc -l)
            if [[ ${running_automations} -gt 0 ]]; then
                log "⚙️ Active AI automations: ${running_automations}"
            fi
        else
            log "❌ Monitoring cycle failed, will retry"
            restart_count=$((restart_count + 1))
            sleep 30  # Wait before retry
            continue
        fi
        
        sleep 300  # Check every 5 minutes
        restart_count=0  # Reset on successful cycle
    done
    
    log "❌ Maximum restart attempts reached, stopping monitoring"
}

# Handle signals
trap 'log "Monitoring stopped by user"; exit 0' INT TERM

# Start monitoring
main_monitoring_loop
EOF

    chmod +x "${monitor_script}"

    # Start monitoring in background with autorestart wrapper
    local wrapper_script="${MONITORING_DIR}/ai_monitor_wrapper.sh"
    cat >"${wrapper_script}" <<EOF
#!/bin/bash
# Autorestart wrapper for AI monitoring

while true; do
    echo "Starting AI monitor at \$(date)" >> "${MONITORING_DIR}/autorestart.log"
    "${monitor_script}"
    exit_code=\$?
    echo "AI monitor exited with code \${exit_code} at \$(date)" >> "${MONITORING_DIR}/autorestart.log"
    
    if [[ \${exit_code} -eq 0 ]]; then
        echo "Clean exit, not restarting" >> "${MONITORING_DIR}/autorestart.log"
        break
    else
        echo "Restarting in 10 seconds..." >> "${MONITORING_DIR}/autorestart.log"
        sleep 10
    fi
done
EOF

    chmod +x "${wrapper_script}"

    # Start wrapper in background
    nohup "${wrapper_script}" >"${MONITORING_DIR}/ai_monitor.out" 2>&1 &
    local monitor_pid=$!

    echo "${monitor_pid}" >"${MONITORING_DIR}/ai_monitor.pid"

    print_success "AI monitoring started with autorestart (PID: ${monitor_pid})"
    print_ai "Monitor logs: ${MONITORING_DIR}/logs/"
    print_ai "Autorestart log: ${MONITORING_DIR}/autorestart.log"
}

# Stop monitoring
stop_monitoring() {
    print_dashboard "Stopping AI monitoring..."

    local pid_file="${MONITORING_DIR}/ai_monitor.pid"

    if [[ -f ${pid_file} ]]; then
        local monitor_pid
        monitor_pid=$(cat "${pid_file}")

        if kill "${monitor_pid}" 2>/dev/null; then
            print_success "AI monitoring stopped (PID: ${monitor_pid})"
            rm -f "${pid_file}"
        else
            print_warning "Failed to stop monitoring process"
        fi
    else
        print_warning "No monitoring process found"
    fi
}

# Generate monitoring reports
generate_monitoring_report() {
    print_dashboard "Generating AI monitoring report..."

    local report_file
    report_file="${MONITORING_DIR}/reports/ai_monitoring_report_$(date +%Y%m%d).md"
    local log_files
    log_files=$(find "${MONITORING_DIR}/logs" -name "*.log" -mtime -7 2>/dev/null || echo "")

    cat >"${report_file}" <<EOF
# AI Monitoring Report
Generated: $(date)

## System Health

### Ollama Status
$(check_ollama_health_status)

### AI Activity Summary
$(summarize_ai_activity "${log_files}")

## Recent AI Operations

$(extract_recent_operations "${log_files}")

## Performance Metrics

$(generate_performance_metrics)

## Recommendations

$(generate_monitoring_recommendations)

---
*Report generated by Quantum Workspace AI Monitoring System*
EOF

    print_success "Monitoring report generated: ${report_file}"
}

# Helper functions for monitoring report
check_ollama_health_status() {
    if command -v ollama &>/dev/null && ollama list &>/dev/null; then
        local model_count
        model_count=$(ollama list | tail -n +2 | wc -l)
        echo "- ✅ Ollama Online"
        echo "- 📊 Models Available: ${model_count}"
    else
        echo "- ❌ Ollama Offline"
    fi
}

summarize_ai_activity() {
    local log_files="$1"

    if [[ -n ${log_files} ]]; then
        local total_entries
        total_entries=$(wc -l "${log_files}" 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
        local ai_operations
        ai_operations=$(grep -c -h "AI activity\|automation\|quality" "${log_files}" 2>/dev/null || echo "0")

        echo "- Total Log Entries: ${total_entries}"
        echo "- AI Operations Detected: ${ai_operations}"
    else
        echo "- No recent log activity"
    fi
}

extract_recent_operations() {
    local log_files="$1"

    if [[ -n ${log_files} ]]; then
        echo "### Last 10 Operations"
        tail -n 50 "${log_files}" 2>/dev/null | grep -E "(AI|automation|quality)" | tail -n 10 | while read -r line; do
            echo "- ${line}"
        done
    else
        echo "No recent operations found"
    fi
}

generate_performance_metrics() {
    local ai_files
    ai_files=$(find "${WORKSPACE_ROOT}" -name "AI_*" -o -name "*ai_*" | wc -l)
    local automation_runs
    automation_runs=$(find "${WORKSPACE_ROOT}" -name "*AUTOMATION_SUMMARY*" | wc -l)
    local quality_reports
    quality_reports=$(find "${WORKSPACE_ROOT}" -name "*QUALITY_REPORT*" | wc -l)

    echo "### File Metrics"
    echo "- AI Generated Files: ${ai_files}"
    echo "- Automation Summary Reports: ${automation_runs}"
    echo "- Quality Analysis Reports: ${quality_reports}"

    echo "### Processing Estimates"
    local estimated_time=$((automation_runs * 120 + quality_reports * 60))
    echo "- Estimated AI Processing Time: $((estimated_time / 60)) minutes"
}

generate_monitoring_recommendations() {
    local recommendations=""

    # Check Ollama status
    if ! command -v ollama &>/dev/null || ! ollama list &>/dev/null; then
        recommendations="${recommendations}- 🔧 Install and start Ollama server for full AI functionality\n"
    fi

    # Check AI activity
    local recent_ai_files
    recent_ai_files=$(find "${WORKSPACE_ROOT}" -name "AI_*" -mtime -1 2>/dev/null | wc -l || echo "0")
    if [[ ${recent_ai_files} -eq 0 ]]; then
        recommendations="${recommendations}- 📈 Run AI automation to enhance workspace projects\n"
    fi

    # Check monitoring
    if [[ ! -f "${MONITORING_DIR}/ai_monitor.pid" ]] || ! kill -0 "$(cat "${MONITORING_DIR}/ai_monitor.pid" 2>/dev/null)" 2>/dev/null; then
        recommendations="${recommendations}- 👁️ Start AI monitoring for real-time insights\n"
    fi

    if [[ -z ${recommendations} ]]; then
        recommendations="- ✅ All systems operating optimally"
    fi

    echo "${recommendations}"
}

# Show dashboard status
show_dashboard_status() {
    print_dashboard "AI Dashboard Status"
    echo ""

    # Check if dashboard exists
    if [[ -f "${DASHBOARD_DIR}/ai_dashboard.html" ]]; then
        local dashboard_age=$(($(date +%s) - $(stat -f %m "${DASHBOARD_DIR}/ai_dashboard.html" 2>/dev/null || date +%s)))
        echo "📊 Dashboard: Available (${dashboard_age} seconds old)"
    else
        echo "📊 Dashboard: Not generated yet"
    fi

    # Check monitoring status
    if [[ -f "${MONITORING_DIR}/ai_monitor.pid" ]] && kill -0 "$(cat "${MONITORING_DIR}/ai_monitor.pid" 2>/dev/null)" 2>/dev/null; then
        echo "👁️ Monitoring: Active (PID: $(cat "${MONITORING_DIR}/ai_monitor.pid"))"
    else
        echo "👁️ Monitoring: Inactive"
    fi

    # Show recent activity
    local recent_logs
    recent_logs=$(find "${MONITORING_DIR}/logs" -name "*.log" -mtime -1 2>/dev/null | wc -l || echo "0")
    echo "📝 Recent Logs: ${recent_logs} files"

    local recent_reports
    recent_reports=$(find "${MONITORING_DIR}/reports" -name "*.md" -mtime -7 2>/dev/null | wc -l || echo "0")
    echo "📋 Recent Reports: ${recent_reports} files"

    echo ""
    print_ai "Use 'generate' to update dashboard, 'start-monitor' to begin monitoring"
}

# Show usage information
show_usage() {
    echo "AI Dashboard and Monitoring System"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  init              - Initialize dashboard and monitoring directories"
    echo "  generate          - Generate comprehensive AI dashboard"
    echo "  start-monitor     - Start real-time AI monitoring"
    echo "  stop-monitor      - Stop AI monitoring"
    echo "  report            - Generate monitoring report"
    echo "  status            - Show dashboard and monitoring status"
    echo "  open              - Open dashboard in default browser"
    echo ""
    echo "Examples:"
    echo "  $0 init"
    echo "  $0 generate"
    echo "  $0 start-monitor"
    echo "  $0 status"
}

# Main execution
main() {
    local command="${1:-start-monitor}" # Default to start-monitor for background operation

    case "${command}" in
    "init")
        init_dashboard
        ;;
    "generate")
        generate_ai_dashboard
        ;;
    "start-monitor")
        start_monitoring
        ;;
    "stop-monitor")
        stop_monitoring
        ;;
    "report")
        generate_monitoring_report
        ;;
    "status")
        show_dashboard_status
        ;;
    "open")
        if [[ -f "${DASHBOARD_DIR}/ai_dashboard.html" ]]; then
            if command -v open &>/dev/null; then
                open "${DASHBOARD_DIR}/ai_dashboard.html"
            else
                print_error "Unable to open browser automatically"
                print_ai "Dashboard location: ${DASHBOARD_DIR}/ai_dashboard.html"
            fi
        else
            print_error "Dashboard not found. Run 'generate' first."
        fi
        ;;
    *)
        show_usage
        ;;
    esac
}

# Execute main function
main "$@"

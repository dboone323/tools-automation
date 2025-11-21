        #!/usr/bin/env bash
        # Auto-injected health & reliability shim

        DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Prefer shared helpers when available
if [[ -f "$DIR/shared_functions.sh" ]]; then
  # shellcheck disable=SC1091
  source "$DIR/shared_functions.sh"
fi

if [[ -f "$DIR/agent_helpers.sh" ]]; then
  # shellcheck disable=SC1091
  source "$DIR/agent_helpers.sh"
fi

set -euo pipefail

AGENT_NAME="todo_scanner_agent.sh"
LOG_FILE="${LOG_FILE:-$DIR/${AGENT_NAME}.log}"
PID=$$

if type update_agent_status >/dev/null 2>&1; then
  trap 'update_agent_status "${AGENT_NAME}" "stopped" $$ ""; exit 0' SIGTERM SIGINT
else
  trap 'exit 0' SIGTERM SIGINT
fi

if [[ "${1-}" == "--health" || "${1-}" == "health" || "${1-}" == "-h" ]]; then
  if type agent_health_check >/dev/null 2>&1; then
    agent_health_check
    exit $?
  fi
  issues=()
  if [[ ! -w "/tmp" ]]; then
    issues+=("tmp_not_writable")
  fi
  if [[ ! -d "$DIR" ]]; then
    issues+=("cwd_missing")
  fi
  if [[ ${#issues[@]} -gt 0 ]]; then
    printf '{"ok":false,"issues":["%s"]}\n' "${issues[*]}"
    exit 2
  fi
  printf '{"ok":true}\n'
  exit 0
fi

# Original agent script continues below
#!/bin/bash
# TODO Scanner Agent
# Continuous scanning agent for automatic TODO detection and task conversion
# Runs every 15 minutes to detect new TODOs and convert them to tasks

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="$WORKSPACE_ROOT/config"
SCRIPTS_DIR="$WORKSPACE_ROOT/scripts"
AGENTS_DIR="$SCRIPT_DIR"

# Files
TODO_OUTPUT_FILE="$CONFIG_DIR/todo-tree-output.json"
PREVIOUS_TODO_FILE="$CONFIG_DIR/previous_todo_scan.json"
SCANNER_LOG_FILE="$CONFIG_DIR/todo_scanner_agent.log"
SCANNER_PID_FILE="$AGENTS_DIR/todo_scanner_agent.pid"
SCANNER_STATUS_FILE="$CONFIG_DIR/todo_scanner_status.json"

# Scanner configuration
SCAN_INTERVAL=900    # 15 minutes in seconds
MAX_LOG_SIZE=1048576 # 1MB log file limit

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >>"$SCANNER_LOG_FILE"

    # Rotate log if too large
    if [ -f "$SCANNER_LOG_FILE" ] && [ $(stat -f%z "$SCANNER_LOG_FILE" 2>/dev/null || stat -c%s "$SCANNER_LOG_FILE" 2>/dev/null || echo "0") -gt $MAX_LOG_SIZE ]; then
        mv "$SCANNER_LOG_FILE" "${SCANNER_LOG_FILE}.old"
        echo "[$timestamp] [INFO] Log rotated" >"$SCANNER_LOG_FILE"
    fi
}

log_info() {
    log "INFO" "$1"
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    log "SUCCESS" "$1"
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    log "WARNING" "$1"
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    log "ERROR" "$1"
    echo -e "${RED}[ERROR]${NC} $1"
}

# Status management
update_status() {
    local status="$1"
    local message="$2"
    local last_scan="$3"
    local new_todos="$4"

    cat >"$SCANNER_STATUS_FILE" <<EOF
{
  "status": "$status",
  "message": "$message",
  "last_scan": "$last_scan",
  "new_todos_found": $new_todos,
  "pid": $$,
  "next_scan": $(($(date +%s) + SCAN_INTERVAL))
}
EOF
}

# Check if scanner is already running
is_running() {
    if [ -f "$SCANNER_PID_FILE" ]; then
        local pid=$(cat "$SCANNER_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0 # Running
        else
            # Stale PID file
            rm -f "$SCANNER_PID_FILE"
        fi
    fi
    return 1 # Not running
}

# Cleanup function
cleanup() {
    log_info "Scanner agent shutting down..."
    rm -f "$SCANNER_PID_FILE"
    update_status "stopped" "Scanner agent stopped" "$(date '+%Y-%m-%d %H:%M:%S')" 0
    exit 0
}

# Signal handlers
trap cleanup SIGTERM SIGINT

# Scan for TODOs
scan_todos() {
    log_info "Starting TODO scan..."

    # Run the TODO scanner with timeout to prevent hanging
    if ! timeout 300 python3 "$SCRIPTS_DIR/regenerate_todo_json.py" >>"$SCANNER_LOG_FILE" 2>&1; then
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            log_error "TODO scan timed out after 5 minutes"
        else
            log_error "Failed to run TODO scanner (exit code: $exit_code)"
        fi
        return 1
    fi

    log_success "TODO scan completed"
    return 0
}

# Compare with previous scan to find new TODOs
find_new_todos() {
    local current_todos="$1"
    local previous_todos="$2"

    if [ ! -f "$previous_todos" ]; then
        # First scan, all TODOs are new
        log_info "First scan - all TODOs considered new"
        cat "$current_todos"
        return
    fi

    # Use jq to find differences
    if command -v jq >/dev/null 2>&1; then
        jq -s '
            def hash: tostring | @base64;
            .[0] as $current | .[1] as $previous |
            $current - $previous
        ' "$current_todos" "$previous_todos" 2>/dev/null || cat "$current_todos"
    else
        # Fallback: consider all current TODOs as new if jq not available
        log_warning "jq not available, treating all TODOs as new"
        cat "$current_todos"
    fi
}

# Convert new TODOs to tasks
convert_todos_to_tasks() {
    local new_todos_file="$1"

    if [ ! -s "$new_todos_file" ] || [ "$(cat "$new_todos_file" | jq '. | length' 2>/dev/null || echo "0")" = "0" ]; then
        log_info "No new TODOs to convert"
        return 0
    fi

    local new_count=$(cat "$new_todos_file" | jq '. | length' 2>/dev/null || echo "0")
    log_info "Converting $new_count new TODOs to tasks..."

    # Run the task converter
    if ! python3 "$SCRIPTS_DIR/todo_task_converter.py" >>"$SCANNER_LOG_FILE" 2>&1; then
        log_error "Failed to convert TODOs to tasks"
        return 1
    fi

    log_success "Successfully converted $new_count TODOs to tasks"
    return 0
}

# Save current scan as previous for next comparison
save_previous_scan() {
    if [ -f "$TODO_OUTPUT_FILE" ]; then
        cp "$TODO_OUTPUT_FILE" "$PREVIOUS_TODO_FILE"
        log_info "Saved current scan for future comparison"
    fi
}

# Main scanning cycle
scan_cycle() {
    local cycle_start=$(date '+%Y-%m-%d %H:%M:%S')
    log_info "Starting scan cycle at $cycle_start"

    update_status "scanning" "Scanning for TODOs..." "$cycle_start" 0

    # Step 1: Scan for TODOs
    if ! scan_todos; then
        update_status "error" "Failed to scan for TODOs" "$cycle_start" 0
        return 1
    fi

    # Step 2: Find new TODOs
    local temp_new_todos="/tmp/new_todos_$$.json"
    find_new_todos "$TODO_OUTPUT_FILE" "$PREVIOUS_TODO_FILE" >"$temp_new_todos"

    local new_count=$(cat "$temp_new_todos" | jq '. | length' 2>/dev/null || echo "0")

    if [ "$new_count" -gt 0 ]; then
        log_info "Found $new_count new TODOs"

        # Step 3: Convert to tasks
        if convert_todos_to_tasks "$temp_new_todos"; then
            log_success "Scan cycle completed successfully - $new_count new tasks added"
            update_status "completed" "Scan completed successfully" "$cycle_start" "$new_count"
        else
            log_error "Failed to convert new TODOs to tasks"
            update_status "error" "Failed to convert TODOs to tasks" "$cycle_start" 0
        fi
    else
        log_info "No new TODOs found"
        update_status "completed" "No new TODOs found" "$cycle_start" 0
    fi

    # Step 4: Save current scan for next comparison
    save_previous_scan

    # Cleanup
    rm -f "$temp_new_todos"

    local cycle_end=$(date '+%Y-%m-%d %H:%M:%S')
    log_info "Scan cycle completed at $cycle_end"
}

# Start the scanner agent
start_agent() {
    log_info "Starting TODO Scanner Agent..."

    # Check if already running
    if is_running; then
        log_warning "Scanner agent is already running"
        echo -e "${YELLOW}Scanner agent is already running${NC}"
        return 1
    fi

    # Save PID
    echo $$ >"$SCANNER_PID_FILE"

    # Initialize status
    update_status "starting" "Scanner agent starting..." "$(date '+%Y-%m-%d %H:%M:%S')" 0

    log_success "TODO Scanner Agent started (PID: $$)"

    # Main loop
    while true; do
        scan_cycle

        # Wait for next scan
        log_info "Waiting $SCAN_INTERVAL seconds until next scan..."
        sleep $SCAN_INTERVAL
    done
}

# Stop the scanner agent
stop_agent() {
    log_info "Stopping TODO Scanner Agent..."

    if [ -f "$SCANNER_PID_FILE" ]; then
        local pid=$(cat "$SCANNER_PID_FILE")
        if kill -TERM "$pid" 2>/dev/null; then
            log_success "Scanner agent stopped (PID: $pid)"
            rm -f "$SCANNER_PID_FILE"
            update_status "stopped" "Scanner agent stopped by user" "$(date '+%Y-%m-%d %H:%M:%S')" 0
        else
            log_error "Failed to stop scanner agent (PID: $pid)"
        fi
    else
        log_warning "No PID file found - scanner agent may not be running"
    fi
}

# Get status
get_status() {
    if [ -f "$SCANNER_STATUS_FILE" ]; then
        cat "$SCANNER_STATUS_FILE" | jq . 2>/dev/null || cat "$SCANNER_STATUS_FILE"
    else
        echo '{"status": "unknown", "message": "Status file not found"}'
    fi
}

# Manual scan
manual_scan() {
    log_info "Manual scan requested"
    scan_cycle
}

# Show usage
usage() {
    cat <<EOF
TODO Scanner Agent - Continuous TODO Detection and Task Conversion

USAGE:
    $0 [COMMAND]

COMMANDS:
    start       Start the continuous scanning agent
    stop        Stop the scanning agent
    status      Show current agent status
    scan        Perform a manual scan immediately
    restart     Restart the scanning agent
    help        Show this help message

CONFIGURATION:
    Scan Interval: Every 15 minutes
    Log File: $SCANNER_LOG_FILE
    Status File: $SCANNER_STATUS_FILE

EXAMPLES:
    $0 start     # Start continuous scanning
    $0 stop      # Stop scanning
    $0 status    # Check status
    $0 scan      # Manual scan now

EOF
}

# Main command handling
case "${1:-start}" in
start)
    start_agent
    ;;
stop)
    stop_agent
    ;;
restart)
    stop_agent
    sleep 2
    start_agent
    ;;
status)
    get_status
    ;;
scan)
    manual_scan
    ;;
help | --help | -h)
    usage
    ;;
*)
    echo -e "${RED}Unknown command: $1${NC}"
    echo
    usage
    exit 1
    ;;
esac

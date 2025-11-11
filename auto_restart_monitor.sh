#!/bin/bash

# Auto-Restart Service Monitor
# Continuously monitors all tools-automation services and restarts them if they become unresponsive

set -e

# Configuration
CHECK_INTERVAL=30    # seconds between health checks
RESTART_TIMEOUT=60   # base seconds to wait after restart before checking again
BACKOFF_BASE=60      # base backoff seconds for exponential backoff
BACKOFF_MAX=900      # maximum backoff seconds
ESCALATE_THRESHOLD=3 # number of consecutive failed restarts before escalation alert
HOLD_THRESHOLD=6     # after this many failed restarts give up attempting further restarts
LOG_FILE="/tmp/tools_autorestart.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Service definitions (using indexed arrays for compatibility)
SERVICES=(
    "tools-automation-grafana"
    "tools-automation-prometheus"
    "tools-automation-uptime-kuma"
    "tools-automation-sonarqube"
    "tools-automation-postgres"
    "tools-automation-node-exporter"
)

HEALTH_URLS=(
    "http://localhost:3000/api/health"
    "http://localhost:9090/-/healthy"
    "http://localhost:3001"
    "http://localhost:9000/api/system/status"
    "pg_isready -h localhost -p 5432 -U sonar -d sonar"
    "http://localhost:9100"
)

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >>"$LOG_FILE"
    echo "[$timestamp] [$level] $message"
}

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Function to check if a service is healthy
check_service_health() {
    local container_name="$1"
    local index="$2"

    # First check if container is running
    if ! docker ps --format "table {{.Names}}" | grep -q "^${container_name}$"; then
        log_message "ERROR" "Container $container_name is not running"
        return 1
    fi

    local health_url="${HEALTH_URLS[$index]}"

    # Prefer Docker container health status when available

    if docker inspect --format '{{json .State.Health}}' "$container_name" >/dev/null 2>&1; then
        local status
        status=$(docker inspect --format '{{.State.Health.Status}}' "$container_name" 2>/dev/null || true)
        if [[ "$status" == "healthy" ]]; then
            return 0
        else
            # If the container reports unhealthy or starting, treat as not healthy
            return 1
        fi
    fi

    # Fallback checks if no Docker health information is available
    # PostgreSQL: run pg_isready inside the container to avoid relying on host binary
    if [[ "$health_url" == pg_isready* ]]; then
        if docker exec "$container_name" sh -c "pg_isready -U sonar -d sonar" >/dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    else
        # HTTP health check against the host port
        if curl -s --max-time 10 --connect-timeout 5 "$health_url" >/dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    fi
}

# Function to restart a service
restart_service() {
    local container_name="$1"
    local index="$2"

    local health_url="${HEALTH_URLS[$index]}"

    log_message "WARNING" "Service $container_name is unhealthy, attempting restart..."

    # Stop the container
    if docker stop "$container_name" >/dev/null 2>&1; then
        log_message "INFO" "Stopped container $container_name"
    else
        log_message "ERROR" "Failed to stop container $container_name"
        return 1
    fi

    # Wait a moment
    sleep 2

    # Start the container
    if docker start "$container_name" >/dev/null 2>&1; then
        log_message "INFO" "Started container $container_name"
    else
        log_message "ERROR" "Failed to start container $container_name"
        return 1
    fi

    # Wait for service to start up
    log_message "INFO" "Waiting $RESTART_TIMEOUT seconds for $container_name to fully start..."
    sleep "$RESTART_TIMEOUT"

    # Verify the service is now healthy
    if check_service_health "$container_name" "$index"; then
        log_message "SUCCESS" "Service $container_name restarted successfully and is now healthy"
        print_status "Auto-restarted $container_name successfully"
        return 0
    else
        log_message "ERROR" "Service $container_name failed health check after restart"
        print_error "Failed to restart $container_name - manual intervention required"
        return 1
    fi
}

# Function to check all services
check_all_services() {
    local unhealthy_count=0

    for i in "${!SERVICES[@]}"; do
        container_name="${SERVICES[$i]}"

        if check_service_health "$container_name" "$i"; then
            # Service is healthy, log only if verbose
            echo -n "."
        else
            # Service is unhealthy
            print_warning "Service $container_name is unhealthy"
            unhealthy_count=$((unhealthy_count + 1))

            # Attempt to restart with backoff & escalation
            if [ "${FAILED_COUNTS[$i]}" -ge $HOLD_THRESHOLD ]; then
                print_error "Skipping restart for $container_name (failed ${FAILED_COUNTS[$i]} times). Escalation required."
                log_message "ERROR" "Skipping restart for $container_name after ${FAILED_COUNTS[$i]} failed attempts"
                send_alert "$container_name" "Monitor has skipped further restart attempts after ${FAILED_COUNTS[$i]} consecutive failures. Manual intervention required."
            else
                if restart_service "$container_name" "$i"; then
                    print_status "Successfully auto-restarted $container_name"
                    FAILED_COUNTS[$i]=0
                else
                    FAILED_COUNTS[$i]=$((FAILED_COUNTS[$i] + 1))
                    print_error "Failed to auto-restart $container_name (consecutive failures: ${FAILED_COUNTS[$i]})"
                    log_message "ERROR" "Failed auto-restart for $container_name (count=${FAILED_COUNTS[$i]})"

                    # If we've crossed escalation threshold, send alert
                    if [ "${FAILED_COUNTS[$i]}" -ge $ESCALATE_THRESHOLD ]; then
                        send_alert "$container_name" "Service failed to restart ${FAILED_COUNTS[$i]} times. Escalation triggered."
                    fi

                    # Apply exponential backoff before next attempt
                    local backoff=$((BACKOFF_BASE * (2 ** (FAILED_COUNTS[$i] - 1))))
                    if [ $backoff -gt $BACKOFF_MAX ]; then
                        backoff=$BACKOFF_MAX
                    fi
                    log_message "INFO" "Applying backoff ${backoff}s for $container_name after failure"
                    sleep $backoff
                fi
            fi
        fi
    done

    if [ "$unhealthy_count" -eq 0 ]; then
        echo -n "."
    fi
}

# Function to show status
show_status() {
    print_info "Service Health Status:"
    echo ""

    for i in "${!SERVICES[@]}"; do
        container_name="${SERVICES[$i]}"

        if check_service_health "$container_name" "$i"; then
            print_status "$container_name: Healthy"
        else
            print_error "$container_name: Unhealthy"
        fi
    done
}

# Function to cleanup old log files
cleanup_logs() {
    # Keep only last 7 days of logs
    find /tmp -name "tools_autorestart.log.*" -mtime +7 -delete 2>/dev/null || true

    # Rotate current log if it gets too big (>10MB)
    if [ -f "$LOG_FILE" ] && [ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) -gt 10485760 ]; then
        mv "$LOG_FILE" "$LOG_FILE.$(date +%Y%m%d_%H%M%S)"
    fi
}

# Main function
main() {
    # Parse command line arguments
    case "${1:-}" in
    "status")
        show_status
        exit 0
        ;;
    "once")
        print_info "Running one-time health check..."
        check_all_services
        echo ""
        show_status
        exit 0
        ;;

    "restart")
        container_name="$2"
        if [ -z "$container_name" ]; then
            print_error "Usage: $0 restart <container_name>"
            print_info "Available containers:"
            for i in "${!SERVICES[@]}"; do
                echo "  - ${SERVICES[$i]}"
            done
            exit 1
        fi

        # Find the index for this container
        local found_index=-1
        for i in "${!SERVICES[@]}"; do
            if [ "${SERVICES[$i]}" = "$container_name" ]; then
                found_index="$i"
                # Send alert via webhook or fallback to alert log
                send_alert() {
                    local service="$1"
                    local message="$2"
                    local payload
                    payload=$(printf '{"service":"%s","message":"%s","time":"%s"}' "$service" "$message" "$(date '+%Y-%m-%d %H:%M:%S')")

                    if [ -n "${ALERT_WEBHOOK:-}" ]; then
                        curl -s -X POST -H 'Content-Type: application/json' -d "$payload" "$ALERT_WEBHOOK" >/dev/null 2>&1 || true
                        log_message "INFO" "Sent alert for $service to webhook"
                    else
                        echo "$(date '+%Y-%m-%d %H:%M:%S') ALERT $service: $message" >>/tmp/tools_autorestart.alert.log
                        log_message "INFO" "Wrote alert to /tmp/tools_autorestart.alert.log for $service"
                    fi

                    # Optionally create a GitHub issue when a token is available
                    if [ -n "${GITHUB_TOKEN:-}" ]; then
                        create_github_issue "$service" "$message" || log_message "ERROR" "GitHub issue creation failed for $service"
                    fi
                }


                create_github_issue() {
                    # Create a GitHub issue for the given service and message when GITHUB_TOKEN is set.
                    # Environment variables (optional): GITHUB_TOKEN, GITHUB_REPO_OWNER, GITHUB_REPO_NAME
                    if [ -z "${GITHUB_TOKEN:-}" ]; then
                        log_message "INFO" "GITHUB_TOKEN not set; skipping GitHub issue creation"
                        return 1
                    fi

                    local owner="${GITHUB_REPO_OWNER:-dboone323}"
                    local repo="${GITHUB_REPO_NAME:-tools-automation}"
                    local title
                    local body

                    title="Auto-restart monitor alert: $1"

                    # include the alert message and latest monitor log excerpt
                    local excerpt
                    excerpt=$(tail -n 80 /tmp/tools_autorestart.log 2>/dev/null || true)

                    body=$(cat <<EOF
                The auto-restart monitor detected a problem with service: **$1**

                Message:
                $2

                Time: $(date '+%Y-%m-%d %H:%M:%S')

                Recent monitor log excerpt:


                ${excerpt}
                EOF
                )

                    # Build JSON payload safely
                    local json
                    json=$(printf '{"title":%s,"body":%s,"labels":["autorestart","automated-alert"]}' "$(printf '%s' "$title" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))')" "$(printf '%s' "$body" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))')")

                    # Post the issue
                    local resp
                    resp=$(curl -s -o /tmp/.github_issue_response -w "%{http_code}" -X POST \
                        -H "Authorization: token ${GITHUB_TOKEN}" \
                        -H "Accept: application/vnd.github+json" \
                        -H "Content-Type: application/json" \
                        -d "$json" \
                        "https://api.github.com/repos/${owner}/${repo}/issues" 2>/dev/null)

                    if [ "$resp" = "201" ]; then
                        # extract issue url
                        local issue_url
                        issue_url=$(jq -r .html_url /tmp/.github_issue_response 2>/dev/null || true)
                        log_message "INFO" "Created GitHub issue for $1: ${issue_url:-(unknown)}"
                        return 0
                    else
                        log_message "ERROR" "Failed to create GitHub issue for $1 (HTTP $resp)"
                        log_message "ERROR" "Response: $(cat /tmp/.github_issue_response 2>/dev/null || true)"
                        return 1
                    fi
                }
                break
            fi
        done

        if [ "$found_index" -eq -1 ]; then
            print_error "Container '$container_name' not found in monitored services"
            exit 1
        fi

        restart_service "$container_name" "$found_index"
        exit $?
        ;;
    esac

    # Continuous monitoring mode
    print_info "Starting Auto-Restart Service Monitor"
    print_info "Monitoring ${#SERVICES[@]} services every $CHECK_INTERVAL seconds"
    print_info "Log file: $LOG_FILE"
    print_info "Press Ctrl+C to stop"
    echo ""

    # Cleanup old logs
    cleanup_logs

    log_message "INFO" "Auto-restart monitor started - monitoring ${#SERVICES[@]} services"

    # Main monitoring loop
    while true; do
        check_all_services
        sleep "$CHECK_INTERVAL"
    done
}

# Function to handle cleanup on exit
cleanup() {
    log_message "INFO" "Auto-restart monitor stopped"
    echo ""
    print_info "Auto-restart monitor stopped"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Run main function
main "$@"

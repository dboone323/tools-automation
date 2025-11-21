#!/bin/bash
# Test Runner with Retry Logic and Monitoring
# Runs xcodebuild tests with automatic retries and resource monitoring

set -e

# Configuration
SCHEME="${1:?Usage: $0 <scheme> <destination> [retry_count]}"
DESTINATION="${2:?Usage: $0 <scheme> <destination> [retry_count]}"
MAX_RETRIES="${3:-3}"
PARALLEL_TESTING="${PARALLEL_TESTING:-NO}"
TEST_TIMEOUT="${TEST_TIMEOUT:-1800}"  # 30 minutes default

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOGS_DIR="$PROJECT_ROOT/test_logs"
MONITORING_LOG="$LOGS_DIR/resource_monitoring_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$LOGS_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to monitor CPU and memory usage
monitor_resources() {
    local pid=$1
    local scheme=$2
    
    log_info "Starting resource monitoring for PID $pid"
    
    {
        echo "=== Resource Monitoring for $scheme ==="
        echo "Timestamp,CPU%,Memory(MB),Threads"
        
        while kill -0 "$pid" 2>/dev/null; do
            if command -v ps &> /dev/null; then
                # Get CPU%, Memory in MB, and thread count
                ps -p "$pid" -o %cpu=,%mem=,vsz=,rss=,thcount= 2>/dev/null | while read -r cpu mem vsz rss threads; do
                    # Convert memory to MB
                    mem_mb=$(awk "BEGIN {printf \"%.2f\", $rss / 1024}")
                    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
                    echo "$timestamp,$cpu,$mem_mb,$threads"
                done
            fi
            sleep 2
        done
    } > "$MONITORING_LOG" &
    
    local monitor_pid=$!
    echo "$monitor_pid"
}

# Function to stop monitoring
stop_monitoring() {
    local monitor_pid=$1
    kill "$monitor_pid" 2>/dev/null || true
    
    if [ -f "$MONITORING_LOG" ]; then
        log_info "Resource monitoring saved to: $MONITORING_LOG"
        
        # Display summary
        if command -v awk &> /dev/null; then
            local max_cpu=$(awk -F',' 'NR>2 {if($2>max) max=$2} END {print max}' "$MONITORING_LOG")
            local max_mem=$(awk -F',' 'NR>2 {if($3>max) max=$3} END {print max}' "$MONITORING_LOG")
            local avg_cpu=$(awk -F',' 'NR>2 {sum+=$2; count++} END {if(count>0) print sum/count; else print 0}' "$MONITORING_LOG")
            
            log_info "Resource Usage Summary:"
            echo "  Max CPU: ${max_cpu}%"
            echo "  Max Memory: ${max_mem} MB"
            echo "  Avg CPU: ${avg_cpu}%"
        fi
    fi
}

# Function to run tests with timeout
run_test_with_timeout() {
    local cmd="$1"
    local timeout_duration="$2"
    
    log_info "Running tests with ${timeout_duration}s timeout"
    
    # Run command in background
    eval "$cmd" &
    local test_pid=$!
    
    # Start monitoring
    local monitor_pid=$(monitor_resources "$test_pid" "$SCHEME")
    
    # Wait with timeout
    local count=0
    while kill -0 "$test_pid" 2>/dev/null && [ $count -lt "$timeout_duration" ]; do
        sleep 1
        count=$((count + 1))
    done
    
    # Check if still running (timeout)
    if kill -0 "$test_pid" 2>/dev/null; then
        log_error "Test timed out after ${timeout_duration}s"
        kill "$test_pid" 2>/dev/null || true
        stop_monitoring "$monitor_pid"
        return 124  # Timeout exit code
    fi
    
    # Get exit code
    wait "$test_pid"
    local exit_code=$?
    
    # Stop monitoring
    stop_monitoring "$monitor_pid"
    
    return $exit_code
}

# Function to run tests
run_tests() {
    local attempt=$1
    local log_file="$LOGS_DIR/test_attempt_${attempt}_$(date +%Y%m%d_%H%M%S).log"
    
    log_info "Test attempt $attempt/$MAX_RETRIES"
    log_info "Logging to: $log_file"
    
    local cmd="xcodebuild -scheme \"$SCHEME\" \
        -destination \"$DESTINATION\" \
        -parallel-testing-enabled $PARALLEL_TESTING \
        test 2>&1 | tee \"$log_file\""
    
    if run_test_with_timeout "$cmd" "$TEST_TIMEOUT"; then
        log_success "Tests passed on attempt $attempt"
        return 0
    else
        local exit_code=$?
        log_error "Tests failed on attempt $attempt (exit code: $exit_code)"
        
        # Analyze failure
        if [ -f "$log_file" ]; then
            local error_count=$(grep -c "error:" "$log_file" 2>/dev/null || echo "0")
            local crash_count=$(grep -c "server died" "$log_file" 2>/dev/null || echo "0")
            
            echo "  Build errors: $error_count"
            echo "  Simulator crashes: $crash_count"
            
            # If simulator crashed, try to restart it before retry
            if [ "$crash_count" -gt 0 ]; then
                log_warning "Simulator crash detected, attempting restart..."
                "$SCRIPT_DIR/warmup_simulator.sh" "$(echo "$DESTINATION" | sed -n 's/.*name=\([^,]*\).*/\1/p')" 10 || true
                sleep 5
            fi
        fi
        
        return 1
    fi
}

# Main execution
main() {
    log_info "================================================"
    log_info "Test Runner with Retry Logic"
    log_info "Scheme: $SCHEME"
    log_info "Destination: $DESTINATION"
    log_info "Max Retries: $MAX_RETRIES"
    log_info "Parallel Testing: $PARALLEL_TESTING"
    log_info "================================================"
    
    local attempt=1
    while [ $attempt -le $MAX_RETRIES ]; do
        if run_tests "$attempt"; then
            log_success "All tests passed!"
            exit 0
        fi
        
        if [ $attempt -lt $MAX_RETRIES ]; then
            local delay=$((attempt * 5))
            log_warning "Retrying in ${delay}s..."
            sleep "$delay"
        fi
        
        attempt=$((attempt + 1))
    done
    
    log_error "Tests failed after $MAX_RETRIES attempts"
    exit 1
}

main

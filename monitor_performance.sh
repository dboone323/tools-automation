#!/bin/bash

# Performance Regression Monitoring System
# Tracks performance trends and alerts on significant slowdowns

set -euo pipefail

# Configuration
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PERF_DIR="$WORKSPACE_ROOT/performance_history"
CONFIG_FILE="$WORKSPACE_ROOT/quality-config.yaml"
CURRENT_RESULTS_DIR="$WORKSPACE_ROOT/test_results"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1" >&2; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" >&2; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Load configuration
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        return 1
    fi

    ALERT_THRESHOLD=$(grep "alert_threshold_percent:" "$CONFIG_FILE" | sed 's/.*: *//' | sed 's/ *#.*//')
    MAX_DURATION=$(grep "max_duration_seconds:" "$CONFIG_FILE" | head -1 | sed 's/.*: *//' | sed 's/ *#.*//')

    log_info "Loaded configuration: alert_threshold=${ALERT_THRESHOLD}%, max_duration=${MAX_DURATION}s"
}

# Function to record current performance metrics
record_performance() {
    local project="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local perf_file="$PERF_DIR/${project}_${timestamp}.json"

    log_info "📊 Recording performance metrics for $project..."

    # Create performance directory
    mkdir -p "$PERF_DIR"

    # Get current test results
    local current_results="$CURRENT_RESULTS_DIR/${project}_test_results.json"

    if [[ ! -f "$current_results" ]]; then
        log_warning "No current test results found for $project"
        return 0
    fi

    # Extract performance metrics
    local total_time=$(jq -r '.total_duration_seconds // 0' "$current_results" 2>/dev/null || echo "0")
    local test_count=$(jq -r '.test_count // 0' "$current_results" 2>/dev/null || echo "0")
    local passed_count=$(jq -r '.passed_count // 0' "$current_results" 2>/dev/null || echo "0")
    local failed_count=$(jq -r '.failed_count // 0' "$current_results" 2>/dev/null || echo "0")

    # Calculate rates
    local pass_rate=0
    local fail_rate=0
    if [[ $test_count -gt 0 ]]; then
        pass_rate=$((passed_count * 100 / test_count))
        fail_rate=$((failed_count * 100 / test_count))
    fi

    # Create performance record
    jq -n \
        --arg project "$project" \
        --arg timestamp "$timestamp" \
        --arg total_time "$total_time" \
        --arg test_count "$test_count" \
        --arg passed_count "$passed_count" \
        --arg failed_count "$failed_count" \
        --arg pass_rate "$pass_rate" \
        --arg fail_rate "$fail_rate" \
        '{
            project: $project,
            timestamp: $timestamp,
            metrics: {
                total_duration_seconds: ($total_time | tonumber),
                test_count: ($test_count | tonumber),
                passed_count: ($passed_count | tonumber),
                failed_count: ($failed_count | tonumber),
                pass_rate_percent: ($pass_rate | tonumber),
                fail_rate_percent: ($fail_rate | tonumber)
            }
        }' >"$perf_file"

    log_success "✅ Performance metrics recorded for $project: ${total_time}s, ${pass_rate}% pass rate"
}

# Function to analyze performance trends
analyze_trends() {
    local project="$1"

    log_info "📈 Analyzing performance trends for $project..."

    # Get all performance records for this project (last 10)
    local perf_files=$(ls -t "$PERF_DIR/${project}_"*.json 2>/dev/null | head -10 || echo "")

    if [[ -z "$perf_files" ]]; then
        log_warning "No historical performance data found for $project"
        return 0
    fi

    # Extract recent performance data
    local recent_times=()
    local recent_rates=()

    for file in $perf_files; do
        local time=$(jq -r '.metrics.total_duration_seconds' "$file" 2>/dev/null || echo "0")
        local rate=$(jq -r '.metrics.pass_rate_percent' "$file" 2>/dev/null || echo "0")

        recent_times+=("$time")
        recent_rates+=("$rate")
    done

    # Calculate trends
    if [[ ${#recent_times[@]} -lt 2 ]]; then
        log_info "Not enough data points for trend analysis"
        return 0
    fi

    # Calculate average of last 3 runs vs first 3 runs
    local recent_count=3
    if [[ ${#recent_times[@]} -lt $recent_count ]]; then
        recent_count=${#recent_times[@]}
    fi

    local recent_avg_time=0
    local recent_avg_rate=0
    local older_avg_time=0
    local older_avg_rate=0

    # Calculate recent averages (last N runs)
    for ((i = 0; i < recent_count; i++)); do
        recent_avg_time=$(echo "$recent_avg_time + ${recent_times[$i]}" | bc -l 2>/dev/null || echo "$recent_avg_time")
        recent_avg_rate=$(echo "$recent_avg_rate + ${recent_rates[$i]}" | bc -l 2>/dev/null || echo "$recent_avg_rate")
    done
    recent_avg_time=$(echo "scale=2; $recent_avg_time / $recent_count" | bc -l 2>/dev/null || echo "0")
    recent_avg_rate=$(echo "scale=2; $recent_avg_rate / $recent_count" | bc -l 2>/dev/null || echo "0")

    # Calculate older averages (runs before the recent ones)
    local older_count=$((${#recent_times[@]} - recent_count))
    if [[ $older_count -gt 0 ]]; then
        for ((i = recent_count; i < ${#recent_times[@]}; i++)); do
            older_avg_time=$(echo "$older_avg_time + ${recent_times[$i]}" | bc -l 2>/dev/null || echo "$older_avg_time")
            older_avg_rate=$(echo "$older_avg_rate + ${recent_rates[$i]}" | bc -l 2>/dev/null || echo "$older_avg_rate")
        done
        older_avg_time=$(echo "scale=2; $older_avg_time / $older_count" | bc -l 2>/dev/null || echo "0")
        older_avg_rate=$(echo "scale=2; $older_avg_rate / $older_count" | bc -l 2>/dev/null || echo "0")
    fi

    # Calculate percentage changes
    local time_change_percent=0
    local rate_change_percent=0

    if (($(echo "$older_avg_time > 0" | bc -l 2>/dev/null || echo "0"))); then
        time_change_percent=$(echo "scale=2; (($recent_avg_time - $older_avg_time) / $older_avg_time) * 100" | bc -l 2>/dev/null || echo "0")
    fi

    if (($(echo "$older_avg_rate > 0" | bc -l 2>/dev/null || echo "0"))); then
        rate_change_percent=$(echo "scale=2; (($recent_avg_rate - $older_avg_rate) / $older_avg_rate) * 100" | bc -l 2>/dev/null || echo "0")
    fi

    # Check for regressions
    local regression_detected=false

    if (($(echo "${time_change_percent#*-} > $ALERT_THRESHOLD" | bc -l 2>/dev/null || echo "0"))); then
        log_warning "🐌 Performance regression detected: ${time_change_percent}% change in execution time"
        regression_detected=true
    fi

    if (($(echo "${rate_change_percent#*-} < -$ALERT_THRESHOLD" | bc -l 2>/dev/null || echo "0"))); then
        log_warning "📉 Test reliability regression detected: ${rate_change_percent}% change in pass rate"
        regression_detected=true
    fi

    # Generate trend report
    local trend_file="$PERF_DIR/${project}_trend_$(date +%Y%m%d_%H%M%S).json"

    jq -n \
        --arg project "$project" \
        --arg recent_avg_time "$recent_avg_time" \
        --arg older_avg_time "$older_avg_time" \
        --arg time_change_percent "$time_change_percent" \
        --arg recent_avg_rate "$recent_avg_rate" \
        --arg older_avg_rate "$older_avg_rate" \
        --arg rate_change_percent "$rate_change_percent" \
        --arg data_points "${#recent_times[@]}" \
        --argjson regression "$regression_detected" \
        '{
            project: $project,
            timestamp: now | strftime("%Y-%m-%dT%H:%M:%SZ"),
            analysis_period: "last_10_runs",
            performance_trends: {
                execution_time: {
                    recent_average_seconds: ($recent_avg_time | tonumber),
                    older_average_seconds: ($older_avg_time | tonumber),
                    change_percent: ($time_change_percent | tonumber)
                },
                test_reliability: {
                    recent_pass_rate_percent: ($recent_avg_rate | tonumber),
                    older_pass_rate_percent: ($older_avg_rate | tonumber),
                    change_percent: ($rate_change_percent | tonumber)
                }
            },
            data_points: ($data_points | tonumber),
            regression_detected: $regression,
            recommendations: [
                "Monitor execution time trends",
                "Review recent code changes for performance impact",
                "Consider test parallelization if execution time increasing",
                "Investigate flaky tests if pass rate declining"
            ]
        }' >"$trend_file"

    if [[ "$regression_detected" == "true" ]]; then
        log_error "🚨 PERFORMANCE REGRESSION DETECTED for $project"
        return 1
    else
        log_success "✅ No performance regression detected for $project"
        return 0
    fi
}

# Function to generate performance dashboard
generate_dashboard() {
    log_info "📊 Generating performance dashboard..."

    local dashboard_file="$PERF_DIR/performance_dashboard_$(date +%Y%m%d_%H%M%S).json"

    # Get all projects
    local projects=("AvoidObstaclesGame" "CodingReviewer" "PlannerApp" "MomentumFinance" "HabitQuest")

    # Collect current metrics for all projects
    local project_metrics="[]"

    for project in "${projects[@]}"; do
        # Get latest performance file
        local latest_file=$(ls -t "$PERF_DIR/${project}_"*.json 2>/dev/null | head -1 || echo "")

        if [[ -n "$latest_file" ]]; then
            local metrics=$(jq '.metrics' "$latest_file" 2>/dev/null || echo "null")
            if [[ "$metrics" != "null" ]]; then
                project_metrics=$(echo "$project_metrics" | jq --arg project "$project" --argjson metrics "$metrics" '. + [{project: $project, metrics: $metrics}]')
            fi
        fi
    done

    # Get trend analysis
    local trend_files=$(ls -t "$PERF_DIR/"*"_trend_"*.json 2>/dev/null | head -5 || echo "")
    local trends="[]"

    for trend_file in $trend_files; do
        local trend=$(jq '{project, performance_trends, regression_detected}' "$trend_file" 2>/dev/null || echo "null")
        if [[ "$trend" != "null" ]]; then
            trends=$(echo "$trends" | jq --argjson trend "$trend" '. + [$trend]')
        fi
    done

    # Generate dashboard
    local avg_pass_rate=0
    local total_exec_time=0
    local metrics_length=$(echo "$project_metrics" | jq 'length')

    if [[ $metrics_length -gt 0 ]]; then
        avg_pass_rate=$(echo "$project_metrics" | jq 'map(.metrics.pass_rate_percent) | add / length' 2>/dev/null || echo "0")
        total_exec_time=$(echo "$project_metrics" | jq 'map(.metrics.total_duration_seconds) | add' 2>/dev/null || echo "0")
    fi

    jq -n \
        --arg timestamp "$(date -Iseconds)" \
        --arg alert_threshold "$ALERT_THRESHOLD" \
        --arg max_duration "$MAX_DURATION" \
        --argjson current_metrics "$project_metrics" \
        --argjson trends "$trends" \
        --arg avg_pass_rate "$avg_pass_rate" \
        --arg total_exec_time "$total_exec_time" \
        --arg metrics_length "$metrics_length" \
        '{
            timestamp: $timestamp,
            configuration: {
                alert_threshold_percent: ($alert_threshold | tonumber),
                max_duration_seconds: ($max_duration | tonumber)
            },
            current_metrics: $current_metrics,
            trend_analysis: $trends,
            summary: {
                total_projects: ($metrics_length | tonumber),
                projects_with_regressions: ($trends | map(select(.regression_detected == true)) | length),
                average_pass_rate: ($avg_pass_rate | tonumber),
                total_test_execution_time: ($total_exec_time | tonumber)
            }
        }' >"$dashboard_file"

    log_success "📊 Performance dashboard generated: $dashboard_file"

    # Print summary to console
    echo
    echo "==========================================="
    echo "     PERFORMANCE MONITORING DASHBOARD"
    echo "==========================================="
    echo "Alert Threshold: ${ALERT_THRESHOLD}%"
    echo "Max Duration: ${MAX_DURATION}s"
    echo

    local regression_count=$(echo "$trends" | jq '[.[] | select(.regression_detected == true)] | length')
    echo "Projects with regressions: $regression_count"

    echo "$project_metrics" | jq -r '.[] | "✓ \(.project): \(.metrics.total_duration_seconds)s, \(.metrics.pass_rate_percent)% pass rate"'
    echo

    if [[ "$regression_count" -gt 0 ]]; then
        log_error "🚨 PERFORMANCE REGRESSIONS DETECTED"
        return 1
    else
        log_success "✅ NO PERFORMANCE REGRESSIONS DETECTED"
        return 0
    fi
}

# Main execution
main() {
    local projects=("$@")

    if [[ ${#projects[@]} -eq 0 ]]; then
        # Default to all projects
        projects=("AvoidObstaclesGame" "CodingReviewer" "PlannerApp" "MomentumFinance" "HabitQuest")
    fi

    log_info "Starting performance regression monitoring for ${#projects[@]} projects..."

    # Load configuration
    load_config

    # Record current performance for each project
    for project in "${projects[@]}"; do
        record_performance "$project"
    done

    # Analyze trends for each project
    local total_regressions=0
    for project in "${projects[@]}"; do
        if ! analyze_trends "$project"; then
            ((total_regressions++))
        fi
    done

    # Generate dashboard
    generate_dashboard
    local dashboard_exit=$?

    log_info "Performance monitoring completed. Regressions detected: $total_regressions"

    exit $dashboard_exit
}

# Run main function with all arguments
main "$@"

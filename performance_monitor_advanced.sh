#!/bin/bash
# Advanced Performance Monitoring and Analytics for CI/CD Pipeline
# Tracks build times, test performance, coverage trends, and bottleneck detection
# Integrates with dashboard_server.py for real-time visualization

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration
METRICS_DIR="$WORKSPACE_ROOT/.metrics"
PERFORMANCE_DB="$METRICS_DIR/performance.db"
TREND_ANALYSIS_FILE="$METRICS_DIR/trend_analysis.json"
REGRESSION_ALERTS_FILE="$METRICS_DIR/regression_alerts.json"

# Thresholds for regression detection
BUILD_TIME_REGRESSION_THRESHOLD=10 # 10% increase
TEST_TIME_REGRESSION_THRESHOLD=15  # 15% increase
COVERAGE_REGRESSION_THRESHOLD=2    # 2% decrease

# Historical data retention
RETENTION_DAYS=90
MAX_ENTRIES_PER_METRIC=1000

# Initialize metrics database
init_metrics_db() {
    mkdir -p "$METRICS_DIR"

    if [[ ! -f "$PERFORMANCE_DB" ]]; then
        # Create SQLite database for performance metrics
        sqlite3 "$PERFORMANCE_DB" <<EOF
CREATE TABLE build_times (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    project TEXT NOT NULL,
    operation TEXT NOT NULL,
    duration_seconds REAL NOT NULL,
    success BOOLEAN NOT NULL,
    commit_sha TEXT,
    ci_run_id TEXT
);

CREATE TABLE test_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    project TEXT NOT NULL,
    test_type TEXT NOT NULL,
    duration_seconds REAL NOT NULL,
    test_count INTEGER,
    failure_count INTEGER,
    coverage_percent REAL,
    commit_sha TEXT,
    ci_run_id TEXT
);

CREATE TABLE coverage_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    project TEXT NOT NULL,
    total_lines INTEGER,
    covered_lines INTEGER,
    coverage_percent REAL,
    commit_sha TEXT,
    ci_run_id TEXT
);

CREATE INDEX idx_build_times_project ON build_times(project);
CREATE INDEX idx_build_times_timestamp ON build_times(timestamp);
CREATE INDEX idx_test_metrics_project ON test_metrics(project);
CREATE INDEX idx_test_metrics_timestamp ON test_metrics(timestamp);
CREATE INDEX idx_coverage_history_project ON coverage_history(project);
CREATE INDEX idx_coverage_history_timestamp ON coverage_history(timestamp);
EOF
        echo "Initialized performance metrics database"
    fi
}

# Record build time metric
record_build_time() {
    local project="$1"
    local operation="$2"
    local duration="$3"
    local success="$4"
    local commit_sha="${5:-}"
    local ci_run_id="${6:-}"

    sqlite3 "$PERFORMANCE_DB" <<EOF
INSERT INTO build_times (project, operation, duration_seconds, success, commit_sha, ci_run_id)
VALUES ('$project', '$operation', $duration, $success, '$commit_sha', '$ci_run_id');
EOF

    echo "Recorded build time: $project $operation ${duration}s (success: $success)"
}

# Record test metrics
record_test_metrics() {
    local project="$1"
    local test_type="$2"
    local duration="$3"
    local test_count="$4"
    local failure_count="$5"
    local coverage_percent="${6:-}"
    local commit_sha="${7:-}"
    local ci_run_id="${8:-}"

    # Handle empty coverage_percent
    local coverage_value="NULL"
    if [[ -n "$coverage_percent" && "$coverage_percent" != "0.0" ]]; then
        coverage_value="$coverage_percent"
    fi

    sqlite3 "$PERFORMANCE_DB" <<EOF
INSERT INTO test_metrics (project, test_type, duration_seconds, test_count, failure_count, coverage_percent, commit_sha, ci_run_id)
VALUES ('$project', '$test_type', $duration, $test_count, $failure_count, $coverage_value, '$commit_sha', '$ci_run_id');
EOF

    echo "Recorded test metrics: $project $test_type ${duration}s (${test_count} tests, ${failure_count} failures)"
}

# Record coverage metrics
record_coverage() {
    local project="$1"
    local total_lines="$2"
    local covered_lines="$3"
    local coverage_percent="$4"
    local commit_sha="${5:-}"
    local ci_run_id="${6:-}"

    sqlite3 "$PERFORMANCE_DB" <<EOF
INSERT INTO coverage_history (project, total_lines, covered_lines, coverage_percent, commit_sha, ci_run_id)
VALUES ('$project', $total_lines, $covered_lines, $coverage_percent, '$commit_sha', '$ci_run_id');
EOF

    echo "Recorded coverage: $project ${coverage_percent}% ($covered_lines/$total_lines lines)"
}

# Analyze performance trends
analyze_trends() {
    local project="$1"
    local days="${2:-30}"

    echo "Analyzing performance trends for $project (last ${days} days)..."

    # Build time trends
    local build_trend
    build_trend=$(
        sqlite3 "$PERFORMANCE_DB" <<EOF
SELECT
    AVG(duration_seconds) as avg_duration,
    MIN(duration_seconds) as min_duration,
    MAX(duration_seconds) as max_duration,
    COUNT(*) as sample_count
FROM build_times
WHERE project = '$project'
  AND timestamp >= datetime('now', '-${days} days')
  AND success = 1;
EOF
    )

    # Test performance trends
    local test_trend
    test_trend=$(
        sqlite3 "$PERFORMANCE_DB" <<EOF
SELECT
    AVG(duration_seconds) as avg_duration,
    AVG(coverage_percent) as avg_coverage,
    COUNT(*) as sample_count
FROM test_metrics
WHERE project = '$project'
  AND timestamp >= datetime('now', '-${days} days');
EOF
    )

    # Coverage trends
    local coverage_trend
    coverage_trend=$(
        sqlite3 "$PERFORMANCE_DB" <<EOF
SELECT
    AVG(coverage_percent) as avg_coverage,
    MIN(coverage_percent) as min_coverage,
    MAX(coverage_percent) as max_coverage,
    COUNT(*) as sample_count
FROM coverage_history
WHERE project = '$project'
  AND timestamp >= datetime('now', '-${days} days');
EOF
    )

    # Generate trend analysis JSON
    cat >"$TREND_ANALYSIS_FILE" <<EOF
{
  "project": "$project",
  "analysis_period_days": $days,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "build_performance": {
    "avg_duration_seconds": $(echo "$build_trend" | cut -d'|' -f1),
    "min_duration_seconds": $(echo "$build_trend" | cut -d'|' -f2),
    "max_duration_seconds": $(echo "$build_trend" | cut -d'|' -f3),
    "sample_count": $(echo "$build_trend" | cut -d'|' -f4)
  },
  "test_performance": {
    "avg_duration_seconds": $(echo "$test_trend" | cut -d'|' -f1),
    "avg_coverage_percent": $(echo "$test_trend" | cut -d'|' -f2),
    "sample_count": $(echo "$test_trend" | cut -d'|' -f3)
  },
  "coverage_trends": {
    "avg_coverage_percent": $(echo "$coverage_trend" | cut -d'|' -f1),
    "min_coverage_percent": $(echo "$coverage_trend" | cut -d'|' -f2),
    "max_coverage_percent": $(echo "$coverage_trend" | cut -d'|' -f3),
    "sample_count": $(echo "$coverage_trend" | cut -d'|' -f4)
  }
}
EOF

    echo "Trend analysis saved to: $TREND_ANALYSIS_FILE"
}

# Detect performance regressions
detect_regressions() {
    local project="$1"
    local baseline_days="${2:-7}"
    local current_days="${3:-1}"

    echo "Detecting performance regressions for $project..."

    # Compare build times
    local baseline_build
    baseline_build=$(
        sqlite3 "$PERFORMANCE_DB" <<EOF
SELECT AVG(duration_seconds)
FROM build_times
WHERE project = '$project'
  AND timestamp >= datetime('now', '-${baseline_days} days')
  AND timestamp < datetime('now', '-${current_days} days')
  AND success = 1;
EOF
    )

    local current_build
    current_build=$(
        sqlite3 "$PERFORMANCE_DB" <<EOF
SELECT AVG(duration_seconds)
FROM build_times
WHERE project = '$project'
  AND timestamp >= datetime('now', '-${current_days} days')
  AND success = 1;
EOF
    )

    # Calculate regression percentage
    local build_regression=0
    if [[ -n "$baseline_build" && -n "$current_build" && "$baseline_build" != "0" ]]; then
        build_regression=$(echo "scale=2; (($current_build - $baseline_build) / $baseline_build) * 100" | bc 2>/dev/null || echo "0")
    fi

    # Compare test times
    local baseline_test
    baseline_test=$(
        sqlite3 "$PERFORMANCE_DB" <<EOF
SELECT AVG(duration_seconds)
FROM test_metrics
WHERE project = '$project'
  AND timestamp >= datetime('now', '-${baseline_days} days')
  AND timestamp < datetime('now', '-${current_days} days');
EOF
    )

    local current_test
    current_test=$(
        sqlite3 "$PERFORMANCE_DB" <<EOF
SELECT AVG(duration_seconds)
FROM test_metrics
WHERE project = '$project'
  AND timestamp >= datetime('now', '-${current_days} days');
EOF
    )

    local test_regression=0
    if [[ -n "$baseline_test" && -n "$current_test" && "$baseline_test" != "0" ]]; then
        test_regression=$(echo "scale=2; (($current_test - $baseline_test) / $baseline_test) * 100" | bc 2>/dev/null || echo "0")
    fi

    # Compare coverage
    local baseline_coverage
    baseline_coverage=$(
        sqlite3 "$PERFORMANCE_DB" <<EOF
SELECT AVG(coverage_percent)
FROM coverage_history
WHERE project = '$project'
  AND timestamp >= datetime('now', '-${baseline_days} days')
  AND timestamp < datetime('now', '-${current_days} days');
EOF
    )

    local current_coverage
    current_coverage=$(
        sqlite3 "$PERFORMANCE_DB" <<EOF
SELECT AVG(coverage_percent)
FROM coverage_history
WHERE project = '$project'
  AND timestamp >= datetime('now', '-${current_days} days');
EOF
    )

    local coverage_regression=0
    if [[ -n "$baseline_coverage" && -n "$current_coverage" ]]; then
        coverage_regression=$(echo "scale=2; ($baseline_coverage - $current_coverage)" | bc 2>/dev/null || echo "0")
    fi

    # Generate regression report
    local alerts="[]"
    local alert_count=0

    # Check build time regression
    if (($(echo "$build_regression > $BUILD_TIME_REGRESSION_THRESHOLD" | bc -l 2>/dev/null || echo "0"))); then
        alerts=$(echo "$alerts" | jq ". + [{\"type\": \"build_time\", \"severity\": \"warning\", \"message\": \"Build time increased by ${build_regression}%\", \"baseline\": $baseline_build, \"current\": $current_build}]")
        ((alert_count++))
    fi

    # Check test time regression
    if (($(echo "$test_regression > $TEST_TIME_REGRESSION_THRESHOLD" | bc -l 2>/dev/null || echo "0"))); then
        alerts=$(echo "$alerts" | jq ". + [{\"type\": \"test_time\", \"severity\": \"warning\", \"message\": \"Test time increased by ${test_regression}%\", \"baseline\": $baseline_test, \"current\": $current_test}]")
        ((alert_count++))
    fi

    # Check coverage regression
    if (($(echo "$coverage_regression > $COVERAGE_REGRESSION_THRESHOLD" | bc -l 2>/dev/null || echo "0"))); then
        alerts=$(echo "$alerts" | jq ". + [{\"type\": \"coverage\", \"severity\": \"error\", \"message\": \"Coverage decreased by ${coverage_regression}%\", \"baseline\": $baseline_coverage, \"current\": $current_coverage}]")
        ((alert_count++))
    fi

    # Save regression alerts
    cat >"$REGRESSION_ALERTS_FILE" <<EOF
{
  "project": "$project",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "baseline_period_days": $baseline_days,
  "current_period_days": $current_days,
  "regressions": {
    "build_time_percent": $build_regression,
    "test_time_percent": $test_regression,
    "coverage_percent_decrease": $coverage_regression
  },
  "alerts": $alerts,
  "alert_count": $alert_count
}
EOF

    echo "Regression analysis complete: $alert_count alerts detected"
    echo "Report saved to: $REGRESSION_ALERTS_FILE"

    return $alert_count
}

# Generate performance dashboard data
generate_dashboard_data() {
    echo "Generating dashboard data..."

    local dashboard_file="$WORKSPACE_ROOT/dashboard_performance_data.json"

    # Get recent metrics for all projects
    local projects=("CodingReviewer" "AvoidObstaclesGame" "PlannerApp" "MomentumFinance" "HabitQuest")

    local dashboard_data="{\"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"projects\": {"

    for project in "${projects[@]}"; do
        # Get latest build time
        local latest_build
        latest_build=$(
            sqlite3 "$PERFORMANCE_DB" <<EOF
SELECT duration_seconds, success
FROM build_times
WHERE project = '$project'
ORDER BY timestamp DESC
LIMIT 1;
EOF
        )

        # Get latest test metrics
        local latest_test
        latest_test=$(
            sqlite3 "$PERFORMANCE_DB" <<EOF
SELECT duration_seconds, test_count, failure_count, coverage_percent
FROM test_metrics
WHERE project = '$project'
ORDER BY timestamp DESC
LIMIT 1;
EOF
        )

        # Get 7-day averages
        local week_avg
        week_avg=$(
            sqlite3 "$PERFORMANCE_DB" <<EOF
SELECT
    AVG(bt.duration_seconds) as avg_build_time,
    AVG(tm.duration_seconds) as avg_test_time,
    AVG(ch.coverage_percent) as avg_coverage
FROM build_times bt
LEFT JOIN test_metrics tm ON tm.project = bt.project AND tm.timestamp >= datetime(bt.timestamp, '-1 hour') AND tm.timestamp <= datetime(bt.timestamp, '+1 hour')
LEFT JOIN coverage_history ch ON ch.project = bt.project AND ch.timestamp >= datetime(bt.timestamp, '-1 hour') AND ch.timestamp <= datetime(bt.timestamp, '+1 hour')
WHERE bt.project = '$project'
  AND bt.timestamp >= datetime('now', '-7 days')
  AND bt.success = 1;
EOF
        )

        dashboard_data+="\"$project\": {"
        dashboard_data+="\"latest_build_seconds\": $(echo "$latest_build" | cut -d'|' -f1 || echo "null"),"
        dashboard_data+="\"latest_build_success\": $(echo "$latest_build" | cut -d'|' -f2 || echo "null"),"
        dashboard_data+="\"latest_test_seconds\": $(echo "$latest_test" | cut -d'|' -f1 || echo "null"),"
        dashboard_data+="\"latest_test_count\": $(echo "$latest_test" | cut -d'|' -f2 || echo "null"),"
        dashboard_data+="\"latest_test_failures\": $(echo "$latest_test" | cut -d'|' -f3 || echo "null"),"
        dashboard_data+="\"latest_coverage_percent\": $(echo "$latest_test" | cut -d'|' -f4 || echo "null"),"
        dashboard_data+="\"week_avg_build_seconds\": $(echo "$week_avg" | cut -d'|' -f1 || echo "null"),"
        dashboard_data+="\"week_avg_test_seconds\": $(echo "$week_avg" | cut -d'|' -f2 || echo "null"),"
        dashboard_data+="\"week_avg_coverage_percent\": $(echo "$week_avg" | cut -d'|' -f3 || echo "null")"
        dashboard_data+="},"
    done

    dashboard_data=${dashboard_data%,} # Remove trailing comma
    dashboard_data+="}}"

    echo "$dashboard_data" | jq . >"$dashboard_file"
    echo "Dashboard data saved to: $dashboard_file"
}

# Clean up old metrics data
cleanup_old_data() {
    local cutoff_date
    cutoff_date=$(date -v-${RETENTION_DAYS}d +%Y-%m-%d 2>/dev/null || date -d "${RETENTION_DAYS} days ago" +%Y-%m-%d)

    echo "Cleaning up data older than $cutoff_date..."

    sqlite3 "$PERFORMANCE_DB" <<EOF
DELETE FROM build_times WHERE timestamp < '$cutoff_date';
DELETE FROM test_metrics WHERE timestamp < '$cutoff_date';
DELETE FROM coverage_history WHERE timestamp < '$cutoff_date';
VACUUM;
EOF

    echo "Cleanup complete"
}

# Main CLI interface
main() {
    init_metrics_db

    case "${1:-}" in
    record-build)
        if [[ $# -lt 5 ]]; then
            echo "Usage: $0 record-build <project> <operation> <duration> <success> [commit_sha] [ci_run_id]"
            exit 1
        fi
        record_build_time "$2" "$3" "$4" "$5" "${6:-}" "${7:-}"
        ;;
    record-test)
        if [[ $# -lt 7 ]]; then
            echo "Usage: $0 record-test <project> <test_type> <duration> <test_count> <failure_count> [coverage_percent] [commit_sha] [ci_run_id]"
            exit 1
        fi
        record_test_metrics "$2" "$3" "$4" "$5" "$6" "${7:-}" "${8:-}" "${9:-}"
        ;;
    record-coverage)
        if [[ $# -lt 5 ]]; then
            echo "Usage: $0 record-coverage <project> <total_lines> <covered_lines> <coverage_percent> [commit_sha] [ci_run_id]"
            exit 1
        fi
        record_coverage "$2" "$3" "$4" "$5" "${6:-}" "${7:-}"
        ;;
    analyze)
        if [[ $# -lt 2 ]]; then
            echo "Usage: $0 analyze <project> [days]"
            exit 1
        fi
        analyze_trends "$2" "${3:-30}"
        ;;
    detect-regressions)
        if [[ $# -lt 2 ]]; then
            echo "Usage: $0 detect-regressions <project> [baseline_days] [current_days]"
            exit 1
        fi
        detect_regressions "$2" "${3:-7}" "${4:-1}"
        ;;
    dashboard)
        generate_dashboard_data
        ;;
    cleanup)
        cleanup_old_data
        ;;
    *)
        cat <<EOF
Advanced Performance Monitoring Tool

Usage: $0 <command> [args...]

Commands:
  record-build <project> <operation> <duration> <success> [commit] [run_id]
    Record a build time metric

  record-test <project> <type> <duration> <count> <failures> [coverage] [commit] [run_id]
    Record test execution metrics

  record-coverage <project> <total> <covered> <percent> [commit] [run_id]
    Record code coverage metrics

  analyze <project> [days]
    Analyze performance trends (default: 30 days)

  detect-regressions <project> [baseline_days] [current_days]
    Detect performance regressions (default: 7 vs 1 day)

  dashboard
    Generate dashboard data for visualization

  cleanup
    Remove data older than retention period

Examples:
  $0 record-build CodingReviewer build 45.2 1 abc123 12345
  $0 record-test CodingReviewer unit 12.3 77 0 92.5 def456 12346
  $0 analyze CodingReviewer 14
  $0 detect-regressions CodingReviewer
  $0 dashboard

EOF
        exit 1
        ;;
    esac
}

main "$@"

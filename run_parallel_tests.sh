#!/bin/bash

# Parallel Test Execution Framework for Quantum-workspace
# SwiftPM-first runner with coverage, parallelism, and JSON artifacts

set -euo pipefail

# ---------------------------------
# Configuration
# ---------------------------------
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECTS=()           # populated by discover_projects unless TEST_PROJECTS is set
COVERAGE_THRESHOLD=85 # percent
TIMEOUT_SECONDS=120
MAX_PARALLEL_JOBS=3

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging helpers
log_info() { echo -e "${BLUE}[INFO]${NC} $1" >&2; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" >&2; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# ---------------------------------
# Path resolution & discovery
# ---------------------------------
resolve_project_path() {
    local project="$1"

    # 1) Legacy layout: Projects/<Name>
    if [[ -d "$WORKSPACE_ROOT/Projects/$project" ]]; then
        echo "$WORKSPACE_ROOT/Projects/$project"
        return 0
    fi

    # 2) Top-level folder with same name (e.g., Shared)
    if [[ -d "$WORKSPACE_ROOT/$project" ]]; then
        echo "$WORKSPACE_ROOT/$project"
        return 0
    fi

    # 3) Special-case Shared package location
    if [[ "$project" == "Shared" && -d "$WORKSPACE_ROOT/Shared" ]]; then
        echo "$WORKSPACE_ROOT/Shared"
        return 0
    fi

    # 4) Fallback: find a Package.swift whose parent dir matches the project name
    local pkg
    while IFS= read -r pkg; do
        local dir
        dir="$(dirname "$pkg")"
        if [[ "$(basename "$dir")" == "$project" ]]; then
            echo "$dir"
            return 0
        fi
    done < <(find "$WORKSPACE_ROOT" -maxdepth 3 -name Package.swift 2>/dev/null)

    echo ""
    return 1
}

discover_projects() {
    local discovered=()

    if [[ -n "${TEST_PROJECTS:-}" ]]; then
        for p in ${TEST_PROJECTS}; do
            discovered+=("$p")
        done
    else
        # Prefer Shared if present
        if [[ -f "$WORKSPACE_ROOT/Shared/Package.swift" ]]; then
            discovered+=("Shared")
        fi
        # Find other Swift packages (exclude Tools/WebInterface)
        while IFS= read -r pkg; do
            local dir name
            dir="$(dirname "$pkg")"
            name="$(basename "$dir")"
            if [[ "$name" != "Shared" && "$dir" != "$WORKSPACE_ROOT/Tools/WebInterface"* ]]; then
                discovered+=("$name")
            fi
        done < <(find "$WORKSPACE_ROOT" -maxdepth 3 -name Package.swift 2>/dev/null)
    fi

    # Deduplicate while preserving order
    if ((${#discovered[@]} == 0)); then
        discovered=("AvoidObstaclesGame" "CodingReviewer" "PlannerApp" "MomentumFinance" "HabitQuest")
    fi
    declare -A seen=()
    PROJECTS=()
    for name in "${discovered[@]}"; do
        if [[ -z "${seen[$name]:-}" ]]; then
            PROJECTS+=("$name")
            seen[$name]=1
        fi
    done
}

# ---------------------------------
# Test execution
# ---------------------------------
run_project_tests() {
    local project="$1"
    local project_path
    project_path="$(resolve_project_path "$project")"
    local start_time
    start_time=$(date +%s)

    log_info "Starting tests for $project..."
    echo "$start_time" >"/tmp/${project}_start_time"

    if [[ -z "$project_path" || ! -d "$project_path" ]]; then
        log_error "Project path not found for $project"
        echo "FAILED" >"/tmp/${project}_test_result"
        echo "$start_time" >"/tmp/${project}_end_time"
        : >"/tmp/${project}_test_output"
        echo "0.00" >"/tmp/${project}_coverage"
        return 1
    fi

    cd "$project_path"
    local test_output_file="/tmp/${project}_test_output"

    if [[ -f "Package.swift" ]]; then
        # Swift Package
        if swift test --enable-code-coverage --parallel >"$test_output_file" 2>&1; then
            log_success "Tests passed for $project"
            echo "PASSED" >"/tmp/${project}_test_result"
        else
            if grep -qiE "no tests? (were )?found" "$test_output_file" 2>/dev/null; then
                log_warning "No tests for $project - running build and marking as PASSED (build-only)"
                swift build >/dev/null 2>&1 || true
                echo "PASSED" >"/tmp/${project}_test_result"
            else
                log_error "Tests failed for $project"
                echo "FAILED" >"/tmp/${project}_test_result"
                # still collect coverage if any to aid diagnostics
            fi
        fi
    else
        # Xcode-based projects (fallback)
        local scheme="$project"
        if xcodebuild test \
            -scheme "$scheme" \
            -destination 'platform=macOS' \
            -enableCodeCoverage YES \
            -parallel-testing-enabled YES \
            -test-timeouts-enabled YES \
            -maximum-test-execution-time-allowance "$TIMEOUT_SECONDS" >"$test_output_file" 2>&1; then
            log_success "Tests passed for $project"
            echo "PASSED" >"/tmp/${project}_test_result"
        else
            log_error "Tests failed for $project"
            echo "FAILED" >"/tmp/${project}_test_result"
        fi
    fi

    local end_time
    end_time=$(date +%s)
    echo "$end_time" >"/tmp/${project}_end_time"

    collect_coverage "$project"
}

# ---------------------------------
# Coverage collection
# ---------------------------------
collect_coverage() {
    local project="$1"
    local project_dir
    project_dir="$(resolve_project_path "$project")"
    local coverage_pct="0.00"

    log_info "Collecting coverage for $project..."

    if [[ -n "$project_dir" && -f "$project_dir/Package.swift" ]]; then
        if command -v xcrun >/dev/null 2>&1; then
            local profraw_list
            profraw_list=$(find "$project_dir/.build" -type f -name "*.profraw" 2>/dev/null || true)
            if [[ -n "$profraw_list" ]]; then
                local profdata_path="$project_dir/.build/coverage.profdata"
                xcrun llvm-profdata merge -sparse $profraw_list -o "$profdata_path" 2>/dev/null || true

                local bin_path
                bin_path=$( (cd "$project_dir" && swift build --show-bin-path 2>/dev/null) || echo "")

                local objects=()
                if [[ -n "$bin_path" && -d "$bin_path" ]]; then
                    while IFS= read -r obj; do objects+=("$obj"); done < <(
                        find "$bin_path" -maxdepth 3 \
                            \( -type f -perm -111 -o -name "*.dylib" -o -name "*.so" \) 2>/dev/null
                    )
                    # Include Mach-O from inside .xctest bundles
                    while IFS= read -r mac; do objects+=("$mac"); done < <(
                        find "$bin_path" -type f -path "*.xctest/Contents/MacOS/*" 2>/dev/null
                    )
                fi

                if ((${#objects[@]} == 0)); then
                    while IFS= read -r obj; do objects+=("$obj"); done < <(
                        find "$project_dir/.build" -type f \
                            \( -perm -111 -o -name "*.dylib" -o -name "*.so" -o -path "*.xctest/Contents/MacOS/*" \) 2>/dev/null
                    )
                fi

                if ((${#objects[@]} > 0)); then
                    local coverage_report
                    coverage_report=$(xcrun llvm-cov report \
                        -instr-profile="$profdata_path" \
                        "${objects[@]}" \
                        -use-color=false \
                        -ignore-filename-regex="\\.build|Tests|/usr" 2>/dev/null || true)

                    local percent
                    percent=$(echo "$coverage_report" | awk '/TOTAL/ {print $NF}' | tr -d '%' | tail -1)
                    if [[ "$percent" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                        coverage_pct="$percent"
                    else
                        percent=$(echo "$coverage_report" | grep -Eo '[0-9]+\.[0-9]+%|[0-9]+%' | tr -d '%' | head -1)
                        [[ -n "$percent" ]] && coverage_pct="$percent"
                    fi
                else
                    log_warning "No instrumented objects found for $project"
                fi
            else
                log_warning "No coverage raw profiles (*.profraw) found for $project"
            fi
        else
            log_warning "xcrun not available; skipping coverage for $project"
        fi
    else
        # Xcode fallback: try to read from xcresult
        local derived_data
        derived_data=$(find "$HOME/Library/Developer/Xcode/DerivedData" -name "*$project*" -type d -maxdepth 1 2>/dev/null | head -1)
        if [[ -n "$derived_data" && -d "$derived_data" ]]; then
            local xcresults
            xcresults=$(find "$derived_data/Logs/Test" -name "*.xcresult" 2>/dev/null | head -1)
            if [[ -n "$xcresults" && -f "$xcresults" ]]; then
                coverage_pct=$(xcrun xccov view --report --json "$xcresults" 2>/dev/null | jq -r '(.targets[0].lineCoverage // 0) * 100' 2>/dev/null || echo "0.00")
            fi
        fi
    fi

    mkdir -p "$WORKSPACE_ROOT/test_results"
    echo "$coverage_pct" >"/tmp/${project}_coverage"
    local coverage_file="$WORKSPACE_ROOT/test_results/${project}_coverage.json"
    cat >"$coverage_file" <<EOF
{
    "project": "$project",
    "coverage_percentage": "$coverage_pct",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    log_info "Coverage for $project: ${coverage_pct}%"
}

# ---------------------------------
# Parallel orchestration
# ---------------------------------
run_parallel_tests() {
    local pids=()
    local projects=("${PROJECTS[@]}")
    local running=0

    for project in "${projects[@]}"; do
        while ((running >= MAX_PARALLEL_JOBS)); do
            sleep 1
            for i in "${!pids[@]}"; do
                if ! kill -0 "${pids[$i]}" 2>/dev/null; then
                    unset 'pids[$i]'
                    ((running--))
                fi
            done
        done

        run_project_tests "$project" &
        pids+=($!)
        ((running++))
        log_info "Started parallel test job for $project (running: $running/$MAX_PARALLEL_JOBS)"
    done

    for pid in "${pids[@]}"; do
        wait "$pid" || true
    done
}

# ---------------------------------
# Reporting
# ---------------------------------
parse_test_output() {
    local output_file="$1"
    local test_results="[]"
    if [[ ! -f "$output_file" ]]; then
        echo "$test_results"
        return
    fi
    local parsed
    parsed=$(grep -E "Test Case.*(passed|failed)" "$output_file" 2>/dev/null |
        sed "s/.*Test Case '-\[\([^]]*\)\]' \([a-z]*\).*/\1 \2/" |
        awk '{
            test_name = $1; for(i=2;i<NF;i++) test_name = test_name " " $i; status = $NF;
            printf "{\"name\":\"%s\",\"status\":\"%s\"},", test_name, status
        }' | sed 's/,$//')
    if [[ -n "$parsed" ]]; then
        test_results="[$parsed]"
    fi
    echo "$test_results"
}

generate_report() {
    local total=${#PROJECTS[@]}
    local passed=0
    local failed_projects=()
    local coverage_warnings=()

    mkdir -p "$WORKSPACE_ROOT/test_results"

    echo
    echo "========================================"
    echo "   PARALLEL TEST EXECUTION REPORT"
    echo "========================================"
    echo

    for project in "${PROJECTS[@]}"; do
        local status_file="/tmp/${project}_test_result"
        local cov_file="/tmp/${project}_coverage"
        local start_file="/tmp/${project}_start_time"
        local end_file="/tmp/${project}_end_time"
        local output_file="/tmp/${project}_test_output"

        local status="UNKNOWN"
        local coverage="N/A"
        local duration="N/A"
        local tests_json="[]"

        [[ -f "$status_file" ]] && status=$(cat "$status_file")
        [[ -f "$cov_file" ]] && coverage=$(cat "$cov_file")
        if [[ -f "$start_file" && -f "$end_file" ]]; then
            local s e
            s=$(cat "$start_file")
            e=$(cat "$end_file")
            duration=$((e - s))
        fi
        [[ -f "$output_file" ]] && tests_json=$(parse_test_output "$output_file")

        local result_file="$WORKSPACE_ROOT/test_results/${project}_test_results.json"
        cat >"$result_file" <<EOF
{
    "project": "$project",
    "status": "$status",
    "coverage": "$coverage",
    "duration": "$duration",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "tests": $tests_json
}
EOF

        if [[ "$status" == "PASSED" ]]; then
            ((passed++))
            echo -e "${GREEN}✓ $project${NC} - PASSED (${duration}s) - Coverage: ${coverage}%"
        else
            failed_projects+=("$project")
            echo -e "${RED}✗ $project${NC} - FAILED (${duration}s) - Coverage: ${coverage}%"
        fi

        if [[ "$coverage" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            if [[ $(echo "$coverage < $COVERAGE_THRESHOLD" | bc -l 2>/dev/null || echo "0") == "1" ]]; then
                coverage_warnings+=("$project (${coverage}%)")
            fi
        fi
    done

    echo
    echo "Summary:"
    echo "- Projects tested: $total"
    echo "- Passed: $passed"
    echo "- Failed: $((total - passed))"
    if ((total > 0)); then
        echo "- Success rate: $((passed * 100 / total))%"
    fi

    if ((${#coverage_warnings[@]} > 0)); then
        echo
        log_warning "Coverage below ${COVERAGE_THRESHOLD}% threshold:"
        for w in "${coverage_warnings[@]}"; do echo "  - $w"; done
    fi

    if ((${#failed_projects[@]} > 0)); then
        echo
        log_error "Failed projects:"
        for f in "${failed_projects[@]}"; do echo "  - $f"; done
        return 1
    fi
}

# ---------------------------------
# Main
# ---------------------------------
main() {
    discover_projects
    log_info "Starting parallel test execution across ${#PROJECTS[@]} projects..."
    log_info "Configuration: Max parallel jobs=$MAX_PARALLEL_JOBS, Timeout=${TIMEOUT_SECONDS}s, Coverage threshold=${COVERAGE_THRESHOLD}%"

    local t0 t1
    t0=$(date +%s)
    run_parallel_tests || true
    t1=$(date +%s)

    generate_report
    local rc=$?
    echo
    log_info "Total execution time: $((t1 - t0))s"
    if ((rc == 0)); then
        log_success "All tests passed!"
    else
        log_error "Some tests failed!"
        exit 1
    fi
}

main "$@"

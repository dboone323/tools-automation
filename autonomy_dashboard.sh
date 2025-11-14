#!/bin/bash
# Autonomy Dashboard - Comprehensive System Health and Autonomy Metrics

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORTS_DIR="$WORKSPACE_ROOT/reports"
UNIFIED_TODOS_FILE="$WORKSPACE_ROOT/unified_todos.json"
PREDICTIVE_DATA_FILE="$WORKSPACE_ROOT/predictive_data.json"

# Colors for dashboard
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Dashboard symbols
CHECKMARK="✅"
CROSS="❌"
WARNING="⚠️"
INFO="ℹ️"
CHART="📊"
GEAR="⚙️"
SHIELD="🛡️"
CLOCK="⏰"

print_header() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                           AUTONOMY DASHBOARD                              ║"
    echo "║                     System Health & Self-Management                       ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${WHITE}Generated: $(date)${NC}"
    echo
}

print_section() {
    local title="$1"
    local symbol="$2"
    echo -e "${BLUE}${symbol} ${title}${NC}"
    echo -e "${BLUE}$(printf '%.0s─' {1..60})${NC}"
}

get_todo_stats() {
    if [[ ! -f "$UNIFIED_TODOS_FILE" ]]; then
        echo "0|0|0|0|0"
        return
    fi

    local total_todos
    total_todos=$(jq '.todos | length' "$UNIFIED_TODOS_FILE" 2>/dev/null || echo "0")

    local pending_todos
    pending_todos=$(jq '.todos | map(select(.status == "pending")) | length' "$UNIFIED_TODOS_FILE" 2>/dev/null || echo "0")

    local completed_todos
    completed_todos=$(jq '.todos | map(select(.status == "completed")) | length' "$UNIFIED_TODOS_FILE" 2>/dev/null || echo "0")

    local assigned_todos
    assigned_todos=$(jq '.todos | map(select(.assignee != null)) | length' "$UNIFIED_TODOS_FILE" 2>/dev/null || echo "0")

    local auto_generated
    auto_generated=$(jq '.todos | map(select(.metadata.auto_generated == true)) | length' "$UNIFIED_TODOS_FILE" 2>/dev/null || echo "0")

    echo "$total_todos|$pending_todos|$completed_todos|$assigned_todos|$auto_generated"
}

get_test_stats() {
    local latest_test_file
    latest_test_file=$(find "$REPORTS_DIR" -name "test_results_*.json" -type f -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -1 || echo "")

    if [[ -z "$latest_test_file" ]] || [[ ! -f "$latest_test_file" ]]; then
        echo "0|0|0|0"
        return
    fi

    local passed
    passed=$(jq '.summary.passed' "$latest_test_file" 2>/dev/null || echo "0")

    local failed
    failed=$(jq '.summary.failed' "$latest_test_file" 2>/dev/null || echo "0")

    local total
    total=$(jq '.summary.total' "$latest_test_file" 2>/dev/null || echo "0")

    local success_rate=0
    if [[ $total -gt 0 ]]; then
        success_rate=$((passed * 100 / total))
    fi

    echo "$passed|$failed|$total|$success_rate"
}

get_predictive_stats() {
    if [[ ! -f "$PREDICTIVE_DATA_FILE" ]]; then
        echo "0|0|0"
        return
    fi

    local predictions_count
    predictions_count=$(jq '.failure_predictions | length' "$PREDICTIVE_DATA_FILE" 2>/dev/null || echo "0")

    local high_confidence
    high_confidence=$(jq '.failure_predictions | map(select(.confidence > 0.8)) | length' "$PREDICTIVE_DATA_FILE" 2>/dev/null || echo "0")

    local healing_actions
    healing_actions=$(jq '.self_healing_actions | keys | length' "$PREDICTIVE_DATA_FILE" 2>/dev/null || echo "0")

    echo "$predictions_count|$high_confidence|$healing_actions"
}

display_todo_metrics() {
    print_section "TASK MANAGEMENT METRICS" "$GEAR"

    IFS='|' read -r total pending completed assigned auto_generated <<<"$(get_todo_stats)"

    echo -e "${WHITE}Total Tasks:${NC}         $total"
    echo -e "${WHITE}Pending Tasks:${NC}       $pending"
    echo -e "${WHITE}Completed Tasks:${NC}     $completed"
    echo -e "${WHITE}Assigned Tasks:${NC}      $assigned"
    echo -e "${WHITE}Auto-Generated:${NC}      $auto_generated"
    echo

    # Calculate rates
    local completion_rate=0
    local assignment_rate=0
    if [[ $total -gt 0 ]]; then
        completion_rate=$((completed * 100 / total))
        assignment_rate=$((assigned * 100 / total))
    fi

    echo -e "${WHITE}Completion Rate:${NC}     ${GREEN}${completion_rate}%${NC}"
    echo -e "${WHITE}Assignment Rate:${NC}     ${BLUE}${assignment_rate}%${NC}"
    echo

    # Task distribution by category
    echo -e "${WHITE}Tasks by Category:${NC}"
    if [[ -f "$UNIFIED_TODOS_FILE" ]]; then
        jq -r '.todos | group_by(.category) | map({category: .[0].category, count: length}) | sort_by(.count) | reverse | .[] | "\(.category): \(.count)"' "$UNIFIED_TODOS_FILE" 2>/dev/null | while read -r line; do
            echo -e "  ${CYAN}•${NC} $line"
        done
        # Show completion with MTTR if available
        local mttr
        mttr=$(jq -r '[.todos[] | select(.status=="completed" and .time_to_resolution_seconds!=null) | .time_to_resolution_seconds] | if length>0 then (add/length) else 0 end' "$UNIFIED_TODOS_FILE" 2>/dev/null || echo "0")
        echo -e "\n${WHITE}Mean Time To Resolution (s):${NC} $mttr"
    fi
    echo
}

display_system_health() {
    print_section "SYSTEM HEALTH STATUS" "$SHIELD"

    IFS='|' read -r passed failed total success_rate <<<"$(get_test_stats)"

    if [[ $total -gt 0 ]]; then
        echo -e "${WHITE}Test Results:${NC}        ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC} (${WHITE}${total} total${NC})"
        echo -e "${WHITE}Success Rate:${NC}        ${GREEN}${success_rate}%${NC}"

        if [[ $success_rate -ge 90 ]]; then
            echo -e "${WHITE}Health Status:${NC}       ${GREEN}${CHECKMARK} EXCELLENT${NC}"
        elif [[ $success_rate -ge 75 ]]; then
            echo -e "${WHITE}Health Status:${NC}       ${YELLOW}${WARNING} GOOD${NC}"
        else
            echo -e "${WHITE}Health Status:${NC}       ${RED}${CROSS} NEEDS ATTENTION${NC}"
        fi
    else
        echo -e "${WHITE}Test Results:${NC}        ${YELLOW}No recent tests found${NC}"
        echo -e "${WHITE}Health Status:${NC}       ${YELLOW}${WARNING} UNKNOWN${NC}"
    fi
    echo

    # System resource checks
    echo -e "${WHITE}System Resources:${NC}"

    # Disk space
    local disk_usage
    disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disk_usage -lt 80 ]]; then
        echo -e "  ${GREEN}${CHECKMARK}${NC} Disk Space: ${disk_usage}% used"
    elif [[ $disk_usage -lt 95 ]]; then
        echo -e "  ${YELLOW}${WARNING}${NC} Disk Space: ${disk_usage}% used"
    else
        echo -e "  ${RED}${CROSS}${NC} Disk Space: ${disk_usage}% used (CRITICAL)"
    fi

    # Memory (simplified check)
    local mem_usage
    mem_usage=$(vm_stat | grep "Pages active" | awk '{print $3}' | tr -d '.' 2>/dev/null || echo "0")
    if [[ $mem_usage -lt 1000000 ]]; then # Rough threshold
        echo -e "  ${GREEN}${CHECKMARK}${NC} Memory: Normal usage"
    else
        echo -e "  ${YELLOW}${WARNING}${NC} Memory: High usage detected"
    fi

    # Network connectivity
    if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        echo -e "  ${GREEN}${CHECKMARK}${NC} Network: Connected"
    else
        echo -e "  ${RED}${CROSS}${NC} Network: Disconnected"
    fi

    echo
}

display_predictive_analytics() {
    print_section "PREDICTIVE ANALYTICS" "$CHART"

    IFS='|' read -r predictions high_confidence healing_actions <<<"$(get_predictive_stats)"

    echo -e "${WHITE}Active Predictions:${NC}   $predictions"
    echo -e "${WHITE}High Confidence:${NC}      ${RED}$high_confidence${NC}"
    echo -e "${WHITE}Self-Healing Actions:${NC} $healing_actions"
    echo

    # Show recent predictions
    if [[ -f "$PREDICTIVE_DATA_FILE" ]] && [[ $predictions -gt 0 ]]; then
        echo -e "${WHITE}Recent Predictions:${NC}"
        jq -r '.failure_predictions[] | "  \(.component): \(.prediction) (\(.confidence * 100 | floor)%)"' "$PREDICTIVE_DATA_FILE" 2>/dev/null | head -3 | while read -r line; do
            echo -e "${YELLOW}${WARNING}${NC} $line"
        done
        echo
    fi

    # Show recent healing actions
    if [[ -f "$PREDICTIVE_DATA_FILE" ]] && [[ $healing_actions -gt 0 ]]; then
        echo -e "${WHITE}Recent Self-Healing:${NC}"
        jq -r '.self_healing_actions | to_entries | sort_by(.key) | reverse | .[0:3][] | .value[]' "$PREDICTIVE_DATA_FILE" 2>/dev/null | head -3 | while read -r line; do
            if [[ $line == *"Successfully"* ]] || [[ $line == *"verified"* ]]; then
                echo -e "  ${GREEN}${CHECKMARK}${NC} $line"
            else
                echo -e "  ${YELLOW}${INFO}${NC} $line"
            fi
        done
        echo
    fi

    # ML risk scores (patterns & components)
    if [[ -f "$PREDICTIVE_DATA_FILE" ]]; then
        local pattern_count
        pattern_count=$(jq '.ml_risk_scores.pattern_risk_scores | length' "$PREDICTIVE_DATA_FILE" 2>/dev/null || echo "0")
        if [[ "$pattern_count" -gt 0 ]]; then
            echo -e "${WHITE}Top Risk Patterns:${NC}"
            jq -r '.ml_risk_scores.pattern_risk_scores | to_entries | sort_by(.value) | reverse | .[0:5] | .[] | "  \(.key): \(.value * 100 | floor)%"' "$PREDICTIVE_DATA_FILE" 2>/dev/null | while read -r line; do
                echo -e "${RED}🔥${NC} $line"
            done
            echo
        fi
        local comp_count
        comp_count=$(jq '.ml_risk_scores.component_risk_scores | length' "$PREDICTIVE_DATA_FILE" 2>/dev/null || echo "0")
        if [[ "$comp_count" -gt 0 ]]; then
            echo -e "${WHITE}Component Risk Scores:${NC}"
            jq -r '.ml_risk_scores.component_risk_scores | to_entries | sort_by(.value) | reverse | .[] | "  \(.key): \(.value * 100 | floor)%"' "$PREDICTIVE_DATA_FILE" 2>/dev/null | while read -r line; do
                echo -e "${PURPLE}⚙️${NC} $line"
            done
            echo
        fi
    fi
}

display_autonomy_score() {
    print_section "AUTONOMY SCORE" "$CLOCK"

    # Calculate autonomy score based on various metrics
    local autonomy_score=0
    local max_score=100

    # Todo management (30 points)
    IFS='|' read -r total pending completed assigned auto_generated <<<"$(get_todo_stats)"
    if [[ $total -gt 0 ]]; then
        local completion_rate=$((completed * 100 / total))
        local assignment_rate=$((assigned * 100 / total))
        local auto_rate=$((auto_generated * 100 / total))
        autonomy_score=$((autonomy_score + (completion_rate * 10 / 100)))
        autonomy_score=$((autonomy_score + (assignment_rate * 10 / 100)))
        autonomy_score=$((autonomy_score + (auto_rate * 10 / 100)))
    fi

    # System health (30 points)
    IFS='|' read -r passed failed total success_rate <<<"$(get_test_stats)"
    if [[ $total -gt 0 ]]; then
        autonomy_score=$((autonomy_score + (success_rate * 30 / 100)))
    fi

    # Predictive capabilities (25 points)
    IFS='|' read -r predictions high_confidence healing_actions <<<"$(get_predictive_stats)"
    autonomy_score=$((autonomy_score + (predictions * 5)))
    autonomy_score=$((autonomy_score + (high_confidence * 10)))
    autonomy_score=$((autonomy_score + (healing_actions * 10)))

    # Cap at 100
    if [[ $autonomy_score -gt 100 ]]; then
        autonomy_score=100
    fi

    # Display score with color coding
    if [[ $autonomy_score -ge 80 ]]; then
        echo -e "${WHITE}Overall Autonomy Score:${NC} ${GREEN}$autonomy_score/100${NC} ${CHECKMARK}"
        echo -e "${GREEN}Status: HIGH AUTONOMY - System is largely self-managing${NC}"
    elif [[ $autonomy_score -ge 60 ]]; then
        echo -e "${WHITE}Overall Autonomy Score:${NC} ${YELLOW}$autonomy_score/100${NC} ${WARNING}"
        echo -e "${YELLOW}Status: MODERATE AUTONOMY - Good progress, room for improvement${NC}"
    elif [[ $autonomy_score -ge 40 ]]; then
        echo -e "${WHITE}Overall Autonomy Score:${NC} ${BLUE}$autonomy_score/100${NC} ${INFO}"
        echo -e "${BLUE}Status: DEVELOPING AUTONOMY - Building autonomous capabilities${NC}"
    else
        echo -e "${WHITE}Overall Autonomy Score:${NC} ${RED}$autonomy_score/100${NC} ${CROSS}"
        echo -e "${RED}Status: LOW AUTONOMY - Manual intervention frequently required${NC}"
    fi

    echo
    echo -e "${WHITE}Score Breakdown:${NC}"
    local todo_score=0
    local health_score=0
    local predictive_score=0
    local mttr_val
    mttr_val=$(jq -r '[.todos[] | select(.status=="completed" and .time_to_resolution_seconds!=null) | .time_to_resolution_seconds] | if length>0 then (add/length) else 0 end' "$UNIFIED_TODOS_FILE" 2>/dev/null || echo "0")

    if [[ $total -gt 0 ]]; then
        local completion_rate=$((completed * 100 / total))
        local assignment_rate=$((assigned * 100 / total))
        local auto_rate=$((auto_generated * 100 / total))
        todo_score=$(((completion_rate * 10 / 100) + (assignment_rate * 10 / 100) + (auto_rate * 10 / 100)))
    fi

    IFS='|' read -r passed failed total_tests success_rate <<<"$(get_test_stats)"
    if [[ $total_tests -gt 0 ]]; then
        health_score=$((success_rate * 30 / 100))
    fi

    IFS='|' read -r predictions high_confidence healing_actions <<<"$(get_predictive_stats)"
    predictive_score=$((predictions * 5 + high_confidence * 10 + healing_actions * 10))

    echo -e "  • Task Management:     $todo_score/30 points"
    echo -e "  • System Health:       $health_score/30 points"
    echo -e "  • Predictive Analytics: $predictive_score/25 points"
    # Display MTTR if computed (value may be float string)
    if [[ "$mttr_val" != "0" && -n "$mttr_val" ]]; then
        printf "  • MTTR: %.2fs (lower is better)\n" "$mttr_val"
    fi
    echo
}

display_recent_activity() {
    print_section "RECENT ACTIVITY" "$INFO"

    echo -e "${WHITE}Latest Reports:${NC}"

    # Show recent reports
    find "$REPORTS_DIR" -name "*.md" -type f -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -5 | while read -r file; do
        local report_name
        report_name=$(basename "$file")
        local report_time
        report_time=$(stat -f "%Sm" -t "%H:%M:%S" "$file" 2>/dev/null || date -r "$file" '+%H:%M:%S' 2>/dev/null || echo "Unknown")
        echo -e "  ${CYAN}•${NC} $report_name (${report_time})"
    done

    echo
    echo -e "${WHITE}Active Agents:${NC}"

    # Show agent status from todos
    if [[ -f "$UNIFIED_TODOS_FILE" ]]; then
        jq -r '.todos | map(select(.assignee != null)) | group_by(.assignee) | map({agent: .[0].assignee, tasks: length}) | sort_by(.tasks) | reverse | .[] | "\(.agent): \(.tasks) active tasks"' "$UNIFIED_TODOS_FILE" 2>/dev/null | while read -r line; do
            echo -e "  ${PURPLE}🤖${NC} $line"
        done
    fi

    echo
}

main() {
    print_header
    display_todo_metrics
    display_system_health
    display_predictive_analytics
    display_autonomy_score
    display_recent_activity

    echo -e "${CYAN}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "                            Dashboard Complete                             "
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${NC}"
}

# Run main if script is called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

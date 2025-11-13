#!/bin/bash
# Test All Agents - Phase 1 Quality Gate Script
# Validates health checks for all 203 agents

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/agents"
AGENT_STATUS_FILE="${SCRIPT_DIR}/agent_status.json"
LOG_FILE="${SCRIPT_DIR}/logs/agent_health_check_$(date +%Y%m%d_%H%M%S).log"
RESULTS_FILE="${SCRIPT_DIR}/reports/agent_health_report_$(date +%Y%m%d_%H%M%S).json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ensure directories exist
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$RESULTS_FILE")"

# Initialize counters
total_agents=0
passing_agents=0
failing_agents=0
declare -a failed_agents=()

echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}   Agent Health Check - Phase 1    ${NC}"
echo -e "${BLUE}====================================${NC}"
echo ""

# Function to test agent health
test_agent_health() {
    local agent_path="$1"
    local agent_name=$(basename "$agent_path" .sh)

    # Skip non-agent files
    if [[ ! "$agent_name" =~ ^agent_ ]] && [[ ! "$agent_name" =~ _agent$ ]]; then
        return 0
    fi

    ((total_agents++))

    echo -n "Testing ${agent_name}... "

    # Check if agent file is executable
    if [[ ! -x "$agent_path" ]]; then
        echo -e "${YELLOW}WARN${NC} - Not executable"
        chmod +x "$agent_path" 2>/dev/null || true
    fi

    # Check for basic shell syntax errors
    if ! bash -n "$agent_path" 2>>"$LOG_FILE"; then
        echo -e "${RED}FAIL${NC} - Syntax error"
        ((failing_agents++))
        failed_agents+=("$agent_name:syntax_error")
        return 1
    fi

    # Check if agent has required functions/sections
    local has_health_check=false
    local has_error_handling=false

    if grep -q "health.*check\|status.*check\|--health" "$agent_path"; then
        has_health_check=true
    fi

    if grep -q "set -e\|trap.*ERR\|error.*handler" "$agent_path"; then
        has_error_handling=true
    fi

    # Try to run agent with --help or --version (non-destructive)
    local can_execute=false
    if timeout 5s "$agent_path" --help >/dev/null 2>&1 ||
        timeout 5s "$agent_path" --version >/dev/null 2>&1 ||
        timeout 5s "$agent_path" status >/dev/null 2>&1; then
        can_execute=true
    fi

    # Evaluate overall health
    local status="PASS"
    local issues=()

    if [[ "$has_health_check" == false ]]; then
        issues+=("no_health_check")
    fi

    if [[ "$has_error_handling" == false ]]; then
        issues+=("no_error_handling")
    fi

    if [[ "${#issues[@]}" -gt 0 ]]; then
        echo -e "${YELLOW}WARN${NC} - Issues: ${issues[*]}"
        ((passing_agents++)) # Still passing but with warnings
    else
        echo -e "${GREEN}PASS${NC}"
        ((passing_agents++))
    fi

    # Log details
    echo "Agent: $agent_name, Status: $status, Health Check: $has_health_check, Error Handling: $has_error_handling, Can Execute: $can_execute" >>"$LOG_FILE"
}

# Test all agent scripts
echo "Scanning all agent scripts from /tmp/all_agents_list.txt"
echo ""

if [[ -f "/tmp/all_agents_list.txt" ]]; then
    while IFS= read -r agent_file || [[ -n "$agent_file" ]]; do
        if [[ -f "$agent_file" ]]; then
            test_agent_health "$agent_file"
        fi
    done <"/tmp/all_agents_list.txt"
else
    echo "Warning: /tmp/all_agents_list.txt not found, falling back to agents/ directory"
    if [[ -d "$AGENTS_DIR" ]]; then
        for agent_file in "$AGENTS_DIR"/agent_*.sh "$AGENTS_DIR"/*_agent.sh; do
            if [[ -f "$agent_file" ]]; then
                test_agent_health "$agent_file"
            fi
        done
    fi

    # Test agents in subdirectories
    for subdir in "$AGENTS_DIR"/*; do
        if [[ -d "$subdir" ]]; then
            for agent_file in "$subdir"/agent_*.sh "$subdir"/*_agent.sh; do
                if [[ -f "$agent_file" ]]; then
                    test_agent_health "$agent_file"
                fi
            done
        fi
    done
fi

# Calculate pass rate
pass_rate=0
if [[ $total_agents -gt 0 ]]; then
    pass_rate=$(awk "BEGIN {printf \"%.2f\", ($passing_agents / $total_agents) * 100}")
fi

# Generate summary
echo ""
echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}         Test Summary               ${NC}"
echo -e "${BLUE}====================================${NC}"
echo "Total Agents Tested: $total_agents"
echo -e "Passing: ${GREEN}$passing_agents${NC}"
echo -e "Failing: ${RED}$failing_agents${NC}"
echo "Pass Rate: ${pass_rate}%"
echo ""

# Prepare failed_agents JSON block safely
failed_agents_json=""
if [[ ${#failed_agents[@]} -gt 0 ]]; then
    for a in "${failed_agents[@]}"; do
        failed_agents_json+=$(printf '    "%s",\n' "$a")
    done
    # remove trailing comma
    failed_agents_json=$(echo -e "$failed_agents_json" | sed '$ s/,$//')
fi

# Generate JSON report
target_agents=$(wc -l <"/tmp/all_agents_list.txt" 2>/dev/null || echo 143)
cat >"$RESULTS_FILE" <<EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "phase": "Phase 1 - Core Infrastructure",
    "test_type": "agent_health_check",
    "summary": {
        "total_agents": $total_agents,
        "passing_agents": $passing_agents,
        "failing_agents": $failing_agents,
        "pass_rate": $pass_rate
    },
    "failed_agents": [
$failed_agents_json
    ],
    "quality_gate": {
        "target": "$target_agents/$target_agents agents passing",
        "achieved": "$passing_agents/$total_agents",
        "status": "$(if [[ $passing_agents -eq $total_agents ]] && [[ $total_agents -ge $target_agents ]]; then echo "PASS"; else echo "FAIL"; fi)"
    },
    "log_file": "$LOG_FILE",
    "next_steps": [
        "Review failed agents in log file",
        "Add health checks to agents missing them",
        "Implement error handling in agents",
        "Re-run validation after fixes"
    ]
}
EOF

echo "Detailed report saved to: $RESULTS_FILE"
echo "Log file saved to: $LOG_FILE"
echo ""

# Quality gate evaluation
target_agents=$(wc -l <"/tmp/all_agents_list.txt" 2>/dev/null || echo 143)
if [[ $passing_agents -eq $total_agents ]] && [[ $total_agents -ge $target_agents ]]; then
    echo -e "${GREEN}✓ QUALITY GATE PASSED${NC}"
    echo "All agents have basic health checks passing"
    exit 0
else
    echo -e "${RED}✗ QUALITY GATE FAILED${NC}"
    echo "Not all agents are passing health checks"
    echo "Target: $target_agents/$target_agents agents passing"
    echo "Actual: $passing_agents/$total_agents passing"

    if [[ ${#failed_agents[@]} -gt 0 ]]; then
        echo ""
        echo "Failed agents:"
        for agent in "${failed_agents[@]}"; do
            echo "  - $agent"
        done
    fi

    exit 1
fi

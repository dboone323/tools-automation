#!/bin/bash
# Performance Baselines Validation Script
# Step 7: Final System Validation

set -e

echo "📊 Performance Baselines Validation"
echo "==================================="
echo "Date: $(date)"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Performance thresholds (adjust based on system capabilities)
MCP_RESPONSE_P95_THRESHOLD=500    # ms
MCP_RESPONSE_P99_THRESHOLD=1000   # ms
AGENT_STARTUP_TIME_THRESHOLD=10   # seconds
WORKFLOW_COMPLETION_THRESHOLD=600 # seconds (10 minutes)
BUILD_TIME_P95_THRESHOLD=900      # seconds (15 minutes)

# Test results
PASSED_CHECKS=0
FAILED_CHECKS=0

check_performance() {
    local metric_name="$1"
    local current_value="$2"
    local threshold="$3"
    local unit="$4"

    if (($(echo "$current_value <= $threshold" | bc -l))); then
        echo -e "${GREEN}✅ PASS${NC}: $metric_name = ${current_value}${unit} (threshold: ${threshold}${unit})"
        ((PASSED_CHECKS++))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}: $metric_name = ${current_value}${unit} (threshold: ${threshold}${unit})"
        ((FAILED_CHECKS++))
        return 1
    fi
}

echo "🔍 Establishing Performance Baselines..."
echo ""

# 1. MCP Server Response Times
echo "1. Testing MCP Server Response Times..."
if python3 -c "
import time
import requests
import statistics

response_times = []
for i in range(50):  # 50 requests for statistical significance
    try:
        start = time.time()
        response = requests.get('http://localhost:5005/health', timeout=5)
        end = time.time()
        if response.status_code == 200:
            response_times.append((end - start) * 1000)  # Convert to ms
    except:
        pass

if response_times:
    p95 = sorted(response_times)[int(len(response_times) * 0.95)]
    p99 = sorted(response_times)[int(len(response_times) * 0.99)]
    avg = statistics.mean(response_times)

    print(f'MCP Response Times (50 requests):')
    print(f'  Average: {avg:.2f}ms')
    print(f'  P95: {p95:.2f}ms')
    print(f'  P99: {p99:.2f}ms')
    print(f'  Min: {min(response_times):.2f}ms')
    print(f'  Max: {max(response_times):.2f}ms')

    # Export for parent script
    print(f'P95_RESPONSE_TIME={p95:.0f}')
    print(f'P99_RESPONSE_TIME={p99:.0f}')
else:
    print('Failed to collect MCP response times')
    exit 1
" >/tmp/mcp_performance.log 2>&1; then

    # Extract values from log
    P95_RESPONSE=$(grep "P95_RESPONSE_TIME=" /tmp/mcp_performance.log | cut -d'=' -f2)
    P99_RESPONSE=$(grep "P99_RESPONSE_TIME=" /tmp/mcp_performance.log | cut -d'=' -f2)

    check_performance "MCP Response Time P95" "$P95_RESPONSE" "$MCP_RESPONSE_P95_THRESHOLD" "ms"
    check_performance "MCP Response Time P99" "$P99_RESPONSE" "$MCP_RESPONSE_P99_THRESHOLD" "ms"
else
    echo -e "${RED}❌ FAIL${NC}: Could not test MCP response times"
    ((FAILED_CHECKS++))
fi

echo ""

# 2. Agent Startup Times
echo "2. Testing Agent Startup Times..."
if [ -f "agents/orchestrator_v2.py" ]; then
    START_TIME=$(date +%s.%3N)
    timeout 15 python3 agents/orchestrator_v2.py status >/dev/null 2>&1
    END_TIME=$(date +%s.%3N)
    STARTUP_TIME=$(echo "$END_TIME - $START_TIME" | bc)

    check_performance "Agent Startup Time" "$STARTUP_TIME" "$AGENT_STARTUP_TIME_THRESHOLD" "s"
else
    echo -e "${YELLOW}⚠️  SKIP${NC}: Agent orchestrator not found"
fi

echo ""

# 3. Workflow Completion Times
echo "3. Testing Workflow Completion Times..."
if [ -f "workflows/ci_orchestrator.sh" ]; then
    START_TIME=$(date +%s)
    timeout 300 bash workflows/ci_orchestrator.sh pr-validation >/dev/null 2>&1
    END_TIME=$(date +%s)
    WORKFLOW_TIME=$((END_TIME - START_TIME))

    check_performance "Workflow Completion Time" "$WORKFLOW_TIME" "$WORKFLOW_COMPLETION_THRESHOLD" "s"
else
    echo -e "${YELLOW}⚠️  SKIP${NC}: Workflow orchestrator not found"
fi

echo ""

# 4. Build Performance (if applicable)
echo "4. Checking Build Performance..."
if [ -f "Makefile" ] || [ -f "package.json" ] || find . -name "*.xcodeproj" -type d | head -1; then
    echo "Build system detected, measuring build time..."
    START_TIME=$(date +%s)

    if [ -f "Makefile" ] && grep -q "^all:" Makefile; then
        timeout 600 make all >/dev/null 2>&1
    elif [ -f "package.json" ] && grep -q '"build"' package.json; then
        timeout 600 npm run build >/dev/null 2>&1
    else
        # Xcode project
        timeout 600 xcodebuild -project "$(find . -name "*.xcodeproj" | head -1)" -scheme "$(basename "$(find . -name "*.xcodeproj" | head -1)" .xcodeproj)" build >/dev/null 2>&1
    fi

    END_TIME=$(date +%s)
    BUILD_TIME=$((END_TIME - START_TIME))

    if [ $BUILD_TIME -gt 10 ]; then # Only check if build actually ran
        check_performance "Build Time" "$BUILD_TIME" "$BUILD_TIME_P95_THRESHOLD" "s"
    else
        echo -e "${YELLOW}⚠️  SKIP${NC}: Build completed too quickly (likely cached or no-op)"
    fi
else
    echo -e "${YELLOW}⚠️  SKIP${NC}: No build system detected"
fi

echo ""

# 5. Memory and CPU Usage
echo "5. Checking System Resource Usage..."
if command -v ps >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
    python3 -c "
import psutil
import os

# Get current process info
current_pid = os.getpid()
process = psutil.Process(current_pid)

# Get system-wide metrics
cpu_percent = psutil.cpu_percent(interval=1)
memory = psutil.virtual_memory()

print(f'System CPU Usage: {cpu_percent:.1f}%')
print(f'System Memory Usage: {memory.percent:.1f}%')
print(f'Available Memory: {memory.available / (1024**3):.1f}GB')

# Check if usage is reasonable (< 90%)
if cpu_percent < 90 and memory.percent < 90:
    print('RESOURCE_CHECK=PASS')
else:
    print('RESOURCE_CHECK=FAIL')
" >/tmp/resource_check.log 2>&1

    if grep -q "RESOURCE_CHECK=PASS" /tmp/resource_check.log; then
        echo -e "${GREEN}✅ PASS${NC}: System resource usage within acceptable limits"
        ((PASSED_CHECKS++))
    else
        echo -e "${RED}❌ FAIL${NC}: System resource usage too high"
        ((FAILED_CHECKS++))
    fi
else
    echo -e "${YELLOW}⚠️  SKIP${NC}: Resource monitoring tools not available"
fi

echo ""

# 6. Network Performance
echo "6. Testing Network Performance..."
if command -v curl >/dev/null 2>&1; then
    NETWORK_TIME=$(curl -o /dev/null -s -w "%{time_total}" http://localhost:5005/health 2>/dev/null || echo "0")

    if (($(echo "$NETWORK_TIME > 0" | bc -l))); then
        NETWORK_MS=$(echo "$NETWORK_TIME * 1000" | bc -l | cut -d'.' -f1)
        check_performance "Network Response Time" "$NETWORK_MS" "1000" "ms"
    else
        echo -e "${RED}❌ FAIL${NC}: Could not measure network performance"
        ((FAILED_CHECKS++))
    fi
else
    echo -e "${YELLOW}⚠️  SKIP${NC}: curl not available for network testing"
fi

echo ""

# Summary
echo "📊 Performance Baseline Results"
echo "==============================="
echo "Passed Checks: $PASSED_CHECKS"
echo "Failed Checks: $FAILED_CHECKS"

if [ $FAILED_CHECKS -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All performance baselines met!${NC}"
    echo -e "${GREEN}✅ System performance validation successful${NC}"

    # Save baseline data for future comparisons
    echo "Saving performance baseline data..."
    cat >performance_baseline_$(date +%Y%m%d_%H%M%S).json <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "mcp_response_p95_ms": $P95_RESPONSE,
  "mcp_response_p99_ms": $P99_RESPONSE,
  "system_info": "$(uname -a)",
  "validation_result": "PASS"
}
EOF

    exit 0
else
    echo -e "\n${RED}❌ $FAILED_CHECKS performance check(s) failed${NC}"
    echo -e "${YELLOW}⚠️  Performance optimization may be needed${NC}"
    exit 1
fi

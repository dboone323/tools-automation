#!/bin/bash
CPU_USAGE=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//')
CPU_CORES=$(sysctl -n hw.ncpu)
MEM_TOTAL=$(echo "$(sysctl -n hw.memsize) / 1024 / 1024 / 1024" | bc)
MEM_USED=$(ps -A -o rss= | awk '{sum+=$1} END {print sum/1024/1024}')
DISK_USAGE=$(df -h "$PWD" | tail -1 | awk '{print $5}' | sed 's/%//')
NETWORK_CHECK=$(curl -s --max-time 5 http://httpbin.org/ip >/dev/null && echo "OK" || echo "FAIL")

echo "Raw values:"
echo "CPU_USAGE: '$CPU_USAGE'"
echo "CPU_CORES: '$CPU_CORES'"
echo "MEM_TOTAL: '$MEM_TOTAL'"
echo "MEM_USED: '$MEM_USED'"
echo "DISK_USAGE: '$DISK_USAGE'"
echo "NETWORK_CHECK: '$NETWORK_CHECK'"

echo ""
echo "Generated JSON:"
cat <<JSON_EOF
{
    "cpu_usage_percent": $CPU_USAGE,
    "cpu_cores": $CPU_CORES,
    "memory_total_gb": $MEM_TOTAL,
    "memory_used_gb": $MEM_USED,
    "disk_usage_percent": $DISK_USAGE,
    "network_connectivity": "$NETWORK_CHECK"
}
JSON_EOF

echo ""
echo "Testing jq parsing:"
cat <<JSON_EOF | jq . 2>&1 || echo "jq failed"
{
    "cpu_usage_percent": $CPU_USAGE,
    "cpu_cores": $CPU_CORES,
    "memory_total_gb": $MEM_TOTAL,
    "memory_used_gb": $MEM_USED,
    "disk_usage_percent": $DISK_USAGE,
    "network_connectivity": "$NETWORK_CHECK"
}
JSON_EOF

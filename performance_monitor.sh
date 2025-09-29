#!/bin/bash

# Performance Monitoring Script
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MONITOR_LOG="${ROOT_DIR}/Tools/Automation/logs/performance.log"
ALERT_THRESHOLD=300

echo "📊 Performance Report - $(date)"
echo "================================"

# Check recent performance
if [[ -f ${MONITOR_LOG} ]]; then
  echo "Recent operations:"
  tail -10 "${MONITOR_LOG}" | while IFS='|' read -r _timestamp operation duration _epoch; do
    if [[ ${duration} -gt ${ALERT_THRESHOLD} ]]; then
      echo "⚠️  Slow operation '${operation}' took ${duration}s"
    else
      echo "✅ ${operation}: ${duration}s"
    fi
  done
else
  echo "No performance data available yet"
fi

echo ""
echo "💡 Optimization Tips:"
echo "   - Use 'make clean' before major builds"
echo "   - Enable Xcode's new build system"
echo "   - Use Swift Package Manager for dependencies"
echo "   - Enable build caching in Xcode"

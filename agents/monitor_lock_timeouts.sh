#!/bin/bash
# Monitor file lock timeouts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

echo "Lock Timeout Monitoring"
echo "======================="
echo ""

total_timeouts=$(get_lock_timeout_count | tr -d '\n')
echo "Total lock timeouts: $total_timeouts"
echo ""

if [[ $total_timeouts -gt 0 ]]; then
  echo "Recent timeouts (last 10):"
  echo "-------------------------"
  get_recent_lock_timeouts 10
  echo ""

  if [[ $total_timeouts -gt 100 ]]; then
    echo "WARNING: High number of lock timeouts detected!"
    echo "Consider investigating agent concurrency issues."
  fi
fi

# Clean old logs (older than 7 days)
clear_old_lock_logs 7
echo "✓ Cleaned old lock timeout logs (>7 days)"

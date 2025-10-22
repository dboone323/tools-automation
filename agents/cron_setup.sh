#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"
# Cron Setup Script for Agent Health Monitoring
# Generated: October 6, 2025
# Purpose: Install cron jobs for automated health checks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "# Agent Health Monitoring Cron Jobs"
echo "# Installed: $(date)"
echo ""

# Preserve existing crontab
crontab -l 2>/dev/null | grep -v "# Agent Health Monitoring" | grep -v "agent_analytics.sh" | grep -v "health_check.sh" | grep -v "monitor_lock_timeouts.sh"

echo ""
echo "# Health checks every hour"
echo "0 * * * * cd ${SCRIPT_DIR} && ./health_check.sh >> /tmp/health_check_cron.log 2>&1"
echo ""
echo "# Lock timeout monitoring every 6 hours"
echo "0 */6 * * * cd ${SCRIPT_DIR} && ./monitor_lock_timeouts.sh >> /tmp/lock_monitor_cron.log 2>&1"
echo ""
echo "# Analytics generation daily at 2 AM"
echo "0 2 * * * cd ${SCRIPT_DIR} && ./agent_analytics.sh > .metrics/reports/analytics_\$(date +\%Y\%m\%d_\%H\%M\%S).json 2>> /tmp/analytics_cron.log"

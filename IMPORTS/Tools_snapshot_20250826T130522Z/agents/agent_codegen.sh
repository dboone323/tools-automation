#!/bin/bash
# CodeGen/Fix Agent: Triggers code generation and auto-fix routines

AGENT_NAME="CodeGenAgent"
LOG_FILE="/Users/danielstevens/Desktop/Code/Tools/Automation/agents/codegen_agent.log"
PROJECT="CodingReviewer"

SLEEP_INTERVAL=900 # Start with 15 minutes
MIN_INTERVAL=60
MAX_INTERVAL=1800

while true; do
	echo "[$(date)] $AGENT_NAME: Running codegen and fix routines..." >>"$LOG_FILE"
	echo "[$(date)] $AGENT_NAME: Creating backup before codegen/fix..." >>"$LOG_FILE"
	echo "[$(date)] $AGENT_NAME: Creating multi-level backup before codegen/enhancement..." >>"$LOG_FILE"
	/Users/danielstevens/Desktop/Code/Tools/Automation/agents/backup_manager.sh backup CodingReviewer >>"$LOG_FILE" 2>&1 || true
	/Users/danielstevens/Desktop/Code/Projects/CodingReviewer/Tools/Automation/automate.sh ai >>"$LOG_FILE" 2>&1
	/Users/danielstevens/Desktop/Code/Projects/CodingReviewer/Tools/Automation/mcp_workflow.sh autofix CodingReviewer >>"$LOG_FILE" 2>&1
	echo "[$(date)] $AGENT_NAME: Running AI enhancement analysis..." >>"$LOG_FILE"
	/Users/danielstevens/Desktop/Code/Projects/CodingReviewer/Tools/Automation/ai_enhancement_system.sh analyze CodingReviewer >>"$LOG_FILE" 2>&1
	echo "[$(date)] $AGENT_NAME: Auto-applying safe AI enhancements..." >>"$LOG_FILE"
	/Users/danielstevens/Desktop/Code/Projects/CodingReviewer/Tools/Automation/ai_enhancement_system.sh auto-apply CodingReviewer >>"$LOG_FILE" 2>&1
	echo "[$(date)] $AGENT_NAME: Validating codegen, fixes, and enhancements..." >>"$LOG_FILE"
	/Users/danielstevens/Desktop/Code/Tools/Automation/intelligent_autofix.sh validate CodingReviewer >>"$LOG_FILE" 2>&1
	echo "[$(date)] $AGENT_NAME: Running automated tests after codegen/enhancement..." >>"$LOG_FILE"
	/Users/danielstevens/Desktop/Code/Projects/CodingReviewer/Tools/Automation/automate.sh test >>"$LOG_FILE" 2>&1
	if tail -40 "$LOG_FILE" | grep -q 'ROLLBACK'; then
		echo "[$(date)] $AGENT_NAME: Rollback detected after validation. Investigate issues." >>"$LOG_FILE"
		SLEEP_INTERVAL=$((SLEEP_INTERVAL / 2))
		if [[ $SLEEP_INTERVAL -lt $MIN_INTERVAL ]]; then SLEEP_INTERVAL=$MIN_INTERVAL; fi
	elif tail -40 "$LOG_FILE" | grep -q 'error'; then
		echo "[$(date)] $AGENT_NAME: Test failure detected, restoring last backup..." >>"$LOG_FILE"
		/Users/danielstevens/Desktop/Code/Tools/Automation/agents/backup_manager.sh restore CodingReviewer >>"$LOG_FILE" 2>&1
		SLEEP_INTERVAL=$((SLEEP_INTERVAL / 2))
		if [[ $SLEEP_INTERVAL -lt $MIN_INTERVAL ]]; then SLEEP_INTERVAL=$MIN_INTERVAL; fi
	else
		echo "[$(date)] $AGENT_NAME: Codegen, enhancement, validation, and tests completed successfully." >>"$LOG_FILE"
		SLEEP_INTERVAL=$((SLEEP_INTERVAL + 60))
		if [[ $SLEEP_INTERVAL -gt $MAX_INTERVAL ]]; then SLEEP_INTERVAL=$MAX_INTERVAL; fi
	fi
	sleep 900 # Check every 15 minutes
done

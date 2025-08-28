#!/bin/bash
# Build Agent: Watches for changes and triggers builds automatically

AGENT_NAME="BuildAgent"
LOG_FILE="/Users/danielstevens/Desktop/Code/Tools/Automation/agents/build_agent.log"
PROJECT="CodingReviewer"

SLEEP_INTERVAL=300 # Start with 5 minutes
MIN_INTERVAL=60
MAX_INTERVAL=1800

while true; do
	echo "[$(date)] $AGENT_NAME: Checking for build trigger..." >>"$LOG_FILE"
	# Trigger build if ENABLE_AUTO_BUILD is true
	if grep -q 'ENABLE_AUTO_BUILD=true' "/Users/danielstevens/Desktop/Code/Projects/CodingReviewer/Tools/Automation/project_config.sh"; then
		echo "[$(date)] $AGENT_NAME: Creating multi-level backup before build..." >>"$LOG_FILE"
		/Users/danielstevens/Desktop/Code/Tools/Automation/agents/backup_manager.sh backup CodingReviewer >>"$LOG_FILE" 2>&1 || true
		echo "[$(date)] $AGENT_NAME: Running build..." >>"$LOG_FILE"
		/Users/danielstevens/Desktop/Code/Projects/CodingReviewer/Tools/Automation/automate.sh build >>"$LOG_FILE" 2>&1
		echo "[$(date)] $AGENT_NAME: Running AI enhancement analysis..." >>"$LOG_FILE"
		/Users/danielstevens/Desktop/Code/Projects/CodingReviewer/Tools/Automation/ai_enhancement_system.sh analyze CodingReviewer >>"$LOG_FILE" 2>&1
		echo "[$(date)] $AGENT_NAME: Auto-applying safe AI enhancements..." >>"$LOG_FILE"
		/Users/danielstevens/Desktop/Code/Projects/CodingReviewer/Tools/Automation/ai_enhancement_system.sh auto-apply CodingReviewer >>"$LOG_FILE" 2>&1
		echo "[$(date)] $AGENT_NAME: Validating build and enhancements..." >>"$LOG_FILE"
		/Users/danielstevens/Desktop/Code/Tools/Automation/intelligent_autofix.sh validate CodingReviewer >>"$LOG_FILE" 2>&1
		echo "[$(date)] $AGENT_NAME: Running automated tests after build and enhancements..." >>"$LOG_FILE"
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
			echo "[$(date)] $AGENT_NAME: Build, AI enhancement, validation, and tests completed successfully." >>"$LOG_FILE"
			SLEEP_INTERVAL=$((SLEEP_INTERVAL + 60))
			if [[ $SLEEP_INTERVAL -gt $MAX_INTERVAL ]]; then SLEEP_INTERVAL=$MAX_INTERVAL; fi
		fi
	fi
	echo "[$(date)] $AGENT_NAME: Sleeping for $SLEEP_INTERVAL seconds." >>"$LOG_FILE"
	sleep $SLEEP_INTERVAL
done

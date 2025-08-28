#!/bin/bash
# Updater Agent: Checks for and applies updates to tools, packages, and dependencies

AGENT_NAME="UpdaterAgent"
LOG_FILE="$(dirname "$0")/updater_agent.log"

SLEEP_INTERVAL=43200 # 12 hours
MIN_INTERVAL=3600
MAX_INTERVAL=86400

while true; do
	echo "[$(date)] $AGENT_NAME: Checking for system and tool updates..." >>"$LOG_FILE"
	# Homebrew
	brew update && brew upgrade >>"$LOG_FILE" 2>&1
	# Python
	pip3 install --upgrade pip setuptools wheel >>"$LOG_FILE" 2>&1
	# npm (use sudo to avoid EACCES errors)
	sudo npm install -g npm && sudo npm update -g >>"$LOG_FILE" 2>&1
	# macOS software
	softwareupdate --install --all >>"$LOG_FILE" 2>&1
	# Xcode tools
	xcode-select --install >>"$LOG_FILE" 2>&1 || true
	echo "[$(date)] $AGENT_NAME: Update cycle complete." >>"$LOG_FILE"
	SLEEP_INTERVAL=$((SLEEP_INTERVAL + 3600))
	if [[ $SLEEP_INTERVAL -gt $MAX_INTERVAL ]]; then SLEEP_INTERVAL=$MAX_INTERVAL; fi
	echo "[$(date)] $AGENT_NAME: Sleeping for $SLEEP_INTERVAL seconds." >>"$LOG_FILE"
	sleep $SLEEP_INTERVAL
done

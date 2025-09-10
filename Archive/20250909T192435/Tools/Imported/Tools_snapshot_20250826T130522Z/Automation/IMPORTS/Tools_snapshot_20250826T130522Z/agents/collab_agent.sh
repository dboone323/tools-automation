#!/bin/bash
# Collaboration Agent: Coordinates all agents, aggregates plans, and ensures best practice learning

AGENT_NAME="CollabAgent"
LOG_FILE="$(dirname "$0")/collab_agent.log"
PLANS_DIR="/Users/danielstevens/Desktop/Code/Tools/Automation/agents/plans"

SLEEP_INTERVAL=900 # 15 minutes
MIN_INTERVAL=300
MAX_INTERVAL=3600

mkdir -p "$PLANS_DIR"

while true; do
    echo "[$(date)] $AGENT_NAME: Aggregating agent plans and results..." >> "$LOG_FILE"
    # Aggregate plans and suggestions from all agents
    cat $PLANS_DIR/*.plan 2>/dev/null >> "$LOG_FILE"
    # Analyze for conflicts, redundancies, and learning opportunities
    /Users/danielstevens/Desktop/Code/Tools/Automation/agents/plugins/collab_analyze.sh >> "$LOG_FILE" 2>&1
    # Update shared knowledge base if needed
    /Users/danielstevens/Desktop/Code/Tools/Automation/agents/auto_generate_knowledge_base.py >> "$LOG_FILE" 2>&1
    echo "[$(date)] $AGENT_NAME: Collaboration and learning cycle complete." >> "$LOG_FILE"
    SLEEP_INTERVAL=$(( SLEEP_INTERVAL + 300 ))
    if [[ $SLEEP_INTERVAL -gt $MAX_INTERVAL ]]; then SLEEP_INTERVAL=$MAX_INTERVAL; fi
    echo "[$(date)] $AGENT_NAME: Sleeping for $SLEEP_INTERVAL seconds." >> "$LOG_FILE"
    sleep $SLEEP_INTERVAL
done

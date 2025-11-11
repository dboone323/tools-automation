#!/bin/bash
# Autorestart wrapper for AI monitoring

while true; do
    echo "Starting AI monitor at $(date)" >> "/Users/danielstevens/Desktop/github-projects/tools-automation/Tools/Automation/monitoring/autorestart.log"
    "/Users/danielstevens/Desktop/github-projects/tools-automation/Tools/Automation/monitoring/ai_monitor.sh"
    exit_code=$?
    echo "AI monitor exited with code ${exit_code} at $(date)" >> "/Users/danielstevens/Desktop/github-projects/tools-automation/Tools/Automation/monitoring/autorestart.log"
    
    if [[ ${exit_code} -eq 0 ]]; then
        echo "Clean exit, not restarting" >> "/Users/danielstevens/Desktop/github-projects/tools-automation/Tools/Automation/monitoring/autorestart.log"
        break
    else
        echo "Restarting in 10 seconds..." >> "/Users/danielstevens/Desktop/github-projects/tools-automation/Tools/Automation/monitoring/autorestart.log"
        sleep 10
    fi
done

#!/bin/bash
# Quality Assurance Agent: Analyzes and improves code quality metrics

AGENT_NAME="quality_agent.sh"
LOG_FILE="/Users/danielstevens/Desktop/Code/Tools/Automation/agents/quality_agent.log"
NOTIFICATION_FILE="/Users/danielstevens/Desktop/Code/Tools/Automation/agents/communication/${AGENT_NAME}_notification.txt"
AGENT_STATUS_FILE="/Users/danielstevens/Desktop/Code/Tools/Automation/agents/agent_status.json"
TASK_QUEUE_FILE="/Users/danielstevens/Desktop/Code/Tools/Automation/agents/task_queue.json"

# Update agent status to available when starting
update_status() {
    local status="$1"
    if command -v jq &> /dev/null; then
        jq ".agents[\"$AGENT_NAME\"].status = \"$status\" | .agents[\"$AGENT_NAME\"].last_seen = $(date +%s)" "$AGENT_STATUS_FILE" > "${AGENT_STATUS_FILE}.tmp" && mv "${AGENT_STATUS_FILE}.tmp" "$AGENT_STATUS_FILE"
    fi
    echo "[$(date)] $AGENT_NAME: Status updated to $status" >> "$LOG_FILE"
}

# Process a specific task
process_task() {
    local task_id="$1"
    echo "[$(date)] $AGENT_NAME: Processing task $task_id" >> "$LOG_FILE"

    # Get task details
    if command -v jq &> /dev/null; then
        local task_desc=$(jq -r ".tasks[] | select(.id == \"$task_id\") | .description" "$TASK_QUEUE_FILE")
        local task_type=$(jq -r ".tasks[] | select(.id == \"$task_id\") | .type" "$TASK_QUEUE_FILE")
        echo "[$(date)] $AGENT_NAME: Task description: $task_desc" >> "$LOG_FILE"
        echo "[$(date)] $AGENT_NAME: Task type: $task_type" >> "$LOG_FILE"

        # Process based on task type
        case "$task_type" in
            "quality"|"lint"|"metrics")
                run_quality_analysis "$task_desc"
                ;;
            *)
                echo "[$(date)] $AGENT_NAME: Unknown task type: $task_type" >> "$LOG_FILE"
                ;;
        esac

        # Mark task as completed
        update_task_status "$task_id" "completed"
        echo "[$(date)] $AGENT_NAME: Task $task_id completed" >> "$LOG_FILE"
    fi
}

# Update task status
update_task_status() {
    local task_id="$1"
    local status="$2"
    if command -v jq &> /dev/null; then
        jq "(.tasks[] | select(.id == \"$task_id\") | .status) = \"$status\"" "$TASK_QUEUE_FILE" > "${TASK_QUEUE_FILE}.tmp" && mv "${TASK_QUEUE_FILE}.tmp" "$TASK_QUEUE_FILE"
    fi
}

# Quality analysis function
run_quality_analysis() {
    local task_desc="$1"
    echo "[$(date)] $AGENT_NAME: Running quality analysis for: $task_desc" >> "$LOG_FILE"

    # Extract project name from task description
    local projects=("CodingReviewer" "MomentumFinance" "HabitQuest" "PlannerApp" "AvoidObstaclesGame")

    for project in "${projects[@]}"; do
        if [[ -d "/Users/danielstevens/Desktop/Code/Projects/$project" ]]; then
            echo "[$(date)] $AGENT_NAME: Analyzing code quality in $project..." >> "$LOG_FILE"
            cd "/Users/danielstevens/Desktop/Code/Projects/$project"

            # Code quality metrics
            echo "[$(date)] $AGENT_NAME: Calculating quality metrics for $project..." >> "$LOG_FILE"

            # Count total lines of code
            local total_lines=$(find . -name "*.swift" -exec wc -l {} \; | awk '{sum += $1} END {print sum}')
            echo "[$(date)] $AGENT_NAME: Total lines of code: $total_lines" >> "$LOG_FILE"

            # Count files
            local total_files=$(find . -name "*.swift" | wc -l)
            echo "[$(date)] $AGENT_NAME: Total Swift files: $total_files" >> "$LOG_FILE"

            # Analyze code quality issues
            echo "[$(date)] $AGENT_NAME: Analyzing code quality issues..." >> "$LOG_FILE"

            # Check for code smells
            local force_unwraps=$(find . -name "*.swift" -exec grep -l "!" {} \; | wc -l)
            local todos=$(find . -name "*.swift" -exec grep -l "TODO\|FIXME" {} \; | wc -l)
            local prints=$(find . -name "*.swift" -exec grep -l "print\|debugPrint" {} \; | wc -l)

            echo "[$(date)] $AGENT_NAME: Force unwraps found in $force_unwraps files" >> "$LOG_FILE"
            echo "[$(date)] $AGENT_NAME: TODO/FIXME found in $todos files" >> "$LOG_FILE"
            echo "[$(date)] $AGENT_NAME: Print statements found in $prints files" >> "$LOG_FILE"

            # Calculate quality score (simple heuristic)
            local quality_score=$((100 - (force_unwraps * 5) - (todos * 2) - (prints * 1)))
            if [[ $quality_score -lt 0 ]]; then
                quality_score=0
            fi

            echo "[$(date)] $AGENT_NAME: Quality score for $project: $quality_score%" >> "$LOG_FILE"

            # Suggest improvements
            echo "[$(date)] $AGENT_NAME: Generating improvement suggestions..." >> "$LOG_FILE"

            if [[ $force_unwraps -gt 0 ]]; then
                echo "[$(date)] $AGENT_NAME: Consider replacing force unwraps with optional binding" >> "$LOG_FILE"
            fi

            if [[ $todos -gt 0 ]]; then
                echo "[$(date)] $AGENT_NAME: Address TODO and FIXME comments" >> "$LOG_FILE"
            fi

            if [[ $prints -gt 0 ]]; then
                echo "[$(date)] $AGENT_NAME: Remove or replace debug print statements" >> "$LOG_FILE"
            fi
        fi
    done

    echo "[$(date)] $AGENT_NAME: Quality analysis completed" >> "$LOG_FILE"
}

# Main agent loop
echo "[$(date)] $AGENT_NAME: Starting quality assurance agent..." >> "$LOG_FILE"
update_status "available"

# Track processed tasks to avoid duplicates
declare -A processed_tasks

while true; do
    # Check for new task notifications
    if [[ -f "$NOTIFICATION_FILE" ]]; then
        while IFS='|' read -r timestamp action task_id; do
            if [[ "$action" == "execute_task" && -z "${processed_tasks[$task_id]}" ]]; then
                update_status "busy"
                process_task "$task_id"
                update_status "available"
                processed_tasks[$task_id]="completed"
                echo "[$(date)] $AGENT_NAME: Marked task $task_id as processed" >> "$LOG_FILE"
            fi
        done < "$NOTIFICATION_FILE"

        # Clear processed notifications to prevent re-processing
        > "$NOTIFICATION_FILE"
    fi

    # Update last seen timestamp
    update_status "available"

    sleep 30  # Check every 30 seconds
done

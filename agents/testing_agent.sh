#!/bin/bash
# Testing Agent: Manages and improves test coverage and quality

AGENT_NAME="testing_agent.sh"
LOG_FILE="/Users/danielstevens/Desktop/Code/Tools/Automation/agents/testing_agent.log"
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
            "test"|"testing"|"coverage")
                run_testing_analysis "$task_desc"
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

# Testing analysis function
run_testing_analysis() {
    local task_desc="$1"
    echo "[$(date)] $AGENT_NAME: Running testing analysis for: $task_desc" >> "$LOG_FILE"

    # Extract project name from task description
    local projects=("CodingReviewer" "MomentumFinance" "HabitQuest" "PlannerApp" "AvoidObstaclesGame")

    for project in "${projects[@]}"; do
        if [[ -d "/Users/danielstevens/Desktop/Code/Projects/$project" ]]; then
            echo "[$(date)] $AGENT_NAME: Analyzing testing coverage in $project..." >> "$LOG_FILE"
            cd "/Users/danielstevens/Desktop/Code/Projects/$project"

            # Test coverage metrics
            echo "[$(date)] $AGENT_NAME: Calculating testing metrics for $project..." >> "$LOG_FILE"

            # Count test files
            local test_files=$(find . -name "*Test*.swift" -o -name "*Tests*.swift" | wc -l)
            echo "[$(date)] $AGENT_NAME: Test files found: $test_files" >> "$LOG_FILE"

            # Count source files
            local source_files=$(find . -name "*.swift" -not -path "*/Tests/*" -not -path "*/UITests/*" | wc -l)
            echo "[$(date)] $AGENT_NAME: Source files found: $source_files" >> "$LOG_FILE"

            # Calculate test coverage ratio
            local coverage_ratio=0
            if [[ $source_files -gt 0 ]]; then
                coverage_ratio=$((test_files * 100 / source_files))
            fi
            echo "[$(date)] $AGENT_NAME: Test coverage ratio: $coverage_ratio%" >> "$LOG_FILE"

            # Analyze test quality
            echo "[$(date)] $AGENT_NAME: Analyzing test quality..." >> "$LOG_FILE"

            if [[ $test_files -gt 0 ]]; then
                # Check for test patterns
                local unit_tests=$(find . -name "*Test*.swift" -exec grep -l "func test" {} \; | wc -l)
                local ui_tests=$(find . -name "*UITest*.swift" -exec grep -l "func test" {} \; | wc -l)
                local async_tests=$(find . -name "*Test*.swift" -exec grep -l "async" {} \; | wc -l)

                echo "[$(date)] $AGENT_NAME: Unit tests: $unit_tests" >> "$LOG_FILE"
                echo "[$(date)] $AGENT_NAME: UI tests: $ui_tests" >> "$LOG_FILE"
                echo "[$(date)] $AGENT_NAME: Async tests: $async_tests" >> "$LOG_FILE"

                # Check for test best practices
                local missing_asserts=$(find . -name "*Test*.swift" -exec grep -l "func test" {} \; | xargs grep -L "XCTAssert\|XCTFail" | wc -l)
                echo "[$(date)] $AGENT_NAME: Tests missing assertions: $missing_asserts" >> "$LOG_FILE"

                # Calculate test quality score
                local quality_score=$((100 - (missing_asserts * 10)))
                if [[ $quality_score -lt 0 ]]; then
                    quality_score=0
                fi
                echo "[$(date)] $AGENT_NAME: Test quality score: $quality_score%" >> "$LOG_FILE"
            else
                echo "[$(date)] $AGENT_NAME: No test files found - test coverage is 0%" >> "$LOG_FILE"
            fi

            # Generate testing recommendations
            echo "[$(date)] $AGENT_NAME: Generating testing recommendations..." >> "$LOG_FILE"

            if [[ $test_files -eq 0 ]]; then
                echo "[$(date)] $AGENT_NAME: Recommendation: Create unit tests for core functionality" >> "$LOG_FILE"
                echo "[$(date)] $AGENT_NAME: Recommendation: Add UI tests for user interactions" >> "$LOG_FILE"
            fi

            if [[ $coverage_ratio -lt 50 ]]; then
                echo "[$(date)] $AGENT_NAME: Recommendation: Increase test coverage to at least 50%" >> "$LOG_FILE"
            fi

            if [[ $missing_asserts -gt 0 ]]; then
                echo "[$(date)] $AGENT_NAME: Recommendation: Add proper assertions to all test methods" >> "$LOG_FILE"
            fi

            if [[ $async_tests -eq 0 ]]; then
                echo "[$(date)] $AGENT_NAME: Recommendation: Add async tests for network and database operations" >> "$LOG_FILE"
            fi
        fi
    done

    echo "[$(date)] $AGENT_NAME: Testing analysis completed" >> "$LOG_FILE"
}

# Main agent loop
echo "[$(date)] $AGENT_NAME: Starting testing agent..." >> "$LOG_FILE"
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

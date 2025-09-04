#!/bin/bash
# Search Agent: Intelligent code analysis using Ollama AI
# Completely free alternative to paid search and analysis tools

AGENT_NAME="search_agent.sh"
WORKSPACE="/Users/danielstevens/Desktop/Quantum-workspace"
LOG_FILE="${WORKSPACE}/Tools/Automation/agents/search_agent.log"
NOTIFICATION_FILE="${WORKSPACE}/Tools/Automation/agents/communication/${AGENT_NAME}_notification.txt"
AGENT_STATUS_FILE="${WORKSPACE}/Tools/Automation/agents/agent_status.json"
TASK_QUEUE_FILE="${WORKSPACE}/Tools/Automation/agents/task_queue.json"

# Update agent status to available when starting
update_status() {
	local status="$1"
	if command -v jq &>/dev/null; then
		jq ".agents[\"${AGENT_NAME}\"].status = \"${status}\" | .agents[\"${AGENT_NAME}\"].last_seen = $(date +%s)" "${AGENT_STATUS_FILE}" >"${AGENT_STATUS_FILE}.tmp" && mv "${AGENT_STATUS_FILE}.tmp" "${AGENT_STATUS_FILE}"
	fi
	echo "[$(date)] ${AGENT_NAME}: Status updated to ${status}" >>"${LOG_FILE}"
}

# Process a specific task
process_task() {
	local task_id="$1"
	echo "[$(date)] ${AGENT_NAME}: Processing task ${task_id}" >>"${LOG_FILE}"

	# Get task details
	if command -v jq &>/dev/null; then
		local task_desc
		task_desc=$(jq -r ".tasks[] | select(.id == \"${task_id}\") | .description" "${TASK_QUEUE_FILE}")
		local task_type
		task_type=$(jq -r ".tasks[] | select(.id == \"${task_id}\") | .type" "${TASK_QUEUE_FILE}")
		echo "[$(date)] ${AGENT_NAME}: Task description: ${task_desc}" >>"${LOG_FILE}"
		echo "[$(date)] ${AGENT_NAME}: Task type: ${task_type}" >>"${LOG_FILE}"

		# Process based on task type
		case "${task_type}" in
		"search" | "find" | "locate" | "discover")
			run_search "${task_desc}"
			;;
		*)
			echo "[$(date)] ${AGENT_NAME}: Unknown task type: ${task_type}" >>"${LOG_FILE}"
			;;
		esac

		# Mark task as completed
		update_task_status "${task_id}" "completed"
		echo "[$(date)] ${AGENT_NAME}: Task ${task_id} completed" >>"${LOG_FILE}"
	fi
}

# Update task status
update_task_status() {
	local task_id="$1"
	local status="$2"
	if command -v jq &>/dev/null; then
		jq "(.tasks[] | select(.id == \"${task_id}\") | .status) = \"${status}\"" "${TASK_QUEUE_FILE}" >"${TASK_QUEUE_FILE}.tmp" && mv "${TASK_QUEUE_FILE}.tmp" "${TASK_QUEUE_FILE}"
	fi
}

# Ollama-powered search and analysis function using Integration Framework
run_search() {
	local task_desc="$1"
	echo "[$(date)] ${AGENT_NAME}: Running Ollama-powered search for: ${task_desc}" >>"${LOG_FILE}"

	# Check if Ollama is running
	if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
		echo "[$(date)] ${AGENT_NAME}: ERROR - Ollama server not running. Starting..." >>"${LOG_FILE}"
		brew services start ollama >>"${LOG_FILE}" 2>&1
		sleep 5 # Wait for Ollama to start
	fi

	# Determine search type based on task description
	local search_type="analyze"
	local project_path=""
	local query="${task_desc}"

	# Extract project name from task description
	if [[ ${task_desc} =~ CodingReviewer ]]; then
		project_path="${WORKSPACE}/Projects/CodingReviewer"
	elif [[ ${task_desc} =~ MomentumFinance ]]; then
		project_path="${WORKSPACE}/Projects/MomentumFinance"
	elif [[ ${task_desc} =~ HabitQuest ]]; then
		project_path="${WORKSPACE}/Projects/HabitQuest"
	elif [[ ${task_desc} =~ PlannerApp ]]; then
		project_path="${WORKSPACE}/Projects/PlannerApp"
	elif [[ ${task_desc} =~ AvoidObstaclesGame ]]; then
		project_path="${WORKSPACE}/Projects/AvoidObstaclesGame"
	else
		project_path="${WORKSPACE}/Projects" # Search all projects
	fi

	# Determine analysis type
	if [[ ${task_desc} =~ (issue|bug|problem|error|warning) ]]; then
		search_type="issues"
		echo "[$(date)] ${AGENT_NAME}: Performing issue analysis..." >>"${LOG_FILE}"
	elif [[ ${task_desc} =~ (search|find|locate|pattern) ]]; then
		search_type="search"
		echo "[$(date)] ${AGENT_NAME}: Performing pattern search..." >>"${LOG_FILE}"
	elif [[ ${task_desc} =~ (insight|overview|summary|architecture) ]]; then
		search_type="insights"
		echo "[$(date)] ${AGENT_NAME}: Generating code insights..." >>"${LOG_FILE}"
	else
		echo "[$(date)] ${AGENT_NAME}: Performing general codebase analysis..." >>"${LOG_FILE}"
	fi

	# Use Ollama Integration Framework for intelligent analysis
	echo "[$(date)] ${AGENT_NAME}: Using Ollama Integration Framework for ${search_type} analysis..." >>"${LOG_FILE}"

	# Create a temporary Swift script to use the framework
	local temp_script="/tmp/ollama_search_$$.swift"
	cat >"${temp_script}" <<EOF
#!/usr/bin/env swift

import Foundation

// Copy the OllamaIntegrationFramework content here for standalone execution
$(cat "${WORKSPACE}/Shared/OllamaIntegrationFramework.swift")

// Main execution
@main
struct SearchRunner {
    static func main() async {
        let manager = OllamaIntegrationManager()

        do {
            // Check service health
            let health = await manager.checkServiceHealth()
            if !health.ollamaRunning {
                print("ERROR: Ollama not running")
                exit(1)
            }

            // Read project files for analysis
            let projectPath = CommandLine.arguments[1]
            let searchType = CommandLine.arguments[2]
            let query = CommandLine.arguments[3]

            var allCode = ""

            // Collect Swift files from project
            let fileManager = FileManager.default
            if let enumerator = fileManager.enumerator(atPath: projectPath) {
                for case let file as String in enumerator {
                    if file.hasSuffix(".swift") && !file.contains("/.build/") {
                        let fullPath = "\(projectPath)/\(file)"
                        if let content = try? String(contentsOfFile: fullPath, encoding: .utf8) {
                            allCode += "\n// File: \(file)\n\(content)\n"
                        }
                    }
                }
            }

            if allCode.isEmpty {
                print("No Swift files found in project")
                exit(1)
            }

            // Perform analysis based on type
            switch searchType {
            case "issues":
                let result = try await manager.analyzeCodebase(
                    code: allCode,
                    language: "Swift",
                    analysisType: .comprehensive
                )
                print("=== ISSUE ANALYSIS ===")
                print("Query: \(query)")
                print("Files analyzed: Swift files in project")
                print("")
                print("ISSUES FOUND:")
                for issue in result.issues {
                    print("- \(issue.description) (Severity: \(issue.severity))")
                }
                print("")
                print("SUGGESTIONS:")
                for suggestion in result.suggestions {
                    print("- \(suggestion)")
                }

            case "insights":
                let result = try await manager.analyzeCodebase(
                    code: allCode,
                    language: "Swift",
                    analysisType: .comprehensive
                )
                print("=== CODE INSIGHTS ===")
                print("Query: \(query)")
                print("Project Analysis:")
                print(result.analysis)
                print("")
                print("Key Issues:")
                for issue in result.issues.prefix(5) {
                    print("- \(issue.description)")
                }

            default:
                let result = try await manager.analyzeCodebase(
                    code: allCode,
                    language: "Swift",
                    analysisType: .comprehensive
                )
                print("=== CODEBASE ANALYSIS ===")
                print("Query: \(query)")
                print("Analysis Results:")
                print(result.analysis)
                print("")
                print("Issues: \(result.issues.count)")
                print("Suggestions: \(result.suggestions.count)")
            }

        } catch {
            print("ERROR: \(error.localizedDescription)")
            exit(1)
        }
    }
}
EOF

	# Execute the Swift script
	local analysis_result
	analysis_result=$(swift "${temp_script}" "${project_path}" "${search_type}" "${query}" 2>>"${LOG_FILE}")

	# Clean up temp script
	rm -f "${temp_script}"

	if [[ $? -eq 0 && -n ${analysis_result} ]]; then
		echo "[$(date)] ${AGENT_NAME}: Analysis completed successfully using framework" >>"${LOG_FILE}"

		# Save analysis results
		local timestamp
		timestamp=$(date +%Y%m%d_%H%M%S)
		local result_file="Analysis_${search_type}_${timestamp}.txt"
		local project_name
		project_name=$(basename "${project_path}")

		mkdir -p "${WORKSPACE}/Tools/Automation/results"
		echo "Analysis Results for: ${task_desc}" >"${WORKSPACE}/Tools/Automation/results/${result_file}"
		echo "Project: ${project_name}" >>"${WORKSPACE}/Tools/Automation/results/${result_file}"
		echo "Analysis Type: ${search_type}" >>"${WORKSPACE}/Tools/Automation/results/${result_file}"
		echo "Timestamp: $(date)" >>"${WORKSPACE}/Tools/Automation/results/${result_file}"
		echo "========================================" >>"${WORKSPACE}/Tools/Automation/results/${result_file}"
		echo "" >>"${WORKSPACE}/Tools/Automation/results/${result_file}"
		echo "${analysis_result}" >>"${WORKSPACE}/Tools/Automation/results/${result_file}"

		echo "[$(date)] ${AGENT_NAME}: Results saved to ${WORKSPACE}/Tools/Automation/results/${result_file}" >>"${LOG_FILE}"

		# Also perform basic file search for complementary results
		echo "[$(date)] ${AGENT_NAME}: Performing complementary file search..." >>"${LOG_FILE}"
		if [[ -d ${project_path} ]]; then
			cd "${project_path}" || {
				echo "[$(date)] ${AGENT_NAME}: ERROR - Could not cd to ${project_path}" >>"${LOG_FILE}"
				return 1
			}

			# Search for common patterns
			local search_patterns=("TODO" "FIXME" "BUG" "HACK" "ERROR" "WARNING" "deprecated" "DEPRECATED")
			for pattern in "${search_patterns[@]}"; do
				local files_with_pattern
				files_with_pattern=$(find . -name "*.swift" -exec grep -l "${pattern}" {} \; 2>/dev/null | head -5)
				if [[ -n ${files_with_pattern} ]]; then
					echo "Files containing '${pattern}':" >>"${WORKSPACE}/Tools/Automation/results/${result_file}"
					echo "${files_with_pattern}" >>"${WORKSPACE}/Tools/Automation/results/${result_file}"
					echo "" >>"${WORKSPACE}/Tools/Automation/results/${result_file}"
				fi
			done
		fi

		echo "[$(date)] ${AGENT_NAME}: Ollama-powered search and analysis completed" >>"${LOG_FILE}"
	else
		echo "[$(date)] ${AGENT_NAME}: ERROR - Failed to perform Ollama analysis with framework" >>"${LOG_FILE}"
	fi
}

# Main agent loop
echo "[$(date)] ${AGENT_NAME}: Starting agent..." >>"${LOG_FILE}"
update_status "available"

# Track processed tasks to avoid duplicates
declare -A processed_tasks

while true; do
	# Check for new task notifications
	if [[ -f ${NOTIFICATION_FILE} ]]; then
		while IFS='|' read -r timestamp action task_id; do
			if [[ ${action} == "execute_task" && -z ${processed_tasks[${task_id}]} ]]; then
				update_status "busy"
				process_task "${task_id}"
				update_status "available"
				processed_tasks[${task_id}]="completed"
				echo "[$(date)] ${AGENT_NAME}: Marked task ${task_id} as processed" >>"${LOG_FILE}"
			fi
		done <"${NOTIFICATION_FILE}"

		# Clear processed notifications to prevent re-processing
		true >"${NOTIFICATION_FILE}"
	fi

	# Update last seen timestamp
	update_status "available"

	sleep 30 # Check every 30 seconds
done

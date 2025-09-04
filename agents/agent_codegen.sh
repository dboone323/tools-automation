#!/bin/bash
# CodeGen Agent: Generates code using Ollama AI models
# Completely free alternative to paid AI services

AGENT_NAME="agent_codegen.sh"
WORKSPACE="/Users/danielstevens/Desktop/Quantum-workspace"
LOG_FILE="${WORKSPACE}/Tools/Automation/agents/codegen_agent.log"
NOTIFICATION_FILE="${WORKSPACE}/Tools/Automation/agents/communication/${AGENT_NAME}_notification.txt"
AGENT_STATUS_FILE="${WORKSPACE}/Tools/Automation/agents/agent_status.json"
TASK_QUEUE_FILE="${WORKSPACE}/Tools/Automation/agents/task_queue.json"
OLLAMA_CODEGEN="${WORKSPACE}/Tools/Automation/agents/ollama_codegen.swift"

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
		"generate" | "create" | "code")
			run_codegen "${task_desc}"
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

# Code generation function using Ollama Integration Framework
run_codegen() {
	local task_desc="$1"
	echo "[$(date)] ${AGENT_NAME}: Running Ollama-powered code generation for: ${task_desc}" >>"${LOG_FILE}"

	# Extract project name from task description
	if [[ ${task_desc} =~ CodingReviewer ]]; then
		PROJECT="CodingReviewer"
	elif [[ ${task_desc} =~ MomentumFinance ]]; then
		PROJECT="MomentumFinance"
	elif [[ ${task_desc} =~ HabitQuest ]]; then
		PROJECT="HabitQuest"
	elif [[ ${task_desc} =~ PlannerApp ]]; then
		PROJECT="PlannerApp"
	elif [[ ${task_desc} =~ AvoidObstaclesGame ]]; then
		PROJECT="AvoidObstaclesGame"
	else
		PROJECT="General" # Default
	fi

	echo "[$(date)] ${AGENT_NAME}: Generating code for project: ${PROJECT}" >>"${LOG_FILE}"

	# Check if Ollama is running
	if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
		echo "[$(date)] ${AGENT_NAME}: ERROR - Ollama server not running. Starting..." >>"${LOG_FILE}"
		brew services start ollama >>"${LOG_FILE}" 2>&1
		sleep 5 # Wait for Ollama to start
	fi

	# Use Ollama Integration Framework for AI-powered code generation
	echo "[$(date)] ${AGENT_NAME}: Using Ollama Integration Framework for code generation..." >>"${LOG_FILE}"

	# Create a temporary Swift script to use the framework
	local temp_script="/tmp/ollama_codegen_$$.swift"
	cat >"${temp_script}" <<EOF
#!/usr/bin/env swift

import Foundation

// Copy the OllamaIntegrationFramework content here for standalone execution
$(cat "${WORKSPACE}/Shared/OllamaIntegrationFramework.swift")

// Main execution
@main
struct CodeGenRunner {
    static func main() async {
        let manager = OllamaIntegrationManager()

        do {
            // Check service health
            let health = await manager.checkServiceHealth()
            if !health.ollamaRunning {
                print("ERROR: Ollama not running")
                exit(1)
            }

            // Generate code
            let result = try await manager.generateCode(
                description: CommandLine.arguments[1],
                language: "Swift",
                complexity: .standard
            )

            print("=== GENERATED CODE ===")
            print(result.code)
            print("=== ANALYSIS ===")
            print(result.analysis)

        } catch {
            print("ERROR: \(error.localizedDescription)")
            exit(1)
        }
    }
}
EOF

	# Execute the Swift script
	local generated_code
	generated_code=$(swift "${temp_script}" "${task_desc}" 2>>"${LOG_FILE}")

	# Clean up temp script
	rm -f "${temp_script}"

	if [[ $? -eq 0 && -n ${generated_code} ]]; then
		echo "[$(date)] ${AGENT_NAME}: Code generated successfully using framework" >>"${LOG_FILE}"

		# Extract code from output
		local code_section
		code_section=$(echo "${generated_code}" | sed -n '/=== GENERATED CODE ===/,/=== ANALYSIS ===/p' | sed '1d;$d')

		# Save generated code to project directory
		local project_dir="${WORKSPACE}/Projects/${PROJECT}"
		if [[ -d ${project_dir} ]]; then
			cd "${project_dir}" || {
				echo "[$(date)] ${AGENT_NAME}: ERROR - Could not cd to ${project_dir}" >>"${LOG_FILE}"
				return 1
			}

			# Create generated code file
			local timestamp
			timestamp=$(date +%Y%m%d_%H%M%S)
			local code_file="GeneratedCode_${timestamp}.swift"
			echo "${code_section}" >"${code_file}"
			echo "[$(date)] ${AGENT_NAME}: Generated code saved to ${project_dir}/${code_file}" >>"${LOG_FILE}"

			# Generate analysis and tests using the framework
			echo "[$(date)] ${AGENT_NAME}: Generating analysis and tests..." >>"${LOG_FILE}"

			# Create analysis script
			local analysis_script="/tmp/ollama_analysis_$$.swift"
			cat >"${analysis_script}" <<EOF
#!/usr/bin/env swift

import Foundation

// Copy the OllamaIntegrationFramework content here for standalone execution
$(cat "${WORKSPACE}/Shared/OllamaIntegrationFramework.swift")

// Main execution
@main
struct AnalysisRunner {
    static func main() async {
        let manager = OllamaIntegrationManager()

        do {
            // Read the generated code
            let code = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)

            // Analyze the code
            let analysis = try await manager.analyzeCodebase(
                code: code,
                language: "Swift",
                analysisType: .comprehensive
            )

            print("=== CODE ANALYSIS ===")
            print(analysis.analysis)
            print("\n=== ISSUES ===")
            for issue in analysis.issues {
                print("- \(issue.description) (Severity: \(issue.severity))")
            }
            print("\n=== SUGGESTIONS ===")
            for suggestion in analysis.suggestions {
                print("- \(suggestion)")
            }

        } catch {
            print("ERROR: \(error.localizedDescription)")
            exit(1)
        }
    }
}
EOF

			# Run analysis
			local analysis_output
			analysis_output=$(swift "${analysis_script}" "${code_file}" 2>>"${LOG_FILE}")

			if [[ -n ${analysis_output} ]]; then
				local analysis_file="${code_file%.swift}_analysis.txt"
				echo "${analysis_output}" >"${analysis_file}"
				echo "[$(date)] ${AGENT_NAME}: Code analysis saved to ${analysis_file}" >>"${LOG_FILE}"
			fi

			# Clean up analysis script
			rm -f "${analysis_script}"

			# Validate the generated code
			echo "[$(date)] ${AGENT_NAME}: Validating generated code..." >>"${LOG_FILE}"
			if command -v swiftc &>/dev/null; then
				if swiftc -parse "${code_file}" >/dev/null 2>&1; then
					echo "[$(date)] ${AGENT_NAME}: ✅ Generated code compiles successfully" >>"${LOG_FILE}"
				else
					echo "[$(date)] ${AGENT_NAME}: ⚠️  Generated code has compilation issues" >>"${LOG_FILE}"
				fi
			fi
		else
			echo "[$(date)] ${AGENT_NAME}: WARNING - Project directory ${project_dir} not found" >>"${LOG_FILE}"
		fi
	else
		echo "[$(date)] ${AGENT_NAME}: ERROR - Failed to generate code with Ollama Integration Framework" >>"${LOG_FILE}"
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
				echo "[$(date)] ${AGENT_NAME}: Processing notification from ${timestamp}" >>"${LOG_FILE}"
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

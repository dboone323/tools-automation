#!/bin/bash
# assign_agent.sh - Assign an agent to a TODO/issue based on text
# Usage: assign_agent.sh <file> <line> <text>

ASSIGNMENTS_FILE="$(dirname "$0")/agent_assignments.json"
file="$1"
line="$2"
text="$3"

# Expanded keyword-based agent assignment
if echo "${text}" | grep -iqE 'ui|ux|accessib'; then
    agent="uiux_agent.sh"
elif echo "${text}" | grep -iqE 'apple|swift|concurr|ios|macos'; then
    agent="apple_pro_agent.sh"
elif echo "${text}" | grep -iqE 'test|unit|coverage|tdd|bdd|integration test|mock|stub'; then
    agent="testing_agent.sh"
elif echo "${text}" | grep -iqE 'perf|speed|optimi|latency|throughput'; then
    agent="performance_agent.sh"
elif echo "${text}" | grep -iqE 'security|vulnerab|auth|crypto|xss|csrf|injection|exploit'; then
    agent="security_agent.sh"
elif echo "${text}" | grep -iqE 'doc|comment|readme|docs|documentation'; then
    agent="documentation_agent.sh"
elif echo "${text}" | grep -iqE 'deploy|release|ci|cd|pipeline|devops'; then
    agent="deployment_agent.sh"
elif echo "${text}" | grep -iqE 'quality|lint|smell|static analysis|qa'; then
    agent="quality_agent.sh"
elif echo "${text}" | grep -iqE 'learn|pattern|best practice|knowledge|insight'; then
    agent="learning_agent.sh"
elif echo "${text}" | grep -iqE 'api|endpoint|public api|rate limit|github api|external service'; then
    agent="public_api_agent.sh"
elif echo "${text}" | grep -iqE 'monitor|health|anomaly|metrics|alert|uptime'; then
    agent="monitoring_agent.sh"
elif echo "${text}" | grep -iqE 'collab|coordinate|aggregate|teamwork|plan aggregation'; then
    agent="collab_agent.sh"
elif echo "${text}" | grep -iqE 'review|code review|pr review|pull request review'; then
    agent="code_review_agent.sh"
elif echo "${text}" | grep -iqE 'update|upgrade|dependency|patch|refresh'; then
    agent="updater_agent.sh"
elif echo "${text}" | grep -iqE 'knowledge base|kb|best practices|learning history'; then
    agent="knowledge_base_agent.sh"
elif echo "${text}" | grep -iqE 'search|find|lookup|query|summarize'; then
    agent="search_agent.sh"
elif echo "${text}" | grep -iqE 'pull request|pr|merge|auto-merge'; then
    agent="pull_request_agent.sh"
elif echo "${text}" | grep -iqE 'auto-update|auto update|self-heal|self update'; then
    agent="auto_update_agent.sh"
elif echo "${text}" | grep -iqE 'build|compile|make|build system'; then
    agent="agent_build.sh"
else
    agent="agent_debug.sh"
fi

assignment_id="assign_$(date +%s%N)"
assignment_json="{\"id\": \"${assignment_id}\", \"file\": \"${file}\", \"line\": ${line}, \"text\": \"${text}\", \"agent\": \"${agent}\"}"

if [[ ! -f ${ASSIGNMENTS_FILE} ]]; then
    echo "[]" >"${ASSIGNMENTS_FILE}"
fi

jq ". + [${assignment_json}]" "${ASSIGNMENTS_FILE}" >"${ASSIGNMENTS_FILE}.tmp" && mv "${ASSIGNMENTS_FILE}.tmp" "${ASSIGNMENTS_FILE}"
echo "Assigned ${agent} to ${file}:${line} (${assignment_id})"

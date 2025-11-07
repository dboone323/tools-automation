#!/bin/bash
# ai_client.sh: Centralized policy-aware AI task router for agents
# Usage:
#   source this file from an agent script, then call:
#   ai_text "Prompt here" [task]
# Optional env:
#   AI_CLIENT: path to policy-aware client (defaults to repo root ollama_client.sh)

set -euo pipefail

TOOLS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AI_CLIENT_DEFAULT="${TOOLS_ROOT}/ollama_client.sh"

ai_task_for_script() {
    local script_name
    script_name=$(basename "${AGENT_NAME:-$0}")
    case "$script_name" in
    ai_code_review_agent.sh | code_review_agent.sh)
        echo "codeAnalysis"
        ;;
    testing_agent.sh | testing_agent_backup.sh)
        echo "testGen"
        ;;
    documentation_agent.sh | ai_docs_agent.sh)
        echo "codeGen"
        ;;
    security_agent.sh)
        echo "codeAnalysis"
        ;;
    encryption_agent.sh)
        echo "codeAnalysis"
        ;;
    monitoring_agent.sh | dashboard_unified.sh)
        echo "dashboardSummary"
        ;;
    predictive_analytics_agent.sh | ai_predictive_analytics_agent.sh)
        echo "projectHealth"
        ;;
    audit_agent.sh)
        echo "archAnalysis"
        ;;
    deployment_agent.sh)
        echo "workflowOptimization"
        ;;
    *)
        echo "codeGen"
        ;;
    esac
}

# ai_generate: emits full JSON response from client
ai_generate() {
    local prompt="$1"
    local task="${2:-$(ai_task_for_script)}"
    local system="${3:-}"
    local client_path="${AI_CLIENT:-$AI_CLIENT_DEFAULT}"
    if [[ ! -x "$client_path" ]]; then
        echo "ERROR: Policy-aware client not found or not executable: $client_path" >&2
        return 1
    fi
    local payload
    if [[ -n "$system" ]]; then
        payload=$(jq -n --arg task "$task" --arg prompt "$prompt" --arg system "$system" '{task:$task, prompt:$prompt, system:$system}')
    else
        payload=$(jq -n --arg task "$task" --arg prompt "$prompt" '{task:$task, prompt:$prompt}')
    fi
    echo "$payload" | "$client_path"
}

# ai_text: emits just the .text field from response
ai_text() {
    ai_generate "$@" | jq -r '.text // empty'
}

#!/usr/bin/env bash
set -euo pipefail

# 🔌 Enhanced MCP Client - Model Context Protocol integration for agents
# Provides unified interface to GitHub Copilot, Ollama, and MCP server

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCP_URL="${MCP_URL:-http://127.0.0.1:5005}"
MCP_LOG="${SCRIPT_DIR}/mcp_client.log"
MCP_CACHE_DIR="${SCRIPT_DIR}/.mcp_cache"
MCP_CONFIG="${SCRIPT_DIR}/mcp_config.json"

# Create cache directory
mkdir -p "${MCP_CACHE_DIR}"

# Initialize MCP configuration
initialize_mcp_config() {
    if [[ ! -f "${MCP_CONFIG}" ]]; then
        cat >"${MCP_CONFIG}" <<'EOF'
{
  "version": "1.0",
  "mcp_server": {
    "enabled": true,
    "url": "http://127.0.0.1:5005"
  },
  "providers": {
    "github_copilot": {
      "enabled": true,
      "type": "vscode_extension",
      "capabilities": ["code_completion", "code_review", "explanation"]
    },
    "ollama": {
      "enabled": false,
      "endpoint": "http://localhost:11434",
      "models": ["codellama", "mistral", "llama2"],
      "capabilities": ["code_generation", "analysis", "chat"]
    }
  },
  "default_provider": "github_copilot",
  "request_timeout": 30,
  "cache_enabled": true,
  "cache_ttl": 3600
}
EOF
    fi
}

# Log MCP operations
log_mcp() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [MCP] [${level}] ${message}" >>"${MCP_LOG}"
}

# Check if provider is available
check_provider() {
    local provider="$1"

    case "${provider}" in
    mcp_server)
        if curl -sf "${MCP_URL}/health" &>/dev/null; then
            return 0
        else
            log_mcp "WARN" "MCP server not responding at ${MCP_URL}"
            return 1
        fi
        ;;
    github_copilot)
        # Check if GitHub Copilot is available via VS Code
        if command -v code &>/dev/null; then
            return 0
        else
            log_mcp "WARN" "GitHub Copilot requires VS Code CLI"
            return 1
        fi
        ;;
    ollama)
        # Check if Ollama is running
        if curl -sf "http://localhost:11434/api/tags" &>/dev/null; then
            return 0
        else
            log_mcp "WARN" "Ollama not running on localhost:11434"
            return 1
        fi
        ;;
    *)
        log_mcp "ERROR" "Unknown provider: ${provider}"
        return 1
        ;;
    esac
}

# Legacy MCP server commands (backward compatible)
mcp_register() {
    local agent="$1"
    log_mcp "INFO" "Registering agent: ${agent}"
    curl -s -X POST "${MCP_URL}/register" \
        -H 'Content-Type: application/json' \
        -d "{\"agent\": \"${agent}\", \"capabilities\": [\"automation\"]}" | jq .
}

mcp_run() {
    local agent="$1"
    local command="$2"
    local project="${3:-}"
    local execute=false

    shift 3 || shift $#
    for arg in "$@"; do
        if [[ "${arg}" == "--execute" ]]; then
            execute=true
        fi
    done

    log_mcp "INFO" "Running command via MCP: ${agent} ${command}"

    local payload
    payload=$(jq -n \
        --arg agent "${agent}" \
        --arg command "${command}" \
        --arg project "${project}" \
        --argjson execute "${execute}" \
        '{agent:$agent,command:$command,project:$project,execute:$execute}')

    curl -s -X POST "${MCP_URL}/run" \
        -H 'Content-Type: application/json' \
        -d "${payload}" | jq .
}

# Enhanced AI provider commands
ai_complete() {
    local file_path="$1"
    local context="${2:-}"

    log_mcp "INFO" "Requesting code completion for ${file_path}"

    # Try GitHub Copilot first
    if check_provider "github_copilot"; then
        echo '{"provider": "github_copilot", "status": "success", "message": "Use VS Code Copilot extension"}'
    elif check_provider "ollama"; then
        local prompt="Complete the following code:\n\nFile: ${file_path}\nContext: ${context}"
        ollama_generate "codellama" "${prompt}"
    else
        echo '{"status": "error", "message": "No AI provider available"}'
        return 1
    fi
}

ai_review() {
    local file_path="$1"

    log_mcp "INFO" "Requesting code review for ${file_path}"

    if [[ ! -f "${file_path}" ]]; then
        echo '{"status": "error", "message": "File not found"}'
        return 1
    fi

    if check_provider "ollama"; then
        local code
        code=$(cat "${file_path}")
        local prompt="Review the following code and identify issues:\n\n${code}"
        ollama_generate "codellama" "${prompt}"
    else
        echo '{"status": "error", "message": "No AI provider available for review"}'
        return 1
    fi
}

ai_explain() {
    local code_snippet="$1"

    log_mcp "INFO" "Requesting code explanation"

    if check_provider "ollama"; then
        local prompt="Explain what this code does:\n\n${code_snippet}"
        ollama_generate "mistral" "${prompt}"
    else
        echo '{"status": "error", "message": "No AI provider available for explanation"}'
        return 1
    fi
}

# Ollama integration
ollama_generate() {
    local model="$1"
    local prompt="$2"

    log_mcp "INFO" "Generating with Ollama ${model}"

    if ! check_provider "ollama"; then
        echo '{"status": "error", "message": "Ollama not available"}'
        return 1
    fi

    local response
    response=$(
        curl -sf -X POST "http://localhost:11434/api/generate" \
            -H "Content-Type: application/json" \
            -d @- <<EOF
{
  "model": "${model}",
  "prompt": "${prompt}",
  "stream": false
}
EOF
    )

    if [[ $? -eq 0 ]]; then
        echo "${response}"
    else
        echo '{"status": "error", "message": "Ollama request failed"}'
        return 1
    fi
}

# List available providers
list_providers() {
    echo "=== MCP Providers ==="
    echo ""

    if check_provider "mcp_server"; then
        echo "✅ MCP Server: ${MCP_URL}"
    else
        echo "❌ MCP Server: offline"
    fi

    if check_provider "github_copilot"; then
        echo "✅ GitHub Copilot: available"
    else
        echo "❌ GitHub Copilot: not available"
    fi

    if check_provider "ollama"; then
        echo "✅ Ollama: available"
        echo "   Models:"
        curl -sf "http://localhost:11434/api/tags" | jq -r '.models[].name' | sed 's/^/     - /'
    else
        echo "❌ Ollama: not available"
    fi
}

usage() {
    cat <<EOF
MCP Client - Model Context Protocol & AI Integration

Legacy Commands (backward compatible):
  $0 register <agent-name>
  $0 run <agent-name> <command> [project] [--execute]

Enhanced AI Commands:
  $0 ai complete <file-path> [context]    - Code completion
  $0 ai review <file-path>                - Code review
  $0 ai explain <code-snippet>            - Explain code
  $0 ai generate <model> <prompt>         - Generate with Ollama

Utility Commands:
  $0 check <provider>       - Check provider availability
  $0 list                   - List all providers
  $0 clear-cache           - Clear MCP cache

Providers:
  - mcp_server      MCP server at ${MCP_URL}
  - github_copilot  GitHub Copilot via VS Code
  - ollama          Local Ollama models

Examples:
  $0 register test_agent
  $0 run test_agent "build project" CodingReviewer
  $0 ai review /path/to/file.swift
  $0 ai generate codellama "Write a Swift function"
  $0 list
EOF
    exit 0
}

# Initialize configuration
initialize_mcp_config

# Main command router
if [[ $# -lt 1 ]]; then
    usage
fi

cmd="$1"
shift

case "${cmd}" in
# Legacy commands (backward compatible)
register)
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 register <agent-name>"
        exit 2
    fi
    mcp_register "$1"
    ;;
run)
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 run <agent-name> <command> [project] [--execute]"
        exit 2
    fi
    mcp_run "$@"
    ;;

# Enhanced AI commands
ai)
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 ai <command> [args...]"
        exit 2
    fi
    ai_cmd="$1"
    shift
    case "${ai_cmd}" in
    complete)
        ai_complete "$@"
        ;;
    review)
        ai_review "$@"
        ;;
    explain)
        ai_explain "$@"
        ;;
    generate)
        if [[ $# -lt 2 ]]; then
            echo "Usage: $0 ai generate <model> <prompt>"
            exit 2
        fi
        ollama_generate "$@"
        ;;
    *)
        echo "Unknown AI command: ${ai_cmd}"
        exit 2
        ;;
    esac
    ;;

# Utility commands
check)
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 check <provider>"
        exit 2
    fi
    if check_provider "$1"; then
        echo "✅ Provider $1 is available"
        exit 0
    else
        echo "❌ Provider $1 is not available"
        exit 1
    fi
    ;;
list)
    list_providers
    ;;
clear-cache)
    rm -rf "${MCP_CACHE_DIR}"/*
    echo "MCP cache cleared"
    ;;

# Help
help | --help | -h)
    usage
    ;;

*)
    echo "Unknown command: ${cmd}"
    usage
    ;;
esac

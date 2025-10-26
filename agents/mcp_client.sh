#!/bin/bash

# MCP Client - Model Context Protocol Interface
# Provides AI-enhanced capabilities to agent system via MCP

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
MCP_CONFIG="${MCP_CONFIG:-$HOME/.config/mcp/config.json}"
MCP_TIMEOUT="${MCP_TIMEOUT:-30}"
OLLAMA_MODEL="${OLLAMA_MODEL:-codellama}"
OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"

# Logging
log() {
    echo "[MCP Client] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

error() {
    log "ERROR: $*"
    exit 1
}

# Check if Ollama is available
check_ollama() {
    if ! command -v ollama &>/dev/null; then
        log "WARN: Ollama not installed or not in PATH"
        return 1
    fi

    # Check if Ollama service is running
    if ! curl -s --max-time 2 "$OLLAMA_HOST/api/tags" &>/dev/null; then
        log "WARN: Ollama service not reachable at $OLLAMA_HOST"
        return 1
    fi

    return 0
}

# Query Ollama with streaming support
query_ollama() {
    local prompt="$1"
    local system_prompt="${2:-You are a helpful assistant for debugging code and build issues.}"

    if ! check_ollama; then
        echo '{"error": "Ollama not available", "suggestion": "Install Ollama or check service status"}'
        return 1
    fi

    local payload
    payload=$(jq -n \
        --arg model "$OLLAMA_MODEL" \
        --arg prompt "$prompt" \
        --arg system "$system_prompt" \
        '{
            model: $model,
            prompt: $prompt,
            system: $system,
            stream: false,
            options: {
                temperature: 0.3,
                top_p: 0.9
            }
        }')

    local response
    response=$(curl -s --max-time "$MCP_TIMEOUT" \
        -X POST "$OLLAMA_HOST/api/generate" \
        -H "Content-Type: application/json" \
        -d "$payload")

    if [ -z "$response" ]; then
        echo '{"error": "Empty response from Ollama"}'
        return 1
    fi

    echo "$response" | jq -r '.response // .error // "No response"'
}

# Analyze error pattern using AI
analyze_error() {
    local error_pattern="$1"
    local context="${2:-}"

    local prompt="Analyze this error and suggest fixes:

Error: $error_pattern

Context: $context

Provide:
1. Root cause analysis (1-2 sentences)
2. Specific fix suggestion (actionable command or code change)
3. Prevention strategy (1 sentence)

Format as JSON with keys: root_cause, fix_suggestion, prevention"

    local system_prompt="You are an expert in Swift, Xcode, iOS/macOS development, and build systems. Provide concise, actionable analysis."

    query_ollama "$prompt" "$system_prompt"
}

# Suggest fix based on error pattern and knowledge base
suggest_fix() {
    local error_pattern="$1"
    local knowledge_file="$SCRIPT_DIR/knowledge/error_patterns.json"

    if [ ! -f "$knowledge_file" ]; then
        log "ERROR: Knowledge base not found at $knowledge_file"
        echo '{"error": "Knowledge base not available"}'
        return 1
    fi

    # Search for similar patterns in knowledge base
    local similar_patterns
    similar_patterns=$(python3 -c "
import json, sys, hashlib

def stable_hash(text):
    return hashlib.md5(text.encode()).hexdigest()[:8]

query = '$error_pattern'
query_hash = stable_hash(query.lower())

with open('$knowledge_file', 'r') as f:
    patterns = json.load(f)

# Find exact match first
if query_hash in patterns:
    result = patterns[query_hash]
    result['match_type'] = 'exact'
    print(json.dumps(result))
    sys.exit(0)

# Find similar patterns by category
query_lower = query.lower()
matches = []
for hash_key, data in patterns.items():
    pattern = data.get('pattern', '').lower()
    if any(word in pattern for word in query_lower.split() if len(word) > 3):
        data['hash'] = hash_key
        data['match_type'] = 'similar'
        matches.append(data)

if matches:
    # Return most frequent pattern
    matches.sort(key=lambda x: x.get('count', 0), reverse=True)
    print(json.dumps(matches[0]))
else:
    print(json.dumps({'match_type': 'none'}))
" 2>/dev/null) || similar_patterns='{"match_type": "none"}'

    local match_type
    match_type=$(echo "$similar_patterns" | jq -r '.match_type // "none"')

    if [ "$match_type" = "none" ]; then
        log "No similar patterns found in knowledge base, using AI analysis"
        analyze_error "$error_pattern" "First occurrence"
    else
        local known_category
        local known_severity
        local known_count
        known_category=$(echo "$similar_patterns" | jq -r '.category // "unknown"')
        known_severity=$(echo "$similar_patterns" | jq -r '.severity // "medium"')
        known_count=$(echo "$similar_patterns" | jq -r '.count // 1')

        log "Found $match_type match: category=$known_category, severity=$known_severity, seen $known_count times"

        # Enhance with AI if high severity or frequent
        if [ "$known_severity" = "high" ] || [ "$known_count" -gt 5 ]; then
            local ai_analysis
            ai_analysis=$(analyze_error "$error_pattern" "Known $known_category issue, seen $known_count times")

            # Combine knowledge base info with AI analysis
            echo "$similar_patterns" | jq --arg ai "$ai_analysis" '.ai_suggestion = $ai'
        else
            echo "$similar_patterns"
        fi
    fi
}

# Evaluate situation and recommend action
evaluate_situation() {
    local situation_desc="$1"
    local available_actions="${2:-}"

    local prompt="Given this situation, recommend the best action:

Situation: $situation_desc

Available Actions: $available_actions

Provide:
1. Recommended action (must be from available actions)
2. Confidence score (0.0-1.0)
3. Reasoning (1-2 sentences)

Format as JSON with keys: action, confidence, reasoning"

    local system_prompt="You are a build automation expert. Choose actions that are safe, efficient, and likely to succeed."

    query_ollama "$prompt" "$system_prompt"
}

# Verify if an action was successful
verify_outcome() {
    local action_taken="$1"
    local before_state="$2"
    local after_state="$3"

    local prompt="Verify if this action was successful:

Action: $action_taken
Before: $before_state
After: $after_state

Provide:
1. Success (true/false)
2. Confidence (0.0-1.0)
3. Explanation (1 sentence)

Format as JSON with keys: success, confidence, explanation"

    local system_prompt="You are verifying build automation outcomes. Be conservative in success evaluation."

    query_ollama "$prompt" "$system_prompt"
}

# Main command dispatcher
main() {
    local command="${1:-help}"
    shift || true

    case "$command" in
    analyze-error)
        if [ $# -lt 1 ]; then
            error "Usage: mcp_client.sh analyze-error <error_pattern> [context]"
        fi
        analyze_error "$1" "${2:-}"
        ;;
    suggest-fix)
        if [ $# -lt 1 ]; then
            error "Usage: mcp_client.sh suggest-fix <error_pattern>"
        fi
        suggest_fix "$1"
        ;;
    evaluate)
        if [ $# -lt 1 ]; then
            error "Usage: mcp_client.sh evaluate <situation> [available_actions]"
        fi
        evaluate_situation "$1" "${2:-}"
        ;;
    verify)
        if [ $# -lt 3 ]; then
            error "Usage: mcp_client.sh verify <action> <before_state> <after_state>"
        fi
        verify_outcome "$1" "$2" "$3"
        ;;
    test)
        log "Testing MCP client connectivity..."
        if check_ollama; then
            log "✅ Ollama available at $OLLAMA_HOST"
            log "✅ Model: $OLLAMA_MODEL"

            # Test query
            local test_result
            test_result=$(query_ollama "Say 'MCP client is working' in one sentence." "You are a test assistant.")
            log "Test query result: $test_result"
        else
            log "❌ Ollama not available"
            exit 1
        fi
        ;;
    help | --help | -h)
        cat <<EOF
MCP Client - Model Context Protocol Interface

Usage: mcp_client.sh <command> [arguments]

Commands:
  analyze-error <pattern> [context]   Analyze error and suggest fixes
  suggest-fix <pattern>               Get fix suggestion from KB + AI
  evaluate <situation> [actions]      Recommend best action for situation
  verify <action> <before> <after>    Verify if action succeeded
  test                                Test MCP connectivity

Environment Variables:
  OLLAMA_MODEL    Model to use (default: codellama)
  OLLAMA_HOST     Ollama API endpoint (default: http://localhost:11434)
  MCP_TIMEOUT     Query timeout in seconds (default: 30)

Examples:
  mcp_client.sh analyze-error "Build failed: No such module 'SharedKit'"
  mcp_client.sh suggest-fix "xcodebuild: error: Unable to find a destination"
  mcp_client.sh evaluate "Tests failing" "rebuild, clean, update deps"
  mcp_client.sh test
EOF
        ;;
    *)
        error "Unknown command: $command (try 'help')"
        ;;
    esac
}

main "$@"

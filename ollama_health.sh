#!/bin/bash
# ollama_health.sh: Check Ollama health and status
# Outputs JSON: { healthy, issues[], loaded_models[], mem_free_mb }

set -euo pipefail

issues=()
loaded_models=()
healthy=true

# Check if ollama serve is running
if ! pgrep -x "ollama" >/dev/null; then
    issues+=("Ollama serve not running")
    healthy=false
fi

# Check API endpoint
if ! curl -s http://localhost:11434/api/tags >/dev/null; then
    issues+=("Ollama API not reachable")
    healthy=false
fi

# Get loaded models
if loaded_output=$(ollama ps 2>/dev/null); then
    # Parse output (simplified)
    loaded_models=$(echo "$loaded_output" | grep -o '[a-zA-Z0-9:_-]*' | tr '\n' ',' | sed 's/,$//')
else
    issues+=("Cannot list running models")
fi

# Check memory (rough estimate)
mem_free=$(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.')
mem_free_mb=$((mem_free * 4096 / 1024 / 1024)) # Pages to MB

# Output JSON
if [[ ${#issues[@]} -eq 0 ]]; then
    issues_json="[]"
else
    issues_json=$(printf '%s\n' "${issues[@]}" | jq -R . | jq -s .)
fi
jq -n \
    --argjson healthy "$healthy" \
    --argjson issues "$issues_json" \
    --arg loaded_models "$loaded_models" \
    --argjson mem_free_mb "$mem_free_mb" \
    '{healthy: $healthy, issues: $issues, loaded_models: $loaded_models, mem_free_mb: $mem_free_mb}'

#!/bin/bash
# bootstrap_models.sh: Pull all models from registry and log checksums
# Outputs to models_bootstrap.jsonl

set -euo pipefail

MODEL_REGISTRY="${MODEL_REGISTRY:-model_registry.json}"
LOG_FILE="models_bootstrap.jsonl"

# Clear log
>"$LOG_FILE"

# Extract all unique models
models=$(jq -r '.[] | .primaryModel, .fallbacks[]' "$MODEL_REGISTRY" | sort | uniq)

for model in $models; do
    echo "Pulling $model..."
    if ollama pull "$model"; then
        # Get SHA/modification time (simplified)
        sha=$(ollama show "$model" | grep -o 'SHA256:.*' | head -1 || echo "unknown")
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        jq -n \
            --arg model "$model" \
            --arg sha "$sha" \
            --arg timestamp "$timestamp" \
            '{model: $model, sha: $sha, pulled_at: $timestamp}' >>"$LOG_FILE"
    else
        echo "Failed to pull $model" >&2
        exit 1
    fi
done

echo "Bootstrap complete. Models logged to $LOG_FILE"

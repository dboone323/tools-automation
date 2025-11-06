#!/bin/bash
# ollama_client.sh: Unified Ollama adapter for bash scripts
# Reads JSON from stdin: { task, prompt, system?, files[], images[], params? }
# Outputs JSON: { text, model, latency_ms, tokens_est?, fallback_used?, error? }
# Options: --dry-run (print routing without inference), --rollback (revert recent changes)

set -euo pipefail

# Parse command line options
DRY_RUN=false
ROLLBACK=false
while [[ $# -gt 0 ]]; do
    case $1 in
    --dry-run)
        DRY_RUN=true
        shift
        ;;
    --rollback)
        ROLLBACK=true
        shift
        ;;
    *)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
    esac
done

# Config paths
MODEL_REGISTRY="${MODEL_REGISTRY:-model_registry.json}"
RESOURCE_PROFILE="${RESOURCE_PROFILE:-resource_profile.json}"

# Handle rollback functionality
if [[ "$ROLLBACK" == true ]]; then
    echo "Rolling back recent Ollama adapter changes..." >&2

    # Create backup directory if it doesn't exist
    backup_dir="./ollama_backups"
    mkdir -p "$backup_dir"

    # Find and restore most recent backup
    latest_backup=$(ls -t "$backup_dir"/*.json 2>/dev/null | head -1 || echo "")

    if [[ -n "$latest_backup" ]]; then
        cp "$latest_backup" "$MODEL_REGISTRY"
        echo "Restored model registry from: $latest_backup" >&2
        echo '{"status": "rollback_complete", "restored_from": "'$latest_backup'"}'
    else
        echo '{"error": "No backups found for rollback"}' >&2
        exit 1
    fi
    exit 0
fi

# Read input JSON from stdin
input=$(cat)
task=$(echo "$input" | jq -r '.task // empty')
prompt=$(echo "$input" | jq -r '.prompt // empty')
system=$(echo "$input" | jq -r '.system // empty')
files=$(echo "$input" | jq -r '.files // []')
images=$(echo "$input" | jq -r '.images // []')
params=$(echo "$input" | jq -r '.params // {}')

if [[ -z "$task" || -z "$prompt" ]]; then
    echo '{"error": "Missing task or prompt"}' >&2
    exit 1
fi

# Load task config from registry
task_config=$(jq -r ".\"$task\" // empty" "$MODEL_REGISTRY")
if [[ -z "$task_config" ]]; then
    echo '{"error": "Task not found in registry"}' >&2
    exit 1
fi

primary_model=$(echo "$task_config" | jq -r '.primaryModel')
fallbacks=$(echo "$task_config" | jq -r '.fallbacks | join(" ")')
preset=$(echo "$task_config" | jq -r '.preset')
limits=$(echo "$task_config" | jq -r '.limits')

# Build Ollama options from preset
num_ctx=$(echo "$preset" | jq -r '.num_ctx // 2048')
temperature=$(echo "$preset" | jq -r '.temperature // 0.7')
top_p=$(echo "$preset" | jq -r '.top_p // 0.9')
top_k=$(echo "$preset" | jq -r '.top_k // 40')
repeat_penalty=$(echo "$preset" | jq -r '.repeat_penalty // 1.1')
num_predict=$(echo "$preset" | jq -r '.num_predict // 128')

# Resource limits
OLLAMA_NUM_PARALLEL=$(jq -r '.OLLAMA_NUM_PARALLEL // 1' "$RESOURCE_PROFILE")
export OLLAMA_NUM_PARALLEL

# Load chunking settings
CHUNK_LARGE_INPUTS=$(jq -r '.guidance.chunkLargeInputs // false' "$RESOURCE_PROFILE")
CHUNK_SIZE_TOKENS=$(jq -r '.guidance.chunkSizeTokens // 2048' "$RESOURCE_PROFILE")
MAX_CHUNK_OVERLAP=$(jq -r '.guidance.maxChunkOverlap // 512' "$RESOURCE_PROFILE")
MEMORY_AWARE_CHUNKING=$(jq -r '.guidance.memoryAwareChunking // false' "$RESOURCE_PROFILE")

# Function to chunk large prompts
chunk_prompt() {
    local prompt=$1
    local max_tokens=$2
    local overlap=$3

    # Rough token estimation: ~4 chars per token
    local prompt_chars=${#prompt}
    local estimated_tokens=$((prompt_chars / 4))

    if [[ $estimated_tokens -le $max_tokens ]]; then
        echo "$prompt"
        return
    fi

    # Split into chunks with overlap
    local chunk_size_chars=$((max_tokens * 4))
    local overlap_chars=$((overlap * 4))
    local chunks=()

    local start=0
    while [[ $start -lt $prompt_chars ]]; do
        local end=$((start + chunk_size_chars))
        if [[ $end -gt $prompt_chars ]]; then
            end=$prompt_chars
        fi

        local chunk="${prompt:start:end-start}"
        chunks+=("$chunk")

        # Move start position with overlap
        start=$((end - overlap_chars))
        if [[ $start -ge $prompt_chars ]]; then
            break
        fi
    done

    # Return chunks as JSON array
    printf '%s\n' "${chunks[@]}" | jq -R . | jq -s .
}

# Function to process chunked prompt
process_chunked_prompt() {
    local full_prompt=$1
    local model=$2

    if [[ "$CHUNK_LARGE_INPUTS" != "true" ]]; then
        echo "$full_prompt"
        return
    fi

    local chunks
    chunks=$(chunk_prompt "$full_prompt" "$CHUNK_SIZE_TOKENS" "$MAX_CHUNK_OVERLAP")

    # For now, just use the first chunk (can be enhanced to combine results)
    echo "$chunks" | jq -r '.[0] // "'$full_prompt'"'
}

# Function to try a model
try_model() {
    local model=$1

    if [[ "$DRY_RUN" == true ]]; then
        # Dry run mode: just return routing info without inference
        echo "{\"dry_run\": true, \"model\": \"$model\", \"task\": \"$task\", \"routing_info\": \"Would call $model for $task\", \"fallback_used\": false}"
        return 0
    fi

    local start_time=$(date +%s)
    local output
    local exit_code

    # Build prompt with system if provided
    local full_prompt="$prompt"
    if [[ -n "$system" ]]; then
        full_prompt="$system\n\n$prompt"
    fi

    # Apply chunking if enabled
    local processed_prompt
    processed_prompt=$(process_chunked_prompt "$full_prompt" "$model")

    # Call Ollama via generate (for non-interactive)
    output=$(echo "{\"model\": \"$model\", \"prompt\": \"$processed_prompt\", \"stream\": false, \"options\": {\"num_ctx\": $num_ctx, \"temperature\": $temperature, \"top_p\": $top_p, \"top_k\": $top_k, \"repeat_penalty\": $repeat_penalty, \"num_predict\": $num_predict}}" | curl -s -X POST http://localhost:11434/api/generate -H "Content-Type: application/json" -d @- | jq -r '.response // empty')
    exit_code=$?
    if [[ $exit_code -eq 0 && -n "$output" ]]; then
        local end_time=$(date +%s)
        local latency_ms=$(((end_time - start_time) * 1000))
        # Estimate tokens (rough: 4 chars per token, account for chunking)
        local tokens_est=$((${#processed_prompt} / 4 + ${#output} / 4))

        # Log usage metrics to dashboard_data.json
        log_usage_metrics "$task" "$model" "$latency_ms" "$tokens_est" "success"

        echo "{\"text\": \"$output\", \"model\": \"$model\", \"latency_ms\": $latency_ms, \"tokens_est\": $tokens_est, \"fallback_used\": false}"
        return 0
    else
        # Log failed attempt
        log_usage_metrics "$task" "$model" "0" "0" "failed"
        return 1
    fi
}

# Log usage metrics to dashboard_data.json
log_usage_metrics() {
    local task=$1
    local model=$2
    local latency_ms=$3
    local tokens_est=$4
    local status=$5

    local dashboard_file="${DASHBOARD_DATA:-dashboard_data.json}"
    local timestamp=$(date +%s)

    # Create backup before modifying registry (for rollback)
    if [[ "$ROLLBACK" != true && -f "$MODEL_REGISTRY" ]]; then
        local backup_dir="./ollama_backups"
        mkdir -p "$backup_dir"
        local backup_file="$backup_dir/$(basename "$MODEL_REGISTRY" .json)_$(date +%Y%m%d_%H%M%S).json"
        cp "$MODEL_REGISTRY" "$backup_file"
    fi

    # Create or update dashboard data with Ollama metrics
    if [[ -f "$dashboard_file" ]]; then
        # Read existing data and add Ollama metrics
        jq --arg task "$task" --arg model "$model" --argjson latency "$latency_ms" --argjson tokens "$tokens_est" --arg status "$status" --argjson timestamp "$timestamp" '
            .ollama_metrics = (.ollama_metrics // {}) + {
                last_updated: $timestamp,
                total_calls: ((.ollama_metrics.total_calls // 0) + 1),
                successful_calls: ((.ollama_metrics.successful_calls // 0) + (if $status == "success" then 1 else 0 end)),
                failed_calls: ((.ollama_metrics.failed_calls // 0) + (if $status == "failed" then 1 else 0 end)),
                total_latency_ms: ((.ollama_metrics.total_latency_ms // 0) + $latency),
                total_tokens: ((.ollama_metrics.total_tokens // 0) + $tokens),
                task_usage: ((.ollama_metrics.task_usage // {}) | .[$task] = ((.[$task] // 0) + 1)),
                model_usage: ((.ollama_metrics.model_usage // {}) | .[$model] = ((.[$model] // 0) + 1)),
                recent_calls: ((.ollama_metrics.recent_calls // []) + [{
                    timestamp: $timestamp,
                    task: $task,
                    model: $model,
                    latency_ms: $latency,
                    tokens_est: $tokens,
                    status: $status
                }] | .[-10:])  # Keep last 10 calls
            }
        ' "$dashboard_file" >"${dashboard_file}.tmp" && mv "${dashboard_file}.tmp" "$dashboard_file" 2>/dev/null || true
    fi
}

# Try primary, then fallbacks
for model in "$primary_model" $fallbacks; do
    if try_model "$model"; then
        exit 0
    fi
done

# All failed
echo '{"error": "All models failed", "fallback_used": true}' >&2
exit 1

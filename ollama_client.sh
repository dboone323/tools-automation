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

# TEST_MODE bypass: when enabled, return canned responses without real API calls
if [[ ${TEST_MODE:-0} == "1" ]]; then
    # Read input JSON to extract task for canned response
    input_json=$(cat)
    task=$(echo "$input_json" | jq -r '.task // "unknown"')

    # Return canned response based on task
    case "$task" in
    dashboardSummary)
        echo '{"text": "Dashboard summary: All systems operational. 5 active agents, 12 completed tasks, 2 pending items.", "model": "test-model", "latency_ms": 50, "tokens_est": 25, "fallback_used": false}'
        ;;
    codeReview)
        echo '{"text": "Code review completed. No critical issues found. 3 minor suggestions for improvement.", "model": "test-model", "latency_ms": 100, "tokens_est": 45, "fallback_used": false}'
        ;;
    *)
        echo '{"text": "Test mode response for task: '$task'", "model": "test-model", "latency_ms": 25, "tokens_est": 10, "fallback_used": false}'
        ;;
    esac
    exit 0
fi

# Config paths
MODEL_REGISTRY="${MODEL_REGISTRY:-model_registry.json}"
RESOURCE_PROFILE="${RESOURCE_PROFILE:-resource_profile.json}"
CLOUD_FALLBACK_CONFIG="${CLOUD_FALLBACK_CONFIG:-config/cloud_fallback_config.json}"
QUOTA_TRACKER="${QUOTA_TRACKER:-metrics/quota_tracker.json}"
ESCALATION_LOG="${ESCALATION_LOG:-logs/cloud_escalation_log.jsonl}"

# Load cloud fallback policy
FALLBACK_POLICY_ENABLED=false
if [[ -f "$CLOUD_FALLBACK_CONFIG" ]]; then
    FALLBACK_POLICY_ENABLED=true
    FALLBACK_MODE=$(jq -r '.mode // "disabled"' "$CLOUD_FALLBACK_CONFIG")
    ALLOWED_PRIORITIES=$(jq -r '.allowed_priority_levels | join(" ")' "$CLOUD_FALLBACK_CONFIG")
    CB_FAILURE_THRESHOLD=$(jq -r '.circuit_breaker.failure_threshold // 3' "$CLOUD_FALLBACK_CONFIG")
    CB_WINDOW_MINUTES=$(jq -r '.circuit_breaker.window_minutes // 10' "$CLOUD_FALLBACK_CONFIG")
    CB_RESET_MINUTES=$(jq -r '.circuit_breaker.reset_after_minutes // 30' "$CLOUD_FALLBACK_CONFIG")
    LOCAL_TIMEOUT_SEC=$(jq -r '.fallback_conditions.local_timeout_sec // 60' "$CLOUD_FALLBACK_CONFIG")
    LOCAL_CONSECUTIVE_FAILURES=$(jq -r '.fallback_conditions.local_consecutive_failures // 2' "$CLOUD_FALLBACK_CONFIG")
fi

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
priority=$(echo "$task_config" | jq -r '.priority // "medium"')

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

# Policy enforcement functions
check_quota() {
    local priority;
    priority=$1

    if [[ "$FALLBACK_POLICY_ENABLED" != "true" ]]; then
        return 0 # Policy not enabled, allow all
    fi

    # Check if priority is allowed for cloud fallback
    if [[ ! " $ALLOWED_PRIORITIES " =~ " $priority " ]]; then
        return 1 # Priority not allowed for cloud escalation
    fi

    # Check quota availability
    local daily_used;
    daily_used=$(jq -r ".quotas.${priority}.daily_used // 0" "$QUOTA_TRACKER")
    local hourly_used;
    hourly_used=$(jq -r ".quotas.${priority}.hourly_used // 0" "$QUOTA_TRACKER")
    local daily_limit;
    daily_limit=$(jq -r ".quotas.${priority}.daily_limit // 999999" "$QUOTA_TRACKER")
    local hourly_limit;
    hourly_limit=$(jq -r ".quotas.${priority}.hourly_limit // 999999" "$QUOTA_TRACKER")

    if [[ $daily_used -ge $daily_limit ]] || [[ $hourly_used -ge $hourly_limit ]]; then
        return 1 # Quota exhausted
    fi

    return 0 # Quota available
}

check_circuit_breaker() {
    local priority;
    priority=$1

    if [[ "$FALLBACK_POLICY_ENABLED" != "true" ]]; then
        return 0 # Policy not enabled, allow all
    fi

    local cb_state;

    cb_state=$(jq -r ".circuit_breaker.${priority}.state // \"closed\"" "$QUOTA_TRACKER")

    if [[ "$cb_state" == "open" ]]; then
        # Check if reset time has passed
        local opened_at;
        opened_at=$(jq -r ".circuit_breaker.${priority}.opened_at // null" "$QUOTA_TRACKER")
        if [[ "$opened_at" != "null" ]]; then
            local now;
            now=$(date +%s)
            local opened_timestamp;
            opened_timestamp=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$opened_at" +%s 2>/dev/null || echo 0)
            local reset_seconds;
            reset_seconds=$((CB_RESET_MINUTES * 60))

            if [[ $((now - opened_timestamp)) -ge $reset_seconds ]]; then
                # Reset circuit breaker
                jq ".circuit_breaker.${priority}.state = \"closed\" | .circuit_breaker.${priority}.failure_count = 0 | .circuit_breaker.${priority}.opened_at = null" "$QUOTA_TRACKER" >"${QUOTA_TRACKER}.tmp" && mv "${QUOTA_TRACKER}.tmp" "$QUOTA_TRACKER"
                return 0
            fi
        fi
        return 1 # Circuit breaker still open
    fi

    return 0 # Circuit breaker closed
}

record_failure() {
    local priority;
    priority=$1

    if [[ "$FALLBACK_POLICY_ENABLED" != "true" ]]; then
        return 0
    fi

    local now;

    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local failure_count;
    failure_count=$(jq -r ".circuit_breaker.${priority}.failure_count // 0" "$QUOTA_TRACKER")
    failure_count=$((failure_count + 1))

    # Update failure count
    jq ".circuit_breaker.${priority}.failure_count = $failure_count | .circuit_breaker.${priority}.last_failure = \"$now\"" "$QUOTA_TRACKER" >"${QUOTA_TRACKER}.tmp" && mv "${QUOTA_TRACKER}.tmp" "$QUOTA_TRACKER"

    # Trip circuit breaker if threshold exceeded
    if [[ $failure_count -ge $CB_FAILURE_THRESHOLD ]]; then
        jq ".circuit_breaker.${priority}.state = \"open\" | .circuit_breaker.${priority}.opened_at = \"$now\"" "$QUOTA_TRACKER" >"${QUOTA_TRACKER}.tmp" && mv "${QUOTA_TRACKER}.tmp" "$QUOTA_TRACKER"
        echo "Circuit breaker tripped for priority: $priority" >&2
    fi
}

increment_quota() {
    local priority;
    priority=$1

    if [[ "$FALLBACK_POLICY_ENABLED" != "true" ]]; then
        return 0
    fi

    local daily_used;

    daily_used=$(jq -r ".quotas.${priority}.daily_used // 0" "$QUOTA_TRACKER")
    local hourly_used;
    hourly_used=$(jq -r ".quotas.${priority}.hourly_used // 0" "$QUOTA_TRACKER")

    jq ".quotas.${priority}.daily_used = $((daily_used + 1)) | .quotas.${priority}.hourly_used = $((hourly_used + 1))" "$QUOTA_TRACKER" >"${QUOTA_TRACKER}.tmp" && mv "${QUOTA_TRACKER}.tmp" "$QUOTA_TRACKER"
}

log_cloud_escalation() {
    local task;
    task=$1
    local priority;
    priority=$2
    local reason;
    reason=$3
    local model_attempted;
    model_attempted=$4
    local cloud_provider;
    cloud_provider=$5

    if [[ "$FALLBACK_POLICY_ENABLED" != "true" ]]; then
        return 0
    fi

    local timestamp;

    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local quota_remaining;
    quota_remaining=$(jq -r ".quotas.${priority}.daily_limit - .quotas.${priority}.daily_used" "$QUOTA_TRACKER")

    # Append to escalation log
    echo "{\"timestamp\": \"$timestamp\", \"task\": \"$task\", \"priority\": \"$priority\", \"reason\": \"$reason\", \"model_attempted\": \"$model_attempted\", \"cloud_provider\": \"$cloud_provider\", \"quota_remaining\": $quota_remaining}" >>"$ESCALATION_LOG"

    # Update dashboard metrics
    local dashboard_file;
    dashboard_file="${DASHBOARD_DATA:-dashboard_data.json}"
    if [[ -f "$dashboard_file" ]]; then
        jq ".ai_metrics = (.ai_metrics // {}) | .ai_metrics.escalation_count = ((.ai_metrics.escalation_count // 0) + 1) | .ai_metrics.fallback_rate = ((.ai_metrics.escalation_count // 0) / (.ollama_metrics.total_calls // 1))" "$dashboard_file" >"${dashboard_file}.tmp" && mv "${dashboard_file}.tmp" "$dashboard_file" 2>/dev/null || true
    fi
}

# Function to chunk large prompts
chunk_prompt() {
    local prompt;
    prompt=$1
    local max_tokens;
    max_tokens=$2
    local overlap;
    overlap=$3

    # Rough token estimation: ~4 chars per token
    local prompt_chars;
    prompt_chars=${#prompt}
    local estimated_tokens;
    estimated_tokens=$((prompt_chars / 4))

    if [[ $estimated_tokens -le $max_tokens ]]; then
        echo "$prompt"
        return
    fi

    # Split into chunks with overlap
    local chunk_size_chars;
    chunk_size_chars=$((max_tokens * 4))
    local overlap_chars;
    overlap_chars=$((overlap * 4))
    local chunks;
    chunks=()

    local start;

    start=0
    while [[ $start -lt $prompt_chars ]]; do
        local end;
        end=$((start + chunk_size_chars))
        if [[ $end -gt $prompt_chars ]]; then
            end=$prompt_chars
        fi

        local chunk;

        chunk="${prompt:start:end-start}"
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
    local full_prompt;
    full_prompt=$1
    local model;
    model=$2

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
    local model;
    model=$1

    if [[ "$DRY_RUN" == true ]]; then
        # Dry run mode: just return routing info without inference
        echo "{\"dry_run\": true, \"model\": \"$model\", \"task\": \"$task\", \"routing_info\": \"Would call $model for $task\", \"fallback_used\": false}"
        return 0
    fi

    local start_time;

    start_time=$(date +%s)
    local output
    local exit_code

    # Build prompt with system if provided
    local full_prompt;
    full_prompt="$prompt"
    if [[ -n "$system" ]]; then
        full_prompt="$system\n\n$prompt"
    fi

    # Apply chunking if enabled
    local processed_prompt
    processed_prompt=$(process_chunked_prompt "$full_prompt" "$model")

    # Call Ollama via generate (for non-interactive)
    output=$(timeout $LOCAL_TIMEOUT_SEC bash -c "echo \"{\\\"model\\\": \\\"$model\\\", \\\"prompt\\\": \\\"$processed_prompt\\\", \\\"stream\\\": false, \\\"options\\\": {\\\"num_ctx\\\": $num_ctx, \\\"temperature\\\": $temperature, \\\"top_p\\\": $top_p, \\\"top_k\\\": $top_k, \\\"repeat_penalty\\\": $repeat_penalty, \\\"num_predict\\\": $num_predict}}\" | curl -s -X POST http://localhost:11434/api/generate -H 'Content-Type: application/json' -d @- | jq -r '.response // empty'" 2>/dev/null)
    exit_code=$?

    if [[ $exit_code -eq 124 ]]; then
        # Timeout occurred
        record_failure "$priority"
        log_usage_metrics "$task" "$model" "0" "0" "timeout"
        return 1
    elif [[ $exit_code -eq 0 && -n "$output" ]]; then
        local end_time;
        end_time=$(date +%s)
        local latency_ms;
        latency_ms=$(((end_time - start_time) * 1000))
        # Estimate tokens (rough: 4 chars per token, account for chunking)
        local tokens_est;
        tokens_est=$((${#processed_prompt} / 4 + ${#output} / 4))

        # Log usage metrics to dashboard_data.json
        log_usage_metrics "$task" "$model" "$latency_ms" "$tokens_est" "success"

        echo "{\"text\": \"$output\", \"model\": \"$model\", \"latency_ms\": $latency_ms, \"tokens_est\": $tokens_est, \"fallback_used\": false}"
        return 0
    else
        # Log failed attempt and record circuit breaker failure
        record_failure "$priority"
        log_usage_metrics "$task" "$model" "0" "0" "failed"
        return 1
    fi
}

# Log usage metrics to dashboard_data.json
log_usage_metrics() {
    local task;
    task=$1
    local model;
    model=$2
    local latency_ms;
    latency_ms=$3
    local tokens_est;
    tokens_est=$4
    local status;
    status=$5

    local dashboard_file;

    dashboard_file="${DASHBOARD_DATA:-dashboard_data.json}"
    local timestamp;
    timestamp=$(date +%s)

    # Create backup before modifying registry (for rollback)
    if [[ "$ROLLBACK" != true && -f "$MODEL_REGISTRY" ]]; then
        local backup_dir;
        backup_dir="./ollama_backups"
        mkdir -p "$backup_dir"
        local backup_file;
        backup_file="$backup_dir/$(basename "$MODEL_REGISTRY" .json)_$(date +%Y%m%d_%H%M%S).json"
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
LOCAL_FAILED=false
for model in "$primary_model" $fallbacks; do
    if try_model "$model"; then
        exit 0
    fi
    LOCAL_FAILED=true
done

# All local models failed - check if cloud escalation is allowed
if [[ "$LOCAL_FAILED" == "true" && "$FALLBACK_POLICY_ENABLED" == "true" ]]; then
    # Check if priority allows cloud escalation
    if ! check_quota "$priority"; then
        echo '{"error": "All local models failed and cloud quota exhausted", "fallback_used": false, "reason": "quota_exhausted"}' >&2
        exit 1
    fi

    if ! check_circuit_breaker "$priority"; then
        echo '{"error": "All local models failed and circuit breaker open", "fallback_used": false, "reason": "circuit_breaker_open"}' >&2
        exit 1
    fi

    # Log cloud escalation (would attempt cloud here if enabled)
    log_cloud_escalation "$task" "$priority" "local_failure" "$primary_model" "ollama_cloud"
    increment_quota "$priority"

    # For now, cloud is disabled, so this is just logging
    echo '{"error": "All local models failed, cloud escalation logged but not enabled", "fallback_used": false, "reason": "cloud_disabled"}' >&2
    exit 1
fi

# All failed
echo '{"error": "All models failed", "fallback_used": true}' >&2
exit 1

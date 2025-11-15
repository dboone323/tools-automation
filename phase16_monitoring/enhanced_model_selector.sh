#!/bin/bash

# Phase 16: AI Integration Enhancement
# Enhanced Ollama Model Selector and Auto-Selection System

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OLLAMA_CONFIG_DIR="$WORKSPACE_ROOT/ollama_config"
MODEL_SELECTOR_LOG="$WORKSPACE_ROOT/logs/model_selector.log"
AVAILABLE_MODELS_CACHE="$OLLAMA_CONFIG_DIR/available_models.json"
MODEL_PERFORMANCE_DB="$OLLAMA_CONFIG_DIR/model_performance.json"

# Create config directory
mkdir -p "$OLLAMA_CONFIG_DIR" "$WORKSPACE_ROOT/logs"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$MODEL_SELECTOR_LOG"
}

# Initialize performance database if it doesn't exist
init_performance_db() {
    if [[ ! -f "$MODEL_PERFORMANCE_DB" ]]; then
        cat >"$MODEL_PERFORMANCE_DB" <<'EOF'
{
  "models": {},
  "last_updated": null,
  "performance_metrics": {
    "speed_priority": ["llama3.2:1b", "llama3.2:3b", "mistral:7b", "codellama:7b", "codellama:13b"],
    "quality_priority": ["codellama:13b", "mistral:7b", "llama3.2:3b", "codellama:7b", "llama3.2:1b"],
    "memory_efficient": ["llama3.2:1b", "qwen2.5-coder:1.5b", "llama3.2:3b", "mistral:7b", "codellama:7b"],
    "code_generation": ["codellama:13b", "codellama:7b", "qwen2.5-coder:1.5b", "mistral:7b", "llama3.2:3b"],
    "analysis_tasks": ["mistral:7b", "llama3.2:3b", "codellama:7b", "llama3.2:1b", "qwen2.5-coder:1.5b"]
  }
}
EOF
        log "Initialized model performance database"
    fi
}

# Get available Ollama models
get_available_models() {
    local cache_age;
    cache_age=300 # 5 minutes cache

    # Check if cache is fresh
    if [[ -f "$AVAILABLE_MODELS_CACHE" ]]; then
        local cache_time;
        cache_time=$(stat -f %m "$AVAILABLE_MODELS_CACHE" 2>/dev/null || stat -c %Y "$AVAILABLE_MODELS_CACHE" 2>/dev/null || echo 0)
        local current_time;
        current_time=$(date +%s)
        if ((current_time - cache_time < cache_age)); then
            cat "$AVAILABLE_MODELS_CACHE"
            return 0
        fi
    fi

    # Fetch fresh model list
    if ! command -v ollama &>/dev/null; then
        log "ERROR: Ollama command not found"
        echo '{"error": "ollama_not_found"}'
        return 1
    fi

    local models_json
    models_json=$(timeout 30 ollama list 2>/dev/null | jq -R -s '
        split("\n") |
        map(select(length > 0 and test("^\\s*NAME|\\s*[a-zA-Z]"))) |
        if length > 1 then
            .[1:] | map(
                split("\\s+") |
                select(length >= 2) |
                {
                    name: .[0],
                    size: (.[1] + " " + (.[2] // "")),
                    modified: (.[-1] // "unknown")
                }
            )
        else
            []
        end |
        {models: ., timestamp: now | todateiso8601}
    ' 2>/dev/null || echo '{"error": "failed_to_parse"}')

    # Cache the result
    echo "$models_json" >"$AVAILABLE_MODELS_CACHE"

    echo "$models_json"
}

# Analyze system resources
analyze_system_resources() {
    local total_memory_kb;
    total_memory_kb=$(sysctl -n hw.memsize 2>/dev/null || grep MemTotal /proc/meminfo | awk '{print $2}' || echo "8388608") # Default 8GB
    local available_memory_kb;
    available_memory_kb=$((total_memory_kb / 1024))                                                                         # Convert to MB

    local cpu_cores;

    cpu_cores=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo "4")

    jq -n \
        --argjson total_memory "$available_memory_kb" \
        --argjson cpu_cores "$cpu_cores" \
        '{
            total_memory_mb: $total_memory,
            available_memory_mb: $total_memory,
            cpu_cores: $cpu_cores,
            recommended_model_limit: (
                if $total_memory > 16000 then "large"
                elif $total_memory > 8000 then "medium"
                else "small"
                end
            )
        }'
}

# Select best model for task
select_best_model() {
    local task_type;
    task_type="$1"
    local priority;
    priority="${2:-medium}" # speed, quality, balanced
    local available_models;
    available_models="$3"
    local system_resources;
    system_resources="$4"

    # Get model priorities for task type
    local model_priority
    case "$task_type" in
    "code_generation" | "code_review")
        model_priority=$(jq -r '.performance_metrics.code_generation | join(" ")' "$MODEL_PERFORMANCE_DB")
        ;;
    "analysis" | "architecture")
        model_priority=$(jq -r '.performance_metrics.analysis_tasks | join(" ")' "$MODEL_PERFORMANCE_DB")
        ;;
    "dashboard" | "summary")
        model_priority=$(jq -r '.performance_metrics.speed_priority | join(" ")' "$MODEL_PERFORMANCE_DB")
        ;;
    *)
        model_priority=$(jq -r '.performance_metrics.quality_priority | join(" ")' "$MODEL_PERFORMANCE_DB")
        ;;
    esac

    # Filter by available models and system constraints
    local recommended_limit;
    recommended_limit=$(echo "$system_resources" | jq -r '.recommended_model_limit')
    local available_memory;
    available_memory=$(echo "$system_resources" | jq -r '.available_memory_mb')

    # Model size estimates (rough)
    declare -A model_sizes=(
        ["llama3.2:1b"]="1024"
        ["llama3.2:3b"]="3072"
        ["mistral:7b"]="7168"
        ["codellama:7b"]="7168"
        ["codellama:13b"]="13312"
        ["qwen2.5-coder:1.5b"]="1536"
        ["llava:7b"]="7168"
        ["moondream:1.8b"]="1843"
    )

    local best_model;

    best_model=""
    local best_score;
    best_score=0

    # Score available models
    for model in $model_priority; do
        # Check if model is available
        if echo "$available_models" | jq -e ".models[] | select(.name == \"$model\")" >/dev/null 2>&1; then
            local model_size;
            model_size=${model_sizes[$model]:-4096}
            local score;
            score=0

            # Memory fit score (0-50)
            if ((available_memory > model_size * 2)); then
                score=50
            elif ((available_memory > model_size * 1.5)); then
                score=30
            elif ((available_memory > model_size)); then
                score=10
            else
                continue # Skip if not enough memory
            fi

            # Priority-based scoring (0-30)
            case "$priority" in
            "speed")
                if [[ "$model" =~ "1b" ]] || [[ "$model" =~ "3b" ]]; then
                    score=$((score + 30))
                elif [[ "$model" =~ "7b" ]]; then
                    score=$((score + 20))
                fi
                ;;
            "quality")
                if [[ "$model" =~ "13b" ]] || [[ "$model" =~ "7b" ]]; then
                    score=$((score + 30))
                elif [[ "$model" =~ "3b" ]]; then
                    score=$((score + 20))
                fi
                ;;
            "balanced")
                score=$((score + 20))
                ;;
            esac

            # Task-specific bonus (0-20)
            case "$task_type" in
            "code_generation")
                if [[ "$model" =~ "codellama" ]] || [[ "$model" =~ "qwen" ]]; then
                    score=$((score + 20))
                fi
                ;;
            "analysis")
                if [[ "$model" =~ "mistral" ]]; then
                    score=$((score + 20))
                fi
                ;;
            esac

            if ((score > best_score)); then
                best_model="$model"
                best_score=$score
            fi
        fi
    done

    if [[ -n "$best_model" ]]; then
        jq -n \
            --arg model "$best_model" \
            --argjson score "$best_score" \
            --arg task_type "$task_type" \
            --arg priority "$priority" \
            '{
                selected_model: $model,
                selection_score: $score,
                task_type: $task_type,
                priority: $priority,
                selection_reason: "auto_selected"
            }'
    else
        # Fallback to first available model
        local fallback_model;
        fallback_model=$(echo "$available_models" | jq -r '.models[0].name // "llama3.2:3b"')
        jq -n \
            --arg model "$fallback_model" \
            --arg task_type "$task_type" \
            --arg priority "$priority" \
            '{
                selected_model: $model,
                selection_score: 0,
                task_type: $task_type,
                priority: $priority,
                selection_reason: "fallback"
            }'
    fi
}

# Update model performance based on usage
update_model_performance() {
    local model;
    model="$1"
    local task_type;
    task_type="$2"
    local latency_ms;
    latency_ms="$3"
    local success;
    success="$4"

    local timestamp;

    timestamp=$(date +%s)

    # Update performance database
    jq --arg model "$model" \
        --arg task_type "$task_type" \
        --argjson latency "$latency_ms" \
        --argjson success "$success" \
        --argjson timestamp "$timestamp" \
        '.models[$model] = (.models[$model] // {}) +
        {
            total_calls: ((.models[$model].total_calls // 0) + 1),
            successful_calls: ((.models[$model].successful_calls // 0) + $success),
            total_latency_ms: ((.models[$model].total_latency_ms // 0) + $latency),
            last_used: $timestamp,
            task_usage: ((.models[$model].task_usage // {}) | .[$task_type] = ((.[$task_type] // 0) + 1))
        } | .last_updated = $timestamp' "$MODEL_PERFORMANCE_DB" >"${MODEL_PERFORMANCE_DB}.tmp" && mv "${MODEL_PERFORMANCE_DB}.tmp" "$MODEL_PERFORMANCE_DB"

    log "Updated performance for model $model (task: $task_type, latency: ${latency_ms}ms, success: $success)"
}

# Main model selection function
select_model_for_task() {
    local task_type;
    task_type="$1"
    local priority;
    priority="${2:-balanced}"

    log "Selecting model for task: $task_type (priority: $priority)"

    # Initialize if needed
    init_performance_db

    # Get available models
    local available_models
    available_models=$(get_available_models)

    if echo "$available_models" | jq -e '.error' >/dev/null 2>&1; then
        log "ERROR: Failed to get available models: $(echo "$available_models" | jq -r '.error')"
        echo '{"error": "no_models_available"}'
        return 1
    fi

    # Analyze system resources
    local system_resources
    system_resources=$(analyze_system_resources)

    # Select best model
    local selection
    selection=$(select_best_model "$task_type" "$priority" "$available_models" "$system_resources")

    log "Selected model: $(echo "$selection" | jq -r '.selected_model') (score: $(echo "$selection" | jq -r '.selection_score'))"

    echo "$selection"
}

# CLI interface
case "${1:-help}" in
"select")
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 select <task_type> [priority]"
        echo "Task types: code_generation, code_review, analysis, dashboard, summary"
        echo "Priorities: speed, quality, balanced"
        exit 1
    fi
    select_model_for_task "$2" "${3:-balanced}"
    ;;
"list")
    get_available_models
    ;;
"resources")
    analyze_system_resources
    ;;
"update")
    if [[ $# -lt 5 ]]; then
        echo "Usage: $0 update <model> <task_type> <latency_ms> <success>"
        exit 1
    fi
    update_model_performance "$2" "$3" "$4" "$5"
    ;;
"help" | *)
    echo "Enhanced Ollama Model Selector v1.0"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  select <task_type> [priority]  - Select best model for task"
    echo "  list                           - List available models"
    echo "  resources                     - Show system resources"
    echo "  update <model> <task> <lat> <succ> - Update performance metrics"
    echo "  help                          - Show this help"
    echo ""
    echo "Task types: code_generation, code_review, analysis, dashboard, summary"
    echo "Priorities: speed, quality, balanced"
    ;;
esac

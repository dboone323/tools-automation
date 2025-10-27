#!/bin/bash
# Global Agent Configuration
# This file contains centralized configuration for all agents
# Source this file in agents to get consistent throttling settings

# Agent Throttling Configuration
# These can be overridden by environment variables
export MAX_CONCURRENCY="${MAX_CONCURRENCY:-2}" # Maximum concurrent instances per agent
export LOAD_THRESHOLD="${LOAD_THRESHOLD:-4.0}" # System load threshold (1.0 = 100% on single core)
export WAIT_WHEN_BUSY="${WAIT_WHEN_BUSY:-30}"  # Initial seconds to wait when system is busy

# Centralized TODO Processing Configuration
export GLOBAL_AGENT_CAP="${GLOBAL_AGENT_CAP:-10}"           # Maximum total agents that can be assigned tasks
export TODO_MONITOR_INTERVAL="${TODO_MONITOR_INTERVAL:-60}" # TODO monitor check interval (seconds)
export TODO_MIN_IDLE_TIME="${TODO_MIN_IDLE_TIME:-300}"      # Agents must be idle for this many seconds before triggering TODOs

# Agent-Specific Overrides (uncomment and modify as needed)
# export MAX_CONCURRENCY_agent_debug=1        # Debug agent: more conservative
# export MAX_CONCURRENCY_agent_build=3        # Build agent: can handle more concurrency
# export MAX_CONCURRENCY_agent_codegen=2      # Codegen agent: default
# export LOAD_THRESHOLD_high_priority=3.0     # Lower threshold for critical agents
# export LOAD_THRESHOLD_low_priority=5.0      # Higher threshold for background agents

# Function to get agent-specific configuration
get_agent_config() {
    local agent_name="$1"
    local config_key="$2"
    local default_value="$3"

    # Check for agent-specific override
    local agent_specific_var="${config_key}_${agent_name}"
    local value="${!agent_specific_var:-$default_value}"

    echo "$value"
}

# Logging configuration
export AGENT_LOG_LEVEL="${AGENT_LOG_LEVEL:-INFO}"           # DEBUG, INFO, WARN, ERROR
export AGENT_LOG_MAX_SIZE="${AGENT_LOG_MAX_SIZE:-10485760}" # 10MB max log size
export AGENT_LOG_RETENTION="${AGENT_LOG_RETENTION:-7}"      # Days to keep logs

# Performance monitoring
export AGENT_PERF_MONITOR="${AGENT_PERF_MONITOR:-true}"                  # Enable performance monitoring
export AGENT_HEALTH_CHECK_INTERVAL="${AGENT_HEALTH_CHECK_INTERVAL:-300}" # Health check every 5 minutes

# Backup and recovery
export AGENT_AUTO_BACKUP="${AGENT_AUTO_BACKUP:-true}"          # Enable automatic backups
export AGENT_BACKUP_INTERVAL="${AGENT_BACKUP_INTERVAL:-86400}" # Daily backups
export AGENT_BACKUP_RETENTION="${AGENT_BACKUP_RETENTION:-30}"  # Keep backups for 30 days

# Resource limits
export AGENT_MAX_MEMORY="${AGENT_MAX_MEMORY:-512}" # MB per agent process
export AGENT_MAX_CPU="${AGENT_MAX_CPU:-50}"        # CPU percentage per agent
export AGENT_TIMEOUT="${AGENT_TIMEOUT:-3600}"      # Max runtime per task (seconds)

# Network and API configuration
export AGENT_API_TIMEOUT="${AGENT_API_TIMEOUT:-30}"      # API call timeout (seconds)
export AGENT_RETRY_ATTEMPTS="${AGENT_RETRY_ATTEMPTS:-3}" # Number of retry attempts
export AGENT_RETRY_DELAY="${AGENT_RETRY_DELAY:-5}"       # Delay between retries (seconds)

# Development and testing
export AGENT_SINGLE_RUN="${SINGLE_RUN:-false}" # Exit after one cycle (for testing)
export AGENT_DRY_RUN="${DRY_RUN:-false}"       # Don't make actual changes (for testing)
export AGENT_VERBOSE="${VERBOSE:-false}"       # Enable verbose logging

# Emergency controls
export AGENT_EMERGENCY_STOP="${EMERGENCY_STOP:-false}"     # Stop all agents immediately
export AGENT_MAINTENANCE_MODE="${MAINTENANCE_MODE:-false}" # Put system in maintenance mode

# Configuration validation
validate_config() {
    local errors=0

    # Validate MAX_CONCURRENCY
    if ! [[ "$MAX_CONCURRENCY" =~ ^[0-9]+$ ]] || [[ "$MAX_CONCURRENCY" -lt 1 ]]; then
        echo "ERROR: MAX_CONCURRENCY must be a positive integer, got: $MAX_CONCURRENCY"
        ((errors++))
    fi

    # Validate LOAD_THRESHOLD
    if ! [[ "$LOAD_THRESHOLD" =~ ^[0-9]*\.?[0-9]+$ ]]; then
        echo "ERROR: LOAD_THRESHOLD must be a number, got: $LOAD_THRESHOLD"
        ((errors++))
    fi

    # Validate WAIT_WHEN_BUSY
    if ! [[ "$WAIT_WHEN_BUSY" =~ ^[0-9]+$ ]] || [[ "$WAIT_WHEN_BUSY" -lt 1 ]]; then
        echo "ERROR: WAIT_WHEN_BUSY must be a positive integer, got: $WAIT_WHEN_BUSY"
        ((errors++))
    fi

    # Validate GLOBAL_AGENT_CAP
    if ! [[ "$GLOBAL_AGENT_CAP" =~ ^[0-9]+$ ]] || [[ "$GLOBAL_AGENT_CAP" -lt 1 ]]; then
        echo "ERROR: GLOBAL_AGENT_CAP must be a positive integer, got: $GLOBAL_AGENT_CAP"
        ((errors++))
    fi

    if [[ $errors -gt 0 ]]; then
        echo "Configuration validation failed with $errors errors"
        return 1
    fi

    echo "Configuration validation passed"
    return 0
}

# Auto-validate on source
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being run directly
    validate_config
else
    # Script is being sourced
    if ! validate_config >/dev/null 2>&1; then
        echo "WARNING: Agent configuration validation failed. Using defaults."
    fi
fi

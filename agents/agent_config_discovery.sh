#!/usr/bin/env bash

# ══════════════════════════════════════════════════════════════
# Enhanced with Agent Autonomy Features
# ══════════════════════════════════════════════════════════════

# Dynamic Configuration Discovery
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/agent_config_discovery.sh" ]]; then
    source "${SCRIPT_DIR}/agent_config_discovery.sh" 2>/dev/null || true
    WORKSPACE_ROOT=$(get_workspace_root 2>/dev/null || echo "${WORKSPACE_ROOT:-$HOME/workspace}")
    MCP_URL=$(get_mcp_url 2>/dev/null || echo "${MCP_URL:-http://127.0.0.1:5000}")
fi

# AI Decision Helpers (uncomment to enable)
# if [[ -f "${SCRIPT_DIR}/../monitoring/ai_helpers.sh" ]]; then
#     source "${SCRIPT_DIR}/../monitoring/ai_helpers.sh"
# fi

# ══════════════════════════════════════════════════════════════

# Agent Configuration Discovery System
# Provides dynamic workspace and configuration discovery for all agents
# Eliminates hardcoded paths and enables environment-agnostic operation

set -euo pipefail

# Version
CONFIG_DISCOVERY_VERSION="1.0.0"

# Cache file for discovered configuration
CONFIG_CACHE_FILE="${HOME}/.agent_config_cache.json"
CONFIG_CACHE_TTL=300  # 5 minutes cache validity

# ============================================================================
# Core Discovery Functions
# ============================================================================

# Discover workspace root by searching for marker files
discover_workspace_root() {
    local search_start="${1:-$(pwd)}"
    local markers=(".git" "tools-automation" "agents")
    
    # Check environment variable first
    if [[ -n "${AGENT_WORKSPACE_ROOT:-}" ]] && [[ -d "${AGENT_WORKSPACE_ROOT}" ]]; then
        echo "${AGENT_WORKSPACE_ROOT}"
        return 0
    fi
    
    # Search upward from current directory
    local current_dir="$search_start"
    while [[ "$current_dir" != "/" ]]; do
        # Prefer directory containing tools-automation subdirectory
        if [[ -d "${current_dir}/tools-automation" ]]; then
            echo "$current_dir"
            return 0
        fi
        
        # Check for workspace markers
        for marker in "${markers[@]}"; do
            if [[ -e "${current_dir}/${marker}" ]]; then
                # If we find tools-automation directory itself, go up one level
                if [[ "$(basename "$current_dir")" == "tools-automation" ]]; then
                    echo "$(dirname "$current_dir")"
                    return 0
                fi
                
                # Validate this is a reasonable workspace
                if [[ -d "${current_dir}/Projects" ]] || [[ -d "${current_dir}/tools-automation" ]]; then
                    echo "$current_dir"
                    return 0
                fi
            fi
        done
        current_dir="$(dirname "$current_dir")"
    done
    
    # Fallback: Check common locations
    local common_locations=(
        "${HOME}/Desktop/github-projects"
        "${HOME}/Desktop/Quantum-workspace"
        "${HOME}/Projects"
        "${HOME}/workspace"
        "/opt/workspace"
    )
    
    for location in "${common_locations[@]}"; do
        if [[ -d "$location/tools-automation" ]] || [[ -d "$location/agents" ]]; then
            echo "$location"
            return 0
        fi
    done
    
    # Ultimate fallback
    echo "${HOME}/workspace"
    return 1
}

# Discover tools-automation directory
discover_tools_automation_dir() {
    local workspace_root="${1:-$(discover_workspace_root)}"
    
    if [[ -n "${AGENT_TOOLS_DIR:-}" ]] && [[ -d "${AGENT_TOOLS_DIR}" ]]; then
        echo "${AGENT_TOOLS_DIR}"
        return 0
    fi
    
    # Common patterns
    local candidates=(
        "${workspace_root}/tools-automation"
        "${workspace_root}/Tools/Automation"
        "${workspace_root}/.automation"
    )
    
    for candidate in "${candidates[@]}"; do
        if [[ -d "$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
    done
    
    echo "${workspace_root}/tools-automation"
    return 1
}

# Discover agents directory
discover_agents_dir() {
    local tools_dir="${1:-$(discover_tools_automation_dir)}"
    
    if [[ -n "${AGENT_DIR:-}" ]] && [[ -d "${AGENT_DIR}" ]]; then
        echo "${AGENT_DIR}"
        return 0
    fi
    
    local candidates=(
        "${tools_dir}/agents"
        "${tools_dir}/Automation/agents"
        "$(dirname "$tools_dir")/agents"
    )
    
    for candidate in "${candidates[@]}"; do
        if [[ -d "$candidate" ]] && [[ -f "${candidate}/shared_functions.sh" ]]; then
            echo "$candidate"
            return 0
        fi
    done
    
    echo "${tools_dir}/agents"
    return 1
}

# Discover MCP server URL
discover_mcp_url() {
    if [[ -n "${MCP_URL:-}" ]]; then
        echo "${MCP_URL}"
        return 0
    fi
    
    # Check if MCP server is running locally
    local default_port=5005
    for port in 5005 5000 8080 3000; do
        if curl -s "http://127.0.0.1:${port}/status" > /dev/null 2>&1; then
            echo "http://127.0.0.1:${port}"
            return 0
        fi
    done
    
    echo "http://127.0.0.1:${default_port}"
    return 0
}

# Discover all projects in workspace
discover_projects() {
    local workspace_root="${1:-$(discover_workspace_root)}"
    local projects_dir="${workspace_root}/Projects"
    
    if [[ ! -d "$projects_dir" ]]; then
        # Try alternate location
        projects_dir="${workspace_root}"
    fi
    
    find "$projects_dir" -maxdepth 2 -type f \( -name "Package.swift" -o -name "*.xcodeproj" -o -name "package.json" \) -exec dirname {} \; | sort -u | while read -r project_path; do
        basename "$project_path"
    done
}

# ============================================================================
# Configuration Caching
# ============================================================================

# Save discovered configuration to cache
save_config_cache() {
    local workspace_root="$1"
    local tools_dir="$2"
    local agents_dir="$3"
    local mcp_url="$4"
    
    cat > "$CONFIG_CACHE_FILE" <<EOF
{
  "version": "${CONFIG_DISCOVERY_VERSION}",
  "timestamp": $(date +%s),
  "workspace_root": "${workspace_root}",
  "tools_automation_dir": "${tools_dir}",
  "agents_dir": "${agents_dir}",
  "mcp_url": "${mcp_url}",
  "projects": $(discover_projects "$workspace_root" | jq -R . | jq -s .)
}
EOF
    chmod 600 "$CONFIG_CACHE_FILE"
}

# Load cached configuration if valid
load_config_cache() {
    if [[ ! -f "$CONFIG_CACHE_FILE" ]]; then
        return 1
    fi
    
    local cache_timestamp
    cache_timestamp=$(jq -r '.timestamp // 0' "$CONFIG_CACHE_FILE" 2>/dev/null || echo 0)
    local current_time
    current_time=$(date +%s)
    local age=$((current_time - cache_timestamp))
    
    if [[ $age -gt $CONFIG_CACHE_TTL ]]; then
        return 1
    fi
    
    # Validate cached paths still exist
    local workspace_root
    workspace_root=$(jq -r '.workspace_root' "$CONFIG_CACHE_FILE" 2>/dev/null || echo "")
    if [[ -z "$workspace_root" ]] || [[ ! -d "$workspace_root" ]]; then
        return 1
    fi
    
    return 0
}

# Get configuration value from cache
get_cached_config() {
    local key="$1"
    if load_config_cache; then
        jq -r ".${key} // \"\"" "$CONFIG_CACHE_FILE" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# ============================================================================
# Main Configuration Discovery
# ============================================================================

# Discover and return all configuration
discover_all_config() {
    local use_cache="${1:-true}"
    
    # Try cache first if enabled
    if [[ "$use_cache" == "true" ]] && load_config_cache; then
        cat "$CONFIG_CACHE_FILE"
        return 0
    fi
    
    # Perform fresh discovery
    local workspace_root
    workspace_root=$(discover_workspace_root)
    
    local tools_dir
    tools_dir=$(discover_tools_automation_dir "$workspace_root")
    
    local agents_dir
    agents_dir=$(discover_agents_dir "$tools_dir")
    
    local mcp_url
    mcp_url=$(discover_mcp_url)
    
    # Save to cache
    save_config_cache "$workspace_root" "$tools_dir" "$agents_dir" "$mcp_url"
    
    cat "$CONFIG_CACHE_FILE"
}

# ============================================================================
# Convenience Functions for Agents
# ============================================================================

# Get workspace root (cached)
get_workspace_root() {
    local cached
    cached=$(get_cached_config "workspace_root")
    if [[ -n "$cached" ]]; then
        echo "$cached"
    else
        discover_workspace_root
    fi
}

# Get tools automation directory (cached)
get_tools_automation_dir() {
    local cached
    cached=$(get_cached_config "tools_automation_dir")
    if [[ -n "$cached" ]]; then
        echo "$cached"
    else
        discover_tools_automation_dir
    fi
}

# Get agents directory (cached)
get_agents_dir() {
    local cached
    cached=$(get_cached_config "agents_dir")
    if [[ -n "$cached" ]]; then
        echo "$cached"
    else
        discover_agents_dir
    fi
}

# Get MCP URL (cached)
get_mcp_url() {
    local cached
    cached=$(get_cached_config "mcp_url")
    if [[ -n "$cached" ]]; then
        echo "$cached"
    else
        discover_mcp_url
    fi
}

# ============================================================================
# CLI Interface
# ============================================================================

show_usage() {
    cat <<EOF
Agent Configuration Discovery v${CONFIG_DISCOVERY_VERSION}

USAGE:
    source agent_config_discovery.sh        # Load functions into shell
    agent_config_discovery.sh [command]     # Run commands

COMMANDS:
    discover                 # Discover and display all configuration
    workspace-root          # Show workspace root directory
    tools-dir               # Show tools-automation directory
    agents-dir              # Show agents directory
    mcp-url                 # Show MCP server URL
    projects                # List all projects
    clear-cache             # Clear configuration cache
    validate                # Validate discovered configuration
    export                  # Export configuration as environment variables
    help                    # Show this help message

ENVIRONMENT VARIABLES:
    AGENT_WORKSPACE_ROOT    # Override workspace root discovery
    AGENT_TOOLS_DIR         # Override tools-automation directory
    AGENT_DIR               # Override agents directory
    MCP_URL                 # Override MCP server URL

EXAMPLES:
    # Discover all configuration
    ./agent_config_discovery.sh discover

    # Get workspace root
    WORKSPACE=\$(./agent_config_discovery.sh workspace-root)

    # Source in agent scripts
    source \$(dirname "\$0")/agent_config_discovery.sh
    WORKSPACE_ROOT=\$(get_workspace_root)
    MCP_URL=\$(get_mcp_url)
EOF
}

# Validate discovered configuration
validate_config() {
    local workspace_root
    workspace_root=$(get_workspace_root)
    
    local tools_dir
    tools_dir=$(get_tools_automation_dir)
    
    local agents_dir
    agents_dir=$(get_agents_dir)
    
    echo "🔍 Validating configuration..."
    echo ""
    
    local errors=0
    
    # Check workspace root
    if [[ -d "$workspace_root" ]]; then
        echo "✅ Workspace root: $workspace_root"
    else
        echo "❌ Workspace root not found: $workspace_root"
        ((errors++))
    fi
    
    # Check tools directory
    if [[ -d "$tools_dir" ]]; then
        echo "✅ Tools automation: $tools_dir"
    else
        echo "⚠️  Tools automation not found: $tools_dir"
        ((errors++))
    fi
    
    # Check agents directory
    if [[ -d "$agents_dir" ]]; then
        echo "✅ Agents directory: $agents_dir"
        
        # Count agents
        local agent_count
        agent_count=$(find "$agents_dir" -maxdepth 1 -name "agent_*.sh" -o -name "*_agent.sh" | wc -l | tr -d ' ')
        echo "   Found ${agent_count} agent scripts"
    else
        echo "⚠️  Agents directory not found: $agents_dir"
        ((errors++))
    fi
    
    # Check MCP server
    local mcp_url
    mcp_url=$(get_mcp_url)
    if curl -s "${mcp_url}/status" > /dev/null 2>&1; then
        echo "✅ MCP server: $mcp_url (online)"
    else
        echo "⚠️  MCP server: $mcp_url (offline)"
    fi
    
    echo ""
    if [[ $errors -eq 0 ]]; then
        echo "✅ Configuration valid"
        return 0
    else
        echo "❌ Configuration has ${errors} errors"
        return 1
    fi
}

# Export configuration as environment variables
export_config() {
    cat <<EOF
export AGENT_WORKSPACE_ROOT="$(get_workspace_root)"
export AGENT_TOOLS_DIR="$(get_tools_automation_dir)"
export AGENT_DIR="$(get_agents_dir)"
export MCP_URL="$(get_mcp_url)"
EOF
}

# ============================================================================
# Main Entry Point
# ============================================================================

# Only run if executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    command="${1:-help}"
    
    case "$command" in
        discover)
            discover_all_config false | jq .
            ;;
        workspace-root)
            get_workspace_root
            ;;
        tools-dir)
            get_tools_automation_dir
            ;;
        agents-dir)
            get_agents_dir
            ;;
        mcp-url)
            get_mcp_url
            ;;
        projects)
            discover_projects | jq -R . | jq -s .
            ;;
        clear-cache)
            rm -f "$CONFIG_CACHE_FILE"
            echo "✅ Cache cleared"
            ;;
        validate)
            validate_config
            ;;
        export)
            export_config
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            echo "Unknown command: $command"
            echo "Run 'agent_config_discovery.sh help' for usage"
            exit 1
            ;;
    esac
fi

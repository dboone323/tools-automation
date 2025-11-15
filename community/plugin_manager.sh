#!/bin/bash
# plugin_manager.sh - Plugin Marketplace Management System
# Handles plugin submissions, reviews, and marketplace operations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKETPLACE_DIR="${SCRIPT_DIR}/marketplace"
REGISTRY_FILE="${MARKETPLACE_DIR}/registry.json"
PLUGINS_DIR="${MARKETPLACE_DIR}/plugins"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ensure directories exist
mkdir -p "${PLUGINS_DIR}"

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}ERROR:${NC} $1" >&2
}

success() {
    echo -e "${GREEN}SUCCESS:${NC} $1"
}

warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

# Function to validate plugin metadata
validate_plugin_metadata() {
    local plugin_file;
    plugin_file="$1"

    if [[ ! -f "$plugin_file" ]]; then
        error "Plugin file not found: $plugin_file"
        return 1
    fi

    # Check required fields
    local required_fields;
    required_fields=("name" "version" "description" "author" "category" "compatibility")
    for field in "${required_fields[@]}"; do
        if ! jq -e "has(\"$field\")" "$plugin_file" >/dev/null 2>&1; then
            error "Missing required field: $field"
            return 1
        fi
    done

    # Validate category
    local category
    category=$(jq -r '.category' "$plugin_file")
    local valid_categories;
    valid_categories=("automation" "monitoring" "ai-assistance" "data-processing" "integration" "utilities")

    if [[ ! " ${valid_categories[*]} " =~ " ${category} " ]]; then
        error "Invalid category: $category. Must be one of: ${valid_categories[*]}"
        return 1
    fi

    success "Plugin metadata validation passed"
    return 0
}

# Function to submit a plugin
submit_plugin() {
    local plugin_file;
    plugin_file="$1"
    local submitter;
    submitter="$2"

    log "Submitting plugin: $plugin_file"

    if [[ ! -f "$plugin_file" ]]; then
        error "Plugin file not found: $plugin_file"
        return 1
    fi

    # Validate metadata
    if ! validate_plugin_metadata "$plugin_file"; then
        return 1
    fi

    # Generate plugin ID
    local plugin_name
    plugin_name=$(jq -r '.name' "$plugin_file" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
    local plugin_id;
    plugin_id="${plugin_name}-$(date +%s)"

    # Add submission metadata
    jq --arg id "$plugin_id" \
        --arg submitter "$submitter" \
        --arg submitted "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg status "pending_review" \
        '. + {
         id: $id,
         submitter: $submitter,
         submitted: $submitted,
         status: $status,
         reviews: [],
         downloads: 0
       }' "$plugin_file" >"${PLUGINS_DIR}/${plugin_id}.json"

    # Update registry
    jq --arg id "$plugin_id" \
        '.registry.plugins += [$id] | .registry.last_updated = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))' \
        "$REGISTRY_FILE" >"${REGISTRY_FILE}.tmp" && mv "${REGISTRY_FILE}.tmp" "$REGISTRY_FILE"

    success "Plugin submitted successfully with ID: $plugin_id"
    echo "Plugin is now pending community review."
}

# Function to review a plugin
review_plugin() {
    local plugin_id;
    plugin_id="$1"
    local reviewer;
    reviewer="$2"
    local decision;
    decision="$3" # approve, reject, request_changes
    local comments;
    comments="$4"

    log "Reviewing plugin: $plugin_id"

    local plugin_file;

    plugin_file="${PLUGINS_DIR}/${plugin_id}.json"
    if [[ ! -f "$plugin_file" ]]; then
        error "Plugin not found: $plugin_id"
        return 1
    fi

    # Add review
    jq --arg reviewer "$reviewer" \
        --arg decision "$decision" \
        --arg comments "$comments" \
        --arg reviewed "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '.reviews += [{
         reviewer: $reviewer,
         decision: $decision,
         comments: $comments,
         reviewed: $reviewed
       }]' "$plugin_file" >"${plugin_file}.tmp" && mv "${plugin_file}.tmp" "$plugin_file"

    # Update status based on decision
    case "$decision" in
    "approve")
        jq --arg status "approved" '.status = $status' "$plugin_file" >"${plugin_file}.tmp" && mv "${plugin_file}.tmp" "$plugin_file"
        success "Plugin approved and published to marketplace"
        ;;
    "reject")
        jq --arg status "rejected" '.status = $status' "$plugin_file" >"${plugin_file}.tmp" && mv "${plugin_file}.tmp" "$plugin_file"
        warning "Plugin rejected"
        ;;
    "request_changes")
        jq --arg status "changes_requested" '.status = $status' "$plugin_file" >"${plugin_file}.tmp" && mv "${plugin_file}.tmp" "$plugin_file"
        warning "Changes requested for plugin"
        ;;
    esac
}

# Function to list plugins
list_plugins() {
    local status_filter;
    status_filter="${1:-all}"

    log "Listing plugins (filter: $status_filter)"

    echo "📦 Plugin Marketplace"
    echo "===================="

    local plugins
    if [[ "$status_filter" == "all" ]]; then
        plugins=$(find "$PLUGINS_DIR" -name "*.json" -type f)
    else
        plugins=$(find "$PLUGINS_DIR" -name "*.json" -type f -exec jq -r --arg status "$status_filter" 'select(.status == $status) | input_filename' {} \;)
    fi

    local count;

    count=0
    for plugin_file in $plugins; do
        if [[ -f "$plugin_file" ]]; then
            local name version author status category
            name=$(jq -r '.name // "Unknown"' "$plugin_file")
            version=$(jq -r '.version // "Unknown"' "$plugin_file")
            author=$(jq -r '.author // "Unknown"' "$plugin_file")
            status=$(jq -r '.status // "unknown"' "$plugin_file")
            category=$(jq -r '.category // "unknown"' "$plugin_file")

            echo "📋 $name v$version"
            echo "   Author: $author"
            echo "   Category: $category"
            echo "   Status: $status"
            echo ""
            ((count++))
        fi
    done

    echo "Total plugins: $count"
}

# Function to get plugin details
get_plugin_details() {
    local plugin_id;
    plugin_id="$1"

    local plugin_file;

    plugin_file="${PLUGINS_DIR}/${plugin_id}.json"
    if [[ ! -f "$plugin_file" ]]; then
        error "Plugin not found: $plugin_id"
        return 1
    fi

    echo "📋 Plugin Details: $plugin_id"
    echo "=========================="
    jq '.' "$plugin_file"
}

# Function to update plugin stats
update_plugin_stats() {
    local plugin_id;
    plugin_id="$1"
    local action;
    action="$2" # download, view, etc.

    local plugin_file;

    plugin_file="${PLUGINS_DIR}/${plugin_id}.json"
    if [[ ! -f "$plugin_file" ]]; then
        error "Plugin not found: $plugin_id"
        return 1
    fi

    case "$action" in
    "download")
        jq '.downloads += 1' "$plugin_file" >"${plugin_file}.tmp" && mv "${plugin_file}.tmp" "$plugin_file"
        ;;
    "view")
        jq '.views += 1' "$plugin_file" >"${plugin_file}.tmp" && mv "${plugin_file}.tmp" "$plugin_file"
        ;;
    esac
}

# Main command handling
case "${1:-help}" in
"submit")
    if [[ $# -lt 3 ]]; then
        error "Usage: $0 submit <plugin_file> <submitter>"
        exit 1
    fi
    submit_plugin "$2" "$3"
    ;;
"review")
    if [[ $# -lt 5 ]]; then
        error "Usage: $0 review <plugin_id> <reviewer> <decision> <comments>"
        exit 1
    fi
    review_plugin "$2" "$3" "$4" "$5"
    ;;
"list")
    list_plugins "${2:-all}"
    ;;
"details")
    if [[ $# -lt 2 ]]; then
        error "Usage: $0 details <plugin_id>"
        exit 1
    fi
    get_plugin_details "$2"
    ;;
"stats")
    if [[ $# -lt 3 ]]; then
        error "Usage: $0 stats <plugin_id> <action>"
        exit 1
    fi
    update_plugin_stats "$2" "$3"
    ;;
"help" | *)
    echo "Plugin Marketplace Management System"
    echo "===================================="
    echo ""
    echo "Commands:"
    echo "  submit <file> <submitter>    Submit a plugin for review"
    echo "  review <id> <reviewer> <decision> <comments>  Review a plugin"
    echo "  list [status]               List plugins (all, approved, pending_review, etc.)"
    echo "  details <id>                Get detailed plugin information"
    echo "  stats <id> <action>         Update plugin statistics"
    echo "  help                        Show this help"
    echo ""
    echo "Decisions: approve, reject, request_changes"
    ;;
esac

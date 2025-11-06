#!/bin/bash
# Keychain secrets management for tools-automation

set -e

KEYCHAIN_SERVICE="tools-automation"

get_secret() {
    local key="$1"
    local service="${KEYCHAIN_SERVICE}-${key}"

    if security find-generic-password -a "$USER" -s "$service" -w 2>/dev/null; then
        return 0
    else
        echo "ERROR: Secret not found for key: $key" >&2
        return 1
    fi
}

set_secret() {
    local key="$1"
    local value="$2"
    local service="${KEYCHAIN_SERVICE}-${key}"

    # Try to add, if exists delete and re-add
    if ! security add-generic-password -a "$USER" -s "$service" -w "$value" -U 2>/dev/null; then
        security delete-generic-password -a "$USER" -s "$service" 2>/dev/null || true
        security add-generic-password -a "$USER" -s "$service" -w "$value" -U
    fi

    echo "✓ Secret stored for key: $key"
}

delete_secret() {
    local key="$1"
    local service="${KEYCHAIN_SERVICE}-${key}"

    if security delete-generic-password -a "$USER" -s "$service" 2>/dev/null; then
        echo "✓ Secret deleted for key: $key"
        return 0
    else
        echo "ERROR: Secret not found for key: $key" >&2
        return 1
    fi
}

list_secrets() {
    echo "Searching for ${KEYCHAIN_SERVICE}-* secrets..."
    security dump-keychain 2>/dev/null | grep -o "${KEYCHAIN_SERVICE}-[a-zA-Z0-9_-]*" | sort -u || echo "No secrets found"
}

# Main
case "$1" in
get)
    get_secret "$2"
    ;;
set)
    if [[ -z "$3" ]]; then
        echo "Usage: $0 set <key> <value>"
        exit 1
    fi
    set_secret "$2" "$3"
    ;;
delete)
    delete_secret "$2"
    ;;
list)
    list_secrets
    ;;
*)
    echo "Usage: $0 {get|set|delete|list} [key] [value]"
    echo ""
    echo "Examples:"
    echo "  $0 set mcp-token abc123"
    echo "  $0 get mcp-token"
    echo "  $0 delete mcp-token"
    echo "  $0 list"
    exit 1
    ;;
esac

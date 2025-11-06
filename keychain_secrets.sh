#!/bin/bash
# keychain_secrets.sh: Manage secrets in macOS Keychain
# Usage: get_secret <service> or set_secret <service> <value>

set -euo pipefail

get_secret() {
    local service=$1
    security find-generic-password -s "$service" -w 2>/dev/null || echo ""
}

set_secret() {
    local service=$1
    local value=$2
    security add-generic-password -s "$service" -w "$value" 2>/dev/null ||
        security add-generic-password -U -s "$service" -w "$value"
}

case "${1:-}" in
get_secret)
    get_secret "$2"
    ;;
set_secret)
    set_secret "$2" "$3"
    ;;
*)
    echo "Usage: $0 get_secret <service> or set_secret <service> <value>" >&2
    exit 1
    ;;
esac

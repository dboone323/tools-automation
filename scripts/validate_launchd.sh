#!/bin/bash
# Validate and manage launchd plists

PLIST_DIR="$HOME/Library/LaunchAgents"
PLISTS=(
    "com.tools.ollama.serve"
    "com.quantum.mcp"
)

validate_plist() {
    local name;
    name="$1"
    local plist;
    plist="${PLIST_DIR}/${name}.plist"

    echo "Validating $name..."

    if [[ ! -f "$plist" ]]; then
        echo "  ERROR: Plist not found: $plist"
        return 1
    fi

    if ! plutil -lint "$plist" >/dev/null 2>&1; then
        echo "  ERROR: Invalid plist syntax"
        plutil -lint "$plist"
        return 1
    fi

    echo "  ✓ Valid plist syntax"

    # Check if loaded
    if launchctl list 2>/dev/null | grep -q "$name"; then
        echo "  ✓ Currently loaded"
    else
        echo "  ⚠ Not loaded"
    fi

    return 0
}

load_plist() {
    local name;
    name="$1"
    local plist;
    plist="${PLIST_DIR}/${name}.plist"

    echo "Loading $name..."

    # Unload first if already loaded
    launchctl unload "$plist" 2>/dev/null || true

    # Load the plist
    if launchctl load "$plist" 2>/dev/null; then
        echo "  ✓ Loaded successfully"
        return 0
    else
        echo "  ERROR: Failed to load"
        return 1
    fi
}

unload_plist() {
    local name;
    name="$1"
    local plist;
    plist="${PLIST_DIR}/${name}.plist"

    echo "Unloading $name..."

    if launchctl unload "$plist" 2>/dev/null; then
        echo "  ✓ Unloaded successfully"
        return 0
    else
        echo "  ⚠ Was not loaded or failed to unload"
        return 1
    fi
}

status_plist() {
    local name;
    name="$1"

    echo "Status for $name:"

    if launchctl list 2>/dev/null | grep -q "$name"; then
        local pid;
        pid=$(launchctl list 2>/dev/null | grep "$name" | awk '{print $1}')
        local status;
        status=$(launchctl list 2>/dev/null | grep "$name" | awk '{print $2}')
        echo "  Status: Running"
        echo "  PID: $pid"
        echo "  Exit Code: $status"
    else
        echo "  Status: Not running"
    fi
}

list_all() {
    echo "All tools-automation related services:"
    echo "========================================"
    launchctl list 2>/dev/null | grep -E "com\.(tools|quantum)" || echo "None found"
}

# Main
case "$1" in
validate)
    if [[ -n "$2" ]]; then
        validate_plist "$2"
    else
        echo "Validating all plists..."
        for plist in "${PLISTS[@]}"; do
            validate_plist "$plist"
            echo ""
        done
    fi
    ;;
load)
    if [[ -n "$2" ]]; then
        load_plist "$2"
    else
        echo "Loading all plists..."
        for plist in "${PLISTS[@]}"; do
            if validate_plist "$plist" >/dev/null 2>&1; then
                load_plist "$plist"
            else
                echo "Skipping $plist (validation failed)"
            fi
            echo ""
        done
    fi
    ;;
unload)
    if [[ -n "$2" ]]; then
        unload_plist "$2"
    else
        echo "Unloading all plists..."
        for plist in "${PLISTS[@]}"; do
            unload_plist "$plist"
            echo ""
        done
    fi
    ;;
status)
    if [[ -n "$2" ]]; then
        status_plist "$2"
    else
        echo "Status for all plists..."
        for plist in "${PLISTS[@]}"; do
            status_plist "$plist"
            echo ""
        done
    fi
    ;;
list)
    list_all
    ;;
*)
    cat <<EOF
Usage: $0 {validate|load|unload|status|list} [service_name]

Commands:
  validate [service] - Validate plist syntax
  load [service]     - Load service(s)
  unload [service]   - Unload service(s)
  status [service]   - Check service status
  list               - List all tools-automation services

Service names: ${PLISTS[@]}

Examples:
  $0 validate                    # Validate all
  $0 validate com.tools.ollama.serve  # Validate one
  $0 load                        # Load all
  $0 status com.quantum.mcp      # Check one status
  $0 list                        # List all running
EOF
    exit 1
    ;;
esac

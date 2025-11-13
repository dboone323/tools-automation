#!/bin/bash
# MCP Client - forwards requests to MCP server
# Usage: mcp_client.sh <command> [args...]

set -e

# Configuration
MCP_HOST="${MCP_HOST:-127.0.0.1}"
MCP_PORT="${MCP_PORT:-5005}"
MCP_URL="http://${MCP_HOST}:${MCP_PORT}"

# Check if curl is available
if ! command -v curl >/dev/null 2>&1; then
    echo "Error: curl is required but not installed" >&2
    exit 1
fi

# Function to make HTTP requests
make_request() {
    local method="$1"
    local endpoint="$2"
    local data="$3"

    if [ "$method" = "GET" ]; then
        curl -s -X GET "${MCP_URL}${endpoint}"
    elif [ "$method" = "POST" ]; then
        curl -s -X POST "${MCP_URL}${endpoint}" \
            -H "Content-Type: application/json" \
            -d "$data"
    else
        echo "Error: Unsupported HTTP method: $method" >&2
        exit 1
    fi
}

# Parse command
COMMAND="$1"
shift

case "$COMMAND" in
status)
    # Get MCP server status
    make_request "GET" "/status"
    ;;
health)
    # Get MCP server health
    make_request "GET" "/health"
    ;;
register)
    # Register an agent
    AGENT_ID="$1"
    CAPABILITIES="$2"
    if [ -z "$AGENT_ID" ]; then
        echo "Usage: $0 register <agent_id> [capabilities]" >&2
        exit 1
    fi
    DATA="{\"agent\": \"$AGENT_ID\""
    if [ -n "$CAPABILITIES" ]; then
        DATA="$DATA, \"capabilities\": \"$CAPABILITIES\""
    fi
    DATA="$DATA}"
    make_request "POST" "/register" "$DATA"
    ;;
run)
    # Submit a task
    AGENT_ID="$1"
    COMMAND="$2"
    EXECUTE="${3:-false}"
    if [ -z "$AGENT_ID" ] || [ -z "$COMMAND" ]; then
        echo "Usage: $0 run <agent_id> <command> [execute]" >&2
        exit 1
    fi
    DATA="{\"agent\": \"$AGENT_ID\", \"command\": \"$COMMAND\", \"execute\": $EXECUTE}"
    make_request "POST" "/run" "$DATA"
    ;;
execute)
    # Execute a task
    TASK_ID="$1"
    if [ -z "$TASK_ID" ]; then
        echo "Usage: $0 execute <task_id>" >&2
        exit 1
    fi
    DATA="{\"task_id\": \"$TASK_ID\"}"
    make_request "POST" "/execute_task" "$DATA"
    ;;
*)
    echo "Usage: $0 <command> [args...]"
    echo "Commands:"
    echo "  status              - Get MCP server status"
    echo "  health              - Get MCP server health"
    echo "  register <id> [cap] - Register an agent"
    echo "  run <agent> <cmd>   - Submit a task"
    echo "  execute <task_id>   - Execute a task"
    exit 1
    ;;
esac

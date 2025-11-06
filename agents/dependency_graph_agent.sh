#!/bin/bash
# Dependency Graph Agent: Monitor submodule relationships and impact

AGENT_NAME="dependency_graph_agent.sh"
LOG_FILE="agents/dependency_graph_agent.log"
WORKSPACE_ROOT="/Users/danielstevens/Desktop/github-projects/tools-automation"
GRAPH_FILE="${WORKSPACE_ROOT}/dependency_graph.json"
SCAN_INTERVAL="${SCAN_INTERVAL:-600}" # 10 minutes

log_message() {
    echo "[$(date)] [${AGENT_NAME}] $*" | tee -a "${LOG_FILE}"
}

# Scan Package.swift files for dependencies
scan_swift_dependencies() {
    local project="$1"
    local package_file="${WORKSPACE_ROOT}/${project}/Package.swift"

    if [[ -f "$package_file" ]]; then
        # Extract dependencies - only get clean names
        grep -A 5 'dependencies:' "$package_file" 2>/dev/null |
            grep '.package' |
            sed -n 's/.*name: "\([^"]*\)".*/\1/p' 2>/dev/null |
            grep -v '^[[:space:]]*$' || echo ""
    fi
}

# Scan for import statements in Swift files
scan_swift_imports() {
    local project="$1"
    local project_dir="${WORKSPACE_ROOT}/${project}"

    if [[ -d "$project_dir" ]]; then
        # Find all Swift files and extract import statements
        find "$project_dir" -name "*.swift" -type f 2>/dev/null |
            xargs grep -h "^import " 2>/dev/null |
            sed 's/^import //' |
            sort -u || echo ""
    fi
}

# Build dependency graph
build_graph() {
    log_message "Building dependency graph..."

    local graph='{"version":"1.0","updated":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","nodes":[],"edges":[]}'

    # Scan submodules
    for submodule in CodingReviewer PlannerApp HabitQuest MomentumFinance AvoidObstaclesGame shared-kit; do
        if [[ -d "${WORKSPACE_ROOT}/${submodule}" ]]; then
            log_message "Scanning $submodule..."

            # Add node
            graph=$(echo "$graph" | jq ".nodes += [{\"name\":\"$submodule\",\"type\":\"submodule\"}]")

            # Scan Package.swift dependencies
            deps=$(scan_swift_dependencies "$submodule")

            # Add edges from Package.swift
            for dep in $deps; do
                # Clean up dep name and only add if valid
                dep=$(echo "$dep" | tr -d '[:space:]' | tr -d '"' | tr -d ',')
                if [[ -n "$dep" && "$dep" != "[]" && "$dep" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                    graph=$(echo "$graph" | jq --arg from "$submodule" --arg to "$dep" '.edges += [{"from":$from,"to":$to,"type":"package"}]')
                    log_message "  Package dependency: $submodule -> $dep"
                fi
            done

            # Scan import statements
            # Add edges from imports (only for other submodules)
            for import_name in $imports; do
                if [[ "$import_name" =~ (CodingReviewer|PlannerApp|HabitQuest|MomentumFinance|AvoidObstaclesGame|shared-kit) ]]; then
                    # Check if edge already exists
                    existing=$(echo "$graph" | jq --arg from "$submodule" --arg to "$import_name" '.edges[] | select(.from==$from and .to==$to)')
                    if [[ -z "$existing" ]]; then
                        graph=$(echo "$graph" | jq --arg from "$submodule" --arg to "$import_name" '.edges += [{"from":$from,"to":$to,"type":"import"}]')
                        log_message "  Import dependency: $submodule -> $import_name"
                    fi
                fi
            done
        fi
    done

    # Calculate metrics
    local node_count=$(echo "$graph" | jq '.nodes | length')
    local edge_count=$(echo "$graph" | jq '.edges | length')

    # Add metadata
    graph=$(echo "$graph" | jq --argjson nodes "$node_count" --argjson edges "$edge_count" --argjson interval "$SCAN_INTERVAL" '. + {"metadata":{"node_count":$nodes,"edge_count":$edges,"scan_interval_sec":$interval}}')

    echo "$graph" >"$GRAPH_FILE"
    log_message "Dependency graph updated: $GRAPH_FILE ($node_count nodes, $edge_count edges)"
}

# Generate impact analysis
analyze_impact() {
    local changed_module="$1"

    log_message "Analyzing impact of changes to: $changed_module"

    if [[ ! -f "$GRAPH_FILE" ]]; then
        log_message "ERROR: Dependency graph not found. Run build_graph first."
        return 1
    fi

    # Find all modules that depend on the changed module
    local impacted=$(jq -r ".edges[] | select(.to==\"$changed_module\") | .from" "$GRAPH_FILE" | sort -u)

    if [[ -z "$impacted" ]]; then
        log_message "  No direct dependents found"
    else
        log_message "  Direct dependents:"
        echo "$impacted" | while read -r module; do
            log_message "    - $module"
        done
    fi

    # Return impacted modules
    echo "$impacted"
}

# Main loop or one-shot
if [[ "$1" == "once" ]]; then
    log_message "Running one-time dependency graph scan..."
    build_graph
    exit 0
elif [[ "$1" == "impact" ]]; then
    if [[ -z "$2" ]]; then
        log_message "ERROR: Usage: $0 impact <module_name>"
        exit 1
    fi
    analyze_impact "$2"
    exit 0
elif [[ "$1" == "help" || "$1" == "--help" ]]; then
    echo "Usage: $0 [once|impact <module>|daemon]"
    echo ""
    echo "Commands:"
    echo "  once             - Run one-time graph scan and exit"
    echo "  impact <module>  - Analyze impact of changes to module"
    echo "  daemon           - Run continuous monitoring (default)"
    echo ""
    echo "Environment variables:"
    echo "  SCAN_INTERVAL    - Seconds between scans (default: 600)"
    exit 0
else
    # Daemon mode
    log_message "Starting Dependency Graph Agent (daemon mode)..."
    log_message "Scan interval: ${SCAN_INTERVAL} seconds"

    while true; do
        build_graph
        sleep "$SCAN_INTERVAL"
    done
fi

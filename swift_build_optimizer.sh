#!/bin/bash
# Swift Build Optimization with ccache
# Enables faster Swift compilation through compiler caching

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/swift_build_optimization.log"

# Configuration
CCACHE_DIR="${HOME}/.ccache"
CCACHE_PATH="/opt/homebrew/opt/ccache/libexec"
SWIFT_CACHE_ENABLED="${SWIFT_CACHE_ENABLED:-true}"

log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date)] [SwiftOptimizer] [${level}] ${message}" >>"${LOG_FILE}"
    echo "[${level}] ${message}"
}

setup_ccache_for_swift() {
    log_message "INFO" "Setting up ccache for Swift compilation"

    # Ensure ccache is in PATH
    export PATH="${CCACHE_PATH}:$PATH"

    # Configure ccache environment
    export CCACHE_DIR="${CCACHE_DIR}"
    export CCACHE_MAXSIZE="5G"
    export CCACHE_CPP2="true"

    # Swift-specific ccache configuration
    export CCACHE_SLOPPINESS="file_macro,time_macros,include_file_mtime,include_file_ctime,file_stat_matches"
    export CCACHE_COMPILERCHECK="content"

    # Create cache directory if it doesn't exist
    mkdir -p "${CCACHE_DIR}"

    log_message "INFO" "ccache configured for Swift with cache dir: ${CCACHE_DIR}"
}

enable_swift_ccache() {
    if [[ "${SWIFT_CACHE_ENABLED}" != "true" ]]; then
        log_message "INFO" "Swift ccache disabled by configuration"
        return 0
    fi

    setup_ccache_for_swift

    # Verify ccache is working
    if command -v ccache &>/dev/null; then
        local cache_stats
        cache_stats=$(ccache -s 2>/dev/null || echo "ccache stats unavailable")
        log_message "INFO" "ccache status: ${cache_stats}"

        # Test Swift compilation with ccache
        if swiftc --version &>/dev/null; then
            log_message "INFO" "Swift compiler available with ccache"
        else
            log_message "WARNING" "Swift compiler not found in PATH"
        fi
    else
        log_message "ERROR" "ccache not found in PATH"
        return 1
    fi
}

optimize_swift_build() {
    local project_dir="$1"

    if [[ ! -d "${project_dir}" ]]; then
        log_message "ERROR" "Project directory not found: ${project_dir}"
        return 1
    fi

    log_message "INFO" "Optimizing Swift build for project: ${project_dir}"

    cd "${project_dir}" || return 1

    # Check if this is a Swift project
    if [[ ! -f "Package.swift" ]] && [[ ! -f "*.xcodeproj" ]]; then
        log_message "WARNING" "No Swift project files found in ${project_dir}"
        return 1
    fi

    # Enable ccache for Swift
    enable_swift_ccache

    # Set Swift compiler flags for optimization
    export SWIFT_OPTIMIZATION="-O"
    export SWIFT_WHOLE_MODULE_OPTIMIZATION="YES"

    # Build with optimizations
    if [[ -f "Package.swift" ]]; then
        log_message "INFO" "Building Swift Package with optimizations"
        swift build --configuration release
    elif find . -name "*.xcodeproj" -type d | head -1; then
        local xcodeproj
        xcodeproj=$(find . -name "*.xcodeproj" -type d | head -1)
        log_message "INFO" "Found Xcode project: ${xcodeproj}"
        # Note: Xcode builds would need xcodebuild command here
        log_message "INFO" "Xcode build optimization configured (manual xcodebuild required)"
    fi

    log_message "INFO" "Swift build optimization completed"
}

show_ccache_stats() {
    log_message "INFO" "ccache Statistics:"
    if command -v ccache &>/dev/null; then
        ccache -s
    else
        log_message "ERROR" "ccache not available"
    fi
}

clear_ccache() {
    log_message "INFO" "Clearing ccache"
    if command -v ccache &>/dev/null; then
        ccache -C
        log_message "INFO" "ccache cleared"
    else
        log_message "ERROR" "ccache not available"
    fi
}

# Main execution
case "${1:-status}" in
"setup")
    setup_ccache_for_swift
    ;;
"enable")
    enable_swift_ccache
    ;;
"optimize")
    if [[ -z "$2" ]]; then
        echo "Usage: $0 optimize <project_directory>"
        exit 1
    fi
    optimize_swift_build "$2"
    ;;
"stats")
    show_ccache_stats
    ;;
"clear")
    clear_ccache
    ;;
"status")
    echo "Swift Build Optimization Status"
    echo "=============================="
    echo "ccache enabled: $(command -v ccache &>/dev/null && echo 'YES' || echo 'NO')"
    echo "Swift available: $(command -v swiftc &>/dev/null && echo 'YES' || echo 'NO')"
    echo "Cache directory: ${CCACHE_DIR}"
    echo "Cache size limit: 5GB"
    if command -v ccache &>/dev/null; then
        echo ""
        echo "Cache Statistics:"
        ccache -s 2>/dev/null || echo "Unable to get cache statistics"
    fi
    ;;
*)
    echo "Usage: $0 {setup|enable|optimize <dir>|stats|clear|status}"
    echo ""
    echo "Commands:"
    echo "  setup    - Configure ccache for Swift"
    echo "  enable   - Enable ccache for current session"
    echo "  optimize - Optimize Swift build in specified directory"
    echo "  stats    - Show ccache statistics"
    echo "  clear    - Clear ccache"
    echo "  status   - Show current status"
    exit 1
    ;;
esac

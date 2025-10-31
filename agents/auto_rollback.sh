#!/bin/bash

# Auto-Rollback System - Automatic State Restoration on Failures
# Monitors validation results and rolls back failed operations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CHECKPOINTS_DIR="$SCRIPT_DIR/checkpoints"
ROLLBACK_LOG="$SCRIPT_DIR/rollback.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[Auto-Rollback]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$ROLLBACK_LOG"
}

warn() {
    echo -e "${YELLOW}[Auto-Rollback]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$ROLLBACK_LOG"
}

error() {
    echo -e "${RED}[Auto-Rollback]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$ROLLBACK_LOG"
}

# Initialize checkpoints directory
init_checkpoints() {
    mkdir -p "$CHECKPOINTS_DIR"
    log "Checkpoints directory initialized: $CHECKPOINTS_DIR"
}

# Create checkpoint of current state
create_checkpoint() {
    local operation_id="$1"
    local files_to_backup="${2:-}"

    local checkpoint_dir
    checkpoint_dir="$CHECKPOINTS_DIR/${operation_id}_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$checkpoint_dir"

    log "Creating checkpoint: $checkpoint_dir"

    # Backup specified files
    if [ -n "$files_to_backup" ]; then
        while IFS= read -r file; do
            if [ -f "$file" ]; then
                local rel_path
                rel_path=$(realpath --relative-to="$ROOT_DIR" "$file" 2>/dev/null || echo "$file")
                local backup_path="$checkpoint_dir/$rel_path"
                mkdir -p "$(dirname "$backup_path")"
                cp "$file" "$backup_path"
                log "  Backed up: $file"
            fi
        done <<<"$files_to_backup"
    fi

    # Capture current git state
    if git -C "$ROOT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
        git -C "$ROOT_DIR" rev-parse HEAD >"$checkpoint_dir/git_commit"
        git -C "$ROOT_DIR" diff >"$checkpoint_dir/git_diff.patch"
        git -C "$ROOT_DIR" status --short >"$checkpoint_dir/git_status"
        log "  Captured git state"
    fi

    # Capture metadata
    cat >"$checkpoint_dir/metadata.json" <<EOF
{
  "operation_id": "$operation_id",
  "created": "$(date -Iseconds)",
  "cwd": "$(pwd)",
  "user": "$(whoami)",
  "files_count": $(echo "$files_to_backup" | wc -l | tr -d ' ')
}
EOF

    echo "$checkpoint_dir"
}

# Restore from checkpoint
restore_checkpoint() {
    local checkpoint_dir="$1"
    local force="${2:-false}"

    if [ ! -d "$checkpoint_dir" ]; then
        error "Checkpoint not found: $checkpoint_dir"
        return 1
    fi

    log "Restoring from checkpoint: $checkpoint_dir"

    # Confirm if not forced
    if [ "$force" != "true" ]; then
        echo -n "Restore from checkpoint? This will overwrite current files. [y/N]: "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            warn "Rollback cancelled by user"
            return 1
        fi
    fi

    # Restore files
    local restored=0
    if [ -d "$checkpoint_dir" ]; then
        # Find all backed up files
        while IFS= read -r backup_file; do
            local rel_path
            rel_path=$(realpath --relative-to="$checkpoint_dir" "$backup_file" 2>/dev/null || echo "$backup_file")

            # Skip metadata files
            if [[ "$rel_path" == "metadata.json" ]] ||
                [[ "$rel_path" == "git_commit" ]] ||
                [[ "$rel_path" == "git_diff.patch" ]] ||
                [[ "$rel_path" == "git_status" ]]; then
                continue
            fi

            local target_file="$ROOT_DIR/$rel_path"
            mkdir -p "$(dirname "$target_file")"
            cp "$backup_file" "$target_file"
            log "  Restored: $target_file"
            restored=$((restored + 1))
        done < <(find "$checkpoint_dir" -type f)
    fi

    # Restore git state if requested
    if [ -f "$checkpoint_dir/git_diff.patch" ] && [ "$force" = "true" ]; then
        if git -C "$ROOT_DIR" apply --reverse "$checkpoint_dir/git_diff.patch" 2>/dev/null; then
            log "  Restored git state"
        else
            warn "  Could not restore git state"
        fi
    fi

    log "Rollback complete: $restored files restored"
    return 0
}

# Monitor validation and auto-rollback on failure
monitor_validation() {
    local validation_result="$1"
    local checkpoint_dir="$2"
    local auto_rollback="${3:-true}"

    log "Monitoring validation result..."

    # Parse validation result
    local overall_passed
    overall_passed=$(echo "$validation_result" | jq -r '.overall_passed // false')

    if [ "$overall_passed" = "true" ]; then
        log "✅ Validation passed - no rollback needed"
        return 0
    fi

    # Validation failed
    error "❌ Validation failed"

    # Extract failure details
    local failed_layer
    failed_layer=$(echo "$validation_result" | jq -r '.layers[] | select(.passed == false) | .layer' | head -1)
    local failure_message
    failure_message=$(echo "$validation_result" | jq -r '.layers[] | select(.passed == false) | .message' | head -1)

    error "  Failed at layer: $failed_layer"
    error "  Reason: $failure_message"

    # Auto-rollback if enabled
    if [ "$auto_rollback" = "true" ]; then
        warn "Initiating automatic rollback..."
        if restore_checkpoint "$checkpoint_dir" "true"; then
            log "✅ Automatic rollback successful"

            # Log failure for learning
            log_failure "$failed_layer" "$failure_message" "rolled_back"
            return 0
        else
            error "❌ Automatic rollback failed"
            log_failure "$failed_layer" "$failure_message" "rollback_failed"
            return 1
        fi
    else
        warn "Auto-rollback disabled - manual intervention required"
        log_failure "$failed_layer" "$failure_message" "manual_intervention_needed"
        return 1
    fi
}

# Try alternative approach after rollback
try_alternative() {
    local operation="$1"
    local error_pattern="$2"

    log "Trying alternative approach for: $operation"

    # Get alternative suggestion from decision engine
    if [ -f "$SCRIPT_DIR/decision_engine.py" ]; then
        local suggestion
        suggestion=$(python3 "$SCRIPT_DIR/decision_engine.py" evaluate "$error_pattern" 2>/dev/null || echo '{}')

        local alternatives
        alternatives=$(echo "$suggestion" | jq -r '.alternatives[]? | .action' 2>/dev/null || echo "")

        if [ -n "$alternatives" ]; then
            log "Alternative approaches available:"
            echo "$alternatives" | while IFS= read -r alt; do
                log "  - $alt"
            done

            # Return first alternative
            echo "$alternatives" | head -1
            return 0
        fi
    fi

    # No alternatives found
    warn "No alternative approaches available"
    return 1
}

# Log failure for learning
log_failure() {
    local layer="$1"
    local reason="$2"
    local action="$3"

    local failure_entry
    failure_entry=$(
        cat <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "layer": "$layer",
  "reason": "$reason",
  "action_taken": "$action"
}
EOF
    )

    # Append to failure analysis
    if [ -f "$SCRIPT_DIR/knowledge/failure_analysis.json" ]; then
        python3 -c "
import json
from pathlib import Path
from datetime import datetime

failure_file = Path('$SCRIPT_DIR/knowledge/failure_analysis.json')
failures = json.loads(failure_file.read_text())

failure_id = f'failure_{datetime.now().strftime(\"%Y%m%d_%H%M%S\")}'
failures[failure_id] = $failure_entry

failure_file.write_text(json.dumps(failures, indent=2))
" 2>/dev/null || true
    fi
}

# List checkpoints
list_checkpoints() {
    log "Available checkpoints:"

    if [ ! -d "$CHECKPOINTS_DIR" ] || [ -z "$(ls -A "$CHECKPOINTS_DIR" 2>/dev/null)" ]; then
        log "  No checkpoints found"
        return 0
    fi

    for checkpoint in "$CHECKPOINTS_DIR"/*; do
        if [ -d "$checkpoint" ]; then
            local checkpoint_name
            checkpoint_name=$(basename "$checkpoint")

            if [ -f "$checkpoint/metadata.json" ]; then
                local created
                local files_count
                created=$(jq -r '.created // "unknown"' "$checkpoint/metadata.json")
                files_count=$(jq -r '.files_count // 0' "$checkpoint/metadata.json")

                log "  📦 $checkpoint_name"
                log "     Created: $created"
                log "     Files: $files_count"
            else
                log "  📦 $checkpoint_name (no metadata)"
            fi
        fi
    done
}

# Clean old checkpoints
clean_checkpoints() {
    local keep_count="${1:-10}"

    log "Cleaning old checkpoints (keeping most recent $keep_count)..."

    if [ ! -d "$CHECKPOINTS_DIR" ]; then
        log "No checkpoints directory"
        return 0
    fi

    # Sort checkpoints by modification time, delete oldest
    local checkpoint_count
    checkpoint_count=$(find "$CHECKPOINTS_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')

    if [ "$checkpoint_count" -le "$keep_count" ]; then
        log "Only $checkpoint_count checkpoints exist, no cleanup needed"
        return 0
    fi

    local to_delete=$((checkpoint_count - keep_count))
    log "Deleting $to_delete old checkpoint(s)..."

    # macOS-compatible find: use stat and ls
    find "$CHECKPOINTS_DIR" -mindepth 1 -maxdepth 1 -type d -print0 |
        xargs -0 ls -dt |
        tail -n "$to_delete" |
        while IFS= read -r old_checkpoint; do
            log "  Removing: $(basename "$old_checkpoint")"
            rm -rf "$old_checkpoint"
        done

    log "Cleanup complete"
}

# Main entry point
main() {
    local command="${1:-help}"
    shift || true

    case "$command" in
    init)
        init_checkpoints
        ;;
    checkpoint)
        if [ $# -lt 1 ]; then
            error "Usage: auto_rollback.sh checkpoint <operation_id> [files...]"
            exit 1
        fi

        operation_id="$1"
        shift
        files="${*}"

        checkpoint_dir=$(create_checkpoint "$operation_id" "$files")
        echo "$checkpoint_dir"
        ;;
    restore)
        if [ $# -lt 1 ]; then
            error "Usage: auto_rollback.sh restore <checkpoint_dir> [force]"
            exit 1
        fi

        restore_checkpoint "$1" "${2:-false}"
        ;;
    monitor)
        if [ $# -lt 2 ]; then
            error "Usage: auto_rollback.sh monitor <validation_json> <checkpoint_dir> [auto_rollback]"
            exit 1
        fi

        monitor_validation "$1" "$2" "${3:-true}"
        ;;
    alternative)
        if [ $# -lt 2 ]; then
            error "Usage: auto_rollback.sh alternative <operation> <error_pattern>"
            exit 1
        fi

        try_alternative "$1" "$2"
        ;;
    list)
        list_checkpoints
        ;;
    clean)
        clean_checkpoints "${1:-10}"
        ;;
    help | --help | -h)
        cat <<EOF
Auto-Rollback System - Automatic State Restoration

Usage: auto_rollback.sh <command> [arguments]

Commands:
  init                                    Initialize checkpoint system
  checkpoint <op_id> [files...]           Create checkpoint before operation
  restore <checkpoint_dir> [force]        Restore from checkpoint
  monitor <validation_json> <checkpoint>  Monitor validation and auto-rollback
  alternative <operation> <error>         Find alternative approach
  list                                    List available checkpoints
  clean [keep_count]                      Clean old checkpoints (default: keep 10)
  help                                    Show this help message

Examples:
  # Create checkpoint
  checkpoint=\$(auto_rollback.sh checkpoint "build_fix" "file1.swift file2.swift")
  
  # Run operation and validate
  validation=\$(validation_framework.py all file.swift '{"operation":"fix"}')
  
  # Auto-rollback if validation fails
  auto_rollback.sh monitor "\$validation" "\$checkpoint"
  
  # List checkpoints
  auto_rollback.sh list
  
  # Clean old checkpoints
  auto_rollback.sh clean 5
EOF
        ;;
    *)
        error "Unknown command: $command (try 'help')"
        exit 1
        ;;
    esac
}

main "$@"

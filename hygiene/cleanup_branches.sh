#!/bin/bash
# OA-06: Branch Cleanup Script
# Automatically cleans up merged and stale branches

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
readonly BRANCH_AGE_DAYS="${BRANCH_AGE_DAYS:-7}"
readonly DRY_RUN="${DRY_RUN:-false}"
readonly MCP_SERVER="${MCP_SERVER:-http://localhost:3000}"

# Protected branches that should never be deleted
readonly PROTECTED_BRANCHES=(
    "main"
    "master"
    "develop"
    "development"
    "staging"
    "production"
)

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $*"
}

# Check if branch is protected
is_protected_branch() {
    local branch="$1"
    
    for protected in "${PROTECTED_BRANCHES[@]}"; do
        if [[ "$branch" == "$protected" ]] || [[ "$branch" == *"release/"* ]]; then
            return 0
        fi
    done
    
    return 1
}

# Get branch last commit date in epoch seconds
get_branch_age_days() {
    local branch="$1"
    local last_commit_date
    local current_date
    local age_seconds
    
    last_commit_date=$(git log -1 --format=%ct "$branch" 2>/dev/null || echo 0)
    current_date=$(date +%s)
    age_seconds=$((current_date - last_commit_date))
    
    echo $((age_seconds / 86400))
}

# Check if branch is merged
is_merged() {
    local branch="$1"
    local base_branch="${2:-main}"
    
    # Check if branch is fully merged into base
    if git merge-base --is-ancestor "$branch" "$base_branch" 2>/dev/null; then
        return 0
    fi
    
    return 1
}

# Delete local branch
delete_local_branch() {
    local branch="$1"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would delete local branch: ${branch}"
        return 0
    fi
    
    if git branch -D "$branch" >/dev/null 2>&1; then
        log_info "✓ Deleted local branch: ${branch}"
        return 0
    else
        log_error "✗ Failed to delete local branch: ${branch}"
        return 1
    fi
}

# Delete remote branch
delete_remote_branch() {
    local branch="$1"
    local remote="${2:-origin}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would delete remote branch: ${remote}/${branch}"
        return 0
    fi
    
    if git push "$remote" --delete "$branch" >/dev/null 2>&1; then
        log_info "✓ Deleted remote branch: ${remote}/${branch}"
        return 0
    else
        log_warning "✗ Failed to delete remote branch: ${remote}/${branch} (may not exist)"
        return 1
    fi
}

# Clean up merged branches
cleanup_merged_branches() {
    log_info "Scanning for merged branches..."
    
    local deleted_count=0
    local skipped_count=0
    local deleted_branches=()
    
    # Get list of local branches
    while IFS= read -r branch; do
        # Skip protected branches
        if is_protected_branch "$branch"; then
            log_debug "Skipping protected branch: ${branch}"
            ((skipped_count++))
            continue
        fi
        
        # Check if merged
        if is_merged "$branch" "main"; then
            local age_days
            age_days=$(get_branch_age_days "$branch")
            
            if [[ $age_days -gt $BRANCH_AGE_DAYS ]]; then
                log_info "Found merged branch (${age_days} days old): ${branch}"
                
                if delete_local_branch "$branch"; then
                    delete_remote_branch "$branch" "origin" || true
                    ((deleted_count++))
                    deleted_branches+=("$branch")
                fi
            else
                log_debug "Branch recently merged, skipping: ${branch} (${age_days} days old)"
                ((skipped_count++))
            fi
        else
            log_debug "Branch not merged: ${branch}"
            ((skipped_count++))
        fi
    done < <(git branch --format='%(refname:short)' 2>/dev/null)
    
    log_info "Merged branch cleanup: ${deleted_count} deleted, ${skipped_count} skipped"
    
    # Return deleted branches list
    printf '%s\n' "${deleted_branches[@]}"
}

# Clean up stale branches (unmerged but old)
cleanup_stale_branches() {
    log_info "Scanning for stale unmerged branches..."
    
    local stale_threshold=$((BRANCH_AGE_DAYS * 4))  # 4x the merged threshold
    local deleted_count=0
    local skipped_count=0
    local deleted_branches=()
    
    # Get list of local branches
    while IFS= read -r branch; do
        # Skip protected branches
        if is_protected_branch "$branch"; then
            ((skipped_count++))
            continue
        fi
        
        # Skip if merged (already handled above)
        if is_merged "$branch" "main"; then
            ((skipped_count++))
            continue
        fi
        
        # Check age
        local age_days
        age_days=$(get_branch_age_days "$branch")
        
        if [[ $age_days -gt $stale_threshold ]]; then
            log_warning "Found stale unmerged branch (${age_days} days old): ${branch}"
            
            # More conservative - only suggest deletion in dry run
            if [[ "$DRY_RUN" == "true" ]]; then
                log_info "[DRY RUN] Would suggest reviewing: ${branch}"
            else
                log_info "Skipping auto-deletion of unmerged branch: ${branch}"
                log_info "  (Run manually: git branch -D ${branch})"
            fi
            ((skipped_count++))
        else
            ((skipped_count++))
        fi
    done < <(git branch --format='%(refname:short)' 2>/dev/null)
    
    log_info "Stale branch scan: ${deleted_count} deleted, ${skipped_count} reviewed/skipped"
    
    # Return deleted branches list
    printf '%s\n' "${deleted_branches[@]}"
}

# Publish cleanup summary to MCP
publish_summary() {
    local deleted_count="$1"
    local deleted_branches="$2"
    
    local branches_json
    branches_json=$(echo "$deleted_branches" | jq -R . | jq -s -c .)
    
    local payload
    payload=$(cat <<EOF
{
  "source": "branch_cleanup",
  "level": "info",
  "message": "Branch cleanup completed",
  "details": {
    "deleted_count": ${deleted_count},
    "deleted_branches": ${branches_json},
    "age_threshold_days": ${BRANCH_AGE_DAYS},
    "dry_run": ${DRY_RUN},
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }
}
EOF
)
    
    if curl -sf -X POST "${MCP_SERVER}/alerts" \
        -H "Content-Type: application/json" \
        -d "$payload" >/dev/null 2>&1; then
        log_info "Published cleanup summary to MCP"
    else
        log_debug "MCP publish skipped (server offline)"
    fi
}

# Main cleanup logic
main() {
    cd "$ROOT_DIR" || exit 1
    
    log_info "Starting branch cleanup..."
    log_info "Time: $(date)"
    log_info "Age threshold: ${BRANCH_AGE_DAYS} days"
    log_info "Dry run: ${DRY_RUN}"
    echo ""
    
    # Ensure we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not a git repository: ${ROOT_DIR}"
        exit 1
    fi
    
    # Fetch latest from remote
    log_info "Fetching latest changes from remote..."
    if git fetch --prune origin >/dev/null 2>&1; then
        log_info "✓ Fetch completed"
    else
        log_warning "✗ Fetch failed (continuing anyway)"
    fi
    echo ""
    
    # Clean up merged branches
    local merged_deleted
    merged_deleted=$(cleanup_merged_branches)
    local merged_count
    merged_count=$(echo "$merged_deleted" | grep -c . || echo 0)
    echo ""
    
    # Clean up stale branches (conservative)
    local stale_deleted
    stale_deleted=$(cleanup_stale_branches)
    local stale_count
    stale_count=$(echo "$stale_deleted" | grep -c . || echo 0)
    echo ""
    
    # Calculate total
    local total_deleted=$((merged_count + stale_count))
    local all_deleted=""
    
    # Combine arrays properly (avoid printf issues with empty strings)
    if [[ -n "$merged_deleted" ]]; then
        all_deleted="$merged_deleted"
    fi
    if [[ -n "$stale_deleted" ]]; then
        if [[ -n "$all_deleted" ]]; then
            all_deleted="${all_deleted}"$'\n'"${stale_deleted}"
        else
            all_deleted="$stale_deleted"
        fi
    fi
    
    # Summary
    log_info "================================================"
    log_info "Branch Cleanup Summary:"
    log_info "  - Merged branches deleted: ${merged_count}"
    log_info "  - Stale branches deleted: ${stale_count}"
    log_info "  - Total deleted: ${total_deleted}"
    log_info "================================================"
    
    if [[ -n "$all_deleted" ]]; then
        log_info "Deleted branches:"
        echo "$all_deleted" | while read -r branch; do
            [[ -n "$branch" ]] && log_info "  - ${branch}"
        done
    fi
    
    # Publish to MCP
    publish_summary "$total_deleted" "$all_deleted"
    
    log_info "Branch cleanup complete!"
}

# Run main function
main "$@"

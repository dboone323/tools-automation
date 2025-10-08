#!/bin/bash

# GitHub Notification Management Script
# Helps manage notifications for automation-related activity

set -e

# GitHub API token - should be set as environment variable or in .env file
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

log_info() {
    echo "[NOTIFICATION-MGMT] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[NOTIFICATION-ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

# Check if GitHub token is available
check_github_token() {
    if [[ -z "${GITHUB_TOKEN}" ]]; then
        log_error "GitHub token not found. Set GITHUB_TOKEN environment variable."
        log_info "You can create a token at: https://github.com/settings/tokens"
        return 1
    fi
    return 0
}

# Mark all notifications as read
mark_all_read() {
    if ! check_github_token; then
        return 1
    fi

    log_info "Marking all notifications as read..."

    curl -X PUT \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/notifications" \
        -d '{"read": true}' 2>/dev/null || {
            log_error "Failed to mark notifications as read"
            return 1
        }

    log_info "All notifications marked as read"
}

# Mark automation-related notifications as read
mark_automation_read() {
    if ! check_github_token; then
        return 1
    fi

    log_info "Marking automation-related notifications as read..."

    # Get notifications
    notifications=$(curl -s \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/notifications?all=true")

    if [[ $? -ne 0 ]]; then
        log_error "Failed to fetch notifications"
        return 1
    fi

    # Filter and mark automation-related notifications
    echo "${notifications}" | jq -r '.[] | select(.subject.title | contains("AI") or contains("automation") or contains("Analysis") or contains("Optimization")) | .id' | while read -r notification_id; do
        if [[ -n "${notification_id}" ]]; then
            log_info "Marking notification ${notification_id} as read"

            curl -X PATCH \
                -H "Authorization: token ${GITHUB_TOKEN}" \
                -H "Accept: application/vnd.github.v3+json" \
                "https://api.github.com/notifications/threads/${notification_id}" \
                -d '{"read": true}' 2>/dev/null || {
                    log_error "Failed to mark notification ${notification_id}"
                }
        fi
    done

    log_info "Automation notifications processed"
}

# List current notifications
list_notifications() {
    if ! check_github_token; then
        return 1
    fi

    log_info "Fetching current notifications..."

    notifications=$(curl -s \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/notifications?all=true")

    if [[ $? -ne 0 ]]; then
        log_error "Failed to fetch notifications"
        return 1
    fi

    echo "Current Notifications:"
    echo "======================"
    echo "${notifications}" | jq -r '.[] | "• \(.subject.title) (\(.reason)) - \(.updated_at)"'

    total_count=$(echo "${notifications}" | jq '. | length')
    unread_count=$(echo "${notifications}" | jq '[.[] | select(.unread == true)] | length')

    echo ""
    echo "Summary: ${total_count} total notifications, ${unread_count} unread"
}

# Create notification filters/rules
create_notification_filters() {
    log_info "Creating notification filter recommendations..."

    cat << 'EOF'
# GitHub Notification Filters Setup

## Recommended Filters:

1. **Automation & AI Activity Filter:**
   - Go to: https://github.com/settings/notifications
   - Add custom route for repository: dboone323/Quantum-workspace
   - Filter keywords: AI, automation, Analysis, Optimization, Enhancement
   - Send to: /dev/null or separate email (optional)

2. **Pull Request Reviews:**
   - Enable notifications for: Pull request reviews
   - Disable notifications for: Pull request pushes (too noisy)

3. **Issue Management:**
   - Enable: Issues assigned to you
   - Enable: Issues mentioning you
   - Disable: All other issue activity

4. **Repository Activity:**
   - Enable: Repository invitations
   - Enable: Security alerts
   - Disable: Repository activity (pushes, etc.)

## Browser Extension Alternative:
Consider using GitHub notification filters or extensions like:
- "GitHub Notification Filter" browser extension
- "Refined GitHub" extension with notification controls

EOF
}

# Main command handler
main() {
    local command="$1"

    case "${command}" in
    mark-all-read)
        mark_all_read
        ;;
    mark-automation-read)
        mark_automation_read
        ;;
    list)
        list_notifications
        ;;
    filters)
        create_notification_filters
        ;;
    *)
        log_error "Unknown command: ${command}"
        log_info "Usage: $0 {mark-all-read|mark-automation-read|list|filters}"
        log_info ""
        log_info "Commands:"
        log_info "  mark-all-read        - Mark all notifications as read"
        log_info "  mark-automation-read - Mark only automation/AI notifications as read"
        log_info "  list                 - List current notifications"
        log_info "  filters              - Show notification filter setup recommendations"
        exit 1
        ;;
    esac
}

# Run main if script is called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        log_error "Usage: $0 {mark-all-read|mark-automation-read|list|filters}"
        exit 1
    fi

    main "$@"
fi
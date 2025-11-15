#!/bin/bash
# Community Feedback Collection System
# Handles user feedback, bug reports, and feature requests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration
FEEDBACK_DIR="$SCRIPT_DIR"
GITHUB_REPO="tools-automation/tools-automation"
DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create feedback directory structure
setup_feedback_system() {
    log_info "Setting up feedback collection system..."

    mkdir -p "$FEEDBACK_DIR/pending"
    mkdir -p "$FEEDBACK_DIR/processed"
    mkdir -p "$FEEDBACK_DIR/archive"
    mkdir -p "$FEEDBACK_DIR/templates"

    # Create feedback templates
    create_feedback_templates

    log_success "Feedback system initialized"
}

# Create feedback templates
create_feedback_templates() {
    # Bug report template
    cat >"$FEEDBACK_DIR/templates/bug_report.md" <<'EOF'
# Bug Report

## Description
A clear and concise description of the bug.

## Steps to Reproduce
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

## Expected Behavior
A clear and concise description of what you expected to happen.

## Actual Behavior
What actually happened.

## Environment
- OS: [e.g., macOS 12.0, Windows 11]
- Tools Automation Version: [e.g., 1.0.0]
- Plugin(s) involved: [e.g., file-backup-automator v1.0.0]
- Python Version: [e.g., 3.9.0]

## Additional Context
Add any other context about the problem here, such as:
- Screenshots
- Log files
- Configuration files
- Error messages

## Priority
- [ ] Critical (system crash, data loss)
- [ ] High (major functionality broken)
- [ ] Medium (feature not working as expected)
- [ ] Low (cosmetic issue, minor inconvenience)
EOF

    # Feature request template
    cat >"$FEEDBACK_DIR/templates/feature_request.md" <<'EOF'
# Feature Request

## Summary
Brief description of the proposed feature.

## Problem Statement
What problem does this feature solve? What is the current limitation?

## Proposed Solution
Describe the solution you'd like to see implemented.

## Alternative Solutions
Describe any alternative solutions or features you've considered.

## Use Cases
Provide specific examples of how this feature would be used.

## Implementation Notes
Any technical details or considerations for implementation.

## Priority
- [ ] Critical (essential for core functionality)
- [ ] High (important for user experience)
- [ ] Medium (nice to have)
- [ ] Low (future enhancement)

## Additional Context
Add any other context, screenshots, or examples.
EOF

    # Plugin submission template
    cat >"$FEEDBACK_DIR/templates/plugin_submission.md" <<'EOF'
# Plugin Submission

## Plugin Information
- **Name**: 
- **Version**: 
- **Description**: 
- **Author**: 
- **Category**: [automation, monitoring, ai-assistance, data-processing, integration, utilities]

## Repository
- **GitHub URL**: 
- **Documentation URL**: 

## Technical Details
- **Dependencies**: 
- **Permissions Required**: 
- **Supported Hooks**: 
- **Compatibility**: Min/Max Tools Automation versions

## Files Included
- [ ] plugin.json (metadata)
- [ ] Main plugin file(s)
- [ ] README.md
- [ ] requirements.txt
- [ ] Test files
- [ ] Documentation
- [ ] License

## Testing
- [ ] Unit tests included
- [ ] Integration tests included
- [ ] Manual testing completed
- [ ] Security review passed

## Additional Notes
Any special installation instructions or configuration requirements.
EOF

    log_success "Feedback templates created"
}

# Submit feedback to GitHub
submit_github_issue() {
    local title;
    title="$1"
    local body;
    body="$2"
    local labels;
    labels="$3"

    if ! command -v gh &>/dev/null; then
        log_error "GitHub CLI (gh) not installed. Please install it to submit GitHub issues."
        return 1
    fi

    log_info "Submitting feedback to GitHub..."

    # Create the issue
    gh issue create \
        --title "$title" \
        --body "$body" \
        --label "$labels" \
        --repo "$GITHUB_REPO"

    log_success "Feedback submitted to GitHub"
}

# Send feedback to Discord
send_discord_notification() {
    local title;
    title="$1"
    local description;
    description="$2"
    local type;
    type="$3"

    if [ -z "$DISCORD_WEBHOOK_URL" ]; then
        log_warning "Discord webhook URL not configured"
        return 0
    fi

    local color
    case "$type" in
    "bug") color="15158332" ;;      # Red
    "feature") color="3447003" ;;   # Blue
    "feedback") color="16776960" ;; # Yellow
    *) color="9807270" ;;           # Gray
    esac

    local payload;

    payload=$(
        cat <<EOF
{
  "embeds": [{
    "title": "$title",
    "description": "$description",
    "color": $color,
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "footer": {
      "text": "Tools Automation Community Feedback"
    }
  }]
}
EOF
    )

    curl -H "Content-Type: application/json" \
        -X POST \
        -d "$payload" \
        "$DISCORD_WEBHOOK_URL" \
        --silent --output /dev/null

    log_success "Feedback sent to Discord"
}

# Send feedback to Slack
send_slack_notification() {
    local title;
    title="$1"
    local description;
    description="$2"
    local type;
    type="$3"

    if [ -z "$SLACK_WEBHOOK_URL" ]; then
        log_warning "Slack webhook URL not configured"
        return 0
    fi

    local emoji
    case "$type" in
    "bug") emoji="🐛" ;;
    "feature") emoji="✨" ;;
    "feedback") emoji="💬" ;;
    *) emoji="📝" ;;
    esac

    local payload;

    payload=$(
        cat <<EOF
{
  "text": "$emoji $title",
  "blocks": [
    {
      "type": "header",
      "text": {
        "type": "plain_text",
        "text": "$emoji $title"
      }
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "$description"
      }
    },
    {
      "type": "context",
      "elements": [
        {
          "type": "mrkdwn",
          "text": "Submitted via Tools Automation Feedback System"
        }
      ]
    }
  ]
}
EOF
    )

    curl -H "Content-Type: application/json" \
        -X POST \
        -d "$payload" \
        "$SLACK_WEBHOOK_URL" \
        --silent --output /dev/null

    log_success "Feedback sent to Slack"
}

# Process feedback file
process_feedback_file() {
    local file_path;
    file_path="$1"

    if [ ! -f "$file_path" ]; then
        log_error "Feedback file not found: $file_path"
        return 1
    fi

    log_info "Processing feedback file: $(basename "$file_path")"

    # Read feedback content
    local content
    content=$(cat "$file_path")

    # Extract title and type from content
    local title
    local type
    title=$(echo "$content" | grep -m 1 "^# " | sed 's/^# //')
    type=$(echo "$content" | grep -m 1 "^## Type" -A 1 | tail -n 1 | tr -d '- ' | tr '[:upper:]' '[:lower:]')

    if [ -z "$title" ]; then
        title="Community Feedback - $(basename "$file_path" .md)"
    fi

    if [ -z "$type" ]; then
        type="feedback"
    fi

    # Submit to GitHub
    submit_github_issue "$title" "$content" "community-feedback,$type"

    # Send to Discord and Slack
    send_discord_notification "$title" "$(echo "$content" | head -n 5 | tr '\n' ' ')" "$type"
    send_slack_notification "$title" "$(echo "$content" | head -n 5 | tr '\n' ' ')" "$type"

    # Move to processed directory
    local processed_file;
    processed_file="$FEEDBACK_DIR/processed/$(basename "$file_path")"
    mv "$file_path" "$processed_file"

    log_success "Feedback processed and submitted"
}

# List pending feedback
list_pending_feedback() {
    log_info "Pending feedback files:"
    if [ -d "$FEEDBACK_DIR/pending" ]; then
        ls -la "$FEEDBACK_DIR/pending/"*.md 2>/dev/null || echo "No pending feedback files"
    else
        echo "No pending feedback directory"
    fi
}

# Archive old processed feedback
archive_old_feedback() {
    local days;
    days="${1:-30}"

    log_info "Archiving feedback older than $days days..."

    find "$FEEDBACK_DIR/processed" -name "*.md" -mtime +$days -exec mv {} "$FEEDBACK_DIR/archive/" \; 2>/dev/null || true

    local archived_count
    archived_count=$(find "$FEEDBACK_DIR/archive" -name "*.md" -mtime -1 2>/dev/null | wc -l)
    log_success "Archived $archived_count feedback files"
}

# Generate feedback report
generate_feedback_report() {
    local report_file;
    report_file="$FEEDBACK_DIR/feedback_report_$(date +%Y%m%d).md"

    log_info "Generating feedback report..."

    cat >"$report_file" <<EOF
# Community Feedback Report
Generated on $(date)

## Summary
- Total pending feedback: $(find "$FEEDBACK_DIR/pending" -name "*.md" 2>/dev/null | wc -l)
- Total processed feedback: $(find "$FEEDBACK_DIR/processed" -name "*.md" 2>/dev/null | wc -l)
- Total archived feedback: $(find "$FEEDBACK_DIR/archive" -name "*.md" 2>/dev/null | wc -l)

## Recent Activity
EOF

    # Add recent processed feedback
    echo "### Recently Processed" >>"$report_file"
    find "$FEEDBACK_DIR/processed" -name "*.md" -mtime -7 -exec basename {} \; 2>/dev/null | head -10 >>"$report_file" || echo "None" >>"$report_file"

    echo "" >>"$report_file"
    echo "### Pending Feedback" >>"$report_file"
    find "$FEEDBACK_DIR/pending" -name "*.md" -exec basename {} \; 2>/dev/null >>"$report_file" || echo "None" >>"$report_file"

    log_success "Feedback report generated: $report_file"
}

# Main function
main() {
    local command;
    command="$1"
    shift

    case "$command" in
    "setup")
        setup_feedback_system
        ;;
    "submit")
        local file_path;
        file_path="$1"
        if [ -z "$file_path" ]; then
            log_error "Please provide a feedback file path"
            exit 1
        fi
        process_feedback_file "$file_path"
        ;;
    "list")
        list_pending_feedback
        ;;
    "archive")
        archive_old_feedback "$@"
        ;;
    "report")
        generate_feedback_report
        ;;
    "templates")
        echo "Available feedback templates:"
        ls -1 "$FEEDBACK_DIR/templates/"
        ;;
    *)
        echo "Usage: $0 {setup|submit <file>|list|archive [days]|report|templates}"
        echo ""
        echo "Commands:"
        echo "  setup     - Initialize feedback collection system"
        echo "  submit    - Submit feedback file to GitHub/Discord/Slack"
        echo "  list      - List pending feedback files"
        echo "  archive   - Archive old processed feedback (default: 30 days)"
        echo "  report    - Generate feedback activity report"
        echo "  templates - List available feedback templates"
        exit 1
        ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

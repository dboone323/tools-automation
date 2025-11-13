# Community Feedback System

A comprehensive feedback collection and management system for the Tools Automation community.

## Overview

The feedback system provides multiple channels for community members to submit bug reports, feature requests, and general feedback. It integrates with GitHub Issues, Discord, and Slack for maximum visibility and collaboration.

## Features

- **Multi-channel Feedback**: Submit feedback via GitHub Issues, Discord, and Slack
- **Structured Templates**: Pre-defined templates for bug reports, feature requests, and plugin submissions
- **Automated Processing**: Batch processing of feedback files with notifications
- **Feedback Analytics**: Generate reports on community feedback trends
- **Archive Management**: Automatic archiving of old feedback for organization

## Setup

1. Initialize the feedback system:

   ```bash
   ./feedback_manager.sh setup
   ```

2. Configure webhooks (optional):

   ```bash
   export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/YOUR/WEBHOOK/URL"
   export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
   ```

3. Install GitHub CLI for issue submission:

   ```bash
   # macOS
   brew install gh

   # Ubuntu/Debian
   curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
   sudo apt update
   sudo apt install gh

   # Authenticate
   gh auth login
   ```

## Usage

### Creating Feedback

1. **Using Templates**: Copy a template from `templates/` to `pending/`:

   ```bash
   cp templates/bug_report.md pending/my_bug_report.md
   # Edit the file with your feedback
   ```

2. **Manual Creation**: Create feedback files directly in the `pending/` directory

### Submitting Feedback

Submit individual feedback files:

```bash
./feedback_manager.sh submit pending/my_feedback.md
```

### Managing Feedback

List pending feedback:

```bash
./feedback_manager.sh list
```

Generate feedback reports:

```bash
./feedback_manager.sh report
```

Archive old feedback:

```bash
./feedback_manager.sh archive 30  # Archive feedback older than 30 days
```

## Feedback Templates

### Bug Report Template

Use for reporting bugs, crashes, or unexpected behavior:

- Description of the issue
- Steps to reproduce
- Expected vs actual behavior
- Environment details
- Priority level

### Feature Request Template

Use for suggesting new features or enhancements:

- Problem statement
- Proposed solution
- Alternative solutions
- Use cases
- Implementation notes

### Plugin Submission Template

Use for submitting new plugins to the marketplace:

- Plugin metadata
- Technical requirements
- File checklist
- Testing information

## Integration Channels

### GitHub Issues

- Automatic issue creation with appropriate labels
- Structured issue templates
- Community discussion and tracking
- Integration with project management

### Discord Integration

- Real-time notifications in community channels
- Color-coded embeds for different feedback types
- Direct community engagement

### Slack Integration

- Team notifications for urgent issues
- Structured message formatting
- Integration with development workflows

## Feedback Workflow

1. **Submission**: User creates feedback using templates
2. **Processing**: Feedback manager processes and distributes to channels
3. **Discussion**: Community discusses and provides input
4. **Resolution**: Issues are addressed, features implemented
5. **Archiving**: Resolved feedback is archived for reference

## Directory Structure

```
feedback/
├── feedback_manager.sh    # Main feedback management script
├── pending/              # Pending feedback files
├── processed/            # Processed feedback files
├── archive/              # Archived feedback files
├── templates/            # Feedback templates
│   ├── bug_report.md
│   ├── feature_request.md
│   └── plugin_submission.md
└── README.md            # This file
```

## Configuration

### Environment Variables

- `DISCORD_WEBHOOK_URL`: Discord webhook for notifications
- `SLACK_WEBHOOK_URL`: Slack webhook for notifications
- `GITHUB_REPO`: Target GitHub repository (default: tools-automation/tools-automation)

### GitHub Configuration

Ensure GitHub CLI is authenticated:

```bash
gh auth status
gh repo set-default tools-automation/tools-automation
```

## Automation

### Cron Jobs

Set up automated feedback processing:

```bash
# Process all pending feedback daily at 9 AM
0 9 * * * /path/to/feedback_manager.sh submit /path/to/pending/*

# Generate weekly reports every Monday at 8 AM
0 8 * * 1 /path/to/feedback_manager.sh report

# Archive old feedback monthly
0 2 1 * * /path/to/feedback_manager.sh archive 90
```

### GitHub Actions

Example workflow for automated feedback processing:

```yaml
name: Process Community Feedback
on:
  schedule:
    - cron: "0 */6 * * *" # Every 6 hours
  workflow_dispatch:

jobs:
  process-feedback:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Process pending feedback
        run: ./community/feedback/feedback_manager.sh submit ./community/feedback/pending/*
```

## Best Practices

### For Users

- Use appropriate templates for your feedback type
- Provide detailed, actionable information
- Include environment details and reproduction steps
- Check existing issues before submitting

### For Maintainers

- Review feedback regularly using the report feature
- Prioritize based on impact and community votes
- Keep the community updated on progress
- Archive resolved issues promptly

## Security Considerations

- Feedback files are processed locally before submission
- Webhook URLs should be kept secure
- GitHub authentication should use personal access tokens
- Sensitive information should not be included in feedback

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the feedback system
5. Submit a pull request

## Support

For issues with the feedback system:

- Create an issue in the Tools Automation repository
- Check the community Discord/Slack channels
- Review the troubleshooting section in the main README

## License

This feedback system is part of the Tools Automation ecosystem and follows the same license terms.

Master Automation

This folder contains the master automation controller and helper scripts used across the workspace.

# Master Automation

This folder contains the master automation controller and helper scripts used across the workspace.

Key scripts:

- `master_automation.sh` — Unified entry point to run project-specific automation, lint, format, validations, and AI enhancements.
- `deploy_workflows_all_projects.sh` — Validates and pushes GitHub Actions workflows to each project repository.
- `intelligent_autofix.sh`, `mcp_workflow.sh`, `ai_enhancement_system.sh` — helper automation/AI scripts used by the master controller.

Notes:

- Project-level automation may write logs to `PROJECT/automation/logs`. `master_automation.sh` will ensure that directory exists before invoking the runner to avoid write/tee errors.
- `deploy_workflows_all_projects.sh` supports a validation-only mode (`--validate`) to check YAML syntax without pushing changes.

Usage examples:

```bash
# List projects with quick status
./master_automation.sh list

# Run automation for a single project (e.g., PlannerApp)
./master_automation.sh run PlannerApp

# Run all project automations
./master_automation.sh all

# Validate workflows only
./deploy_workflows_all_projects.sh --validate
```

If you'd like I can also add a lightweight GitHub Actions workflow to run `master_automation.sh --validate` on PRs. Let me know if you want that added.

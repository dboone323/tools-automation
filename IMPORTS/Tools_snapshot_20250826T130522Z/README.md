# Master Automation

This folder contains the master automation controller and helper scripts used across the workspace.

Key scripts:

Notes:

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

Note: retrigger marker — CI test edit.

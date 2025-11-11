# Workflow Orchestration

Centralized CI/CD and workflow orchestration scripts for tools-automation and all submodules.

## Overview

This directory contains workflow orchestration scripts that coordinate builds, deployments, and automated processes across the entire project ecosystem.

## Scripts

### ci_orchestrator.sh
Primary CI/CD orchestration script that:
- Coordinates builds across multiple projects
- Manages test execution
- Handles deployment pipelines
- Integrates with agents and MCP servers

### enhanced_workflow.sh
Enhanced workflow engine with:
- Advanced pipeline features
- Parallel execution support
- Error recovery mechanisms
- Progress tracking

### automated_deployment_pipeline.sh
Full deployment automation:
- Environment setup
- Build verification
- Deployment execution
- Rollback capabilities

### local_ci_orchestrator_backup.sh
Backup/legacy version of CI orchestrator for reference

### enhanced_ollama_workflow.sh
Ollama integration workflow for:
- Local LLM integration
- AI-assisted development workflows
- Model management

### ci_orchestrator_old.sh
Previous version from `ci/` directory (for reference)

## Usage

### Running CI Orchestration
```bash
cd /path/to/tools-automation/workflows
./ci_orchestrator.sh --project <project-name>
```

### Enhanced Workflows
```bash
./enhanced_workflow.sh --config <config-file> --target <target>
```

### Deployment Pipeline
```bash
./automated_deployment_pipeline.sh --env production
```

## Integration with Agents

Workflows coordinate with agents:
- **agent_build.sh**: Triggered by CI workflows
- **agent_deployment.sh**: Called during deployment
- **agent_monitoring.sh**: Monitors workflow execution
- **task_orchestrator.sh**: Manages workflow tasks

## Configuration

Workflows use configuration from:
- `../config/automation_config.yaml`
- `../config/deployment_config.json`
- Project-specific configs in submodules

## Submodule Integration

Submodules reference shared workflows via GitHub Actions:

```yaml
# .github/workflows/build.yml
jobs:
  build:
    uses: ./../tools-automation/.github/workflows/shared-build.yml@main
    with:
      project-name: MyProject
      build-command: xcodebuild
```

## Monitoring

Check workflow status:
```bash
# View active workflows
ps aux | grep orchestrator

# Check logs
tail -f /tmp/ci_orchestrator.log
```

## Troubleshooting

### Workflow Fails to Start
1. Check permissions: `chmod +x workflows/*.sh`
2. Verify configuration files exist
3. Ensure dependencies are installed

### Build Failures
1. Check agent logs in `../agents/`
2. Verify configuration in `../config/`
3. Review workflow-specific logs

### Deployment Issues
1. Check environment variables
2. Verify deployment config
3. Review rollback procedures

## Related Directories

- `../agents/` - Agent scripts executed by workflows
- `../mcp/` - MCP servers for AI integration
- `../.github/workflows/` - GitHub Actions workflows
- `../config/` - Configuration files
- `../docs/` - Documentation

## Migration Notes

Centralized on 2025-11-11 from scattered locations. All workflow scripts now live here for consistent orchestration across projects.

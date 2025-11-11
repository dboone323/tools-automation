# Repository Reorganization Plan

## Executive Summary

**Objective**: Centralize shared tools (agents, MCP servers, workflows) in the `tools-automation` superproject, eliminate duplication across submodules, and establish best practices for monorepo structure.

**Key Findings**:

- **72 duplicate agents** between `./agents/` and `./CodingReviewer/Tools/Automation/agents/`
- **7 unique agents** in root only (auto*restart*\*, workflow_optimization_agent, etc.)
- **0 agents** in other 4 submodules (AvoidObstaclesGame, HabitQuest, MomentumFinance, PlannerApp, shared-kit)
- **Multiple MCP config files**: 1 in root + 6 in submodule `.tools-automation/` directories
- **Scattered workflows**: 3 root + 1-4 per submodule GitHub Actions
- **Tools/Automation directories**: Present in all 6 submodules + root (mostly empty except CodingReviewer)

---

## Current State Analysis

### Agent Distribution

```
Location                                        | Count | Status
------------------------------------------------|-------|------------------
./agents/                                       | 111   | Primary location
./CodingReviewer/Tools/Automation/agents/       | 104   | 72 duplicates + 32 non-agents
./AvoidObstaclesGame/Tools/Automation/agents/   | 0     | Empty directory
./HabitQuest/Tools/Automation/agents/           | 0     | Empty directory
./MomentumFinance/Tools/Automation/agents/      | 0     | Empty directory
./PlannerApp/Tools/Automation/agents/           | 0     | Empty directory
./shared-kit/Tools/Automation/                  | N/A   | No agents subdirectory
```

**72 Common Agents** (duplicated):

- agent_analytics.sh, agent_backup.sh, agent_build.sh, agent_codegen.sh, agent_debug.sh
- agent_deployment.sh, agent_documentation.sh, agent_monitoring.sh, agent_optimization.sh
- agent_security.sh, agent_testing.sh, agent_todo.sh, auto_update_agent.sh
- _(full list in appendix)_

**7 Unique Agents** (root only):

1. auto_restart_code_analysis_agent.sh
2. auto_restart_project_health_agent.sh
3. auto_restart_workflow_optimization_agent.sh
4. code_analysis_agent.sh
5. dependency_graph_agent.sh
6. project_health_agent.sh
7. workflow_optimization_agent.sh

### MCP Server Distribution

```
Root MCP Files:
- ./mcp_config.json
- ./mcp_workflow.sh
- ./mcp_controller.py
- ./mcp_dashboard_flask.py
- ./mcp_server_venv.sh
- ./mcp_client.sh
- ./agents/mcp_client.sh
- ./agents/run_mcp_server.sh
- ./Tools/Automation/start_mcp_server.sh

Submodule MCP Files:
- ./MomentumFinance/.tools-automation/mcp_config.json
- ./MomentumFinance/Tools/ProjectScripts/Automation/mcp_workflow.sh
- ./AvoidObstaclesGame/.tools-automation/mcp_config.json
- ./AvoidObstaclesGame/Tools/Automation/mcp_workflow.sh
- ./PlannerApp/.tools-automation/mcp_config.json
- ./PlannerApp/Tools/ProjectScripts/mcp_workflow.sh
- ./HabitQuest/.tools-automation/mcp_config.json
- ./HabitQuest/Tools/ProjectScripts/Automation/mcp_workflow.sh
- ./shared-kit/.tools-automation/mcp_config.json
- ./CodingReviewer/.tools-automation/mcp_config.json
```

### GitHub Workflows

```
Location                                | Workflow Files
----------------------------------------|---------------
./.github/workflows/                    | 3
./MomentumFinance/.github/workflows/    | 1
./AvoidObstaclesGame/.github/workflows/ | 1
./PlannerApp/.github/workflows/         | 0
./HabitQuest/.github/workflows/         | 1
./shared-kit/.github/workflows/         | 0
./CodingReviewer/.github/workflows/     | 1
```

### Configuration Files

```
Root Configuration:
- agent_config.sh (MAX_CONCURRENCY, LOAD_THRESHOLD, paths)
- shared_functions.sh (core task management functions)
- agent_status.json, task_queue.json, agent_assignments.json

CodingReviewer Configuration:
- CodingReviewer/Tools/Automation/agents/agent_config.sh
- CodingReviewer/Tools/Automation/agents/shared_functions.sh
```

---

## Target Architecture

### Centralized Structure

```
tools-automation/                          # Superproject (shared resources)
├── .github/
│   └── workflows/                         # Shared reusable workflows
│       ├── shared-build.yml
│       ├── shared-test.yml
│       └── shared-deploy.yml
├── agents/                                # All agent scripts (centralized)
│   ├── agent_config.sh                    # Central configuration
│   ├── shared_functions.sh                # Shared utilities
│   ├── agent_build.sh
│   ├── agent_codegen.sh
│   ├── agent_debug.sh
│   ├── ... (111 total agents)
│   └── README.md                          # Agent documentation
├── mcp/                                   # NEW: Centralized MCP servers
│   ├── mcp_config.json                    # Primary MCP configuration
│   ├── mcp_workflow.sh                    # MCP orchestration
│   ├── mcp_controller.py                  # Python MCP controller
│   ├── mcp_dashboard_flask.py             # Dashboard
│   ├── servers/                           # MCP server implementations
│   │   ├── start_mcp_server.sh
│   │   ├── mcp_client.sh
│   │   └── run_mcp_server.sh
│   └── README.md                          # MCP documentation
├── workflows/                             # NEW: Workflow orchestration scripts
│   ├── ci_orchestrator.sh
│   ├── enhanced_workflow.sh
│   ├── automated_deployment_pipeline.sh
│   └── README.md                          # Workflow documentation
├── config/                                # NEW: Shared configuration files
│   ├── agent_status.json
│   ├── task_queue.json
│   ├── agent_assignments.json
│   └── README.md
├── scripts/                               # NEW: Utility scripts
│   ├── regenerate_todo_json.py
│   ├── ai_*.sh scripts
│   └── README.md
└── docs/                                  # NEW: Documentation
    ├── AGENT_HEALTH_REPORT.md
    ├── TODO_SYSTEM_ENHANCEMENT_PLAN.md
    ├── REPOSITORY_REORGANIZATION_PLAN.md (this file)
    └── README.md

AvoidObstaclesGame/                        # Submodule (project-specific)
├── .github/
│   └── workflows/
│       └── build.yml                      # Uses: tools-automation/.github/workflows/shared-build.yml
├── .tools-automation/                     # Submodule-specific overrides
│   └── mcp_config.json                    # Project-specific MCP settings
└── Tools/                                 # Project-specific tools (if needed)
    └── Automation/
        └── custom_project_script.sh       # Only project-specific scripts

CodingReviewer/                            # Submodule (cleanup duplicate agents)
├── .github/
│   └── workflows/
│       └── swift-ci.yml                   # Uses shared workflows
├── .tools-automation/
│   └── mcp_config.json
└── Tools/
    └── Automation/
        └── agents/                        # TO BE REMOVED (72 duplicates)

HabitQuest/                                # Similar structure to AvoidObstaclesGame
MomentumFinance/                           # Similar structure
PlannerApp/                                # Similar structure
shared-kit/                                # Similar structure
```

### Path Resolution Strategy

**Agent Execution**: All agents run from `tools-automation/agents/`

```bash
# In any submodule or superproject
export TOOLS_AUTOMATION_ROOT="/Users/danielstevens/Desktop/github-projects/tools-automation"
source "$TOOLS_AUTOMATION_ROOT/agents/agent_config.sh"
source "$TOOLS_AUTOMATION_ROOT/agents/shared_functions.sh"
```

**MCP Server Access**:

```bash
# Primary config
"$TOOLS_AUTOMATION_ROOT/mcp/mcp_config.json"

# Submodule override (if exists)
"$SUBMODULE_ROOT/.tools-automation/mcp_config.json"
```

**Workflow Usage**:

```yaml
# In submodule .github/workflows/build.yml
jobs:
  build:
    uses: ./../tools-automation/.github/workflows/shared-build.yml@main
    with:
      project-path: .
```

---

## Migration Plan

### Phase 1: Preparation & Backup (Safety First)

**1.1 Create Backup Branch**

```bash
cd /Users/danielstevens/Desktop/github-projects/tools-automation
git checkout -b backup-before-reorganization
git add -A
git commit -m "Backup: Pre-reorganization state"
git push origin backup-before-reorganization
```

**1.2 Document Current State**

```bash
# Create comprehensive file manifest
find . -type f \( -name "*agent*.sh" -o -name "*mcp*" -o -name "*workflow*.sh" \) \
  ! -path "*/\.*" > migration_manifest.txt
```

**1.3 Verify Submodule Integrity**

```bash
git submodule status
git submodule foreach 'git status'
```

### Phase 2: Create New Directory Structure

**2.1 Create Centralized Directories**

```bash
cd /Users/danielstevens/Desktop/github-projects/tools-automation

# Create new structure
mkdir -p mcp/servers
mkdir -p workflows
mkdir -p config
mkdir -p scripts
mkdir -p docs

# Move existing docs
mv AGENT_HEALTH_REPORT.md docs/
mv TODO_SYSTEM_ENHANCEMENT_PLAN.md docs/
mv AGENT_ENHANCEMENT_MASTER_PLAN.md docs/
mv AI_MONITORING_GUIDE.md docs/
```

**2.2 Move MCP Files**

```bash
# Move MCP core files
mv mcp_config.json mcp/
mv mcp_workflow.sh mcp/
mv mcp_controller.py mcp/
mv mcp_dashboard_flask.py mcp/
mv mcp_server_venv.sh mcp/
mv mcp_client.sh mcp/
mv mcp_dashboard.sh mcp/
mv mcp_dashboard_venv.sh mcp/
mv simple_mcp_check.sh mcp/

# Move MCP server scripts
mv Tools/Automation/start_mcp_server.sh mcp/servers/
mv agents/mcp_client.sh mcp/servers/
mv agents/run_mcp_server.sh mcp/servers/
```

**2.3 Move Workflow Scripts**

```bash
mv ci_orchestrator.sh workflows/
mv enhanced_workflow.sh workflows/
mv automated_deployment_pipeline.sh workflows/
mv local_ci_orchestrator_backup.sh workflows/
mv enhanced_ollama_workflow.sh workflows/
mv ci/ci_orchestrator.sh workflows/ci_orchestrator_old.sh  # Handle duplicate
```

**2.4 Move Configuration Files**

```bash
# Keep agent_config.sh in ./agents/ but move status/queue files
mv agent_status.json config/
mv task_queue.json config/
mv agent_assignments.json config/
```

**2.5 Move Utility Scripts**

```bash
mv regenerate_todo_json.py scripts/
mv ai_*.sh scripts/
mv ai_*.py scripts/
mv automate.sh scripts/
mv dashboard_unified.sh scripts/
```

**2.6 Update agent_config.sh Paths**

```bash
# Edit agents/agent_config.sh to update paths
sed -i '' 's|./agent_status.json|../config/agent_status.json|g' agents/agent_config.sh
sed -i '' 's|./task_queue.json|../config/task_queue.json|g' agents/agent_config.sh
```

### Phase 3: Remove Duplicates from CodingReviewer

**3.1 Verify Files Are Identical**

```bash
# Compare checksums of common agents
for agent in $(comm -12 /tmp/root_agents.txt /tmp/cr_agents.txt); do
  root_sum=$(md5 -q "./agents/$agent")
  cr_sum=$(md5 -q "./CodingReviewer/Tools/Automation/agents/$agent")
  if [ "$root_sum" != "$cr_sum" ]; then
    echo "DIFF: $agent"
  fi
done > agent_differences.txt
```

**3.2 Remove Duplicate Agents from CodingReviewer**

```bash
cd CodingReviewer
git checkout -b remove-duplicate-agents

# Remove 72 duplicate agent files
for agent in $(comm -12 /tmp/root_agents.txt /tmp/cr_agents.txt); do
  git rm "Tools/Automation/agents/$agent"
done

# Commit removal
git commit -m "Remove 72 duplicate agents - now centralized in superproject tools-automation/agents/"
```

**3.3 Create Symlink or Path Configuration**

```bash
# Option A: Symlink (if filesystem supports)
cd CodingReviewer/Tools/Automation
ln -s ../../../agents ./agents

# Option B: Environment variable (recommended)
# Create .envrc in CodingReviewer root
cat > .envrc << 'EOF'
export TOOLS_AUTOMATION_ROOT="$(cd ../../ && pwd)"
export PATH="$TOOLS_AUTOMATION_ROOT/agents:$PATH"
EOF
```

### Phase 4: Update Path References

**4.1 Fix agent_codegen.sh WORKSPACE Path**

```bash
# Line ~101 in agents/agent_codegen.sh
# OLD: WORKSPACE="${WORKSPACE:-$(cd "${SCRIPT_DIR}/../../.." && pwd)}"
# NEW: WORKSPACE="${WORKSPACE:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

sed -i '' 's|cd "${SCRIPT_DIR}/\.\./\.\./\.\."|cd "${SCRIPT_DIR}/\.\."|g' agents/agent_codegen.sh
```

**4.2 Update All Agent Scripts to Use Relative Paths**

```bash
# Search for hardcoded paths
grep -r "/Desktop/github-projects/tools-automation" ./agents/ > hardcoded_paths.txt

# Replace with relative paths or environment variable
find ./agents -name "*.sh" -exec sed -i '' \
  's|/Desktop/github-projects/tools-automation|${TOOLS_AUTOMATION_ROOT:-$(cd "$(dirname "$0")/.." \&\& pwd)}|g' {} \;
```

**4.3 Update MCP Scripts**

```bash
# Update mcp_workflow.sh to use new mcp/ directory structure
cd mcp
# Edit mcp_workflow.sh to reference ./mcp_config.json instead of ../mcp_config.json
```

**4.4 Update GitHub Workflows to Use Shared Workflows**

```yaml
# Example: AvoidObstaclesGame/.github/workflows/build.yml
name: Build

on: [push, pull_request]

jobs:
  build:
    uses: ./../tools-automation/.github/workflows/shared-build.yml@main
    with:
      project-name: AvoidObstaclesGame
      build-command: xcodebuild
```

### Phase 5: Testing & Validation

**5.1 Test Agent System**

```bash
cd /Users/danielstevens/Desktop/github-projects/tools-automation

# Source new configuration
source agents/agent_config.sh
source agents/shared_functions.sh

# Test agent startup
./agents/agent_build.sh &
./agents/agent_codegen.sh &
./agents/agent_debug.sh &

# Verify agents start without errors
ps aux | grep agent
cat config/agent_status.json
```

**5.2 Test MCP System**

```bash
cd mcp
./mcp_workflow.sh --check-config
python3 mcp_controller.py --status
```

**5.3 Test from Submodule**

```bash
cd CodingReviewer

# Set environment
export TOOLS_AUTOMATION_ROOT="../"
source "$TOOLS_AUTOMATION_ROOT/agents/agent_config.sh"

# Verify agent access
which agent_build.sh
agent_build.sh --version  # Should work
```

**5.4 Verify No Broken Links**

```bash
# Find any remaining references to old paths
grep -r "Tools/Automation/agents" . --exclude-dir=".git" > old_path_references.txt
```

### Phase 6: Documentation & Cleanup

**6.1 Create README Files**

Create `agents/README.md`:

````markdown
# Shared Agent System

All agents for tools-automation and submodules are centralized here.

## Usage from Submodules

```bash
export TOOLS_AUTOMATION_ROOT="/path/to/tools-automation"
source "$TOOLS_AUTOMATION_ROOT/agents/agent_config.sh"
source "$TOOLS_AUTOMATION_ROOT/agents/shared_functions.sh"
```
````

## Agent List

- agent_build.sh: Automated build and test execution
- agent_codegen.sh: Code generation and improvement
- agent_debug.sh: Debugging and issue analysis
  ... (111 agents total)

````

Create `mcp/README.md`, `workflows/README.md`, `config/README.md`

**6.2 Update Root README.md**
```markdown
# tools-automation

Centralized automation tools for all projects.

## Structure
- `/agents/` - Shared agent system (111 agents)
- `/mcp/` - MCP servers and configuration
- `/workflows/` - CI/CD orchestration scripts
- `/config/` - Shared configuration files
- `/scripts/` - Utility scripts
- `/docs/` - Documentation

## Submodules
- AvoidObstaclesGame
- CodingReviewer
- HabitQuest
- MomentumFinance
- PlannerApp
- shared-kit
````

**6.3 Commit Changes**

```bash
cd /Users/danielstevens/Desktop/github-projects/tools-automation

git add -A
git commit -m "Repository reorganization: Centralize shared tools

- Created mcp/, workflows/, config/, scripts/, docs/ directories
- Moved MCP servers and configs to mcp/
- Moved workflow orchestration to workflows/
- Moved utility scripts to scripts/
- Moved documentation to docs/
- Updated all path references
- Fixed agent_codegen.sh WORKSPACE path bug

Ref: docs/REPOSITORY_REORGANIZATION_PLAN.md"

git push origin main
```

**6.4 Update Submodule CodingReviewer**

```bash
cd CodingReviewer
git add -A
git commit -m "Remove 72 duplicate agents - use centralized tools-automation/agents/"
git push origin main

# Update superproject reference
cd ..
git add CodingReviewer
git commit -m "Update CodingReviewer submodule: agents removed, use centralized"
git push origin main
```

---

## Rollback Plan

If issues arise during migration:

```bash
# 1. Restore from backup branch
git checkout backup-before-reorganization
git checkout -b reorganization-fix

# 2. Restore submodule state
cd CodingReviewer
git reflog
git checkout <commit-before-removal>
cd ..
git submodule update --remote

# 3. Fix specific issues and re-attempt migration steps
```

---

## Benefits

1. **Elimination of Duplication**: Remove 72 duplicate agent files from CodingReviewer
2. **Single Source of Truth**: All shared tools in one location
3. **Easier Maintenance**: Update once, all submodules benefit
4. **Clearer Organization**: Purpose-driven directories (mcp/, workflows/, agents/)
5. **Scalability**: Easy to add new submodules without duplicating infrastructure
6. **Consistent Configuration**: Centralized agent_config.sh, mcp_config.json
7. **Reduced Git Repository Size**: Fewer duplicate files tracked across repos

---

## Post-Migration Tasks

1. **Fix agent_codegen.sh path issue** (already identified)
2. **Implement TODO system enhancements** (after structure stabilizes)
3. **Create shared GitHub Actions workflows** (reusable across submodules)
4. **Setup centralized logging** (all agents log to tools-automation/logs/)
5. **Implement agent version management** (semver for agent releases)
6. **Create agent discovery mechanism** (auto-detect available agents)
7. **Setup integration tests** (verify submodules can access shared tools)

---

## Appendix: Full List of 72 Common Agents

```
agent_analytics.sh
agent_backup.sh
agent_build.sh
agent_build_enhanced.sh
agent_cleanup.sh
agent_codegen.sh
agent_config.sh
agent_control.sh
agent_debug.sh
agent_debug_enhanced.sh
agent_deployment.sh
agent_documentation.sh
agent_helpers.sh
agent_integration.sh
agent_keeper.sh
agent_loop_utils.sh
agent_migration.sh
agent_monitoring.sh
agent_notification.sh
agent_optimization.sh
agent_performance.sh
agent_quality.sh
agent_recovery.sh
agent_resource_manager.sh
agent_restart.sh
agent_security.sh
agent_status_manager.sh
agent_task_manager.sh
agent_testing.sh
agent_todo.sh
agent_validation.sh
ai_enhanced_agent_launcher.sh
auto_restart_agent.sh
auto_restart_agent_analytics.sh
auto_restart_agent_backup.sh
auto_restart_agent_build.sh
auto_restart_agent_cleanup.sh
auto_restart_agent_codegen.sh
auto_restart_agent_control.sh
auto_restart_agent_debug.sh
auto_restart_agent_deployment.sh
auto_restart_agent_documentation.sh
auto_restart_agent_integration.sh
auto_restart_agent_keeper.sh
auto_restart_agent_migration.sh
auto_restart_agent_monitoring.sh
auto_restart_agent_notification.sh
auto_restart_agent_optimization.sh
auto_restart_agent_performance.sh
auto_restart_agent_quality.sh
auto_restart_agent_recovery.sh
auto_restart_agent_resource_manager.sh
auto_restart_agent_restart.sh
auto_restart_agent_security.sh
auto_restart_agent_status_manager.sh
auto_restart_agent_task_manager.sh
auto_restart_agent_testing.sh
auto_restart_agent_todo.sh
auto_restart_agent_validation.sh
auto_restart_knowledge_base_agent.sh
auto_restart_learning_agent.sh
auto_restart_quantum_orchestrator_agent.sh
auto_restart_resource_optimizer_agent.sh
auto_restart_task_orchestrator.sh
auto_update_agent.sh
knowledge_base_agent.sh
learning_agent.sh
quantum_orchestrator_agent.sh
resource_optimizer_agent.sh
shared_functions.sh
task_orchestrator.sh
test_agent_system.sh
```

---

## Timeline

| Phase                               | Duration    | Status            |
| ----------------------------------- | ----------- | ----------------- |
| 1. Preparation & Backup             | 30 min      | ✅ **COMPLETED**  |
| 2. Create New Structure             | 1 hour      | ✅ **COMPLETED**  |
| 3. Remove CodingReviewer Duplicates | 30 min      | ✅ **COMPLETED**  |
| 4. Update Path References           | 1 hour      | ✅ **COMPLETED**  |
| 5. Testing & Validation             | 1 hour      | ✅ **COMPLETED**  |
| 6. Documentation & Cleanup          | 1 hour      | ✅ **COMPLETED**  |
| **Total Estimated Time**            | **5 hours** | **100% Complete** |

---

## Approval & Next Steps

**Before proceeding**, confirm:

- [x] Backup branch created and verified
- [x] All submodules have committed changes (no uncommitted work)
- [x] Team members notified of pending reorganization
- [x] CI/CD pipelines will not break during migration

**Execute migration**: Follow phases 1-6 sequentially

**Post-migration**: Run comprehensive tests, update documentation, notify team

---

_Document created: 2025-01-27_  
_Last updated: 2025-11-11_  
_Version: 2.0 - COMPLETED_

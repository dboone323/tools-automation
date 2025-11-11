# Utility Scripts

Centralized utility scripts for tools-automation and all submodules.

## Overview

This directory contains utility scripts for TODO management, AI-assisted automation, and general maintenance tasks.

## Scripts

### TODO Management
- **regenerate_todo_json.py**: Scans codebase for TODO/FIXME comments and generates structured output

### AI Integration
- **ai_*.sh**: AI-assisted automation scripts for various tasks
- **ai_*.py**: Python-based AI utilities

### General Utilities
- **automate.sh**: General automation orchestration
- **dashboard_unified.sh**: Unified dashboard for monitoring

## regenerate_todo_json.py

Comprehensive TODO scanning across the codebase.

**Usage:**
```bash
cd /path/to/tools-automation
python3 scripts/regenerate_todo_json.py
```

**Features:**
- Scans multiple file types: `.swift`, `.sh`, `.md`, `.py`, `.js`, `.ts`, `.json`, `.yml`, `.yaml`
- Extracts TODO, FIXME, HACK, NOTE comments
- Supports submodule scanning
- Generates structured JSON output

**Output:**
Results saved to project-specific locations (configurable)

**Configuration:**
Edit script to customize:
- File extensions to scan
- Comment patterns
- Output location
- Exclusion patterns

## AI Scripts

### Available AI Utilities
- AI-assisted code analysis
- Automated code review
- Smart refactoring suggestions
- Documentation generation
- Test generation

**Common Usage Pattern:**
```bash
./scripts/ai_<task>.sh --project <name> --mode <mode>
```

## Dashboard

### dashboard_unified.sh
Unified monitoring dashboard providing:
- Agent status overview
- Task queue visualization
- System health metrics
- Recent activity logs

**Launch:**
```bash
./scripts/dashboard_unified.sh
```

## automate.sh

General automation orchestration script.

**Usage:**
```bash
./scripts/automate.sh --action <action> --target <target>
```

## Integration with Agents

Utilities are called by agents:
- `agent_todo.sh` uses `regenerate_todo_json.py`
- `agent_codegen.sh` uses AI scripts
- `agent_monitoring.sh` uses dashboard utilities

## Usage from Submodules

```bash
export TOOLS_AUTOMATION_ROOT="/path/to/tools-automation"
python3 "$TOOLS_AUTOMATION_ROOT/scripts/regenerate_todo_json.py"
```

## Adding New Scripts

1. Add script to this directory
2. Make executable: `chmod +x scripts/new_script.sh`
3. Document in this README
4. Update related agent if needed

## Related Directories

- `../agents/` - Agent scripts that use utilities
- `../workflows/` - Workflows that call utilities
- `../config/` - Configuration for utilities
- `../docs/` - Detailed documentation

## Migration Notes

Utility scripts were moved here on 2025-11-11 from the root directory for better organization. All references in agents and workflows have been updated.

# Phase 1 Quick Reference Guide

## Overview
Phase 1 provides autonomous error learning, AI-powered analysis, and intelligent decision making for agent operations.

## Quick Start

### 1. Initial Setup (First Time Only)
```bash
cd Tools/Automation/agents
./implement_phase1.sh
```

### 2. Validate Installation
```bash
./test_phase1_integration.sh
```

Expected output:
```
✅ Decision engine working
✅ Fix suggester working
✅ MCP client available and working
✅ Agent helpers working
✅ All enhanced agents present
```

## Common Operations

### Using Enhanced Build Agent

**Basic build with suggestions:**
```bash
./agent_build_enhanced.sh CodingReviewer
```

**Auto-fixing build:**
```bash
./agent_build_enhanced.sh CodingReviewer true
```

**What it does:**
1. Attempts build
2. If fails, extracts errors from log
3. Queries decision engine for fixes
4. Auto-executes high-confidence fixes (≥0.75)
5. Retries build after fix
6. Records results in fix_history.json

### Using Enhanced Debug Agent

**Debug specific error:**
```bash
./agent_debug_enhanced.sh error "Build failed: No such module 'SharedKit'"
```

Output includes:
- Fix suggestion with confidence score
- AI analysis (if Ollama available)
- Alternative actions ranked by confidence

**Analyze log file:**
```bash
./agent_debug_enhanced.sh log ../test_results.log
```

Output includes:
- Unique errors extracted from log
- Fix suggestions for each error
- Ranked alternatives

### Direct Component Usage

**Decision Engine:**
```bash
# Evaluate situation
python3 decision_engine.py evaluate "Build failed: Missing module"

# Verify outcome
python3 decision_engine.py verify "rebuild" "build failed" "build succeeded"

# Record fix attempt
python3 decision_engine.py record "Build failed" "rebuild" "true" 65
```

**Fix Suggester:**
```bash
# Get fix suggestion
python3 fix_suggester.py suggest "xcodebuild error"

# Explain action
python3 fix_suggester.py explain clean_build
```

**MCP Client:**
```bash
# Test connectivity
./mcp_client.sh test

# Analyze error with AI
./mcp_client.sh analyze-error "Build failed: No such module"

# Suggest fix
./mcp_client.sh suggest-fix "Build failed"

# Evaluate situation
./mcp_client.sh evaluate "Tests failing" "rebuild, clean, update deps"
```

**Error Learning:**
```bash
# Scan log once
./error_learning_agent.sh --scan-once /path/to/log.txt

# Watch directory for new logs
./error_learning_agent.sh --watch /path/to/logs
```

## Writing Custom Enhanced Agents

### Template
```bash
#!/bin/bash
# my_enhanced_agent.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Import helper functions
source "$SCRIPT_DIR/agent_helpers.sh"

# Override action implementations
agent_action_rebuild() {
    echo "Running custom rebuild..."
    # Your rebuild logic
    return 0
}

agent_action_clean_build() {
    echo "Running custom clean build..."
    # Your clean build logic
    return 0
}

# Main logic
main() {
    local error_msg="$1"
    
    # Get fix suggestion
    echo "Analyzing error..."
    local suggestion
    suggestion=$(agent_suggest_fix "$error_msg")
    
    local action
    action=$(echo "$suggestion" | jq -r '.primary_suggestion.action')
    echo "Recommended: $action"
    
    # Auto-fix with decision engine
    agent_auto_fix "$error_msg" '{"project": "MyProject"}' "true"
}

main "$@"
```

### Available Helper Functions

| Function | Purpose | Returns |
|----------|---------|---------|
| `agent_suggest_fix <pattern> [context]` | Get fix recommendation | JSON with action, confidence, alternatives |
| `agent_decide <pattern> [context]` | Get decision engine recommendation | JSON with action, reasoning, auto_execute |
| `agent_record_fix <pattern> <action> <success> [duration]` | Record fix attempt | JSON status |
| `agent_verify <action> <before> <after>` | Verify outcome | JSON with success, confidence, explanation |
| `agent_ai_analyze <pattern> [context]` | Get AI analysis | JSON or text analysis |
| `agent_auto_fix <pattern> [context] [force]` | Execute autonomous fix | Exit code (0=success, 1=failed, 2=low confidence) |

### Action Implementations to Override

```bash
agent_action_rebuild()         # Rebuild project
agent_action_clean_build()     # Clean + rebuild
agent_action_fix_lint()        # Run SwiftLint --fix (default provided)
agent_action_fix_format()      # Run SwiftFormat (default provided)
```

## Knowledge Base Management

### View Current Patterns
```bash
# All patterns
cat knowledge/error_patterns.json | jq .

# High severity only
cat knowledge/error_patterns.json | jq '.[] | select(.severity == "high")'

# By category
cat knowledge/error_patterns.json | jq '.[] | select(.category == "build")'
```

### View Fix History
```bash
# All fixes
cat knowledge/fix_history.json | jq .

# Successful fixes only
cat knowledge/fix_history.json | jq '.[] | select(.success == true)'

# Fix success rates
cat knowledge/fix_history.json | jq '.[] | {action, success_rate, times_used}'
```

### Manual Pattern Addition
```python
import json
from pathlib import Path

knowledge_dir = Path("knowledge")
patterns_file = knowledge_dir / "error_patterns.json"

with open(patterns_file, 'r') as f:
    patterns = json.load(f)

# Add new pattern
patterns["abc12345"] = {
    "pattern": "Your error pattern",
    "category": "build",
    "severity": "high",
    "count": 1,
    "examples": ["Full error message"],
    "files": [],
    "first_seen": "2025-10-25T12:00:00",
    "last_seen": "2025-10-25T12:00:00"
}

with open(patterns_file, 'w') as f:
    json.dump(patterns, f, indent=2)
```

## Confidence Scores

### Understanding Confidence
- **0.9-1.0**: Extremely confident - Fix has worked many times
- **0.75-0.89**: High confidence - Auto-execute enabled
- **0.50-0.74**: Medium confidence - Manual approval suggested
- **0.30-0.49**: Low confidence - Try alternative or manual fix
- **0.0-0.29**: Very low confidence - Unknown error, needs analysis

### Factors Affecting Confidence
1. **Pattern Match**: Known vs unknown error (+0.4)
2. **Success Rate**: Historical fix success (±0.2)
3. **Occurrence**: How often seen (+0.15 max)
4. **Severity**: High severity gets boost (+0.15)

### Tuning Auto-Execute Threshold
Edit `decision_engine.py`:
```python
MIN_CONFIDENCE_AUTO_EXECUTE = 0.75  # Adjust this value
MIN_CONFIDENCE_SUGGEST = 0.50       # Adjust this value
```

## MCP / Ollama Setup

### Installing Ollama (for AI features)
```bash
# macOS
brew install ollama

# Start service
ollama serve

# Pull model (in separate terminal)
ollama pull codellama
```

### Testing MCP Connection
```bash
./mcp_client.sh test
```

Expected output:
```
✅ Ollama available at http://localhost:11434
✅ Model: codellama
Test query result: MCP client is working
```

### Troubleshooting MCP

**Problem**: Connection timeout
```bash
# Check Ollama service
ps aux | grep ollama

# Check port
lsof -i :11434

# Increase timeout
export MCP_TIMEOUT=60
```

**Problem**: Wrong model
```bash
# List available models
ollama list

# Change default model
export OLLAMA_MODEL=mistral
```

## Integration with Existing Workflows

### CI/CD Integration
```yaml
# .github/workflows/agent-build.yml
- name: Run Enhanced Build Agent
  run: |
    cd Tools/Automation/agents
    ./agent_build_enhanced.sh CodingReviewer true
```

### Pre-commit Hook
```bash
#!/bin/bash
# .git/hooks/pre-commit

cd Tools/Automation/agents
./agent_debug_enhanced.sh log $(git diff --name-only --cached | grep '\.log$')
```

### Scheduled Learning
```bash
# Cron job to scan logs daily
0 2 * * * cd /path/to/project/Tools/Automation/agents && ./error_learning_agent.sh --scan-once /path/to/logs/*.log
```

## Monitoring & Maintenance

### Daily Checks
```bash
# Knowledge base size
du -sh knowledge/*.json

# Recent patterns
jq '.[] | select(.last_seen > "2025-10-25")' knowledge/error_patterns.json

# Fix success rates
jq '.[] | select(.success_rate < 0.5)' knowledge/fix_history.json
```

### Weekly Tasks
1. Backup knowledge base: `cp -r knowledge knowledge.backup.$(date +%Y%m%d)`
2. Review low-confidence fixes: `jq '.[] | select(.confidence < 0.5)' knowledge/fix_history.json`
3. Update agent action implementations based on learned patterns

### Monthly Tasks
1. Analyze correlation matrix for patterns
2. Remove obsolete error patterns (old versions)
3. Update MCP client if Ollama models updated
4. Review and optimize confidence thresholds

## Troubleshooting

### "Knowledge base not found"
```bash
cd Tools/Automation/agents
./implement_phase1.sh  # Re-run bootstrap
```

### "Decision engine failed"
```bash
# Check Python 3 installed
python3 --version

# Check file permissions
chmod +x decision_engine.py fix_suggester.py

# Test manually
python3 decision_engine.py evaluate "test error"
```

### "MCP client not available"
```bash
# Check if installed
ls -la mcp_client.sh

# Check permissions
chmod +x mcp_client.sh

# Test connectivity
./mcp_client.sh test
```

### "Integration test failed"
```bash
# Run each component test individually
python3 decision_engine.py evaluate "test"
python3 fix_suggester.py suggest "test"
./mcp_client.sh test
source agent_helpers.sh && agent_suggest_fix "test"
```

## Best Practices

### DO:
- ✅ Run bootstrap script before first use
- ✅ Test integration after any updates
- ✅ Record all fix attempts (automatic with helpers)
- ✅ Backup knowledge base regularly
- ✅ Use auto-fix for high-confidence fixes only
- ✅ Review AI suggestions before executing
- ✅ Override action implementations for project-specific logic

### DON'T:
- ❌ Edit knowledge JSON files directly (use update_knowledge.py)
- ❌ Run auto-fix on production without testing
- ❌ Ignore low-confidence warnings
- ❌ Skip integration tests after changes
- ❌ Delete fix_history.json (loses learning)
- ❌ Use generic error messages (be specific)

## Support & Documentation

- **Full Implementation Details**: `PHASE1_IMPLEMENTATION_COMPLETE.md`
- **Master Plan**: `AGENT_ENHANCEMENT_MASTER_PLAN.md`
- **Architecture Guide**: `../../ARCHITECTURE.md`
- **Component Help**: All scripts support `--help` flag

## Quick Command Reference

```bash
# Setup
./implement_phase1.sh                          # Bootstrap Phase 1
./test_phase1_integration.sh                   # Validate installation

# Build
./agent_build_enhanced.sh <project> [true]     # Build with auto-fix

# Debug
./agent_debug_enhanced.sh error "<pattern>"    # Debug error
./agent_debug_enhanced.sh log <file>           # Analyze log

# Components
python3 decision_engine.py evaluate "<error>"  # Get recommendation
python3 fix_suggester.py suggest "<error>"     # Get fix suggestion
./mcp_client.sh test                          # Test AI connection
./error_learning_agent.sh --scan-once <log>   # Learn from log

# Knowledge
cat knowledge/error_patterns.json | jq .      # View patterns
cat knowledge/fix_history.json | jq .         # View history
```

---

**Last Updated:** October 25, 2025  
**Phase 1 Version:** 1.0.0  
**Maintainer:** Quantum Agent System

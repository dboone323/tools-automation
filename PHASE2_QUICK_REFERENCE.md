# Phase 2 Quick Reference Guide

**Intelligence Amplification Components**

---

## 🚀 Quick Start

```bash
cd Tools/Automation/agents

# Initialize Phase 2 (run once)
./integrate_phase2.sh

# Test installation
./test_phase2_integration.sh

# View current status
./context_loader.sh summary
```

---

## 📚 Knowledge Sync Commands

### Sync Knowledge Base
```bash
# Run sync once
./knowledge_sync.sh sync

# Continuous mode (every 5 minutes)
./knowledge_sync.sh watch

# Stop continuous mode
pkill -f knowledge_sync.sh
```

### Query Knowledge
```bash
# View best practices
./knowledge_sync.sh query best_practices

# View global patterns
./knowledge_sync.sh query global_patterns

# View anti-patterns
./knowledge_sync.sh query anti_patterns

# View statistics
./knowledge_sync.sh query stats

# View insights for specific agent type
cat shared_insights/build_insights.json | jq .
```

---

## ✅ Validation Commands

### Syntax Validation (Layer 1)
```bash
# Validate Swift file
python3 validation_framework.py syntax path/to/file.swift

# Validate Python file
python3 validation_framework.py syntax path/to/file.py

# Validate Bash script
python3 validation_framework.py syntax path/to/script.sh
```

### Full Validation (All 4 Layers)
```bash
# Validate with context
python3 validation_framework.py all path/to/file.swift '{
  "operation": "fix",
  "affects_build": true,
  "affects_tests": true
}'

# Parse validation results
validation=$(python3 validation_framework.py all file.swift '{}')
passed=$(echo "$validation" | jq -r '.passed')

if [ "$passed" = "true" ]; then
    echo "✅ Validation passed"
else
    echo "❌ Validation failed"
    echo "$validation" | jq '.layers'
fi
```

---

## 🔄 Rollback Commands

### Create Checkpoint
```bash
# Create checkpoint before operation
checkpoint=$(./auto_rollback.sh checkpoint "operation_name" "file1.swift file2.swift")
echo "Created checkpoint: $checkpoint"
```

### Monitor Validation & Auto-Rollback
```bash
# Run operation
# ... your operation code ...

# Validate
validation=$(python3 validation_framework.py all file.swift '{}')

# Auto-rollback if failed
./auto_rollback.sh monitor "$validation" "$checkpoint"
```

### Manual Restore
```bash
# List available checkpoints
./auto_rollback.sh list

# Restore specific checkpoint
./auto_rollback.sh restore checkpoint_20251025_123456

# Force restore (ignore warnings)
./auto_rollback.sh restore checkpoint_20251025_123456 --force
```

### Cleanup
```bash
# Clean old checkpoints (keep last 10)
./auto_rollback.sh clean 10

# Clean all checkpoints
./auto_rollback.sh clean 0
```

---

## ✨ Success Verification Commands

### Verify Code Generation
```bash
python3 success_verifier.py codegen path/to/file.swift '{
  "project": "CodingReviewer",
  "operation": "fix"
}'
```

### Verify Build
```bash
python3 success_verifier.py build '{
  "project": "CodingReviewer",
  "build_command": "xcodebuild"
}'
```

### Verify Tests
```bash
python3 success_verifier.py test '{
  "project": "CodingReviewer",
  "test_command": "xcodebuild test"
}'
```

### Verify Fix
```bash
python3 success_verifier.py fix "Build failed: No such module SharedKit" '{
  "operation": "build",
  "project": "CodingReviewer"
}'
```

---

## 🧠 Context Operations

### Load Context
```bash
# Load full context for operation
./context_loader.sh load build "Fix SharedKit import error"

# This returns JSON with:
# - project_memory
# - recent_changes (git log)
# - related_issues
# - sprint_goals
```

### View Project Memory
```bash
# View entire memory
./context_loader.sh memory

# View specific section
./context_loader.sh memory | jq '.history.successful_patterns'
./context_loader.sh memory | jq '.current_state'
```

### View Summary
```bash
# Get quick status overview
./context_loader.sh summary

# Output includes:
# - Project name
# - Last update time
# - Common errors count
# - Successful patterns count
# - Architecture rules count
# - Test coverage %
# - Build status
```

### Record Success
```bash
# Record successful pattern
./context_loader.sh record-success "Pattern name" "Description of what works"

# Example
./context_loader.sh record-success "Clean build fix" "Running clean build before regular build resolves most dependency issues"
```

### Record Error
```bash
# Record common error
./context_loader.sh record-error "Error message" frequency

# Example
./context_loader.sh record-error "Build failed: No such module SharedKit" 3
```

### Update State
```bash
# Update current state field
./context_loader.sh update "current_state.test_coverage" "0.82"
./context_loader.sh update "current_state.build_status" "passing"
```

---

## 🔧 Integrated Workflow

### Using the Phase 2 Template

**1. Create your agent script:**
```bash
#!/bin/bash
source agent_workflow_phase2.sh

# Define your operation function
execute_operation() {
    local operation="$1"
    local file_path="$2"
    
    echo "Executing $operation on $file_path..."
    
    # Your agent logic here
    # Return 0 for success, non-zero for failure
    
    return 0
}

# Run with full Phase 1+2 workflow
run_agent_with_full_validation "fix_build_error" "path/to/file.swift" '{
  "project": "CodingReviewer",
  "affects_build": true
}'
```

**2. The workflow automatically:**
- ✅ Loads historical context
- ✅ Checks knowledge base for insights
- ✅ Creates checkpoint before operation
- ✅ Executes your operation
- ✅ Validates at 4 layers
- ✅ Auto-rolls back if validation fails
- ✅ Verifies success comprehensively
- ✅ Records success in context memory
- ✅ Syncs new learnings to knowledge base

---

## 📊 Monitoring & Status

### Check System Health
```bash
# Context status
./context_loader.sh summary

# Knowledge base stats
./knowledge_sync.sh query stats

# Recent checkpoints
./auto_rollback.sh list | head -5

# Validation history (check logs)
tail -f ../../../logs/validation_*.log
```

### View Agent Insights
```bash
# Build agent insights
cat shared_insights/build_insights.json | jq .

# Debug agent insights
cat shared_insights/debug_insights.json | jq .

# Codegen agent insights
cat shared_insights/codegen_insights.json | jq .

# Test agent insights
cat shared_insights/test_insights.json | jq .
```

---

## 🔍 Troubleshooting

### Knowledge Sync Issues
```bash
# Check central hub exists
cat knowledge/central_hub.json | jq '.metadata'

# Verify shared insights directory
ls -la shared_insights/

# Check sync is running
ps aux | grep knowledge_sync.sh

# Manual sync
./knowledge_sync.sh sync
```

### Validation Issues
```bash
# Test validation directly
python3 validation_framework.py syntax test_file.swift

# Check if validation layers work
python3 -c "from validation_framework import ValidationFramework; print('OK')"

# View validation logs
find ../../../logs -name "validation_*.log" -exec tail -20 {} \;
```

### Rollback Issues
```bash
# List all checkpoints
./auto_rollback.sh list

# Check checkpoint directory
ls -la checkpoints/

# Verify git status
git status

# Force restore if needed
./auto_rollback.sh restore checkpoint_name --force
```

### Context Loader Issues
```bash
# Check project memory exists
cat context/project_memory.json | jq .

# Verify git integration
./context_loader.sh get-recent-changes 5

# Test context loading
./context_loader.sh load test "Test operation"
```

---

## 🎯 Best Practices

### 1. Always Create Checkpoints
```bash
# Before any risky operation
checkpoint=$(./auto_rollback.sh checkpoint "operation_$$" "$files")
```

### 2. Use Full Validation for Critical Changes
```bash
# For build-affecting changes
python3 validation_framework.py all file.swift '{
  "affects_build": true,
  "affects_tests": true
}'
```

### 3. Record All Successes and Errors
```bash
# After successful fix
./context_loader.sh record-success "Fix description" "What worked"

# When encountering error
./context_loader.sh record-error "Error message" 1
```

### 4. Sync Knowledge Regularly
```bash
# Run in background
nohup ./knowledge_sync.sh watch > sync.log 2>&1 &

# Or set up cron job
# */5 * * * * cd /path/to/agents && ./knowledge_sync.sh sync
```

### 5. Monitor Context Health
```bash
# Check daily
./context_loader.sh summary

# Update coverage regularly
./context_loader.sh update "current_state.test_coverage" "$coverage"
```

---

## 📝 Configuration

### Knowledge Sync Interval
```bash
# Edit knowledge_sync.sh
SYNC_INTERVAL=300  # 5 minutes (default)
```

### Validation Layer Delays
```python
# Edit validation_framework.py
class ValidationLayer(Enum):
    SYNTAX = (1, 0)           # Immediate
    LOGICAL = (2, 10)         # 10 seconds
    INTEGRATION = (3, 30)     # 30 seconds
    OUTCOME = (4, 300)        # 5 minutes
```

### Checkpoint Retention
```bash
# Keep last N checkpoints
./auto_rollback.sh clean 10  # Keep 10 most recent
```

### Context Git History Depth
```bash
# Edit context_loader.sh
MAX_COMMITS=10  # Last 10 commits (default)
```

---

## 🔗 Related Documentation

- **Full Implementation Guide**: [PHASE2_IMPLEMENTATION_COMPLETE.md](PHASE2_IMPLEMENTATION_COMPLETE.md)
- **Master Plan**: [AGENT_ENHANCEMENT_MASTER_PLAN.md](AGENT_ENHANCEMENT_MASTER_PLAN.md)
- **Phase 1 Documentation**: [PHASE1_IMPLEMENTATION_COMPLETE.md](PHASE1_IMPLEMENTATION_COMPLETE.md)

---

**Need help?** Check the full documentation or run `./test_phase2_integration.sh` to verify your setup.

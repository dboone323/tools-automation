# Phase 3 Quick Reference Guide

**Advanced Autonomy System - Command Reference**

---

## Installation & Setup

```bash
# Install Phase 3 (requires Phase 1 & 2)
cd Tools/Automation/agents
./integrate_phase3.sh

# Validate installation
./test_phase3_integration.sh
```

---

## 1. Failure Prediction Engine

**Location:** `Tools/Automation/agents/prediction_engine.py`

### Commands

```bash
# Analyze a code change for risks
python3 prediction_engine.py analyze <file_path> <change_type>
# change_type: addition, modification, deletion

# Update prediction outcome (for accuracy tracking)
python3 prediction_engine.py update <prediction_id> <outcome>
# outcome: success, failure

# Check prediction accuracy
python3 prediction_engine.py accuracy
```

### Examples

```bash
# Analyze a Swift file modification
python3 prediction_engine.py analyze Projects/CodingReviewer/ViewModel.swift modification

# Update after operation completes
python3 prediction_engine.py update pred_20251025180634 success

# Check how well predictions are working
python3 prediction_engine.py accuracy
```

### Output

```json
{
  "risk_score": 0.65,
  "risk_level": "high",
  "predicted_issues": [
    {
      "type": "complexity",
      "severity": "medium",
      "description": "File has 520 lines (>500), increasing failure risk"
    }
  ],
  "preventions": [
    {
      "strategy": "comprehensive_testing",
      "action": "Run full test suite",
      "priority": "high"
    }
  ],
  "recommendation": "CAUTION: High risk detected. Apply suggested preventions."
}
```

### Risk Levels
- **0.0-0.4**: Low (SAFE)
- **0.4-0.6**: Medium (REVIEW)
- **0.6-0.8**: High (CAUTION)
- **0.8-1.0**: Critical (BLOCK)

---

## 2. Proactive Monitoring System

**Location:** `Tools/Automation/agents/proactive_monitor.sh`

### Commands

```bash
# Initialize monitoring system
./proactive_monitor.sh init

# Run all monitors once
./proactive_monitor.sh run

# Continuous monitoring (every 5 minutes)
./proactive_monitor.sh watch

# Check current status
./proactive_monitor.sh status

# List active alerts
./proactive_monitor.sh alerts

# Resolve an alert
./proactive_monitor.sh resolve <alert_id>
```

### Examples

```bash
# Start background monitoring
nohup ./proactive_monitor.sh watch > monitor.log 2>&1 &

# Check for alerts
./proactive_monitor.sh alerts

# Daily status check
./proactive_monitor.sh status

# Resolve alert after fixing issue
./proactive_monitor.sh resolve alert_20251025180634
```

### Monitors

1. **Code Complexity** (threshold: 15)
2. **Test Coverage** (alert on >5% drop)
3. **Build Times** (alert on >20% increase)
4. **Error Rates** (alert at >10 errors/day)
5. **Dependencies** (alert if >90 days stale)

### Configuration

```bash
# Set environment variables before running
export MONITOR_INTERVAL=300              # 5 minutes
export COMPLEXITY_THRESHOLD=15
export COVERAGE_DROP_THRESHOLD=5         # %
export BUILD_TIME_INCREASE_THRESHOLD=20  # %
export ERROR_RATE_THRESHOLD=10           # errors/day
export DEPENDENCY_AGE_THRESHOLD=90       # days
```

---

## 3. Strategy Performance Tracking

**Location:** `Tools/Automation/agents/strategy_tracker.py`

### Commands

```bash
# Record strategy execution
python3 strategy_tracker.py record <strategy_id> <context> <success> <time>
# success: true or false
# time: execution time in seconds

# Record strategy adaptation
python3 strategy_tracker.py adapt <strategy_id> <description> <impact>

# Get strategy performance
python3 strategy_tracker.py performance <strategy_id>

# Find best strategy for context
python3 strategy_tracker.py best <context>

# List all strategies
python3 strategy_tracker.py list

# Get recommendations for context
python3 strategy_tracker.py recommend <context>
```

### Examples

```bash
# Record successful rebuild
python3 strategy_tracker.py record rebuild build_error true 58.3

# Record failed clean build
python3 strategy_tracker.py record clean_build dependency_issue false 92.1

# Record adaptation
python3 strategy_tracker.py adapt rebuild "Added pre-validation" "+12% success"

# Get rebuild performance
python3 strategy_tracker.py performance rebuild

# Find best strategy for build errors
python3 strategy_tracker.py best build_error

# Get all recommendations
python3 strategy_tracker.py recommend build_error
```

### Default Strategies

- **rebuild**: Clean rebuild (risk: 0.1, ~60s)
- **clean_build**: Clean and rebuild (risk: 0.2, ~90s)
- **fix_imports**: Update imports (risk: 0.3, ~40s)
- **run_tests**: Execute test suite (risk: 0.1, ~180s)

---

## 4. Adaptive Strategy Evolution

**Location:** `Tools/Automation/agents/strategy_evolution.py`

### Commands

```bash
# Generate strategy variant
python3 strategy_evolution.py variant <strategy_id>

# Create A/B test
python3 strategy_evolution.py create-test <strategy_id> <context> [sample_size]
# sample_size: default 20

# Record experiment result
python3 strategy_evolution.py record <experiment_id> <variant> <success> <time>
# variant: base or variant

# Check experiment status
python3 strategy_evolution.py status <experiment_id>

# List active experiments
python3 strategy_evolution.py list

# View evolution history
python3 strategy_evolution.py history
```

### Examples

```bash
# Generate variant of rebuild strategy
python3 strategy_evolution.py variant rebuild

# Create A/B test for build errors
exp_id=$(python3 strategy_evolution.py create-test rebuild build_error 20)

# Record base strategy result
python3 strategy_evolution.py record $exp_id base true 55.2

# Record variant result
python3 strategy_evolution.py record $exp_id variant true 48.7

# Check experiment status
python3 strategy_evolution.py status $exp_id

# List all active experiments
python3 strategy_evolution.py list

# View successful evolutions
python3 strategy_evolution.py history
```

### Mutation Types

- **adjust_timing**: Modify timing parameters (±20%)
- **add_pre_step**: Add preparation steps
- **add_post_step**: Add verification steps
- **change_order**: Reorder execution steps
- **add_validation**: Add intermediate validations

### Winner Criteria

- **Scoring**: 60% success rate + 40% time efficiency
- **Threshold**: Variant must be 5% better to be adopted
- **Sample Size**: Default 20 executions per variant

---

## 5. Emergency Response System

**Location:** `Tools/Automation/agents/emergency_response.sh`

### Commands

```bash
# Initialize emergency system
./emergency_response.sh init

# Classify error severity
./emergency_response.sh classify "<error_message>"

# Declare emergency
./emergency_response.sh declare "<description>" <severity> [context_json]
# severity: critical, high, medium, low

# Handle emergency (starts escalation)
./emergency_response.sh handle <emergency_id>

# Resolve emergency
./emergency_response.sh resolve <emergency_id> "<resolution>"

# List emergencies
./emergency_response.sh list

# Check safe-mode status
./emergency_response.sh safe-mode

# Disable safe-mode
./emergency_response.sh disable-safe-mode
```

### Examples

```bash
# Classify an error
severity=$(./emergency_response.sh classify "Build failed: No such module")

# Declare critical emergency
emergency_id=$(./emergency_response.sh declare "Build system failure" "critical" '{"file":"ViewModel.swift"}')

# Start escalation
./emergency_response.sh handle $emergency_id

# Check if in safe-mode
./emergency_response.sh safe-mode

# After fixing, resolve emergency
./emergency_response.sh resolve $emergency_id "Rebuilt from clean state"

# Disable safe-mode if enabled
./emergency_response.sh disable-safe-mode
```

### Severity Levels

- **Critical**: System down, data loss risk (requires human)
- **High**: Feature broken, blocking development
- **Medium**: Degraded performance, workarounds exist
- **Low**: Minor issue, scheduled fix acceptable

### Escalation Ladder

**Level 1: Agent Auto-Fix** (0-2 minutes)
- Actions: auto_fix, retry, alternative_strategy
- Timeout: 120 seconds

**Level 2: Alternative Strategy** (2-5 minutes)
- Actions: try_alternative, rollback, clean_environment
- Timeout: 300 seconds

**Level 3: Cross-Agent Consultation** (5-10 minutes)
- Actions: query_knowledge_base, check_similar_issues
- Timeout: 600 seconds

**Level 4: Human Notification** (10-15 minutes)
- Actions: notify_human, create_ticket, document_issue
- Timeout: 900 seconds

**Level 5: System Safe-Mode** (critical failures)
- Actions: enable_safe_mode, halt_operations, preserve_state
- Manual intervention required

---

## 6. Integrated Workflow (All Phases)

**Location:** `Tools/Automation/agents/agent_workflow_phase3.sh`

### Usage in Agent Scripts

```bash
#!/bin/bash
source agent_workflow_phase3.sh

# Define your operation logic
execute_operation() {
    local operation="$1"
    local file_path="$2"
    local context="$3"
    
    # Your agent logic here
    # Return 0 for success, non-zero for failure
    return 0
}

# Run with full autonomy (15-step workflow)
run_agent_with_full_autonomy "build" "ViewModel.swift" '{"project":"CodingReviewer"}'
```

### Workflow Steps

1. **Predict Failures**: Analyze risk before execution
2. **Check Monitors**: Review proactive alerts
3. **Select Strategy**: Choose optimal approach
4. **Load Context**: Get historical awareness
5. **Check Knowledge**: Query related issues
6. **Create Checkpoint**: Prepare for rollback
7. **Execute with Emergency Handling**: Run operation
8. **Validate**: 4-layer validation
9. **Auto-Rollback**: Restore if failed
10. **Verify Success**: Comprehensive checks
11. **Record Strategy Performance**: Update tracker
12. **Update Prediction**: Accuracy tracking
13. **Record Success**: Update context memory
14. **Sync Knowledge**: Share learnings
15. **Resolve Emergency**: Close if declared

---

## Common Workflows

### Daily Operations

```bash
# Morning: Check system status
./proactive_monitor.sh status
./emergency_response.sh list
python3 strategy_tracker.py list

# During work: Use Phase 3 enhanced workflow
source agent_workflow_phase3.sh
run_agent_with_full_autonomy "operation" "file.swift" '{}'

# Evening: Review and resolve
./proactive_monitor.sh alerts
python3 prediction_engine.py accuracy
python3 strategy_evolution.py list
```

### Weekly Tasks

```bash
# Review strategy performance
python3 strategy_tracker.py list | jq '.'

# Check A/B test results
python3 strategy_evolution.py history

# Review resolved emergencies
./emergency_response.sh list | jq '.[] | select(.status=="resolved")'

# Update monitoring thresholds if needed
export COMPLEXITY_THRESHOLD=20  # Increase if too noisy
```

### Monthly Maintenance

```bash
# Analyze prediction accuracy
python3 prediction_engine.py accuracy

# Review evolution effectiveness
python3 strategy_evolution.py history | jq '.successful_evolutions'

# Check emergency patterns
./emergency_response.sh list | jq 'group_by(.severity)'

# Clean old data
# (Add cleanup scripts as needed)
```

---

## Integration with Existing Agents

### Minimal Integration (Prediction Only)

```bash
# Before risky operation
prediction=$(python3 prediction_engine.py analyze "$file" "modification")
risk=$(echo "$prediction" | jq -r '.risk_score')

if (( $(echo "$risk > 0.6" | bc -l) )); then
    echo "High risk detected, applying preventions..."
    # Apply suggested preventions
fi
```

### Moderate Integration (Prediction + Strategy)

```bash
# Select best strategy
strategy=$(python3 strategy_tracker.py best "$context")
strategy_id=$(echo "$strategy" | jq -r '.strategy_id')

# Execute strategy
if execute_strategy "$strategy_id"; then
    python3 strategy_tracker.py record "$strategy_id" "$context" true $time
else
    python3 strategy_tracker.py record "$strategy_id" "$context" false $time
fi
```

### Full Integration (Complete Workflow)

```bash
# Use the complete 15-step workflow
source agent_workflow_phase3.sh
run_agent_with_full_autonomy "operation" "file.swift" '{}'
```

---

## Troubleshooting

### Prediction Engine Issues

```bash
# Check if knowledge base exists
ls -la Tools/Automation/agents/knowledge/error_patterns.json

# Validate predictions.json
jq '.' Tools/Automation/agents/knowledge/predictions.json

# Test prediction
python3 prediction_engine.py analyze TestFile.swift modification
```

### Monitoring Issues

```bash
# Check if monitoring is running
ps aux | grep proactive_monitor

# Verify metrics file
jq '.' Tools/Automation/agents/knowledge/proactive_metrics.json

# Test monitoring
./proactive_monitor.sh run
```

### Strategy Tracking Issues

```bash
# Verify strategies exist
python3 strategy_tracker.py list

# Check strategy history
jq '.' Tools/Automation/agents/knowledge/strategies.json
jq '.' Tools/Automation/agents/knowledge/strategy_history.json
```

### Emergency Response Issues

```bash
# Check if in safe-mode
./emergency_response.sh safe-mode

# List active emergencies
./emergency_response.sh list | jq '.[] | select(.status=="active")'

# Force disable safe-mode (if needed)
rm -f Tools/Automation/agents/.safe_mode
```

---

## Performance Tips

1. **Prediction Engine**: Cache results for unchanged files
2. **Proactive Monitoring**: Use watch mode for continuous monitoring
3. **Strategy Tracking**: Review recommendations weekly
4. **Strategy Evolution**: Start experiments for low-performing strategies
5. **Emergency Response**: Set appropriate timeout thresholds

---

## Files & Locations

```
Tools/Automation/agents/
├── prediction_engine.py          # Failure prediction
├── proactive_monitor.sh          # Continuous monitoring
├── strategy_tracker.py           # Performance tracking
├── strategy_evolution.py         # A/B testing
├── emergency_response.sh         # Emergency handling
├── agent_workflow_phase3.sh      # Complete workflow
├── integrate_phase3.sh           # Integration script
├── test_phase3_integration.sh    # Test suite
└── knowledge/
    ├── predictions.json          # Prediction history
    ├── proactive_metrics.json    # Monitor metrics
    ├── proactive_alerts.json     # Active alerts
    ├── strategies.json           # Strategy definitions
    ├── strategy_history.json     # Execution history
    ├── strategy_evolution.json   # Evolution tracking
    ├── ab_experiments.json       # A/B tests
    ├── emergencies.json          # Emergency records
    └── escalations.json          # Escalation history
```

---

**For complete documentation, see [PHASE3_IMPLEMENTATION_COMPLETE.md](PHASE3_IMPLEMENTATION_COMPLETE.md)**

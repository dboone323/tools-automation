# 🤖 AI Agent Monitoring & Performance Guide

**Date:** October 6, 2025  
**Status:** ✅ Ollama Installed & Configured  
**Models:** CodeLlama (3.8GB) + Llama2 (3.8GB)  
**AI Coverage:** 100% (12/12 agents)

---

## 📊 Quick Status Check

### Installed Models
```bash
ollama list
```

**Current Models:**
- ✅ `codellama:latest` (3.8 GB) - Code generation, review, optimization
- ✅ `llama2:latest` (3.8 GB) - CI/CD analysis, deployment decisions
- ✅ `codellama:13b` (7.4 GB) - Advanced code analysis (optional)
- ✅ `codellama:7b` (3.8 GB) - Lightweight code tasks
- ⚡ Additional models available for specialized tasks

### Verify Ollama Service
```bash
# Check if Ollama is running
ps aux | grep ollama | grep -v grep

# Test basic functionality
ollama run llama2 "Say hello"
```

---

## 🧪 AI Feature Testing

### Test 1: Code Complexity Analysis (CodeLlama)
```bash
cd /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation
source enhancements/ai_codegen_optimizer.sh

# Create test Swift file
cat > /tmp/test.swift << 'EOF'
func fibonacci(_ n: Int) -> Int {
    if n <= 1 { return n }
    return fibonacci(n - 1) + fibonacci(n - 2)
}
EOF

# Analyze complexity
ai_analyze_complexity /tmp/test.swift
# Expected: "medium" or "high" (recursive, exponential complexity)
```

### Test 2: Function Naming Suggestions
```bash
# Get AI-suggested function names
ai_suggest_names "Validate user email address format" "function"
# Expected: 3 clear, descriptive function names
```

### Test 3: Deployment Readiness (Llama2)
```bash
source enhancements/ai_integration_optimizer.sh

# Create test metrics
cat > /tmp/metrics.txt << 'EOF'
Build: Passed
Tests: 42/42 passed
Coverage: 87%
Security: No vulnerabilities
Performance: Within limits
EOF

# Check deployment readiness
ai_check_deployment_readiness /tmp/metrics.txt
# Expected: "GO" or "NO_GO" with reasoning
```

### Test 4: Deployment Strategy Selection
```bash
# Get AI recommendation for deployment strategy
ai_select_deployment_strategy "production" "high" "critical"
# Expected: "blue-green" or "canary" (safe strategies for critical services)
```

---

## 📈 Monitoring AI Performance

### 1. Track AI Response Times

Create a monitoring script:
```bash
cat > /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/monitor_ai_performance.sh << 'EOF'
#!/bin/bash

# AI Performance Monitoring Script
LOG_FILE="ai_performance_log.txt"

echo "=== AI Performance Test - $(date) ===" >> "$LOG_FILE"

# Test CodeLlama response time
echo "Testing CodeLlama..."
START=$(date +%s)
echo "Hello world in Swift" | ollama run codellama --verbose 2>&1 > /dev/null
END=$(date +%s)
CODELLAMA_TIME=$((END - START))
echo "CodeLlama Response Time: ${CODELLAMA_TIME}s" >> "$LOG_FILE"

# Test Llama2 response time
echo "Testing Llama2..."
START=$(date +%s)
echo "Should we deploy?" | ollama run llama2 --verbose 2>&1 > /dev/null
END=$(date +%s)
LLAMA2_TIME=$((END - START))
echo "Llama2 Response Time: ${LLAMA2_TIME}s" >> "$LOG_FILE"

echo "Average Response Time: $(( (CODELLAMA_TIME + LLAMA2_TIME) / 2 ))s" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Display summary
tail -10 "$LOG_FILE"
EOF

chmod +x /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/monitor_ai_performance.sh
```

**Run monitoring:**
```bash
cd /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation
./monitor_ai_performance.sh
```

### 2. Track AI Recommendation Accuracy

Create tracking file:
```bash
cat > /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/ai_accuracy_log.json << 'EOF'
{
  "recommendations": [],
  "metrics": {
    "total_recommendations": 0,
    "accepted": 0,
    "rejected": 0,
    "accuracy_rate": 0.0
  }
}
EOF
```

**Log AI recommendations:**
```bash
# Example: Log a deployment decision
cat >> ai_recommendations.log << EOF
$(date) | agent_integration | ai_check_deployment_readiness | GO | Accepted | Deployment successful
EOF
```

### 3. Monitor Agent AI Usage

```bash
# Check which agents are using AI functions
grep -r "ai_" /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/*.sh | \
  grep -v "^#" | \
  awk -F: '{print $1}' | \
  sort -u | \
  xargs -I {} basename {}
```

**Expected output:**
- agent_backup.sh
- agent_build.sh
- agent_cleanup.sh
- agent_codegen.sh
- agent_integration.sh
- agent_testing.sh

---

## 🎯 AI Function Usage Examples

### Code Generation Agent (agent_codegen)

#### 1. Generate Code
```bash
source enhancements/ai_codegen_optimizer.sh
ai_generate_code "Create a Swift struct for a User with name, email, and age" "swift" "/tmp/generated_code.swift"
cat /tmp/generated_code.swift
```

#### 2. Get Refactoring Suggestions
```bash
# Create sample code with issues
cat > /tmp/code_to_refactor.swift << 'EOF'
func processData(data: [String]) {
    for i in 0..<data.count {
        let item = data[i]
        print(item)
        if item.contains("error") {
            print("Error found!")
        }
        if item.contains("warning") {
            print("Warning found!")
        }
    }
}
EOF

# Get AI refactoring suggestions
ai_suggest_refactoring /tmp/code_to_refactor.swift
```

#### 3. Automated Code Review
```bash
ai_code_review /tmp/code_to_refactor.swift
# Returns APPROVE or REQUEST_CHANGES with detailed feedback
```

#### 4. Generate API Documentation
```bash
ai_generate_api_docs /tmp/generated_code.swift /tmp/api_docs.md
cat /tmp/api_docs.md
```

#### 5. Generate Test Cases
```bash
ai_generate_test_cases /tmp/generated_code.swift "XCTest"
```

### CI/CD Integration Agent (agent_integration)

#### 1. Optimize GitHub Workflow
```bash
source enhancements/ai_integration_optimizer.sh

# Create sample workflow
cat > /tmp/workflow.yml << 'EOF'
name: CI
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: swift test
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: swift build
EOF

# Get optimization suggestions
ai_optimize_workflow /tmp/workflow.yml
```

#### 2. Analyze CI Failure
```bash
# Simulate failure log
cat > /tmp/ci_failure.log << 'EOF'
Error: Test failed - testUserValidation
Expected: true
Actual: false
Stack trace:
  at UserValidator.validate (line 42)
  at TestUserValidation.testEmailValidation (line 18)
EOF

ai_analyze_ci_failure /tmp/ci_failure.log
```

#### 3. Recommend Deployment Window
```bash
ai_recommend_deployment_window "production" "2024-10-07" "high"
# Returns optimal deployment time window
```

#### 4. Assess Rollback Need
```bash
# Simulate deployment metrics
cat > /tmp/deployment_metrics.txt << 'EOF'
Error Rate: 5%
Response Time: +200ms
CPU Usage: 85%
Memory Usage: 78%
User Reports: 3 critical issues
EOF

ai_assess_rollback_need /tmp/deployment_metrics.txt
# Returns ROLLBACK or MONITOR with reasoning
```

---

## 📊 Performance Metrics to Track

### 1. Response Times
- **CodeLlama:** 2-10 seconds (depends on prompt complexity)
- **Llama2:** 2-8 seconds (general analysis)
- **Target:** <5 seconds for most operations

### 2. Accuracy Metrics
Track these for each AI function:
- **Code Complexity:** Compare AI assessment vs manual review
- **Naming Suggestions:** % of suggestions adopted
- **Deployment Decisions:** GO/NO_GO accuracy rate
- **Code Reviews:** % of issues correctly identified

### 3. Resource Usage
```bash
# Monitor Ollama resource usage
top -l 1 | grep ollama

# Check disk space for models
du -sh ~/.ollama/models
```

### 4. Agent Performance
```bash
# Check agent execution times (with vs without AI)
time ./agents/agent_codegen.sh analyze /path/to/code
time ./agents/agent_integration.sh check-deployment
```

---

## 🔧 Troubleshooting

### Issue: Ollama Not Responding
```bash
# Restart Ollama service
pkill ollama
ollama serve &

# Check if models are accessible
ollama list
```

### Issue: Slow AI Responses
```bash
# Use smaller, faster models
ollama pull codellama:7b  # Instead of codellama:13b

# Check system resources
top -l 1 | grep -E "CPU|PhysMem"
```

### Issue: AI Functions Returning Defaults
```bash
# Verify Ollama is running
ps aux | grep ollama | grep -v grep

# Test direct Ollama access
echo "test" | ollama run llama2

# Check agent logs for errors
tail -f /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/*.log
```

### Issue: Inaccurate AI Recommendations
**Solution:** Improve prompts in AI modules
- Edit prompts in `enhancements/ai_*_optimizer.sh`
- Add more context to prompts
- Use more specific examples
- Consider using larger models (13b instead of 7b)

---

## 🚀 Advanced Features (Future)

### 1. Model Selection Per Agent
```bash
# Allow agents to choose optimal model per task
# Edit agent configuration:
cat >> agents/agent_codegen.sh << 'EOF'
# Use larger model for complex analysis
AI_MODEL_COMPLEX="codellama:13b"
AI_MODEL_SIMPLE="codellama:7b"

# Select model based on task complexity
if [[ $complexity == "high" ]]; then
    MODEL=$AI_MODEL_COMPLEX
else
    MODEL=$AI_MODEL_SIMPLE
fi
EOF
```

### 2. Learning Loops with Feedback
```bash
# Track AI recommendations and outcomes
cat > ai_feedback_loop.sh << 'EOF'
#!/bin/bash
# Log AI recommendation
echo "$(date)|$AGENT|$FUNCTION|$RECOMMENDATION|$OUTCOME" >> ai_feedback.log

# Analyze patterns quarterly
# Use feedback to improve prompts
EOF
```

### 3. Response Caching
```bash
# Cache AI responses for common queries
cat > ai_cache.sh << 'EOF'
#!/bin/bash
CACHE_FILE="~/.ai_response_cache.json"

cache_response() {
    local key=$(echo "$1" | md5)
    local response="$2"
    echo "{\"$key\": \"$response\"}" >> "$CACHE_FILE"
}

get_cached_response() {
    local key=$(echo "$1" | md5)
    jq -r ".[\"$key\"]" "$CACHE_FILE" 2>/dev/null
}
EOF
```

### 4. A/B Testing AI Strategies
```bash
# Compare AI recommendations vs manual decisions
cat > ab_test_ai.sh << 'EOF'
#!/bin/bash
# 50% of time use AI recommendation
# 50% of time use manual decision
# Track success rates of each approach
EOF
```

---

## 📝 Performance Log Template

Create weekly performance reports:
```bash
cat > weekly_ai_performance_report.md << 'EOF'
# AI Performance Report - Week of $(date +%Y-%m-%d)

## Summary
- Total AI operations: X
- Average response time: Xs
- Recommendation acceptance rate: X%
- Issues prevented: X

## Top Performing Functions
1. ai_check_deployment_readiness - 95% accuracy
2. ai_analyze_complexity - 90% accuracy
3. ai_suggest_refactoring - 85% adoption rate

## Areas for Improvement
- Reduce response time for complex analysis
- Improve naming suggestion relevance
- Fine-tune deployment strategy recommendations

## Action Items
- [ ] Update prompts for better accuracy
- [ ] Consider larger models for critical decisions
- [ ] Implement response caching

EOF
```

---

## ✅ Success Criteria

### AI is Working Well When:
- ✅ Response times < 5 seconds for most operations
- ✅ Recommendation acceptance rate > 80%
- ✅ No false positives in critical decisions (deployment GO/NO_GO)
- ✅ Code complexity assessments match manual review
- ✅ Generated code compiles without errors
- ✅ Test case suggestions are relevant and comprehensive

### Review AI Performance:
- **Daily:** Check response times and error rates
- **Weekly:** Review recommendation accuracy
- **Monthly:** Analyze trends and optimize prompts
- **Quarterly:** Evaluate ROI and consider model upgrades

---

## 🎯 Next Steps

1. **Run Initial Tests** (20 minutes)
   ```bash
   cd /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation
   ./test_ai_features.sh
   ```

2. **Monitor for 1 Week** (ongoing)
   - Track response times
   - Log recommendation outcomes
   - Collect user feedback

3. **Optimize Prompts** (based on results)
   - Update prompts in `enhancements/ai_*_optimizer.sh`
   - A/B test different prompt strategies
   - Fine-tune for your specific use cases

4. **Scale Up** (if needed)
   - Consider `codellama:13b` for complex analysis
   - Implement response caching
   - Add learning loops

---

**For Questions or Issues:**
- Check agent logs in `Tools/Automation/agents/*.log`
- Review AI function implementations in `enhancements/ai_*_optimizer.sh`
- Test Ollama directly: `ollama run codellama "test prompt"`
- Monitor system resources: `top -l 1`

**Documentation:** `AGENT_ECOSYSTEM_ANALYSIS_20251006.md`  
**Last Updated:** October 6, 2025, 19:15 CST

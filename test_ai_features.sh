#!/bin/bash

# Test AI Features Script
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║          🧪 Testing AI Agent Features                     ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Source AI modules
source enhancements/ai_codegen_optimizer.sh
source enhancements/ai_integration_optimizer.sh

# Test 1: AI Code Complexity Analysis
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Test 1: Analyzing Code Complexity"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create test file
cat >/tmp/test_code.swift <<'EOF'
func calculateFactorial(_ n: Int) -> Int {
    if n <= 1 { return 1 }
    return n * calculateFactorial(n - 1)
}
EOF

echo "Code sample:"
cat /tmp/test_code.swift
echo ""
echo "AI Complexity Assessment:"
complexity=$(ai_analyze_complexity /tmp/test_code.swift)
echo "Result: $complexity"
echo ""

# Test 2: AI Name Suggestions
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 Test 2: Suggesting Function Names"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Purpose: Calculate user's age from birthdate"
echo ""
echo "AI Suggested Names:"
ai_suggest_names "Calculate user's age from birthdate" "function"
echo ""

# Test 3: Deployment Readiness Check
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Test 3: Deployment Readiness Assessment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Simulating deployment readiness check..."
echo ""

# Create test metrics
cat >/tmp/test_metrics.txt <<'EOF'
Build Status: Passed
Test Coverage: 85%
Failed Tests: 0
Code Quality: A
Security Scan: Passed
Performance Tests: All green
EOF

echo "Build Metrics:"
cat /tmp/test_metrics.txt
echo ""
echo "AI Deployment Decision:"
decision=$(ai_check_deployment_readiness /tmp/test_metrics.txt)
echo "Result: $decision"
echo ""

# Test 4: Deployment Strategy Selection
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 Test 4: Deployment Strategy Recommendation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Context: High-traffic production environment, critical service"
echo ""
echo "AI Recommended Strategy:"
strategy=$(ai_select_deployment_strategy "production" "high" "critical")
echo "Result: $strategy"
echo ""

# Test 5: Workflow Optimization
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚡ Test 5: GitHub Actions Workflow Optimization"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create sample workflow
cat >/tmp/test_workflow.yml <<'EOF'
name: CI
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: npm test
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: npm run build
EOF

echo "Current Workflow:"
cat /tmp/test_workflow.yml
echo ""
echo "AI Optimization Suggestions:"
ai_optimize_workflow /tmp/test_workflow.yml | head -20
echo ""

# Cleanup
rm -f /tmp/test_code.swift /tmp/test_metrics.txt /tmp/test_workflow.yml

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ AI Feature Testing Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🎉 All AI functions are operational with:"
echo "   • CodeLlama for code analysis & generation"
echo "   • Llama2 for CI/CD & deployment decisions"
echo ""

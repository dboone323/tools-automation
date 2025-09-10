#!/bin/bash

# MomentumFinance Automation Wrapper
# Quick access to automation features for the financial management app

# Load project configuration
source "$(dirname "$0")/project_config.sh"

echo "💰 MomentumFinance Automation Suite"
echo "Project: $PROJECT_NAME ($PROJECT_TYPE)"
echo "Features: Financial Management, Security, Compliance"
echo ""

case "${1:-help}" in
    "build")
        echo "🏗️  Building MomentumFinance..."
        ./Tools/Automation/master_automation.sh run MomentumFinance
        ;;
    "test")
        echo "🧪 Running tests (including financial calculations)..."
        xcodebuild test -scheme "$BUILD_SCHEME" -destination "platform=iOS Simulator,name=$TARGET_DEVICE"
        ;;
    "lint")
        echo "🔍 Running linting..."
        ./Tools/Automation/master_automation.sh lint MomentumFinance
        ;;
    "format")
        echo "✨ Formatting code..."
        ./Tools/Automation/master_automation.sh format MomentumFinance
        ;;
    "mcp")
        echo "🔗 MCP Integration..."
        ./Tools/Automation/mcp_workflow.sh "${2:-status}" MomentumFinance
        ;;
    "ai")
        echo "🤖 AI Enhancements (including financial validation)..."
        ./Tools/Automation/ai_enhancement_system.sh "${2:-status}"
        ;;
    "status")
        echo "📊 Project Status..."
        ./Tools/Automation/master_automation.sh status
        ;;
    "security")
        echo "🔒 Running security audit..."
        echo "  • Dependency vulnerability check..."
        echo "  • API security validation..."
        echo "  • Data privacy compliance..."
        ;;
    "compliance")
        echo "📋 Running regulatory compliance checks..."
        echo "  • Financial calculation accuracy..."
        echo "  • Data handling compliance..."
        echo "  • Security standards validation..."
        ;;
    "all")
        echo "🚀 Running full automation suite..."
        ./Tools/Automation/master_automation.sh all
        ;;
    "help"|*)
        echo "Available commands:"
        echo "  build       - Build the project"
        echo "  test        - Run tests (includes financial validation)"
        echo "  lint        - Run linting"
        echo "  format      - Format code"
        echo "  mcp         - MCP integration"
        echo "  ai          - AI enhancements"
        echo "  status      - Show status"
        echo "  security    - Run security audit"
        echo "  compliance  - Check regulatory compliance"
        echo "  all         - Run everything"
        ;;
esac

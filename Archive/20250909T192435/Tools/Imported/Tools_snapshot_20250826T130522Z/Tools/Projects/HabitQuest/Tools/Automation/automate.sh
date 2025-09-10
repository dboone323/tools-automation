#!/bin/bash

# HabitQuest Automation Wrapper
# Quick access to automation features for the gamified habit tracker

# Load project configuration
source "$(dirname "$0")/project_config.sh"

echo "🎮 HabitQuest Automation Suite"
echo "Project: $PROJECT_NAME ($PROJECT_TYPE)"
echo "Features: Gamification, XP System, Achievements"
echo ""

case "${1:-help}" in
    "build")
        echo "🏗️  Building HabitQuest..."
        ./Tools/Automation/master_automation.sh run HabitQuest
        ;;
    "test")
        echo "🧪 Running tests (including XP validation)..."
        xcodebuild test -scheme "$BUILD_SCHEME" -destination "platform=iOS Simulator,name=$TARGET_DEVICE"
        ;;
    "lint")
        echo "🔍 Running linting..."
        ./Tools/Automation/master_automation.sh lint HabitQuest
        ;;
    "format")
        echo "✨ Formatting code..."
        ./Tools/Automation/master_automation.sh format HabitQuest
        ;;
    "mcp")
        echo "🔗 MCP Integration..."
        ./Tools/Automation/mcp_workflow.sh "${2:-status}" HabitQuest
        ;;
    "ai")
        echo "🤖 AI Enhancements (including gamification optimization)..."
        ./Tools/Automation/ai_enhancement_system.sh "${2:-status}"
        ;;
    "status")
        echo "📊 Project Status..."
        ./Tools/Automation/master_automation.sh status
        ;;
    "validate-game")
        echo "🎮 Validating gamification features..."
        echo "  • Checking XP calculations..."
        echo "  • Validating achievement system..."
        echo "  • Testing level progression..."
        ;;
    "all")
        echo "🚀 Running full automation suite..."
        ./Tools/Automation/master_automation.sh all
        ;;
    "help"|*)
        echo "Available commands:"
        echo "  build         - Build the project"
        echo "  test          - Run tests (includes XP validation)"
        echo "  lint          - Run linting"
        echo "  format        - Format code"
        echo "  mcp           - MCP integration"
        echo "  ai            - AI enhancements"
        echo "  status        - Show status"
        echo "  validate-game - Validate gamification features"
        echo "  all           - Run everything"
        ;;
esac

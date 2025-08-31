#!/bin/bash
# CodingReviewer Automation Wrapper
# Quick access to automation features for CodingReviewer

# Load project configuration
source "$(dirname "$0")/project_config.sh"

echo "🚀 CodingReviewer Automation Suite"
echo "Project: $PROJECT_NAME ($PROJECT_TYPE)"
echo ""

case "${1:-help}" in
"build")
	echo "🏗️  Building CodingReviewer..."
	./Tools/Automation/master_automation.sh run CodingReviewer
	;;
"test")
	echo "🧪 Running tests..."
	xcodebuild test -scheme "$BUILD_SCHEME" -destination "platform=iOS Simulator,name=$TARGET_DEVICE"
	;;
"lint")
	echo "🔍 Running linting..."
	./Tools/Automation/master_automation.sh lint CodingReviewer
	;;
"format")
	echo "✨ Formatting code..."
	./Tools/Automation/master_automation.sh format CodingReviewer
	;;
"mcp")
	echo "🔗 MCP Integration..."
	./Tools/Automation/mcp_workflow.sh "${2:-status}" CodingReviewer
	;;
"ai")
	echo "🤖 AI Enhancements..."
	./Tools/Automation/ai_enhancement_system.sh "${2:-status}"
	;;
"status")
	echo "📊 Project Status..."
	./Tools/Automation/master_automation.sh status
	;;
"all")
	echo "🚀 Running full automation suite..."
	./Tools/Automation/master_automation.sh all
	;;
"help" | *)
	echo "Available commands:"
	echo "  build         - Build the project"
	echo "  test          - Run tests"
	echo "  lint          - Run linting"
	echo "  format        - Format code"
	echo "  mcp           - MCP integration"
	echo "  ai            - AI enhancements"
	echo "  status        - Show status"
	;;
esac

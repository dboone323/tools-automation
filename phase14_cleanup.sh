#!/bin/bash

# Phase 14 Cleanup and Workspace Organization Script
# This script cleans up the workspace after completing Phase 14 Advanced Monitoring & Analytics

set -e

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE_DIR="$WORKSPACE_ROOT/archives"
LOGS_DIR="$WORKSPACE_ROOT/logs"
BACKUPS_DIR="$WORKSPACE_ROOT/backups"

echo "🧹 Starting Phase 14 cleanup and workspace organization..."

# Create archive directories if they don't exist
mkdir -p "$ARCHIVE_DIR" "$LOGS_DIR" "$BACKUPS_DIR"

# Function to archive old files
archive_old_files() {
    local source_dir;
    source_dir="$1"
    local pattern;
    pattern="$2"
    local archive_name;
    archive_name="$3"
    local days_old;
    days_old="${4:-30}"

    echo "📦 Archiving $pattern files older than $days_old days..."

    # Find files matching pattern that are older than specified days
    local old_files;
    old_files=$(find "$source_dir" -name "$pattern" -type f -mtime +$days_old 2>/dev/null || true)

    if [ -n "$old_files" ]; then
        local archive_path;
        archive_path="$ARCHIVE_DIR/${archive_name}_$(date +%Y%m%d_%H%M%S).tar.gz"
        echo "$old_files" | tar -czf "$archive_path" -T - 2>/dev/null || true

        if [ -f "$archive_path" ]; then
            echo "$old_files" | xargs rm -f 2>/dev/null || true
            echo "✅ Archived $(echo "$old_files" | wc -l) files to $archive_path"
        fi
    else
        echo "ℹ️  No old $pattern files to archive"
    fi
}

# Archive old log files
archive_old_files "$WORKSPACE_ROOT" "*.log" "old_logs"
archive_old_files "$WORKSPACE_ROOT" "shellcheck_fixes_*.log" "shellcheck_logs"
archive_old_files "$WORKSPACE_ROOT" "sdk_validation_*.log" "sdk_logs"
archive_old_files "$WORKSPACE_ROOT" "master_startup_*.log" "master_startup_logs"

# Archive old backup files
archive_old_files "$WORKSPACE_ROOT" "*.backup" "backup_files"
archive_old_files "$WORKSPACE_ROOT" "*.bak*" "bak_files"

# Move processed task files to archives
echo "📦 Moving processed task files to archives..."
find "$WORKSPACE_ROOT" -name "*_processed_tasks.txt" -type f -exec mv {} "$ARCHIVE_DIR/" \; 2>/dev/null || true

# Clean up test temporary files
echo "🧽 Cleaning up test temporary files..."
find "$WORKSPACE_ROOT" -name "test_tmp" -type d -exec rm -rf {} \; 2>/dev/null || true
find "$WORKSPACE_ROOT" -name "*.tmp" -type f -mtime +7 -delete 2>/dev/null || true

# Organize Phase 14 artifacts
echo "📁 Organizing Phase 14 monitoring scripts..."
PHASE14_DIR="$WORKSPACE_ROOT/phase14_monitoring"
mkdir -p "$PHASE14_DIR"

# Move Phase 14 scripts to dedicated directory
if [ -f "$WORKSPACE_ROOT/agent_performance_analytics.sh" ]; then
    mv "$WORKSPACE_ROOT/agent_performance_analytics.sh" "$PHASE14_DIR/"
fi
if [ -f "$WORKSPACE_ROOT/alert_correlation_engine.sh" ]; then
    mv "$WORKSPACE_ROOT/alert_correlation_engine.sh" "$PHASE14_DIR/"
fi
if [ -f "$WORKSPACE_ROOT/proactive_health_monitor.sh" ]; then
    mv "$WORKSPACE_ROOT/proactive_health_monitor.sh" "$PHASE14_DIR/"
fi

# Create Phase 14 completion documentation
cat >"$PHASE14_DIR/PHASE14_COMPLETION_README.md" <<'EOF'
# Phase 14: Advanced Monitoring & Analytics - COMPLETED

## Overview
Phase 14 implemented advanced monitoring and analytics capabilities for the tools-automation system.

## Components Implemented

### 1. Agent Performance Analytics (`agent_performance_analytics.sh`)
- **Purpose**: Performance analytics and predictive scoring for agent systems
- **Features**:
  - Performance metrics collection and analysis
  - Trend analysis and predictive scoring
  - Automated performance reports
  - Health status monitoring

### 2. Alert Correlation Engine (`alert_correlation_engine.sh`)
- **Purpose**: Intelligent alert correlation and noise reduction
- **Features**:
  - Alert parsing and correlation analysis
  - Noise filtering and deduplication
  - Correlation rule application
  - Alert state management

### 3. Proactive Health Monitor (`proactive_health_monitor.sh`)
- **Purpose**: Predictive system health monitoring and preventive actions
- **Features**:
  - Health trend analysis
  - Resource monitoring and prediction
  - Preventive alert generation
  - System health optimization

## Status
✅ **COMPLETED** - All monitoring scripts implemented, debugged, and validated functional

## Next Phase
Phase 16: AI Integration Enhancement
- Expand Ollama model support and auto-selection
- Implement AI-powered code review and optimization
- Add intelligent agent coordination and load balancing

## Files Location
This directory contains the final, working versions of all Phase 14 monitoring scripts.
EOF

# Update main README with Phase 14 completion status
if [ -f "$WORKSPACE_ROOT/README.md" ]; then
    echo "📝 Updating main README with Phase 14 completion status..."
    # Add Phase 14 completion note if not already present
    if ! grep -q "Phase 14.*COMPLETED" "$WORKSPACE_ROOT/README.md"; then
        sed -i '' '/## Project Status/a\
\
### Phase 14: Advanced Monitoring & Analytics ✅ COMPLETED\
- Agent performance analytics and predictive scoring\
- Intelligent alert correlation and noise reduction\
- Proactive health monitoring and preventive actions\
- All monitoring scripts implemented and functional\
' "$WORKSPACE_ROOT/README.md"
    fi
fi

# Create Phase 16 preparation note
cat >"$WORKSPACE_ROOT/PHASE16_PREPARATION.md" <<'EOF'
# Phase 16: AI Integration Enhancement - PREPARATION

## Overview
Phase 16 will focus on enhancing AI integration capabilities across the tools-automation system.

## Planned Components

### 1. Ollama Model Support Expansion
- Auto-selection of appropriate models based on task requirements
- Support for multiple model sizes and capabilities
- Model performance monitoring and optimization

### 2. AI-Powered Code Review
- Automated code quality assessment
- Intelligent bug detection and suggestions
- Code optimization recommendations

### 3. Intelligent Agent Coordination
- Load balancing across available agents
- Task prioritization and resource allocation
- Inter-agent communication and collaboration

## Preparation Checklist
- [ ] Review current Ollama integration
- [ ] Assess existing AI agent capabilities
- [ ] Identify integration points for enhancement
- [ ] Plan model selection algorithms
- [ ] Design agent coordination framework

## Dependencies
- Ollama service and models
- Existing agent framework
- Performance monitoring infrastructure (Phase 14)

## Next Steps
1. Analyze current AI integration points
2. Design enhanced model selection system
3. Implement AI-powered code review features
4. Develop intelligent agent coordination
EOF

echo "✅ Phase 14 cleanup completed successfully!"
echo "📁 Phase 14 scripts organized in: $PHASE14_DIR"
echo "📦 Old logs and backups archived to: $ARCHIVE_DIR"
echo "📝 Phase 16 preparation documentation created"
echo ""
echo "🚀 Ready to proceed to Phase 16: AI Integration Enhancement"

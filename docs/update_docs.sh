#!/bin/bash

# Documentation Update Workflow Script
# Handles regular documentation maintenance tasks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOCS_DIR="$SCRIPT_DIR"
MAINTENANCE_SCRIPT="$DOCS_DIR/docs_maintenance.sh"

# Configuration
WORKFLOW_LOG="$DOCS_DIR/logs/workflow_$(date +%Y%m%d).log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - WORKFLOW: $1" | tee -a "$WORKFLOW_LOG"
}

# Update API documentation from code comments
update_api_docs() {
    log "Updating API documentation from code..."

    local api_docs_file="$DOCS_DIR/api_documentation.md"

    cat >"$api_docs_file" <<'EOF'
# API Documentation

This documentation is automatically generated from code comments and function definitions.

## Python Modules

EOF

    # Simple extraction of function and class definitions (limited to avoid timeout)
    find "$PROJECT_ROOT" -name "*.py" -type f | head -5 | while read -r file; do
        local module_name
        module_name=$(basename "$file" .py)

        echo "### $module_name" >>"$api_docs_file"
        echo "" >>"$api_docs_file"
        echo '```python' >>"$api_docs_file"

        # Extract function and class definitions (simplified, limited)
        grep -E "^(def |class )" "$file" | head -5 >>"$api_docs_file"

        echo '```' >>"$api_docs_file"
        echo "" >>"$api_docs_file"
        echo "---" >>"$api_docs_file"
        echo "" >>"$api_docs_file"
    done

    log "API documentation updated: $api_docs_file"
}

# Update examples and tutorials
update_examples() {
    log "Updating examples and tutorials..."

    local examples_dir="$DOCS_DIR/examples"
    mkdir -p "$examples_dir"

    # Generate basic usage examples
    cat >"$examples_dir/basic_usage.md" <<'EOF'
# Basic Usage Examples

## Python SDK Usage

```python
from tools_automation import ToolsAutomation

# Initialize client
client = ToolsAutomation(api_key='your-api-key')

# Basic operations
result = client.run_analysis('project-path')
print(f"Analysis complete: {result}")
```

## TypeScript SDK Usage

```typescript
import { ToolsAutomation } from 'tools-automation-sdk';

const client = new ToolsAutomation('your-api-key');
const result = await client.runAnalysis('project-path');
console.log(`Analysis complete: ${result}`);
```

## Go SDK Usage

```go
package main

import (
    "fmt"
    ta "github.com/tools-automation/go-sdk"
)

func main() {
    client := ta.NewClient("your-api-key")
    result, err := client.RunAnalysis("project-path")
    if err != nil {
        panic(err)
    }
    fmt.Printf("Analysis complete: %s\n", result)
}
```

## CLI Usage

```bash
# Install CLI
npm install -g @tools-automation/cli

# Run analysis
tools-automation analyze project-path

# Generate reports
tools-automation report --format json project-path
```
EOF

    log "Examples updated in $examples_dir"
}

# Monitor documentation feedback (basic implementation)
monitor_feedback() {
    log "Monitoring documentation feedback..."

    # Check for recent changes to documentation files
    local recent_changes
    recent_changes=$(find "$DOCS_DIR" -name "*.md" -mtime -7 | wc -l)

    # Check for any error logs or issues
    local error_count=0
    if [ -d "$LOGS_DIR" ]; then
        error_count=$(find "$LOGS_DIR" -name "*.log" -exec grep -l "ERROR\|WARNING" {} \; | wc -l)
    fi

    # Basic feedback metrics
    local total_files
    total_files=$(find "$DOCS_DIR" -name "*.md" -type f | wc -l)

    log "Documentation feedback metrics:"
    log "  - Total documentation files: $total_files"
    log "  - Files changed in last 7 days: $recent_changes"
    log "  - Log files with issues: $error_count"

    # Generate basic feedback report
    cat >"$DOCS_DIR/reports/feedback_summary_$(date +%Y%m%d).txt" <<EOF
Documentation Feedback Summary - $(date)

Total Files: $total_files
Recent Changes (7 days): $recent_changes
Issues Detected: $error_count

Recommendations:
- Review recent changes for quality
- Address any logged errors
- Consider user feedback integration for future versions

EOF

    log "Feedback monitoring completed - report saved"
}

# Clean up old logs and reports
cleanup_old_files() {
    log "Cleaning up old documentation files..."

    # Keep only last 30 days of logs
    find "$DOCS_DIR/logs" -name "*.log" -mtime +30 -delete 2>/dev/null || true
    find "$DOCS_DIR/reports" -name "*.md" -mtime +30 -delete 2>/dev/null || true

    log "Cleanup completed"
}

# Main workflow execution
main() {
    log "Starting documentation update workflow..."

    # Run maintenance script first
    if [ -x "$MAINTENANCE_SCRIPT" ]; then
        log "Running maintenance script..."
        "$MAINTENANCE_SCRIPT"
    else
        log "ERROR: Maintenance script not found or not executable: $MAINTENANCE_SCRIPT"
        exit 1
    fi

    # Update documentation
    update_api_docs
    update_examples
    monitor_feedback

    # Cleanup
    cleanup_old_files

    log "Documentation update workflow completed successfully"
}

# Run main function
main "$@"

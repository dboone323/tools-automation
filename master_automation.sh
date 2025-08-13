#!/bin/bash

# Master Automation Controller for Unified Code Architecture
CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECTS_DIR="$CODE_DIR/Projects"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[AUTOMATION]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# List available projects
list_projects() {
    print_status "Available projects in unified Code architecture:"
    for project in "$PROJECTS_DIR"/*; do
        if [[ -d "$project" ]]; then
            local project_name=$(basename "$project")
            local swift_files=$(find "$project" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
            local has_automation=""
            if [[ -d "$project/automation" ]]; then
                has_automation=" (✅ automation)"
            else
                has_automation=" (❌ no automation)"
            fi
            echo "  - $project_name: $swift_files Swift files$has_automation"
        fi
    done
}

# Run automation for specific project
run_project_automation() {
    local project_name="$1"
    local project_path="$PROJECTS_DIR/$project_name"
    
    if [[ ! -d "$project_path" ]]; then
        echo "❌ Project $project_name not found"
        return 1
    fi
    
    print_status "Running automation for $project_name..."
    
    if [[ -f "$project_path/automation/run_automation.sh" ]]; then
        cd "$project_path" && bash automation/run_automation.sh
        print_success "$project_name automation completed"
    else
        print_warning "No automation script found for $project_name"
        return 1
    fi
}

# Run automation for all projects
run_all_automation() {
    print_status "Running automation for all projects in unified architecture..."
    
    local success_count=0
    local total_count=0
    
    for project in "$PROJECTS_DIR"/*; do
        if [[ -d "$project" ]]; then
            local project_name=$(basename "$project")
            print_status "Processing $project_name..."
            ((total_count++))
            
            if run_project_automation "$project_name"; then
                ((success_count++))
            fi
            echo ""
        fi
    done
    
    print_success "Automation completed: $success_count/$total_count projects successful"
}

# Show unified architecture status
show_status() {
    print_status "Unified Code Architecture Status"
    echo ""
    
    echo "📍 Location: $CODE_DIR"
    echo "📊 Projects: $(find "$PROJECTS_DIR" -maxdepth 1 -type d | tail -n +2 | wc -l | tr -d ' ')"
    
    echo ""
    list_projects
}

# Main execution
case "${1:-}" in
    "list")
        list_projects
        ;;
    "run")
        if [[ -n "${2:-}" ]]; then
            run_project_automation "$2"
        else
            echo "Usage: $0 run <project_name>"
            list_projects
            exit 1
        fi
        ;;
    "all")
        run_all_automation
        ;;
    "status")
        show_status
        ;;
    *)
        echo "🏗️  Unified Code Architecture - Master Automation Controller"
        echo ""
        echo "Usage: $0 {list|run <project>|all|status}"
        echo ""
        echo "Commands:"
        echo "  list                    # List all projects with status"
        echo "  run <project>          # Run automation for specific project" 
        echo "  all                    # Run automation for all projects"
        echo "  status                 # Show unified architecture status"
        echo ""
        exit 1
        ;;
esac

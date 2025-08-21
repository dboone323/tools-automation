#!/bin/bash

# Deploy Workflows to All Projects
# This script pushes GitHub Actions workflows for all projects in the workspace

set -e

# Configuration
CODE_DIR="/Users/danielstevens/Desktop/Code"
PROJECTS_DIR="$CODE_DIR/Projects"
TOOLS_DIR="$CODE_DIR/Tools"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_header() {
    echo -e "\n${PURPLE}================================================${NC}"
    echo -e "${PURPLE} 🚀 MULTI-PROJECT WORKFLOW DEPLOYMENT${NC}"
    echo -e "${PURPLE}================================================${NC}\n"
}

print_status() {
    echo -e "${BLUE}[DEPLOY]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate workflows YAML syntax
validate_workflows() {
    local project_path="$1"
    local project_name="$2"
    
    print_status "Validating workflows for $project_name..."
    
    if [[ ! -d "$project_path/.github/workflows" ]]; then
        print_warning "No workflows directory found in $project_name"
        return 1
    fi
    
    local validation_failed=0
    
    for workflow_file in "$project_path/.github/workflows"/*.yml; do
        if [[ -f "$workflow_file" ]]; then
            local filename=$(basename "$workflow_file")
            if python3 -c "import yaml; yaml.safe_load(open('$workflow_file', 'r'))" 2>/dev/null; then
                echo "  ✅ $filename: Valid YAML"
            else
                echo "  ❌ $filename: Invalid YAML"
                validation_failed=1
            fi
        fi
    done
    
    return $validation_failed
}

# Push workflows for a single project
push_project_workflows() {
    local project_path="$1"
    local project_name="$2"
    
    print_status "Processing $project_name..."
    
    # Check if it's a git repository
    if [[ ! -d "$project_path/.git" ]]; then
        print_warning "$project_name is not a git repository. Skipping..."
        return 1
    fi
    
    # Change to project directory
    cd "$project_path" || {
        print_error "Failed to change to $project_path"
        return 1
    }
    
    # Validate workflows first
    if ! validate_workflows "$project_path" "$project_name"; then
        print_error "Workflow validation failed for $project_name. Skipping push..."
        return 1
    fi
    
    # Check for workflow changes
    local workflow_changes=$(git status --porcelain .github/workflows/ 2>/dev/null || true)
    
    if [[ -z "$workflow_changes" ]]; then
        print_status "$project_name: No workflow changes to push"
        
        # Check if we need to push any staged workflows
        local staged_workflows=$(git diff --cached --name-only .github/workflows/ 2>/dev/null || true)
        if [[ -n "$staged_workflows" ]]; then
            print_status "$project_name: Found staged workflow changes"
        else
            # Try to push anyway in case there are committed but unpushed changes
            local unpushed=$(git log origin/main..HEAD --oneline 2>/dev/null || git log --oneline -1 2>/dev/null || true)
            if [[ -n "$unpushed" ]]; then
                print_status "$project_name: Found unpushed commits, attempting push..."
            else
                print_success "$project_name: Workflows are up to date"
                return 0
            fi
        fi
    else
        print_status "$project_name: Found workflow changes:"
        echo "$workflow_changes" | sed 's/^/    /'
        
        # Stage workflow changes
        git add .github/workflows/ 2>/dev/null || true
    fi
    
    # Check current branch
    local current_branch=$(git branch --show-current 2>/dev/null || echo "main")
    print_status "$project_name: Current branch: $current_branch"
    
    # Commit workflow changes if any
    if git diff --cached --quiet --exit-code 2>/dev/null; then
        print_status "$project_name: No staged changes to commit"
    else
        print_status "$project_name: Committing workflow changes..."
        if git commit -m "🔄 Deploy: Update GitHub Actions workflows

- Synchronized workflows across projects
- Validated YAML syntax for all workflow files
- Deployed via automated workflow deployment script

Deployment timestamp: $(date '+%Y-%m-%d %H:%M:%S')"; then
            print_success "$project_name: Workflow changes committed"
        else
            print_error "$project_name: Failed to commit workflow changes"
            return 1
        fi
    fi
    
    # Push to remote
    print_status "$project_name: Pushing workflows to remote..."
    if git push origin "$current_branch" 2>/dev/null; then
        print_success "$project_name: Workflows pushed successfully! 🚀"
        
        # Show workflow count
        local workflow_count=$(find .github/workflows -name "*.yml" -type f 2>/dev/null | wc -l | tr -d ' ')
        echo "    📁 Deployed $workflow_count workflow files"
        
    else
        print_error "$project_name: Failed to push workflows"
        
        # Try to get more info about the error
        print_status "$project_name: Checking remote status..."
        git remote -v 2>/dev/null || print_warning "No remote configured"
        
        return 1
    fi
    
    return 0
}

# Main deployment function
deploy_all_workflows() {
    print_header
    
    local total_projects=0
    local successful_deployments=0
    local failed_deployments=0
    
    print_status "Scanning projects in $PROJECTS_DIR..."
    
    for project_dir in "$PROJECTS_DIR"/*; do
        if [[ -d "$project_dir" ]]; then
            local project_name=$(basename "$project_dir")
            total_projects=$((total_projects + 1))
            
            echo -e "\n${YELLOW}[$total_projects] Processing: $project_name${NC}"
            
            if push_project_workflows "$project_dir" "$project_name"; then
                successful_deployments=$((successful_deployments + 1))
            else
                failed_deployments=$((failed_deployments + 1))
            fi
        fi
    done
    
    # Summary
    echo -e "\n${PURPLE}================================================${NC}"
    echo -e "${PURPLE} 📊 DEPLOYMENT SUMMARY${NC}"
    echo -e "${PURPLE}================================================${NC}"
    echo -e "Total Projects: $total_projects"
    echo -e "${GREEN}✅ Successful: $successful_deployments${NC}"
    echo -e "${RED}❌ Failed: $failed_deployments${NC}"
    
    if [[ $failed_deployments -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 All workflows deployed successfully!${NC}"
        return 0
    else
        echo -e "\n${YELLOW}⚠️  Some deployments failed. Check the output above for details.${NC}"
        return 1
    fi
}

# Show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Deploy GitHub Actions workflows to all projects"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --validate Validate workflows only (no push)"
    echo "  -p, --project  Deploy to specific project only"
    echo ""
    echo "Examples:"
    echo "  $0                           # Deploy workflows to all projects"
    echo "  $0 --validate               # Validate all workflows without pushing"
    echo "  $0 --project CodingReviewer # Deploy only to CodingReviewer"
}

# Validate only mode
validate_only() {
    print_header
    print_status "Validation mode - checking workflow syntax only..."
    
    local validation_errors=0
    
    for project_dir in "$PROJECTS_DIR"/*; do
        if [[ -d "$project_dir" ]]; then
            local project_name=$(basename "$project_dir")
            echo -e "\n${YELLOW}Validating: $project_name${NC}"
            
            if ! validate_workflows "$project_dir" "$project_name"; then
                validation_errors=$((validation_errors + 1))
            fi
        fi
    done
    
    if [[ $validation_errors -eq 0 ]]; then
        print_success "All workflows have valid YAML syntax! ✅"
        return 0
    else
        print_error "$validation_errors projects have workflow validation errors"
        return 1
    fi
}

# Deploy to specific project
deploy_specific_project() {
    local project_name="$1"
    local project_path="$PROJECTS_DIR/$project_name"
    
    if [[ ! -d "$project_path" ]]; then
        print_error "Project '$project_name' not found in $PROJECTS_DIR"
        return 1
    fi
    
    print_header
    print_status "Deploying workflows for specific project: $project_name"
    
    if push_project_workflows "$project_path" "$project_name"; then
        print_success "Workflow deployment completed for $project_name! 🚀"
        return 0
    else
        print_error "Workflow deployment failed for $project_name"
        return 1
    fi
}

# Main script logic
main() {
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--validate)
            validate_only
            exit $?
            ;;
        -p|--project)
            if [[ -z "${2:-}" ]]; then
                print_error "Project name required with --project option"
                show_help
                exit 1
            fi
            deploy_specific_project "$2"
            exit $?
            ;;
        "")
            deploy_all_workflows
            exit $?
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"

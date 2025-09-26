#!/bin/bash
# Enhanced Ollama Workflow with Trunk Quality Assurance
# Integrates AI code generation with comprehensive quality checks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$(cd "$SCRIPT_DIR/../.." && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/agents"
LOG_FILE="${WORKSPACE}/Tools/Automation/logs/enhanced_workflow_$(date +%Y%m%d_%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Status update function
print_status() {
  echo -e "${BLUE}[INFO]${NC} $1"
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

# Function to run trunk checks
run_trunk_checks() {
  local target_dir="$1"
  local check_type="${2:-full}"

  log "Running trunk checks on: $target_dir"

  cd "$target_dir" || {
    print_error "Failed to change to directory: $target_dir"
    return 1
  }

  # Check if trunk is available
  if ! command -v trunk &>/dev/null; then
    print_warning "Trunk not found, skipping quality checks"
    return 0
  fi

  case "$check_type" in
  "full")
    print_status "Running full trunk check suite..."
    if trunk check --all; then
      print_success "All trunk checks passed"
      return 0
    else
      print_error "Trunk checks failed"
      return 1
    fi
    ;;
  "lint")
    print_status "Running trunk lint checks..."
    if trunk check --filter=lint; then
      print_success "Lint checks passed"
      return 0
    else
      print_error "Lint checks failed"
      return 1
    fi
    ;;
  "security")
    print_status "Running trunk security checks..."
    if trunk check --filter=security; then
      print_success "Security checks passed"
      return 0
    else
      print_error "Security checks failed"
      return 1
    fi
    ;;
  *)
    print_warning "Unknown check type: $check_type"
    return 0
    ;;
  esac
}

# Function to run ollama code generation
run_ollama_codegen() {
  local prompt="$1"
  local output_file="$2"
  local model="${3:-codellama}"

  log "Running Ollama code generation with model: $model"

  # Check if ollama is running
  if ! curl -s http://localhost:11434/api/tags &>/dev/null; then
    print_error "Ollama service not running. Please start Ollama first."
    return 1
  fi

  print_status "Generating code with Ollama ($model)..."

  # Use the Swift ollama integration if available
  if [[ -f "${AGENTS_DIR}/ollama_codegen.swift" ]]; then
    cd "$AGENTS_DIR"
    swift run ollama_codegen.swift generate "$prompt" "$output_file" "$model"
  else
    # Fallback to direct API call
    curl -X POST http://localhost:11434/api/generate \
      -H "Content-Type: application/json" \
      -d "{\"model\": \"$model\", \"prompt\": \"$prompt\", \"stream\": false}" |
      jq -r '.response' >"$output_file"
  fi

  if [[ -s $output_file ]]; then
    print_success "Code generation completed: $output_file"
    return 0
  else
    print_error "Code generation failed"
    return 1
  fi
}

# Function to enhance agent with quality checks
enhance_agent_quality() {
  local agent_file="$1"
  local backup_file

  backup_file="${agent_file}.backup.$(date +%s)"

  log "Enhancing agent quality: $agent_file"

  # Create backup
  cp "$agent_file" "$backup_file"
  print_status "Backup created: $backup_file"

  # Add quality checks to agent
  cat >>"$agent_file" <<'EOF'

# Quality Assurance Integration
run_quality_checks() {
    local target_file="$1"

    log "Running quality checks on: $target_file"

    # Run trunk checks if available
    if command -v trunk &> /dev/null && [[ -f ".trunk/trunk.yaml" ]]; then
        print_status "Running trunk quality checks..."
        if trunk check "$target_file" 2>/dev/null; then
            print_success "Quality checks passed"
        else
            print_warning "Quality issues found, attempting auto-fix..."
            trunk fix "$target_file" 2>/dev/null || true
        fi
    fi

    # Run shellcheck for shell scripts
    if [[ "$target_file" == *.sh ]] && command -v shellcheck &> /dev/null; then
        print_status "Running shellcheck..."
        if shellcheck "$target_file" 2>/dev/null; then
            print_success "Shellcheck passed"
        else
            print_warning "Shellcheck found issues"
        fi
    fi
}

# Security validation
validate_security() {
    local target_file="$1"

    log "Running security validation on: $target_file"

    # Check for common security issues
    if grep -q "password\|secret\|token\|api_key" "$target_file" 2>/dev/null; then
        print_warning "Potential hardcoded secrets found in: $target_file"
        return 1
    fi

    # Check file permissions
    local permissions
    permissions=$(stat -c "%a" "$target_file" 2>/dev/null || stat -f "%A" "$target_file" 2>/dev/null)
    if [[ "${permissions: -1}" != "0" ]]; then
        print_warning "Insecure file permissions on: $target_file"
        return 1
    fi

    print_success "Security validation passed"
    return 0
}

EOF

  print_success "Quality enhancements added to: $agent_file"
}

# Function to start enhanced agents
start_enhanced_agents() {
  log "Starting enhanced agent ecosystem..."

  # Start quality agent with trunk integration
  if [[ -f "${AGENTS_DIR}/quality_agent.sh" ]]; then
    print_status "Starting enhanced quality agent..."
    nohup "${AGENTS_DIR}/quality_agent.sh" >"${AGENTS_DIR}/quality_agent_enhanced.log" 2>&1 &
    echo $! >"${AGENTS_DIR}/quality_agent_enhanced.pid"
    print_success "Quality agent started (PID: $(cat "${AGENTS_DIR}/quality_agent_enhanced.pid"))"
  fi

  # Start codegen agent with quality checks
  if [[ -f "${AGENTS_DIR}/agent_codegen.sh" ]]; then
    print_status "Starting enhanced codegen agent..."
    nohup "${AGENTS_DIR}/agent_codegen.sh" >"${AGENTS_DIR}/codegen_agent_enhanced.log" 2>&1 &
    echo $! >"${AGENTS_DIR}/codegen_agent_enhanced.pid"
    print_success "Codegen agent started (PID: $(cat "${AGENTS_DIR}/codegen_agent_enhanced.pid"))"
  fi

  # Start security agent
  if [[ -f "${AGENTS_DIR}/security_agent.sh" ]]; then
    print_status "Starting enhanced security agent..."
    nohup "${AGENTS_DIR}/security_agent.sh" >"${AGENTS_DIR}/security_agent_enhanced.log" 2>&1 &
    echo $! >"${AGENTS_DIR}/security_agent_enhanced.pid"
    print_success "Security agent started (PID: $(cat "${AGENTS_DIR}/security_agent_enhanced.pid"))"
  fi
}

# Function to monitor agent health
monitor_agents() {
  log "Monitoring agent health..."

  local agent_pids=(
    "${AGENTS_DIR}/quality_agent_enhanced.pid"
    "${AGENTS_DIR}/codegen_agent_enhanced.pid"
    "${AGENTS_DIR}/security_agent_enhanced.pid"
  )

  for pid_file in "${agent_pids[@]}"; do
    if [[ -f $pid_file ]]; then
      local pid
      pid=$(cat "$pid_file")
      if kill -0 "$pid" 2>/dev/null; then
        print_success "$(basename "$pid_file" .pid) is running (PID: $pid)"
      else
        print_error "$(basename "$pid_file" .pid) is not running"
        rm -f "$pid_file"
      fi
    else
      print_warning "$(basename "$pid_file" .pid) PID file not found"
    fi
  done
}

# Function to generate comprehensive report
generate_workflow_report() {
  local report_file

  report_file="${WORKSPACE}/Tools/ollama_workflow_report_$(date +%Y%m%d_%H%M%S).md"

  log "Generating workflow report: $report_file"

  cat >"$report_file" <<EOF
# Ollama Workflow Quality Report
Generated: $(date)

## Quality Metrics

### Trunk Check Results
\`\`\`
$(cd "$WORKSPACE" && trunk check --format=json 2>/dev/null || echo "Trunk not available")
\`\`\`

### Agent Status
$(monitor_agents)

### Code Generation Stats
- Ollama Models Available: $(curl -s http://localhost:11434/api/tags 2>/dev/null | jq '.models | length' 2>/dev/null || echo "Ollama not running")
- Generated Files: $(find "$WORKSPACE" -name "*generated*" -type f 2>/dev/null | wc -l)

## Recommendations

1. **Quality Assurance**: All generated code should pass trunk checks
2. **Security**: Regular security scans of generated and modified files
3. **Performance**: Monitor agent response times and resource usage
4. **Integration**: Ensure seamless integration between AI generation and quality checks

## Next Steps

- Implement automated quality gates for all AI-generated code
- Add performance monitoring for agent operations
- Create comprehensive testing suite for generated code
- Establish continuous integration with quality checks

EOF

  print_success "Workflow report generated: $report_file"
}

# Main workflow execution
main() {
  local action="${1:-full}"

  log "Starting Enhanced Ollama Workflow (Action: $action)"

  case "$action" in
  "check")
    print_status "Running quality checks..."
    run_trunk_checks "$WORKSPACE" "full"
    ;;
  "generate")
    local prompt="${2:-Generate a simple Swift function}"
    local output_file="${3:-generated_code.swift}"
    print_status "Running code generation..."
    run_ollama_codegen "$prompt" "$output_file"
    run_trunk_checks "$(dirname "$output_file")" "lint"
    ;;
  "enhance")
    print_status "Enhancing agents with quality checks..."
    for agent in "${AGENTS_DIR}"/*.sh; do
      [[ -f $agent ]] && enhance_agent_quality "$agent"
    done
    ;;
  "start")
    print_status "Starting enhanced agents..."
    start_enhanced_agents
    ;;
  "monitor")
    print_status "Monitoring agent health..."
    monitor_agents
    ;;
  "report")
    print_status "Generating workflow report..."
    generate_workflow_report
    ;;
  "full")
    print_status "Running full enhanced workflow..."

    # Step 1: Quality checks
    run_trunk_checks "$WORKSPACE" "full"

    # Step 2: Enhance agents
    for agent in "${AGENTS_DIR}"/*.sh; do
      [[ -f $agent ]] && enhance_agent_quality "$agent"
    done

    # Step 3: Start enhanced agents
    start_enhanced_agents

    # Step 4: Generate report
    generate_workflow_report

    print_success "Full enhanced workflow completed!"
    ;;
  *)
    echo "Usage: $0 {check|generate|enhance|start|monitor|report|full}"
    echo ""
    echo "Actions:"
    echo "  check    - Run trunk quality checks"
    echo "  generate - Generate code with quality checks"
    echo "  enhance  - Add quality checks to agents"
    echo "  start    - Start enhanced agents"
    echo "  monitor  - Monitor agent health"
    echo "  report   - Generate workflow report"
    echo "  full     - Run complete enhanced workflow"
    exit 1
    ;;
  esac

  log "Enhanced Ollama Workflow completed (Action: $action)"
}

# Run main function with all arguments
main "$@"

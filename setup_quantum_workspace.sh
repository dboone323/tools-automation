#!/bin/bash
# Quantum Workspace - Complete Local Setup Script
# One-time installation for all development tools and dependencies

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="${WORKSPACE_DIR}/setup_log_$(date +%Y%m%d_%H%M%S).txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

print_header() {
  echo -e "${PURPLE}================================================${NC}"
  echo -e "${PURPLE}  $1${NC}"
  echo -e "${PURPLE}================================================${NC}"
}

print_step() {
  echo -e "${BLUE}[STEP]${NC} $1"
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

print_info() {
  echo -e "${CYAN}[INFO]${NC} $1"
}

# Check if running on macOS
check_macos() {
  if [[ ${OSTYPE} != "darwin"* ]]; then
    print_error "This setup script is designed for macOS only."
    exit 1
  fi
  print_success "macOS detected: $(sw_vers -productVersion)"
}

# Check and install Homebrew
setup_homebrew() {
  print_step "Setting up Homebrew..."

  if ! command -v brew &>/dev/null; then
    print_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for Apple Silicon Macs
    if [[ $(uname -m) == "arm64" ]]; then
      # shellcheck disable=SC2016
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>~/.zshrc
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    print_success "Homebrew installed successfully"
  else
    print_success "Homebrew already installed"
  fi

  # Update Homebrew
  print_info "Updating Homebrew..."
  brew update
  print_success "Homebrew updated"
}

# Install development tools
install_dev_tools() {
  print_step "Installing development tools..."

  local tools=(
    git
    python@3.11
    node
    npm
    yarn
    swiftlint
    shellcheck
    jq
    wget
    curl
    tree
    htop
    tmux
    neovim
    gh # GitHub CLI
  )

  for tool in "${tools[@]}"; do
    if ! command -v "${tool}" &>/dev/null && ! brew list "${tool}" &>/dev/null; then
      print_info "Installing ${tool}..."
      brew install "${tool}"
      print_success "${tool} installed"
    else
      print_success "${tool} already installed"
    fi
  done
}

# Setup Python environment
setup_python() {
  print_step "Setting up Python environment..."

  # Install pip if not present
  if ! command -v pip3 &>/dev/null; then
    print_info "Installing pip..."
    curl https://bootstrap.pypa.io/get-pip.py | python3
  fi

  # Install virtualenv
  if ! command -v virtualenv &>/dev/null; then
    print_info "Installing virtualenv..."
    pip3 install virtualenv
  fi

  # Create virtual environment for the workspace
  local venv_dir="${WORKSPACE_DIR}/.venv"
  if [[ ! -d ${venv_dir} ]]; then
    print_info "Creating Python virtual environment..."
    python3 -m venv "${venv_dir}"
    print_success "Virtual environment created at ${venv_dir}"
  else
    print_success "Virtual environment already exists"
  fi

  # Activate and install requirements
  print_info "Installing Python requirements..."
  # shellcheck source=/dev/null
  source "${venv_dir}/bin/activate"

  if [[ -f "${WORKSPACE_DIR}/Tools/Automation/requirements.txt" ]]; then
    pip install -r "${WORKSPACE_DIR}/Tools/Automation/requirements.txt"
    print_success "Python requirements installed"
  fi

  if [[ -f "${WORKSPACE_DIR}/Tools/Automation/requirements-dev.txt" ]]; then
    pip install -r "${WORKSPACE_DIR}/Tools/Automation/requirements-dev.txt"
    print_success "Development requirements installed"
  fi
}

# Setup Node.js environment
setup_nodejs() {
  print_step "Setting up Node.js environment..."

  # Setup NVM
  export NVM_DIR="${HOME}/.nvm"
  if [[ -s "${NVM_DIR}/nvm.sh" ]]; then
    # shellcheck source=/dev/null
    . "${NVM_DIR}/nvm.sh"
  fi
  if [[ -s "${NVM_DIR}/bash_completion" ]]; then
    # shellcheck source=/dev/null
    . "${NVM_DIR}/bash_completion"
  fi

  # Install nvm (Node Version Manager)
  if [[ ! -d "${HOME}/.nvm" ]]; then
    print_info "Installing NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

    # Source nvm again after installation
    export NVM_DIR="${HOME}/.nvm"
    if [[ -s "${NVM_DIR}/nvm.sh" ]]; then
      # shellcheck source=/dev/null
      . "${NVM_DIR}/nvm.sh"
    fi
    if [[ -s "${NVM_DIR}/bash_completion" ]]; then
      # shellcheck source=/dev/null
      . "${NVM_DIR}/bash_completion"
    fi

    print_success "NVM installed"
  else
    print_success "NVM already installed"
  fi

  # Install latest LTS Node.js
  print_info "Installing Node.js LTS..."
  if command -v nvm &>/dev/null; then
    nvm install --lts
    nvm use --lts
    nvm alias default 'lts/*'

    print_success "Node.js $(node --version) installed"
    print_success "npm $(npm --version) ready"
  else
    print_warning "NVM not available, installing Node.js via Homebrew..."
    brew install node
    print_success "Node.js installed via Homebrew"
  fi
}

# Setup Ollama
setup_ollama() {
  print_step "Setting up Ollama AI models..."

  if ! command -v ollama &>/dev/null; then
    print_info "Installing Ollama..."
    brew install ollama
    print_success "Ollama installed"
  else
    print_success "Ollama already installed"
  fi

  # Start Ollama service
  print_info "Starting Ollama service..."
  brew services start ollama

  # Wait for Ollama to start
  sleep 5

  # Pull essential models
  local models=(
    "codellama:7b"
    "codellama:13b"
    "llama2:7b"
    "mistral:7b"
  )

  for model in "${models[@]}"; do
    print_info "Pulling Ollama model: ${model}..."
    if ollama pull "${model}"; then
      print_success "Model ${model} downloaded"
    else
      print_warning "Failed to download model ${model}"
    fi
  done

  print_success "Ollama setup completed"
}

# Setup Trunk CI
setup_trunk() {
  print_step "Setting up Trunk CI..."

  if ! command -v trunk &>/dev/null; then
    print_info "Installing Trunk..."
    curl https://get.trunk.io -fsSL | bash
    print_success "Trunk installed"
  else
    print_success "Trunk already installed"
  fi

  # Initialize trunk in workspace
  cd "${WORKSPACE_DIR}"
  if [[ ! -f ".trunk/trunk.yaml" ]]; then
    print_info "Initializing Trunk configuration..."
    trunk init
    print_success "Trunk initialized"
  else
    print_success "Trunk already configured"
  fi

  # Install trunk plugins
  print_info "Installing Trunk plugins..."
  trunk install
  print_success "Trunk plugins installed"
}

# Setup Swift development environment
setup_swift() {
  print_step "Setting up Swift development environment..."

  # Install Xcode command line tools
  if ! xcode-select -p &>/dev/null; then
    print_info "Installing Xcode Command Line Tools..."
    xcode-select --install
    print_success "Xcode Command Line Tools installed"
  else
    print_success "Xcode Command Line Tools already installed"
  fi

  # Install SwiftLint
  if ! command -v swiftlint &>/dev/null; then
    print_info "Installing SwiftLint..."
    brew install swiftlint
    print_success "SwiftLint installed"
  else
    print_success "SwiftLint already installed"
  fi

  # Install SwiftFormat
  if ! command -v swiftformat &>/dev/null; then
    print_info "Installing SwiftFormat..."
    brew install swiftformat
    print_success "SwiftFormat installed"
  else
    print_success "SwiftFormat already installed"
  fi
}

# Setup GitHub CLI
setup_github_cli() {
  print_step "Setting up GitHub CLI..."

  if ! command -v gh &>/dev/null; then
    print_info "Installing GitHub CLI..."
    brew install gh
    print_success "GitHub CLI installed"
  else
    print_success "GitHub CLI already installed"
  fi

  # Check if authenticated
  if ! gh auth status &>/dev/null; then
    print_warning "GitHub CLI not authenticated. Run 'gh auth login' manually."
  else
    print_success "GitHub CLI authenticated"
  fi
}

# Setup VS Code extensions
setup_vscode_extensions() {
  print_step "Setting up VS Code with MCP servers..."

  if command -v code &>/dev/null; then
    print_info "Note: Migrated to MCP servers for AI integration (Nov 2025)"
    print_info "Most extensions replaced by MCP servers. Installing only essentials..."
    
    local extensions=(
      "github.copilot"
      "github.copilot-chat"
    )

    for ext in "${extensions[@]}"; do
      print_info "Installing VS Code extension: ${ext}..."
      if code --install-extension "${ext}" --force; then
        print_success "Extension ${ext} installed"
      else
        print_warning "Failed to install extension ${ext}"
      fi
    done
    
    print_info "MCP servers will auto-install via npx when needed"
    print_info "See MCP_QUICK_REFERENCE.md for details"
  else
    print_warning "VS Code not found. Install it manually for full MCP support."
  fi
}

# Setup workspace directories and permissions
setup_workspace() {
  print_step "Setting up workspace directories..."

  local dirs=(
    "${WORKSPACE_DIR}/Tools/Automation/agents/communication"
    "${WORKSPACE_DIR}/Tools/Automation/reports"
    "${WORKSPACE_DIR}/Tools/Automation/logs"
    "${WORKSPACE_DIR}/Tools/Automation/metrics"
    "${WORKSPACE_DIR}/Tools/Automation/monitoring"
    "${WORKSPACE_DIR}/Tools/Automation/agents/knowledge_exports"
    "${WORKSPACE_DIR}/Tools/Automation/agents/knowledge_reports"
  )

  for dir in "${dirs[@]}"; do
    if [[ ! -d ${dir} ]]; then
      mkdir -p "${dir}"
      print_success "Created directory: ${dir}"
    else
      print_success "Directory exists: ${dir}"
    fi
  done

  # Set proper permissions
  find "${WORKSPACE_DIR}/Tools/Automation" -type f -name "*.sh" -exec chmod +x {} \;
  print_success "Script permissions set"
}

# Create configuration files
create_config_files() {
  print_step "Creating configuration files..."

  # Create agent status file
  local agent_status_file="${WORKSPACE_DIR}/Tools/Automation/agents/agent_status.json"
  if [[ ! -f ${agent_status_file} ]]; then
    cat >"${agent_status_file}" <<'EOF'
{
  "agents": {
    "quality_agent.sh": {
      "status": "stopped",
      "last_seen": 0,
      "capabilities": ["quality", "lint", "metrics", "trunk"]
    },
    "agent_codegen.sh": {
      "status": "stopped",
      "last_seen": 0,
      "capabilities": ["codegen", "ollama", "swift"]
    },
    "security_agent.sh": {
      "status": "stopped",
      "last_seen": 0,
      "capabilities": ["security", "validation", "scanning"]
    }
  },
  "last_updated": 0
}
EOF
    print_success "Agent status file created"
  fi

  # Create task queue file
  local task_queue_file="${WORKSPACE_DIR}/Tools/Automation/agents/task_queue.json"
  if [[ ! -f ${task_queue_file} ]]; then
    cat >"${task_queue_file}" <<'EOF'
{
  "tasks": [],
  "last_updated": 0
}
EOF
    print_success "Task queue file created"
  fi
}

# Setup shell environment
setup_shell_env() {
  print_step "Setting up shell environment..."

  local shell_rc="${HOME}/.zshrc"

  # Add workspace functions
  if ! grep -q "quantum-workspace" "${shell_rc}"; then
    cat >>"${shell_rc}" <<'EOF'

# Quantum Workspace Environment
export QUANTUM_WORKSPACE="/Users/danielstevens/Desktop/Quantum-workspace"
export PATH="$QUANTUM_WORKSPACE/Tools/Automation:$PATH"

# Quick navigation
qw() {
    cd "$QUANTUM_WORKSPACE" || return
}

# Quick agent management
qwa() {
    cd "$QUANTUM_WORKSPACE/Tools/Automation/agents" || return
}

# Start all agents
qw-start-agents() {
    "$QUANTUM_WORKSPACE/Tools/Automation/enhanced_ollama_workflow.sh" start
}

# Stop all agents
qw-stop-agents() {
    pkill -f "agent.*\.sh" || true
    print_success "All agents stopped"
}

# Check agent status
qw-agent-status() {
    "$QUANTUM_WORKSPACE/Tools/Automation/enhanced_ollama_workflow.sh" monitor
}

# Run quality checks
qw-quality-check() {
    "$QUANTUM_WORKSPACE/Tools/Automation/enhanced_ollama_workflow.sh" check
}

EOF
    print_success "Shell environment configured"
  else
    print_success "Shell environment already configured"
  fi
}

# Final verification
final_verification() {
  print_step "Running final verification..."

  local checks_passed=0
  local total_checks=0

  # Check essential tools
  local essential_tools=(
    git
    python3
    node
    npm
    brew
    trunk
    ollama
    gh
    jq
    swiftlint
  )

  for tool in "${essential_tools[@]}"; do
    ((total_checks++))
    if command -v "${tool}" &>/dev/null; then
      print_success "${tool}: ✓"
      ((checks_passed++))
    else
      print_error "${tool}: ✗"
    fi
  done

  # Check Ollama models
  ((total_checks++))
  if ollama list | grep -q "codellama"; then
    print_success "Ollama models: ✓"
    ((checks_passed++))
  else
    print_error "Ollama models: ✗"
  fi

  # Check workspace structure
  ((total_checks++))
  if [[ -d "${WORKSPACE_DIR}/Tools/Automation/agents" ]]; then
    print_success "Workspace structure: ✓"
    ((checks_passed++))
  else
    print_error "Workspace structure: ✗"
  fi

  echo ""
  print_info "Verification complete: ${checks_passed}/${total_checks} checks passed"

  if [[ ${checks_passed} -eq ${total_checks} ]]; then
    print_success "🎉 Setup completed successfully!"
    echo ""
    print_info "Next steps:"
    echo "1. Restart your terminal to load the new environment"
    echo "2. Run 'qw' to navigate to the workspace"
    echo "3. Run 'qw-start-agents' to start the AI agents"
    echo "4. Run 'qw-quality-check' to verify everything works"
  else
    print_warning "Some checks failed. Review the output above."
  fi
}

# Main setup function
main() {
  print_header "Quantum Workspace - Complete Setup"
  log "Starting Quantum Workspace setup..."

  # Pre-flight checks
  check_macos

  # Installation steps
  setup_homebrew
  install_dev_tools
  setup_python
  setup_nodejs
  setup_ollama
  setup_trunk
  setup_swift
  setup_github_cli
  setup_vscode_extensions
  setup_workspace
  create_config_files
  setup_shell_env

  # Final verification
  final_verification

  log "Quantum Workspace setup completed!"
  print_header "Setup Complete!"
}

# Handle command line arguments
case "${1-}" in
"verify")
  final_verification
  ;;
"clean")
  print_warning "Cleaning up setup files..."
  rm -f "${LOG_FILE}"
  print_success "Cleanup completed"
  ;;
*)
  main
  ;;
esac

#!/bin/bash

# Tools Automation Free Tools Setup Script
# Installs and configures free monitoring and development tools

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[SETUP]${NC} $1"
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

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get >/dev/null 2>&1; then
            echo "ubuntu"
        elif command -v yum >/dev/null 2>&1; then
            echo "centos"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# Install Docker
install_docker() {
    local os=$(detect_os)

    print_status "Installing Docker..."

    case "$os" in
    "macos")
        if ! command -v brew >/dev/null 2>&1; then
            print_error "Homebrew is required for macOS Docker installation."
            print_status "Install Homebrew first: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            return 1
        fi

        print_status "Installing Docker Desktop for macOS..."
        brew install --cask docker
        print_success "Docker Desktop installed. Please start Docker Desktop from Applications."
        ;;

    "ubuntu")
        print_status "Installing Docker for Ubuntu..."
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg lsb-release
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        sudo usermod -aG docker $USER
        print_success "Docker installed. Please log out and back in for group changes to take effect."
        ;;

    *)
        print_error "Unsupported OS for automatic Docker installation."
        print_status "Please install Docker manually from: https://docs.docker.com/get-docker/"
        return 1
        ;;
    esac
}

# Install Python dependencies
install_python_deps() {
    print_status "Installing Python dependencies..."

    if ! command -v python3 >/dev/null 2>&1; then
        print_error "Python 3 is required but not found."
        return 1
    fi

    pip3 install flask prometheus_client

    print_success "Python dependencies installed."
}

# Install Node.js and npm (for some tools)
install_nodejs() {
    local os=$(detect_os)

    print_status "Installing Node.js and npm..."

    case "$os" in
    "macos")
        if command -v brew >/dev/null 2>&1; then
            brew install node
        else
            print_error "Homebrew required for Node.js installation on macOS."
            return 1
        fi
        ;;

    "ubuntu")
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
        ;;

    *)
        print_error "Unsupported OS for automatic Node.js installation."
        return 1
        ;;
    esac

    print_success "Node.js and npm installed."
}

# Setup precommit
setup_precommit() {
    print_status "Setting up pre-commit..."

    if ! command -v python3 >/dev/null 2>&1; then
        print_error "Python 3 required for pre-commit."
        return 1
    fi

    pip3 install pre-commit

    if [[ -f ".pre-commit-config.yaml" ]]; then
        pre-commit install
        print_success "Pre-commit installed and configured."
    else
        print_warning "No .pre-commit-config.yaml found. Run 'pre-commit init' to create one."
    fi
}

# Setup MkDocs
setup_mkdocs() {
    print_status "Setting up MkDocs..."

    if ! command -v python3 >/dev/null 2>&1; then
        print_error "Python 3 required for MkDocs."
        return 1
    fi

    pip3 install mkdocs mkdocs-material mkdocs-git-revision-date-localized-plugin mkdocs-git-committers-plugin-2

    if [[ -f "mkdocs.yml" ]]; then
        print_success "MkDocs installed and configured."
    else
        print_warning "No mkdocs.yml found. Run 'mkdocs new .' to create one."
    fi
}

# Setup security tools
setup_security_tools() {
    print_status "Setting up security tools..."

    # Install Trivy
    if ! command -v trivy >/dev/null 2>&1; then
        case "$os" in
        "macos")
            if command -v brew >/dev/null 2>&1; then
                brew install trivy
            else
                print_error "Homebrew required for Trivy installation."
                return 1
            fi
            ;;
        "ubuntu")
            sudo apt-get install -y wget apt-transport-https
            wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
            echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
            sudo apt-get update
            sudo apt-get install -y trivy
            ;;
        *)
            print_warning "Unsupported OS for Trivy. Install manually from: https://aquasecurity.github.io/trivy/"
            ;;
        esac
    fi

    # Install Snyk
    if ! command -v snyk >/dev/null 2>&1; then
        if command -v npm >/dev/null 2>&1; then
            npm install -g snyk
        else
            print_warning "npm not available. Install Snyk manually from: https://snyk.io/download/"
        fi
    fi

    print_success "Security tools setup completed."
}

# Install development tools
install_dev_tools() {
    local os=$(detect_os)

    print_status "Installing development tools..."

    case "$os" in
    "macos")
        if command -v brew >/dev/null 2>&1; then
            brew install jq httpie
            print_success "Development tools installed."
        else
            print_error "Homebrew required for tool installation."
            return 1
        fi
        ;;

    "ubuntu")
        sudo apt-get update
        sudo apt-get install -y jq httpie
        print_success "Development tools installed."
        ;;

    *)
        print_warning "Unsupported OS. Please install jq and httpie manually."
        ;;
    esac
}

# Create pre-commit configuration
create_precommit_config() {
    if [[ ! -f ".pre-commit-config.yaml" ]]; then
        print_status "Creating pre-commit configuration..."

        cat >.pre-commit-config.yaml <<'EOF'
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files

  - repo: https://github.com/psf/black
    rev: 22.10.0
    hooks:
      - id: black
        language_version: python3

  - repo: https://github.com/pycqa/isort
    rev: 5.12.0
    hooks:
      - id: isort

  - repo: https://github.com/pre-commit/mirrors-eslint
    rev: v8.44.0
    hooks:
      - id: eslint
        files: \.(js|ts)$
        types: [file]
EOF

        print_success "Pre-commit configuration created."
    fi
}

# Main setup function
main() {
    local install_docker_flag=false
    local install_monitoring_flag=false
    local install_devtools_flag=false
    local install_quality_flag=false
    local install_security_flag=false
    local install_docs_flag=false

    while [[ $# -gt 0 ]]; do
        case $1 in
        --docker)
            install_docker_flag=true
            shift
            ;;
        --monitoring)
            install_monitoring_flag=true
            shift
            ;;
        --quality)
            install_quality_flag=true
            shift
            ;;
        --security)
            install_security_flag=true
            shift
            ;;
        --docs)
            install_docs_flag=true
            shift
            ;;
        --devtools)
            install_devtools_flag=true
            shift
            ;;
        --all)
            install_docker_flag=true
            install_monitoring_flag=true
            install_quality_flag=true
            install_security_flag=true
            install_docs_flag=true
            install_devtools_flag=true
            shift
            ;;
        *)
            echo "Usage: $0 [--docker] [--monitoring] [--quality] [--security] [--docs] [--devtools] [--all]"
            exit 1
            ;;
        esac
    done

    print_status "🛠️  Tools Automation Free Tools Setup"
    echo ""

    # Install Docker if requested
    if [[ "$install_docker_flag" == true ]]; then
        if ! command -v docker >/dev/null 2>&1; then
            install_docker
        else
            print_success "Docker is already installed."
        fi
    fi

    # Install monitoring dependencies
    if [[ "$install_monitoring_flag" == true ]]; then
        install_python_deps
        print_success "Monitoring dependencies installed."
    fi

    # Install quality tools
    if [[ "$install_quality_flag" == true ]]; then
        print_success "Quality tools will be installed via Docker Compose."
    fi

    # Install security tools
    if [[ "$install_security_flag" == true ]]; then
        setup_security_tools
    fi

    # Install documentation tools
    if [[ "$install_docs_flag" == true ]]; then
        setup_mkdocs
    fi

    # Install development tools
    if [[ "$install_devtools_flag" == true ]]; then
        install_nodejs
        install_dev_tools
        setup_precommit
        create_precommit_config
    fi

    echo ""
    print_success "Setup completed!"
    echo ""
    print_status "Next steps:"
    if [[ "$install_docker_flag" == true ]]; then
        echo "  1. Start Docker Desktop (macOS) or restart your terminal (Linux)"
    fi
    if [[ "$install_monitoring_flag" == true ]]; then
        echo "  2. Start monitoring: ./monitoring.sh start"
        echo "  3. Start metrics exporter: python3 metrics_exporter.py"
    fi
    if [[ "$install_quality_flag" == true ]]; then
        echo "  4. Start quality tools: ./quality.sh start"
    fi
    if [[ "$install_security_flag" == true ]]; then
        echo "  5. Run security scan: ./security_scan.sh audit"
    fi
    if [[ "$install_docs_flag" == true ]]; then
        echo "  6. Start documentation: ./docs.sh serve"
    fi
    if [[ "$install_devtools_flag" == true ]]; then
        echo "  7. Run pre-commit: pre-commit run --all-files"
    fi
}

main "$@"

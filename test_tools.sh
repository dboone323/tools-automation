#!/bin/bash

# Tools Automation Comprehensive Test Script
# Tests all implemented free tools for functionality

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Test Docker installation
test_docker() {
    print_header "Testing Docker Installation"

    if ! command -v docker >/dev/null 2>&1; then
        print_warning "Docker not found - install Docker Desktop from https://docs.docker.com/get-docker/"
        print_status "Docker is required for: monitoring stack, quality tools"
        return 1
    fi

    print_status "Checking Docker version..."
    docker --version

    print_status "Checking Docker Compose..."
    if command -v docker-compose >/dev/null 2>&1; then
        docker-compose --version
    elif docker compose version >/dev/null 2>&1; then
        docker compose version
    else
        print_warning "Docker Compose not available - included with Docker Desktop"
        return 1
    fi

    print_status "Testing Docker daemon..."
    if ! docker info >/dev/null 2>&1; then
        print_warning "Docker daemon not running - start Docker Desktop"
        return 1
    fi

    print_success "Docker is properly installed and running"
}

# Test monitoring stack
test_monitoring() {
    print_header "Testing Monitoring Stack"

    if ! command -v docker >/dev/null 2>&1; then
        print_warning "Docker required for monitoring stack validation"
        print_status "Monitoring stack includes: Prometheus, Grafana, Uptime Kuma"
        return 1
    fi

    if [[ ! -f "docker-compose.monitoring.yml" ]]; then
        print_error "Monitoring compose file not found"
        return 1
    fi

    print_status "Validating monitoring compose file..."
    if ! docker-compose -f docker-compose.monitoring.yml config --quiet >/dev/null 2>&1; then
        print_error "Invalid monitoring compose configuration"
        return 1
    fi

    print_status "Checking monitoring script..."
    if [[ ! -x "monitoring.sh" ]]; then
        print_error "Monitoring script not executable"
        return 1
    fi

    print_status "Testing monitoring script help..."
    if ! ./monitoring.sh --help >/dev/null 2>&1; then
        print_error "Monitoring script help failed"
        return 1
    fi

    print_success "Monitoring stack configuration is valid"
}

# Test quality tools
test_quality() {
    print_header "Testing Quality Tools"

    if ! command -v docker >/dev/null 2>&1; then
        print_warning "Docker required for quality tools validation"
        print_status "Quality tools include: SonarQube, PostgreSQL"
        return 1
    fi

    if [[ ! -f "docker-compose.quality.yml" ]]; then
        print_error "Quality compose file not found"
        return 1
    fi

    print_status "Validating quality compose file..."
    if ! docker-compose -f docker-compose.quality.yml config --quiet >/dev/null 2>&1; then
        print_error "Invalid quality compose configuration"
        return 1
    fi

    print_status "Checking quality script..."
    if [[ ! -x "quality.sh" ]]; then
        print_error "Quality script not executable"
        return 1
    fi

    print_success "Quality tools configuration is valid"
}

# Test security tools
test_security() {
    print_header "Testing Security Tools"

    print_status "Checking Trivy installation..."
    if ! command -v trivy >/dev/null 2>&1; then
        print_warning "Trivy not installed - install with: brew install trivy (macOS) or apt install trivy (Ubuntu)"
    else
        trivy --version
        print_success "Trivy is installed"
    fi

    print_status "Checking Snyk installation..."
    if ! command -v snyk >/dev/null 2>&1; then
        print_warning "Snyk not installed - install with: npm install -g snyk"
    else
        snyk --version
        print_success "Snyk is installed"
    fi

    print_status "Checking security scripts..."
    if [[ ! -x "security_scan.sh" ]]; then
        print_error "Security scan script not executable"
        return 1
    fi

    if [[ ! -x "dependency_scan.sh" ]]; then
        print_error "Dependency scan script not executable"
        return 1
    fi

    print_success "Security tools are properly configured"
}

# Test documentation tools
test_documentation() {
    print_header "Testing Documentation Tools"

    print_status "Checking MkDocs installation..."
    if ! command -v mkdocs >/dev/null 2>&1; then
        print_warning "MkDocs not installed - install with: pip3 install mkdocs mkdocs-material"
        print_status "Documentation tools include: MkDocs with Material theme"
        return 1
    fi

    mkdocs --version

    print_status "Checking MkDocs configuration..."
    if [[ ! -f "mkdocs.yml" ]]; then
        print_error "MkDocs configuration file not found"
        return 1
    fi

    print_status "Validating MkDocs configuration..."
    if ! python3 -c "import yaml; yaml.safe_load(open('mkdocs.yml'))" 2>/dev/null; then
        # MkDocs config may have Python objects, try mkdocs build instead
        if ! mkdocs build --quiet >/dev/null 2>&1; then
            print_error "Invalid MkDocs configuration"
            return 1
        fi
    fi

    print_status "Testing MkDocs build..."
    if ! mkdocs build --quiet >/dev/null 2>&1; then
        print_error "MkDocs build failed - check configuration and content"
        return 1
    fi

    print_status "Checking documentation script..."
    if [[ ! -x "docs.sh" ]]; then
        print_error "Documentation script not executable"
        return 1
    fi

    print_status "Checking documentation structure..."
    if [[ ! -d "docs" ]]; then
        print_error "Documentation directory not found"
        return 1
    fi

    if [[ ! -f "docs/index.md" ]]; then
        print_error "Main documentation page not found"
        return 1
    fi

    print_success "Documentation tools are properly configured"
}

# Test development tools
test_dev_tools() {
    print_header "Testing Development Tools"

    print_status "Checking Python installation..."
    if ! command -v python3 >/dev/null 2>&1; then
        print_error "Python 3 not found"
        return 1
    fi

    python3 --version

    print_status "Checking Node.js installation..."
    if ! command -v node >/dev/null 2>&1; then
        print_warning "Node.js not installed - install with: brew install node (macOS) or curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt-get install -y nodejs (Ubuntu)"
    else
        node --version
        print_success "Node.js is installed"
    fi

    print_status "Checking npm..."
    if ! command -v npm >/dev/null 2>&1; then
        print_warning "npm not available"
    else
        npm --version
        print_success "npm is available"
    fi

    print_status "Checking jq..."
    if ! command -v jq >/dev/null 2>&1; then
        print_warning "jq not installed - install with: brew install jq (macOS) or apt install jq (Ubuntu)"
    else
        jq --version
        print_success "jq is installed"
    fi

    print_status "Checking HTTPie..."
    if ! command -v http >/dev/null 2>&1; then
        print_warning "HTTPie not installed - install with: brew install httpie (macOS) or apt install httpie (Ubuntu)"
    else
        http --version
        print_success "HTTPie is installed"
    fi

    print_status "Checking pre-commit..."
    if ! command -v pre-commit >/dev/null 2>&1; then
        print_warning "pre-commit not installed - install with: pip3 install pre-commit"
    else
        pre-commit --version
        print_success "pre-commit is installed"
    fi

    print_success "Development tools check completed"
}

# Test metrics exporter
test_metrics_exporter() {
    print_header "Testing Metrics Exporter"

    if [[ ! -f "metrics_exporter.py" ]]; then
        print_error "Metrics exporter script not found"
        return 1
    fi

    print_status "Checking Python dependencies..."
    if ! /Library/Frameworks/Python.framework/Versions/3.12/bin/python3 -c "import flask, prometheus_client" 2>/dev/null; then
        print_error "Required Python packages not installed - install with: pip3 install flask prometheus_client"
        return 1
    fi

    print_status "Validating metrics exporter syntax..."
    if ! python3 -m py_compile metrics_exporter.py; then
        print_error "Metrics exporter has syntax errors"
        return 1
    fi

    print_success "Metrics exporter is valid"
}

# Test agent status integration
test_agent_integration() {
    print_header "Testing Agent Integration"

    if [[ ! -f "agent_status.json" ]]; then
        print_warning "Agent status file not found - this is normal if agents haven't run yet"
    else
        print_status "Validating agent status JSON..."
        if ! jq . agent_status.json >/dev/null 2>&1; then
            print_error "Invalid agent status JSON"
            return 1
        fi
        print_success "Agent status JSON is valid"
    fi

    if [[ ! -f "agent_assignments.json" ]]; then
        print_warning "Agent assignments file not found - this is normal if no assignments exist"
    else
        print_status "Validating agent assignments JSON..."
        if ! jq . agent_assignments.json >/dev/null 2>&1; then
            print_error "Invalid agent assignments JSON"
            return 1
        fi
        print_success "Agent assignments JSON is valid"
    fi
}

# Run all tests
run_all_tests() {
    local failed_tests=()

    print_header "Running Comprehensive Tools Test Suite"

    # Test each component
    if ! test_docker; then
        failed_tests+=("docker")
    fi

    if ! test_monitoring; then
        failed_tests+=("monitoring")
    fi

    if ! test_quality; then
        failed_tests+=("quality")
    fi

    if ! test_security; then
        failed_tests+=("security")
    fi

    if ! test_documentation; then
        failed_tests+=("documentation")
    fi

    if ! test_dev_tools; then
        failed_tests+=("dev_tools")
    fi

    if ! test_metrics_exporter; then
        failed_tests+=("metrics_exporter")
    fi

    if ! test_agent_integration; then
        failed_tests+=("agent_integration")
    fi

    # Report results
    echo ""
    print_header "Test Results"

    if [[ ${#failed_tests[@]} -eq 0 ]]; then
        print_success "All tests passed! 🎉"
        echo ""
        print_status "Your free tools stack is ready to use."
        echo ""
        print_status "Quick start commands:"
        echo "  Monitoring: ./monitoring.sh start"
        echo "  Quality: ./quality.sh start"
        echo "  Documentation: ./docs.sh serve"
        echo "  Security scan: ./security_scan.sh audit"
        echo "  Metrics: python3 metrics_exporter.py"
    else
        print_error "Some tests failed: ${failed_tests[*]}"
        echo ""
        print_status "Fix the failed components and run this test again."
        return 1
    fi
}

# Main function
main() {
    case "${1:-all}" in
    "docker")
        test_docker
        ;;
    "monitoring")
        test_monitoring
        ;;
    "quality")
        test_quality
        ;;
    "security")
        test_security
        ;;
    "docs" | "documentation")
        test_documentation
        ;;
    "dev" | "devtools")
        test_dev_tools
        ;;
    "metrics")
        test_metrics_exporter
        ;;
    "agents")
        test_agent_integration
        ;;
    "all")
        run_all_tests
        ;;
    *)
        echo "Usage: $0 [docker|monitoring|quality|security|docs|dev|metrics|agents|all]"
        exit 1
        ;;
    esac
}

main "$@"

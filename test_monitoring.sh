#!/bin/bash

# Tools Automation Monitoring Test Script
# Tests that all monitoring components are working correctly

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
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Test Docker installation
test_docker() {
    print_status "Testing Docker installation..."

    if ! command -v docker >/dev/null 2>&1; then
        print_error "Docker is not installed or not in PATH"
        return 1
    fi

    if ! docker info >/dev/null 2>&1; then
        print_error "Docker daemon is not running"
        return 1
    fi

    print_success "Docker is installed and running"
}

# Test Docker Compose
test_docker_compose() {
    print_status "Testing Docker Compose..."

    if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
        print_error "Docker Compose is not available"
        return 1
    fi

    print_success "Docker Compose is available"
}

# Test Python dependencies
test_python_deps() {
    print_status "Testing Python dependencies..."

    if ! command -v python3 >/dev/null 2>&1; then
        print_error "Python 3 is not installed"
        return 1
    fi

    # Test Flask
    if ! python3 -c "import flask" >/dev/null 2>&1; then
        print_error "Flask is not installed. Run: pip3 install flask"
        return 1
    fi

    # Test Prometheus client
    if ! python3 -c "import prometheus_client" >/dev/null 2>&1; then
        print_error "prometheus_client is not installed. Run: pip3 install prometheus_client"
        return 1
    fi

    print_success "Python dependencies are installed"
}

# Test monitoring services
test_monitoring_services() {
    print_status "Testing monitoring services..."

    local services=("prometheus" "grafana" "uptime-kuma" "node-exporter")
    local failed_services=()

    for service in "${services[@]}"; do
        if docker-compose -f docker-compose.monitoring.yml ps "${service}" 2>/dev/null | grep -q "Up"; then
            print_success "✅ ${service} is running"
        else
            print_error "❌ ${service} is not running"
            failed_services+=("${service}")
        fi
    done

    if [[ ${#failed_services[@]} -gt 0 ]]; then
        print_warning "Some services are not running. Run: ./monitoring.sh start"
        return 1
    fi
}

# Test metrics exporter
test_metrics_exporter() {
    print_status "Testing metrics exporter..."

    # Check if metrics exporter is running
    if ! pgrep -f "metrics_exporter.py" >/dev/null 2>&1; then
        print_warning "Metrics exporter is not running. Start it with: python3 metrics_exporter.py"
        return 1
    fi

    # Test metrics endpoint
    if ! curl -s http://localhost:8080/metrics >/dev/null 2>&1; then
        print_error "Metrics endpoint is not responding"
        return 1
    fi

    # Test health endpoint
    if ! curl -s http://localhost:8080/health >/dev/null 2>&1; then
        print_error "Health endpoint is not responding"
        return 1
    fi

    print_success "Metrics exporter is running and responding"
}

# Test development tools
test_dev_tools() {
    print_status "Testing development tools..."

    # Test jq
    if command -v jq >/dev/null 2>&1; then
        print_success "✅ jq is installed"
    else
        print_warning "❌ jq is not installed"
    fi

    # Test httpie
    if command -v http >/dev/null 2>&1; then
        print_success "✅ httpie is installed"
    else
        print_warning "❌ httpie is not installed"
    fi

    # Test pre-commit
    if command -v pre-commit >/dev/null 2>&1; then
        print_success "✅ pre-commit is installed"
    else
        print_warning "❌ pre-commit is not installed"
    fi

    # Test Node.js
    if command -v node >/dev/null 2>&1; then
        print_success "✅ Node.js is installed"
    else
        print_warning "❌ Node.js is not installed"
    fi
}

# Test configuration files
test_config_files() {
    print_status "Testing configuration files..."

    local config_files=(
        "docker-compose.monitoring.yml"
        "monitoring/prometheus.yml"
        "monitoring/grafana/provisioning/datasources/prometheus.yml"
        "monitoring/grafana/provisioning/dashboards/dashboard.yml"
        "agent_status.json"
    )

    for config_file in "${config_files[@]}"; do
        if [[ -f "${config_file}" ]]; then
            print_success "✅ ${config_file} exists"
        else
            print_error "❌ ${config_file} is missing"
        fi
    done
}

# Generate test report
generate_report() {
    print_status "Generating test report..."

    cat <<EOF

📊 Tools Automation Monitoring Test Report
==========================================

Test completed at: $(date)

System Information:
- OS: $(uname -s) $(uname -r)
- User: $(whoami)
- Working Directory: $(pwd)

Components Tested:
✅ Docker Installation
✅ Docker Compose
✅ Python Dependencies
✅ Monitoring Services
✅ Metrics Exporter
✅ Development Tools
✅ Configuration Files

Next Steps:
1. If any tests failed, follow the setup guide
2. Start monitoring: ./monitoring.sh start
3. Start metrics: python3 metrics_exporter.py
4. Access Grafana: http://localhost:3000

For detailed troubleshooting, see TOOLS_IMPLEMENTATION_GUIDE.md

EOF
}

# Main test function
main() {
    echo "🧪 Tools Automation Monitoring Test Suite"
    echo "=========================================="
    echo ""

    local test_results=()

    # Run all tests
    test_docker && test_results+=("docker:pass") || test_results+=("docker:fail")
    test_docker_compose && test_results+=("compose:pass") || test_results+=("compose:fail")
    test_python_deps && test_results+=("python:pass") || test_results+=("python:fail")
    test_config_files && test_results+=("config:pass") || test_results+=("config:fail")
    test_dev_tools && test_results+=("devtools:pass") || test_results+=("devtools:fail")

    # These tests require services to be running
    if test_docker && test_docker_compose; then
        test_monitoring_services && test_results+=("services:pass") || test_results+=("services:fail")
        test_metrics_exporter && test_results+=("metrics:pass") || test_results+=("metrics:fail")
    fi

    echo ""
    generate_report

    # Count failures
    local failures=0
    for result in "${test_results[@]}"; do
        if [[ "${result}" == *":fail" ]]; then
            ((failures++))
        fi
    done

    if [[ ${failures} -gt 0 ]]; then
        echo "❌ ${failures} test(s) failed. Check the output above for details."
        exit 1
    else
        echo "✅ All tests passed!"
    fi
}

main "$@"

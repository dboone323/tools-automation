#!/bin/bash

# Tools Automation Quality Tools Manager
# Manages SonarQube and other code quality tools

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.quality.yml"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[QUALITY]${NC} $1"
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

# Check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
}

# Check if docker-compose file exists
check_compose_file() {
    if [[ ! -f "${COMPOSE_FILE}" ]]; then
        print_error "Docker Compose file not found: ${COMPOSE_FILE}"
        exit 1
    fi
}

# Start quality tools stack
start_quality() {
    print_status "Starting Tools Automation Quality Tools Stack..."

    cd "${PROJECT_ROOT}"

    # Start services
    docker-compose -f "${COMPOSE_FILE}" up -d --remove-orphans

    print_success "Quality tools stack started successfully!"
    echo ""
    print_status "Access URLs:"
    echo "  📊 SonarQube: http://localhost:9000 (admin/admin)"
    echo ""
    print_status "Waiting for services to be ready..."
    print_warning "SonarQube may take 2-3 minutes to fully initialize on first startup."
    sleep 30

    # Check service health
    check_quality_services
}

# Stop quality tools stack
stop_quality() {
    print_status "Stopping Tools Automation Quality Tools Stack..."

    cd "${PROJECT_ROOT}"
    docker-compose -f "${COMPOSE_FILE}" down

    print_success "Quality tools stack stopped."
}

# Restart quality tools stack
restart_quality() {
    print_status "Restarting Tools Automation Quality Tools Stack..."
    stop_quality
    sleep 5
    start_quality
}

# Check service status
check_quality_services() {
    print_status "Checking quality service status..."

    local services=("sonarqube" "db")
    local failed_services=()

    for service in "${services[@]}"; do
        if docker-compose -f "${COMPOSE_FILE}" ps "${service}" 2>/dev/null | grep -q "Up"; then
            print_success "✅ ${service} is running"
        else
            print_error "❌ ${service} is not running"
            failed_services+=("${service}")
        fi
    done

    if [[ ${#failed_services[@]} -gt 0 ]]; then
        print_warning "Some services are not running. Check logs with: ./quality.sh logs"
        return 1
    fi
}

# Show logs
show_logs() {
    local service="$1"

    if [[ -n "${service}" ]]; then
        print_status "Showing logs for ${service}..."
        cd "${PROJECT_ROOT}"
        docker-compose -f "${COMPOSE_FILE}" logs -f "${service}"
    else
        print_status "Showing all logs..."
        cd "${PROJECT_ROOT}"
        docker-compose -f "${COMPOSE_FILE}" logs -f
    fi
}

# Run SonarQube analysis
run_sonar_analysis() {
    local project_key="${1:-tools-automation}"
    local project_name="${2:-Tools Automation}"
    local sources="${3:-.}"

    print_status "Running SonarQube analysis..."

    if ! command -v docker >/dev/null 2>&1; then
        print_error "Docker is required for SonarQube analysis"
        exit 1
    fi

    # Run sonar-scanner
    docker run --rm \
        --network tools-automation_quality \
        -v "$(pwd):/usr/src" \
        sonarsource/sonar-scanner-cli \
        -Dsonar.projectKey="${project_key}" \
        -Dsonar.projectName="${project_name}" \
        -Dsonar.sources="${sources}" \
        -Dsonar.host.url="http://sonarqube:9000" \
        -Dsonar.login="admin" \
        -Dsonar.password="admin"

    print_success "SonarQube analysis completed."
    print_status "View results at: http://localhost:9000"
}

# Clean up quality data
cleanup_quality() {
    print_warning "This will remove all quality tool data and containers."
    read -p "Are you sure? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Cleaning up quality tools stack..."

        cd "${PROJECT_ROOT}"
        docker-compose -f "${COMPOSE_FILE}" down -v --remove-orphans

        print_success "Cleanup completed."
    else
        print_status "Cleanup cancelled."
    fi
}

# Show usage
show_usage() {
    echo "🧪 Tools Automation Quality Tools Manager"
    echo ""
    echo "Usage: $0 {start|stop|restart|status|logs [service]|analyze [project_key] [project_name] [sources]|cleanup}"
    echo ""
    echo "Commands:"
    echo "  start           # Start the quality tools stack"
    echo "  stop            # Stop the quality tools stack"
    echo "  restart         # Restart the quality tools stack"
    echo "  status          # Check service status"
    echo "  logs [service]  # Show logs (all services or specific service)"
    echo "  analyze [opts]  # Run SonarQube analysis on current directory"
    echo "  cleanup         # Remove all quality tool data and containers"
    echo ""
    echo "Services: sonarqube, db"
    echo ""
    echo "Analysis Options:"
    echo "  project_key     # SonarQube project key (default: tools-automation)"
    echo "  project_name    # Project display name (default: Tools Automation)"
    echo "  sources         # Source directory (default: .)"
    echo ""
    exit 1
}

# Main execution
main() {
    local command="$1"
    local arg1="$2"
    local arg2="$3"
    local arg3="$4"

    check_docker
    check_compose_file

    case "${command}" in
    "start")
        start_quality
        ;;
    "stop")
        stop_quality
        ;;
    "restart")
        restart_quality
        ;;
    "status")
        check_quality_services
        ;;
    "logs")
        show_logs "${arg1}"
        ;;
    "analyze")
        run_sonar_analysis "${arg1}" "${arg2}" "${arg3}"
        ;;
    "cleanup")
        cleanup_quality
        ;;
    *)
        show_usage
        ;;
    esac
}

main "$@"

#!/bin/bash

# Uptime Kuma Monitor Setup Script
# Provides automated setup instructions and manual configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Function to check service availability
check_service() {
    local url;
    url="$1"
    local name;
    name="$2"

    if curl -s --max-time 5 "$url" >/dev/null 2>&1; then
        print_status "$name is accessible"
        return 0
    else
        print_warning "$name is not accessible (monitor will still be created)"
        return 0 # Don't fail the script
    fi
}

# Function to generate monitor JSON for API
generate_monitor_json() {
    local name;
    name="$1"
    local url;
    url="$2"
    local interval;
    interval="$3"
    local timeout;
    timeout="$4"
    local retries;
    retries="$5"

    cat <<EOF
{
    "name": "$name",
    "type": "http",
    "url": "$url",
    "interval": $interval,
    "timeout": $timeout,
    "maxretries": $retries,
    "ignoreTls": false,
    "upsideDown": false,
    "resendInterval": 0
}
EOF
}

# Function to try automated setup
try_automated_setup() {
    print_info "Attempting automated monitor setup..."

    # Try to get auth token
    local token;
    token=$(curl -s -X POST "${UPTIME_KUMA_URL}/api/login" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"admin\",\"password\":\"admin\"}" 2>/dev/null | jq -r '.token // empty' 2>/dev/null)

    if [ -z "$token" ] || [ "$token" = "null" ] || [ "$token" = "" ]; then
        print_warning "Could not authenticate automatically. Uptime Kuma may need initial setup."
        return 1
    fi

    print_success "Authentication successful! Setting up monitors automatically..."

    # Create all monitors
    create_monitor_api "$token" "Grafana Dashboard" "http" "http://localhost:3000" 60 10 3
    create_monitor_api "$token" "Prometheus Metrics" "http" "http://localhost:9090/-/healthy" 30 5 2
    create_monitor_api "$token" "Agent Metrics Exporter" "http" "http://localhost:8080/health" 30 5 2
    create_monitor_api "$token" "Documentation Site" "http" "http://localhost:8000" 60 10 3
    create_monitor_api "$token" "Code Quality (SonarQube)" "http" "http://localhost:9000/api/system/status" 120 15 2
    create_monitor_api "$token" "Uptime Kuma (Self)" "http" "http://localhost:3001/metrics" 60 5 2

    print_success "All monitors created successfully!"
    print_info "Visit http://localhost:3001 to see your monitors"
    return 0
}

# Function to create monitor via API
create_monitor_api() {
    local token;
    token="$1"
    local name;
    name="$2"
    local type;
    type="$3"
    local url;
    url="$4"
    local interval;
    interval="$5"
    local timeout;
    timeout="$6"
    local retries;
    retries="$7"

    local response;

    response=$(curl -s -X POST "${UPTIME_KUMA_URL}/api/monitors" \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"$name\",
            \"type\": \"$type\",
            \"url\": \"$url\",
            \"interval\": $interval,
            \"timeout\": $timeout,
            \"maxretries\": $retries,
            \"ignoreTls\": false,
            \"upsideDown\": false,
            \"resendInterval\": 0
        }")

    local success;

    success=$(echo "$response" | jq -r '.ok // false' 2>/dev/null)

    if [ "$success" = "true" ]; then
        print_success "✅ Created monitor: $name"
    else
        print_warning "⚠️  Could not create monitor: $name (may already exist)"
    fi
}

# Main function
main() {
    print_header "Uptime Kuma Monitor Setup Script"
    echo ""

    # Check if Uptime Kuma is running
    if ! curl -s --max-time 5 "http://localhost:3001" >/dev/null 2>&1; then
        print_error "Uptime Kuma is not accessible at http://localhost:3001"
        print_error "Please make sure Uptime Kuma is running with: ./monitoring.sh start"
        exit 1
    fi

    print_status "Uptime Kuma is running and accessible"

    echo ""
    print_info "Checking service availability before creating monitors..."
    echo ""

    check_service "http://localhost:3000" "Grafana"
    check_service "http://localhost:9090/-/healthy" "Prometheus"
    check_service "http://localhost:8080/health" "Metrics Exporter"
    check_service "http://localhost:8000" "MkDocs"
    check_service "http://localhost:9000/api/system/status" "SonarQube"

    echo ""

    # Try automated setup first
    if try_automated_setup; then
        return 0
    fi

    echo ""
    print_header "MANUAL SETUP INSTRUCTIONS"
    echo ""
    print_info "Automated setup failed. Please complete initial Uptime Kuma setup first:"
    echo ""

    echo "1. 🌐 Open your browser and go to: http://localhost:3001"
    echo "2. 📝 Complete the initial setup (create admin account if prompted)"
    echo "3. ➕ Click 'Add New Monitor' for each service below"
    echo ""

    print_header "MONITOR CONFIGURATIONS"
    echo ""

    echo "📊 GRAFANA DASHBOARD"
    echo "   Monitor Type: HTTP(s)"
    echo "   Friendly Name: Grafana Dashboard"
    echo "   URL: http://localhost:3000"
    echo "   Monitoring Interval: 60 seconds"
    echo "   Timeout: 10 seconds"
    echo "   Retries: 3"
    echo ""

    echo "📈 PROMETHEUS METRICS"
    echo "   Monitor Type: HTTP(s)"
    echo "   Friendly Name: Prometheus Metrics"
    echo "   URL: http://localhost:9090/-/healthy"
    echo "   Monitoring Interval: 30 seconds"
    echo "   Timeout: 5 seconds"
    echo "   Retries: 2"
    echo ""

    echo "📊 AGENT METRICS EXPORTER"
    echo "   Monitor Type: HTTP(s)"
    echo "   Friendly Name: Agent Metrics Exporter"
    echo "   URL: http://localhost:8080/health"
    echo "   Monitoring Interval: 30 seconds"
    echo "   Timeout: 5 seconds"
    echo "   Retries: 2"
    echo ""

    echo "📚 DOCUMENTATION SITE"
    echo "   Monitor Type: HTTP(s)"
    echo "   Friendly Name: Documentation Site"
    echo "   URL: http://localhost:8000"
    echo "   Monitoring Interval: 60 seconds"
    echo "   Timeout: 10 seconds"
    echo "   Retries: 3"
    echo ""

    echo "🧪 CODE QUALITY (SONARQUBE)"
    echo "   Monitor Type: HTTP(s)"
    echo "   Friendly Name: Code Quality (SonarQube)"
    echo "   URL: http://localhost:9000/api/system/status"
    echo "   Monitoring Interval: 120 seconds"
    echo "   Timeout: 15 seconds"
    echo "   Retries: 2"
    echo "   Expected Status Code: 200"
    echo ""

    echo "⏱️  UPTIME KUMA (SELF-MONITOR)"
    echo "   Monitor Type: HTTP(s)"
    echo "   Friendly Name: Uptime Kuma (Self)"
    echo "   URL: http://localhost:3001/metrics"
    echo "   Monitoring Interval: 60 seconds"
    echo "   Timeout: 5 seconds"
    echo "   Retries: 2"
    echo ""

    print_header "ADVANCED SETTINGS"
    echo ""
    echo "For each monitor, expand 'Advanced Settings' and set:"
    echo "• Resend Notification if Down X times: 2"
    echo "• Enable 'Send Test Notification' to test alerts"
    echo ""

    print_header "WHAT TO EXPECT"
    echo ""
    print_status "After setup, you'll see:"
    echo "• 🟢 Green status indicators for healthy services"
    echo "• 📊 Uptime percentages and response times"
    echo "• 📈 Historical uptime charts"
    echo "• 🔔 Alert notifications when services go down"
    echo ""

    print_info "💡 Tip: You can also set up notification channels (email, Slack, etc.)"
    print_info "   in Uptime Kuma settings to get alerted when services go down."
    echo ""

    # Offer API setup as alternative
    echo ""
    print_header "AUTOMATED API SETUP (Advanced)"
    echo ""
    print_info "If you prefer automated setup, you can use the API after initial setup:"
    echo ""
    echo "# Get authentication token:"
    echo "curl -X POST http://localhost:3001/api/login \\"
    echo "  -H 'Content-Type: application/json' \\"
    echo "  -d '{\"username\":\"admin\",\"password\":\"yourpassword\"}'"
    echo ""
    echo "# Then create monitors with the token"
    echo "# (See the full API script in this file for complete automation)"
    echo ""

    print_status "Setup instructions complete!"
    print_info "Visit http://localhost:3001 to configure your monitors"
}

# Run main function
if [ "$1" = "--manual" ]; then
    # Force manual mode
    print_header "Uptime Kuma Monitor Setup Script (Manual Mode)"
    echo ""
    print_info "Skipping automated setup. Showing manual instructions only."
    echo ""
    # Show manual instructions directly
    echo "1. 🌐 Open your browser and go to: http://localhost:3001"
    echo "2. 📝 Complete the initial setup (create admin account if prompted)"
    echo "3. ➕ Click 'Add New Monitor' for each service below"
    echo ""
    print_header "MONITOR CONFIGURATIONS"
    echo ""
    echo "📊 GRAFANA DASHBOARD"
    echo "   Monitor Type: HTTP(s)"
    echo "   Friendly Name: Grafana Dashboard"
    echo "   URL: http://localhost:3000"
    echo "   Monitoring Interval: 60 seconds"
    echo "   Timeout: 10 seconds"
    echo "   Retries: 3"
    echo ""
    echo "📈 PROMETHEUS METRICS"
    echo "   Monitor Type: HTTP(s)"
    echo "   Friendly Name: Prometheus Metrics"
    echo "   URL: http://localhost:9090/-/healthy"
    echo "   Monitoring Interval: 30 seconds"
    echo "   Timeout: 5 seconds"
    echo "   Retries: 2"
    echo ""
    echo "📊 AGENT METRICS EXPORTER"
    echo "   Monitor Type: HTTP(s)"
    echo "   Friendly Name: Agent Metrics Exporter"
    echo "   URL: http://localhost:8080/health"
    echo "   Monitoring Interval: 30 seconds"
    echo "   Timeout: 5 seconds"
    echo "   Retries: 2"
    echo ""
    echo "📚 DOCUMENTATION SITE"
    echo "   Monitor Type: HTTP(s)"
    echo "   Friendly Name: Documentation Site"
    echo "   URL: http://localhost:8000"
    echo "   Monitoring Interval: 60 seconds"
    echo "   Timeout: 10 seconds"
    echo "   Retries: 3"
    echo ""
    echo "🧪 CODE QUALITY (SONARQUBE)"
    echo "   Monitor Type: HTTP(s)"
    echo "   Friendly Name: Code Quality (SonarQube)"
    echo "   URL: http://localhost:9000/api/system/status"
    echo "   Monitoring Interval: 120 seconds"
    echo "   Timeout: 15 seconds"
    echo "   Retries: 2"
    echo "   Expected Status Code: 200"
    echo ""
    echo "⏱️  UPTIME KUMA (SELF-MONITOR)"
    echo "   Monitor Type: HTTP(s)"
    echo "   Friendly Name: Uptime Kuma (Self)"
    echo "   URL: http://localhost:3001/metrics"
    echo "   Monitoring Interval: 60 seconds"
    echo "   Timeout: 5 seconds"
    echo "   Retries: 2"
    echo ""
    print_header "ADVANCED SETTINGS"
    echo ""
    echo "For each monitor, expand 'Advanced Settings' and set:"
    echo "• Resend Notification if Down X times: 2"
    echo "• Enable 'Send Test Notification' to test alerts"
    echo ""
    print_status "Manual setup instructions displayed!"
    print_info "Visit http://localhost:3001 to configure your monitors"
else
    main "$@"
fi

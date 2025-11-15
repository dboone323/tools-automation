#!/bin/bash

# Enterprise Deployment Script Template
# This script provides a secure, automated deployment process for the tools-automation system

set -euo pipefail

# Configuration variables (should be set via environment or config file)
DEPLOYMENT_ENV="${DEPLOYMENT_ENV:-production}"
REGION="${REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-tools-automation-cluster}"
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-CHANGE_THIS_PASSWORD}"
BACKUP_ENCRYPTION_KEY="${BACKUP_ENCRYPTION_KEY:-CHANGE_THIS_KEY}"

# Internal variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_ROOT/config/enterprise_config.json"
BACKUP_DIR="$PROJECT_ROOT/backups/$(date +%Y%m%d_%H%M%S)"

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$DEPLOYMENT_ENV] $*" | tee -a "$PROJECT_ROOT/logs/deployment.log"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2
    exit 1
}

# Pre-deployment validation
pre_deployment_checks() {
    log "Running pre-deployment checks..."

    # Check required tools
    local required_tools=("docker" "kubectl" "helm" "jq" "openssl")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "Required tool not found: $tool"
        fi
    done

    # Check configuration file
    if [[ ! -f "$CONFIG_FILE" ]]; then
        error "Configuration file not found: $CONFIG_FILE"
    fi

    # Validate configuration
    if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
        error "Invalid JSON configuration file: $CONFIG_FILE"
    fi

    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot connect to Kubernetes cluster"
    fi

    log "Pre-deployment checks completed successfully"
}

# Create backup
create_backup() {
    log "Creating deployment backup..."

    mkdir -p "$BACKUP_DIR"

    # Backup current configuration
    if [[ -d "$PROJECT_ROOT/config" ]]; then
        cp -r "$PROJECT_ROOT/config" "$BACKUP_DIR/"
    fi

    # Backup current data
    if [[ -d "$PROJECT_ROOT/data" ]]; then
        cp -r "$PROJECT_ROOT/data" "$BACKUP_DIR/"
    fi

    # Backup current logs
    if [[ -d "$PROJECT_ROOT/logs" ]]; then
        cp -r "$PROJECT_ROOT/logs" "$BACKUP_DIR/"
    fi

    log "Backup created: $BACKUP_DIR"
}

# Setup security
setup_security() {
    log "Setting up enterprise security..."

    # Generate TLS certificates
    local cert_dir="$PROJECT_ROOT/certs"
    mkdir -p "$cert_dir"

    # Generate CA certificate
    openssl genrsa -out "$cert_dir/ca.key" 4096
    openssl req -new -x509 -days 3650 -key "$cert_dir/ca.key" -sha256 -out "$cert_dir/ca.crt" \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=Tools-Automation-CA"

    # Generate server certificate
    openssl genrsa -out "$cert_dir/server.key" 2048
    openssl req -subj "/CN=tools-automation.$CLUSTER_NAME" -new -key "$cert_dir/server.key" -out "$cert_dir/server.csr"
    openssl x509 -req -days 365 -in "$cert_dir/server.csr" -CA "$cert_dir/ca.crt" -CAkey "$cert_dir/ca.key" \
        -out "$cert_dir/server.crt" -sha256 -CAcreateserial

    # Set proper permissions
    chmod 600 "$cert_dir"/*.key
    chmod 644 "$cert_dir"/*.crt

    log "Security setup completed"
}

# Deploy RBAC system
deploy_rbac() {
    log "Deploying RBAC system..."

    # Create RBAC namespace
    kubectl create namespace tools-automation-rbac --dry-run=client -o yaml | kubectl apply -f -

    # Deploy RBAC service
    kubectl apply -f "$PROJECT_ROOT/deployment/kubernetes/rbac-deployment.yaml"

    # Wait for deployment
    kubectl wait --for=condition=available --timeout=300s deployment/rbac-system -n tools-automation-rbac

    # Initialize default users
    kubectl exec -n tools-automation-rbac deployment/rbac-system -- ./rbac_system.sh init

    log "RBAC system deployed successfully"
}

# Deploy audit system
deploy_audit() {
    log "Deploying audit and compliance system..."

    # Create audit namespace
    kubectl create namespace tools-automation-audit --dry-run=client -o yaml | kubectl apply -f -

    # Deploy audit service
    kubectl apply -f "$PROJECT_ROOT/deployment/kubernetes/audit-deployment.yaml"

    # Wait for deployment
    kubectl wait --for=condition=available --timeout=300s deployment/audit-system -n tools-automation-audit

    # Initialize audit system
    kubectl exec -n tools-automation-audit deployment/audit-system -- ./audit_compliance.sh init

    log "Audit system deployed successfully"
}

# Deploy monitoring stack
deploy_monitoring() {
    log "Deploying monitoring stack..."

    # Add Helm repositories
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update

    # Install Prometheus
    helm upgrade --install prometheus prometheus-community/prometheus \
        --namespace monitoring --create-namespace \
        --set server.persistentVolume.enabled=true \
        --set server.persistentVolume.size=50Gi

    # Install Grafana
    helm upgrade --install grafana grafana/grafana \
        --namespace monitoring \
        --set persistence.enabled=true \
        --set persistence.size=10Gi \
        --set adminPassword="$ADMIN_PASSWORD"

    log "Monitoring stack deployed successfully"
}

# Deploy main application
deploy_application() {
    log "Deploying main application..."

    # Create application namespace
    kubectl create namespace tools-automation --dry-run=client -o yaml | kubectl apply -f -

    # Deploy application components
    kubectl apply -f "$PROJECT_ROOT/deployment/kubernetes/app-deployment.yaml"

    # Wait for deployments
    kubectl wait --for=condition=available --timeout=600s deployment/agent-coordinator -n tools-automation
    kubectl wait --for=condition=available --timeout=600s deployment/monitoring-system -n tools-automation

    log "Main application deployed successfully"
}

# Post-deployment validation
post_deployment_validation() {
    log "Running post-deployment validation..."

    # Check RBAC system
    if ! kubectl exec -n tools-automation-rbac deployment/rbac-system -- ./rbac_system.sh status &> /dev/null; then
        error "RBAC system health check failed"
    fi

    # Check audit system
    if ! kubectl exec -n tools-automation-audit deployment/audit-system -- ./audit_compliance.sh query | jq empty &> /dev/null; then
        error "Audit system health check failed"
    fi

    # Check application components
    if ! kubectl get pods -n tools-automation | grep -q "Running"; then
        error "Application pods are not running"
    fi

    # Check monitoring
    if ! kubectl get pods -n monitoring | grep -q "Running"; then
        error "Monitoring pods are not running"
    fi

    log "Post-deployment validation completed successfully"
}

# Rollback function
rollback() {
    log "Starting rollback process..."

    # Restore from backup
    if [[ -d "$BACKUP_DIR" ]]; then
        cp -r "$BACKUP_DIR/config" "$PROJECT_ROOT/" 2>/dev/null || true
        cp -r "$BACKUP_DIR/data" "$PROJECT_ROOT/" 2>/dev/null || true
        log "Configuration and data restored from backup"
    fi

    # Rollback Kubernetes deployments
    kubectl rollout undo deployment -n tools-automation 2>/dev/null || true
    kubectl rollout undo deployment -n tools-automation-rbac 2>/dev/null || true
    kubectl rollout undo deployment -n tools-automation-audit 2>/dev/null || true

    log "Rollback completed"
}

# Main deployment process
main() {
    log "Starting enterprise deployment for environment: $DEPLOYMENT_ENV"

    trap rollback ERR

    pre_deployment_checks
    create_backup
    setup_security
    deploy_rbac
    deploy_audit
    deploy_monitoring
    deploy_application
    post_deployment_validation

    log "Enterprise deployment completed successfully!"
    log "Access URLs:"
    log "  RBAC Admin: https://rbac.tools-automation.$CLUSTER_NAME"
    log "  Monitoring: https://grafana.tools-automation.$CLUSTER_NAME"
    log "  Application: https://app.tools-automation.$CLUSTER_NAME"
}

# Run main function
main "$@"

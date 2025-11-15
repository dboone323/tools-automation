#!/bin/bash

# Phase 17: Enterprise Features - Enterprise Deployment Templates

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_TEMPLATES_DIR="$WORKSPACE_ROOT/deployment_templates"
CONFIG_TEMPLATES_DIR="$DEPLOYMENT_TEMPLATES_DIR/config"
SCRIPT_TEMPLATES_DIR="$DEPLOYMENT_TEMPLATES_DIR/scripts"
DOCKER_TEMPLATES_DIR="$DEPLOYMENT_TEMPLATES_DIR/docker"
KUBERNETES_TEMPLATES_DIR="$DEPLOYMENT_TEMPLATES_DIR/kubernetes"

# Create deployment directories
mkdir -p "$DEPLOYMENT_TEMPLATES_DIR" "$CONFIG_TEMPLATES_DIR" "$SCRIPT_TEMPLATES_DIR" "$DOCKER_TEMPLATES_DIR" "$KUBERNETES_TEMPLATES_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$WORKSPACE_ROOT/logs/deployment.log"
}

# Generate secure configuration template
generate_secure_config_template() {
    local template_file="$CONFIG_TEMPLATES_DIR/enterprise_config_template.json"

    cat >"$template_file" <<'EOF'
{
  "enterprise_config": {
    "version": "1.0",
    "deployment": {
      "environment": "{{ENVIRONMENT}}",
      "region": "{{REGION}}",
      "datacenter": "{{DATACENTER}}",
      "cluster_name": "{{CLUSTER_NAME}}"
    },
    "security": {
      "rbac_enabled": true,
      "audit_enabled": true,
      "encryption_enabled": true,
      "tls_version": "1.3",
      "certificate_authority": "{{CA_CERT_PATH}}",
      "key_rotation_days": 90,
      "session_timeout_minutes": 30,
      "max_login_attempts": 5,
      "password_policy": {
        "min_length": 12,
        "require_uppercase": true,
        "require_lowercase": true,
        "require_numbers": true,
        "require_special_chars": true,
        "prevent_reuse": 5
      }
    },
    "networking": {
      "internal_network": "{{INTERNAL_NETWORK}}",
      "external_network": "{{EXTERNAL_NETWORK}}",
      "load_balancer_ip": "{{LB_IP}}",
      "firewall_rules": [
        {
          "name": "allow_internal",
          "source": "{{INTERNAL_NETWORK}}",
          "destination": "{{INTERNAL_NETWORK}}",
          "ports": ["22", "80", "443", "2379", "2380"],
          "protocol": "tcp"
        },
        {
          "name": "allow_monitoring",
          "source": "{{MONITORING_NETWORK}}",
          "destination": "{{INTERNAL_NETWORK}}",
          "ports": ["9090", "9100", "3000"],
          "protocol": "tcp"
        }
      ]
    },
    "storage": {
      "backup_enabled": true,
      "backup_schedule": "0 2 * * *",
      "retention_days": 30,
      "encryption_key": "{{BACKUP_ENCRYPTION_KEY}}",
      "storage_class": "enterprise-ssd",
      "volumes": [
        {
          "name": "config-volume",
          "size": "10Gi",
          "mount_path": "/etc/tools-automation"
        },
        {
          "name": "logs-volume",
          "size": "50Gi",
          "mount_path": "/var/log/tools-automation"
        },
        {
          "name": "data-volume",
          "size": "100Gi",
          "mount_path": "/var/lib/tools-automation"
        }
      ]
    },
    "monitoring": {
      "prometheus_enabled": true,
      "grafana_enabled": true,
      "alertmanager_enabled": true,
      "metrics_retention_days": 30,
      "alert_endpoints": ["{{ALERT_EMAIL}}", "{{ALERT_SLACK_WEBHOOK}}"],
      "health_check_interval": "30s",
      "log_level": "info"
    },
    "scaling": {
      "auto_scaling_enabled": true,
      "min_replicas": 3,
      "max_replicas": 10,
      "cpu_threshold": 70,
      "memory_threshold": 80,
      "scale_up_cooldown": "300s",
      "scale_down_cooldown": "600s"
    },
    "compliance": {
      "frameworks": ["SOX", "GDPR", "HIPAA", "PCI-DSS"],
      "audit_retention_days": 2555,
      "data_classification": "confidential",
      "encryption_at_rest": true,
      "encryption_in_transit": true
    }
  },
  "component_configs": {
    "rbac_system": {
      "enabled": true,
      "default_admin_user": "{{ADMIN_USER}}",
      "default_admin_password": "{{ADMIN_PASSWORD}}",
      "session_timeout": 1800,
      "max_sessions_per_user": 5
    },
    "audit_system": {
      "enabled": true,
      "log_level": "detailed",
      "alert_on_suspicious": true,
      "compliance_reports_schedule": "0 6 * * 1"
    },
    "agent_coordinator": {
      "enabled": true,
      "max_concurrent_agents": 50,
      "agent_timeout_seconds": 3600,
      "resource_limits": {
        "cpu": "2000m",
        "memory": "4Gi"
      }
    },
    "monitoring_system": {
      "enabled": true,
      "collection_interval": "15s",
      "retention_period": "30d",
      "alert_thresholds": {
        "cpu_usage": 85,
        "memory_usage": 90,
        "disk_usage": 95
      }
    }
  }
}
EOF

    log "Generated secure configuration template: $template_file"
}

# Generate deployment script template
generate_deployment_script_template() {
    local template_file="$SCRIPT_TEMPLATES_DIR/enterprise_deploy.sh"

    cat >"$template_file" <<'EOF'
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
EOF

    chmod +x "$template_file"
    log "Generated deployment script template: $template_file"
}

# Generate Docker Compose template for development/testing
generate_docker_compose_template() {
    local template_file="$DOCKER_TEMPLATES_DIR/docker-compose.enterprise.yml"

    cat >"$template_file" <<'EOF'
version: '3.8'

services:
  # RBAC System
  rbac-system:
    build:
      context: ..
      dockerfile: deployment/docker/Dockerfile.rbac
    container_name: tools-automation-rbac
    environment:
      - RBAC_CONFIG_PATH=/app/config/rbac_config
      - LOG_LEVEL=info
    volumes:
      - ./config/rbac_config:/app/config/rbac_config
      - ./logs:/app/logs
    networks:
      - internal
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "./rbac_system.sh", "status"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Audit and Compliance System
  audit-system:
    build:
      context: ..
      dockerfile: deployment/docker/Dockerfile.audit
    container_name: tools-automation-audit
    environment:
      - AUDIT_CONFIG_PATH=/app/audit_config
      - COMPLIANCE_FRAMEWORKS=SOX,GDPR,HIPAA,PCI-DSS
    volumes:
      - ./audit_config:/app/audit_config
      - ./compliance_reports:/app/compliance_reports
      - ./logs:/app/logs
    networks:
      - internal
    restart: unless-stopped
    depends_on:
      - rbac-system

  # Agent Coordinator
  agent-coordinator:
    build:
      context: ..
      dockerfile: deployment/docker/Dockerfile.agent
    container_name: tools-automation-coordinator
    environment:
      - AGENT_CONFIG_PATH=/app/config
      - MAX_CONCURRENT_AGENTS=20
      - AGENT_TIMEOUT=3600
    volumes:
      - ./config:/app/config
      - ./data:/app/data
      - ./logs:/app/logs
    networks:
      - internal
    restart: unless-stopped
    depends_on:
      - rbac-system
      - audit-system

  # Monitoring System
  monitoring-system:
    build:
      context: ..
      dockerfile: deployment/docker/Dockerfile.monitoring
    container_name: tools-automation-monitoring
    environment:
      - MONITORING_CONFIG_PATH=/app/config
      - PROMETHEUS_PORT=9090
      - GRAFANA_PORT=3000
    ports:
      - "9090:9090"
      - "3000:3000"
    volumes:
      - ./config:/app/config
      - ./data/prometheus:/app/data/prometheus
      - ./data/grafana:/app/data/grafana
      - ./logs:/app/logs
    networks:
      - internal
    restart: unless-stopped

  # PostgreSQL Database (for enterprise features)
  postgres:
    image: postgres:15-alpine
    container_name: tools-automation-postgres
    environment:
      - POSTGRES_DB=tools_automation
      - POSTGRES_USER=automation_user
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-CHANGE_THIS_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./config/postgres/init.sql:/docker-entrypoint-initdb.d/init.sql
    networks:
      - internal
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U automation_user -d tools_automation"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Redis Cache
  redis:
    image: redis:7-alpine
    container_name: tools-automation-redis
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD:-CHANGE_THIS_PASSWORD}
    volumes:
      - redis_data:/data
    networks:
      - internal
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Load Balancer
  nginx:
    image: nginx:alpine
    container_name: tools-automation-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./config/nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./config/nginx/ssl:/etc/nginx/ssl
      - ./logs/nginx:/var/log/nginx
    networks:
      - internal
      - external
    restart: unless-stopped
    depends_on:
      - agent-coordinator
      - monitoring-system

volumes:
  postgres_data:
  redis_data:

networks:
  internal:
    driver: bridge
    internal: true
  external:
    driver: bridge
EOF

    log "Generated Docker Compose template: $template_file"
}

# Generate Kubernetes deployment templates
generate_kubernetes_templates() {
    # RBAC Deployment
    cat >"$KUBERNETES_TEMPLATES_DIR/rbac-deployment.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rbac-system
  namespace: tools-automation-rbac
spec:
  replicas: 2
  selector:
    matchLabels:
      app: rbac-system
  template:
    metadata:
      labels:
        app: rbac-system
    spec:
      containers:
      - name: rbac
        image: tools-automation/rbac:latest
        ports:
        - containerPort: 8080
        env:
        - name: RBAC_CONFIG_PATH
          value: "/app/config"
        volumeMounts:
        - name: config-volume
          mountPath: /app/config
        - name: logs-volume
          mountPath: /app/logs
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: config-volume
        persistentVolumeClaim:
          claimName: rbac-config-pvc
      - name: logs-volume
        persistentVolumeClaim:
          claimName: rbac-logs-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: rbac-service
  namespace: tools-automation-rbac
spec:
  selector:
    app: rbac-system
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rbac-config-pvc
  namespace: tools-automation-rbac
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rbac-logs-pvc
  namespace: tools-automation-rbac
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF

    # Audit Deployment
    cat >"$KUBERNETES_TEMPLATES_DIR/audit-deployment.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: audit-system
  namespace: tools-automation-audit
spec:
  replicas: 2
  selector:
    matchLabels:
      app: audit-system
  template:
    metadata:
      labels:
        app: audit-system
    spec:
      containers:
      - name: audit
        image: tools-automation/audit:latest
        ports:
        - containerPort: 8081
        env:
        - name: AUDIT_CONFIG_PATH
          value: "/app/audit_config"
        volumeMounts:
        - name: audit-events-volume
          mountPath: /app/audit_config
        - name: compliance-reports-volume
          mountPath: /app/compliance_reports
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8081
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8081
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: audit-events-volume
        persistentVolumeClaim:
          claimName: audit-events-pvc
      - name: compliance-reports-volume
        persistentVolumeClaim:
          claimName: compliance-reports-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: audit-service
  namespace: tools-automation-audit
spec:
  selector:
    app: audit-system
  ports:
  - port: 80
    targetPort: 8081
  type: ClusterIP
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: audit-events-pvc
  namespace: tools-automation-audit
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: compliance-reports-pvc
  namespace: tools-automation-audit
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
EOF

    # Main Application Deployment
    cat >"$KUBERNETES_TEMPLATES_DIR/app-deployment.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: agent-coordinator
  namespace: tools-automation
spec:
  replicas: 3
  selector:
    matchLabels:
      app: agent-coordinator
  template:
    metadata:
      labels:
        app: agent-coordinator
    spec:
      containers:
      - name: coordinator
        image: tools-automation/coordinator:latest
        ports:
        - containerPort: 8082
        env:
        - name: AGENT_CONFIG_PATH
          value: "/app/config"
        - name: RBAC_SERVICE_URL
          value: "http://rbac-service.tools-automation-rbac.svc.cluster.local"
        - name: AUDIT_SERVICE_URL
          value: "http://audit-service.tools-automation-audit.svc.cluster.local"
        volumeMounts:
        - name: config-volume
          mountPath: /app/config
        - name: data-volume
          mountPath: /app/data
        resources:
          requests:
            memory: "1Gi"
            cpu: "1000m"
          limits:
            memory: "2Gi"
            cpu: "2000m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8082
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /ready
            port: 8082
          initialDelaySeconds: 10
          periodSeconds: 10
      volumes:
      - name: config-volume
        persistentVolumeClaim:
          claimName: app-config-pvc
      - name: data-volume
        persistentVolumeClaim:
          claimName: app-data-pvc
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: monitoring-system
  namespace: tools-automation
spec:
  replicas: 1
  selector:
    matchLabels:
      app: monitoring-system
  template:
    metadata:
      labels:
        app: monitoring-system
    spec:
      containers:
      - name: monitoring
        image: tools-automation/monitoring:latest
        ports:
        - containerPort: 9090
        - containerPort: 3000
        volumeMounts:
        - name: monitoring-data-volume
          mountPath: /app/data
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
      volumes:
      - name: monitoring-data-volume
        persistentVolumeClaim:
          claimName: monitoring-data-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: app-service
  namespace: tools-automation
spec:
  selector:
    app: agent-coordinator
  ports:
  - port: 80
    targetPort: 8082
  type: LoadBalancer
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-config-pvc
  namespace: tools-automation
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data-pvc
  namespace: tools-automation
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: monitoring-data-pvc
  namespace: tools-automation
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
EOF

    log "Generated Kubernetes deployment templates"
}

# Generate Dockerfile templates
generate_dockerfile_templates() {
    # RBAC Dockerfile
    cat >"$DOCKER_TEMPLATES_DIR/Dockerfile.rbac" <<'EOF'
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    jq \
    curl \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy application files
COPY rbac_system.sh ./
COPY rbac_config/ ./config/

# Make scripts executable
RUN chmod +x rbac_system.sh

# Create non-root user
RUN useradd -r -s /bin/false rbacuser && \
    chown -R rbacuser:rbacuser /app

USER rbacuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ./rbac_system.sh status || exit 1

# Expose port
EXPOSE 8080

# Start command
CMD ["./rbac_system.sh", "serve"]
EOF

    # Audit Dockerfile
    cat >"$DOCKER_TEMPLATES_DIR/Dockerfile.audit" <<'EOF'
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    jq \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy application files
COPY audit_compliance.sh ./
COPY audit_config/ ./audit_config/

# Make scripts executable
RUN chmod +x audit_compliance.sh

# Create directories
RUN mkdir -p compliance_reports logs

# Create non-root user
RUN useradd -r -s /bin/false audituser && \
    chown -R audituser:audituser /app

USER audituser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ./audit_compliance.sh query | jq empty || exit 1

# Expose port
EXPOSE 8081

# Start command
CMD ["./audit_compliance.sh", "serve"]
EOF

    # Agent Coordinator Dockerfile
    cat >"$DOCKER_TEMPLATES_DIR/Dockerfile.agent" <<'EOF'
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    jq \
    curl \
    python3 \
    python3-pip \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy application files
COPY agent_coordinator.sh ./
COPY config/ ./config/
COPY scripts/ ./scripts/

# Install Python dependencies
COPY requirements.txt ./
RUN pip3 install --no-cache-dir -r requirements.txt

# Make scripts executable
RUN chmod +x agent_coordinator.sh scripts/*.sh

# Create non-root user
RUN useradd -r -s /bin/false agentuser && \
    chown -R agentuser:agentuser /app

USER agentuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8082/health || exit 1

# Expose port
EXPOSE 8082

# Start command
CMD ["./agent_coordinator.sh", "serve"]
EOF

    # Monitoring Dockerfile
    cat >"$DOCKER_TEMPLATES_DIR/Dockerfile.monitoring" <<'EOF'
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    jq \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install Prometheus
RUN wget -q https://github.com/prometheus/prometheus/releases/download/v2.40.0/prometheus-2.40.0.linux-amd64.tar.gz && \
    tar xzf prometheus-2.40.0.linux-amd64.tar.gz && \
    mv prometheus-2.40.0.linux-amd64 /opt/prometheus && \
    rm prometheus-2.40.0.linux-amd64.tar.gz

# Install Grafana
RUN wget -q https://dl.grafana.com/oss/release/grafana-9.3.0.linux-amd64.tar.gz && \
    tar xzf grafana-9.3.0.linux-amd64.tar.gz && \
    mv grafana-9.3.0 /opt/grafana && \
    rm grafana-9.3.0.linux-amd64.tar.gz

# Create app directory
WORKDIR /app

# Copy configuration files
COPY config/monitoring/ ./config/

# Create non-root user
RUN useradd -r -s /bin/false monitoringuser && \
    chown -R monitoringuser:monitoringuser /app /opt/prometheus /opt/grafana

USER monitoringuser

# Expose ports
EXPOSE 9090 3000

# Start command
CMD ["/app/scripts/start_monitoring.sh"]
EOF

    log "Generated Dockerfile templates"
}

# Generate deployment documentation
generate_deployment_docs() {
    local docs_file="$DEPLOYMENT_TEMPLATES_DIR/README.md"

    cat >"$docs_file" <<'EOF'
# Enterprise Deployment Templates

This directory contains comprehensive deployment templates for the tools-automation system in enterprise environments.

## Directory Structure

```
deployment_templates/
├── config/                    # Configuration templates
│   └── enterprise_config_template.json
├── scripts/                   # Deployment scripts
│   └── enterprise_deploy.sh
├── docker/                    # Docker-related files
│   ├── docker-compose.enterprise.yml
│   ├── Dockerfile.rbac
│   ├── Dockerfile.audit
│   ├── Dockerfile.agent
│   └── Dockerfile.monitoring
├── kubernetes/                # Kubernetes manifests
│   ├── rbac-deployment.yaml
│   ├── audit-deployment.yaml
│   └── app-deployment.yaml
└── README.md                  # This file
```

## Deployment Options

### 1. Docker Compose (Development/Testing)

For development and testing environments:

```bash
cd deployment_templates/docker
docker-compose -f docker-compose.enterprise.yml up -d
```

### 2. Kubernetes (Production)

For production enterprise deployments:

```bash
# Deploy RBAC system
kubectl apply -f kubernetes/rbac-deployment.yaml

# Deploy audit system
kubectl apply -f kubernetes/audit-deployment.yaml

# Deploy main application
kubectl apply -f kubernetes/app-deployment.yaml
```

### 3. Automated Enterprise Deployment

For full enterprise deployment with security setup:

```bash
# Set environment variables
export DEPLOYMENT_ENV=production
export REGION=us-east-1
export CLUSTER_NAME=my-cluster
export ADMIN_USER=admin
export ADMIN_PASSWORD=secure_password
export BACKUP_ENCRYPTION_KEY=encryption_key

# Run deployment script
./scripts/enterprise_deploy.sh
```

## Configuration

### Enterprise Configuration Template

The `config/enterprise_config_template.json` contains all enterprise settings:

- **Security**: RBAC, encryption, TLS, password policies
- **Networking**: Internal/external networks, firewall rules, load balancing
- **Storage**: Backup schedules, retention policies, volume configurations
- **Monitoring**: Prometheus, Grafana, alerting endpoints
- **Scaling**: Auto-scaling rules, resource limits
- **Compliance**: SOX, GDPR, HIPAA, PCI-DSS requirements

### Environment Variables

Required environment variables for deployment:

- `DEPLOYMENT_ENV`: Environment name (development/staging/production)
- `REGION`: Deployment region
- `CLUSTER_NAME`: Kubernetes cluster name
- `ADMIN_USER`: Default admin username
- `ADMIN_PASSWORD`: Default admin password
- `BACKUP_ENCRYPTION_KEY`: Encryption key for backups
- `POSTGRES_PASSWORD`: Database password
- `REDIS_PASSWORD`: Redis password

## Security Features

### RBAC (Role-Based Access Control)
- User authentication and authorization
- Session management with timeouts
- Permission-based access control
- Audit logging of all access attempts

### Audit and Compliance
- Comprehensive audit trail logging
- Compliance reporting for SOX, GDPR, HIPAA, PCI-DSS
- Automated security alerting
- Data retention policies

### Network Security
- Internal network isolation
- TLS 1.3 encryption
- Certificate-based authentication
- Firewall rule management

### Data Protection
- Encryption at rest and in transit
- Automated backup with encryption
- Data classification and handling
- Secure key management

## Monitoring and Observability

### Metrics Collection
- Prometheus for metrics collection
- Grafana for visualization
- Custom dashboards for system monitoring
- Alert manager for incident response

### Health Checks
- Application health endpoints
- Database connectivity checks
- Service dependency monitoring
- Automated recovery procedures

## Scaling and Performance

### Auto-scaling
- Horizontal pod autoscaling
- CPU/memory-based scaling triggers
- Configurable scaling limits
- Cooldown periods to prevent thrashing

### Resource Management
- Resource requests and limits
- Quality of Service guarantees
- Resource quota management
- Performance monitoring

## Compliance and Governance

### Supported Frameworks
- **SOX**: Financial reporting compliance
- **GDPR**: Data protection and privacy
- **HIPAA**: Healthcare data protection
- **PCI-DSS**: Payment card industry standards

### Audit Requirements
- 2555-day retention for SOX/GDPR/HIPAA
- 365-day retention for PCI-DSS
- Automated compliance reporting
- Security incident tracking

## Backup and Recovery

### Automated Backups
- Daily configuration backups
- Transaction log backups
- Encrypted backup storage
- Point-in-time recovery

### Disaster Recovery
- Multi-region deployment support
- Automated failover procedures
- Data replication strategies
- Recovery time objectives (RTO) and recovery point objectives (RPO)

## Troubleshooting

### Common Issues

1. **RBAC Authentication Failures**
   - Check user credentials in rbac_config/users.json
   - Verify session timeouts
   - Review audit logs for failed attempts

2. **Audit System Not Starting**
   - Check audit_config/audit_config.json
   - Verify file permissions
   - Check disk space for audit logs

3. **Kubernetes Deployment Failures**
   - Check cluster resources
   - Verify persistent volume claims
   - Review pod logs: `kubectl logs <pod-name>`

4. **Monitoring Not Collecting Metrics**
   - Check Prometheus configuration
   - Verify service discovery
   - Review Grafana data sources

### Logs and Debugging

All components write logs to:
- `/var/log/tools-automation/` (production)
- `./logs/` (development)

Enable debug logging by setting `LOG_LEVEL=debug` in environment variables.

## Support and Maintenance

### Regular Maintenance Tasks

1. **Certificate Rotation**: Rotate TLS certificates every 90 days
2. **Key Rotation**: Rotate encryption keys annually
3. **Backup Verification**: Test backup restoration monthly
4. **Security Updates**: Apply security patches promptly
5. **Compliance Audits**: Run compliance reports quarterly

### Monitoring Alerts

Configure alerts for:
- Authentication failures (>5 per hour)
- Authorization denials (>10 per hour)
- System resource usage (>90%)
- Service availability (downtime >5 minutes)
- Security incidents (any occurrence)

## Contributing

When modifying deployment templates:

1. Test in development environment first
2. Update documentation for any configuration changes
3. Ensure backward compatibility
4. Validate security implications
5. Update compliance mappings if needed
EOF

    log "Generated deployment documentation: $docs_file"
}

# CLI interface
case "${1:-help}" in
"generate-all")
    generate_secure_config_template
    generate_deployment_script_template
    generate_docker_compose_template
    generate_kubernetes_templates
    generate_dockerfile_templates
    generate_deployment_docs
    log "All enterprise deployment templates generated successfully"
    ;;
"config")
    generate_secure_config_template
    ;;
"script")
    generate_deployment_script_template
    ;;
"docker")
    generate_docker_compose_template
    generate_dockerfile_templates
    ;;
"kubernetes")
    generate_kubernetes_templates
    ;;
"docs")
    generate_deployment_docs
    ;;
"help" | *)
    echo "Enterprise Deployment Templates Generator v1.0"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  generate-all    - Generate all deployment templates"
    echo "  config          - Generate configuration template"
    echo "  script          - Generate deployment script"
    echo "  docker          - Generate Docker templates"
    echo "  kubernetes      - Generate Kubernetes manifests"
    echo "  docs            - Generate documentation"
    echo "  help            - Show this help"
    echo ""
    echo "Run 'generate-all' to create complete enterprise deployment package"
    ;;
esac

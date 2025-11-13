---
title: Configuration Reference
description: Complete reference for all configuration options and settings
author: Tools Automation Team
date: 2025-11-12
---

# ⚙️ Configuration Reference

**Complete reference for all configuration options, environment variables, and settings in the Tools Automation system.**

## 📋 Configuration Overview

The Tools Automation system uses a hierarchical configuration system with multiple sources:

1. **Environment Variables** (highest priority)
2. **YAML Configuration Files** (`config/automation_config.yaml`)
3. **Default Values** (lowest priority)

## 🔧 Core Configuration

### MCP Server Configuration

```yaml
mcp_server:
  host: "0.0.0.0" # Server bind address
  port: 5005 # Server port
  debug: false # Debug mode
  workers: 4 # Number of worker processes
  timeout: 30 # Request timeout (seconds)
  max_request_size: "10MB" # Maximum request size
  cors_origins: ["*"] # CORS allowed origins

  # Rate limiting
  rate_limit:
    enabled: true
    requests_per_minute: 50 # Per IP rate limit
    burst_limit: 10 # Burst allowance

  # Authentication
  auth:
    enabled: false
    provider: "basic" # basic, oauth2, jwt
    secret_key: "change-me-in-prod" # Secret key for sessions

  # SSL/TLS
  ssl:
    enabled: false
    cert_file: "/path/to/cert.pem"
    key_file: "/path/to/key.pem"
```

**Environment Variables:**

```bash
MCP_HOST=0.0.0.0
MCP_PORT=5005
MCP_DEBUG=false
MCP_WORKERS=4
MCP_TIMEOUT=30
MCP_RATE_LIMIT_REQUESTS=50
MCP_AUTH_ENABLED=false
MCP_SSL_ENABLED=false
```

### Agent Orchestrator Configuration

```yaml
agent_orchestrator:
  enabled: true # Enable task orchestration
  max_parallel_tasks: 3 # Maximum concurrent tasks
  task_timeout: 300 # Task timeout (seconds)
  retry_attempts: 3 # Task retry attempts
  retry_delay: 60 # Delay between retries (seconds)

  # Agent capabilities mapping
  agent_capabilities:
    testing_agent.sh: ["unit_tests", "integration_tests", "e2e_tests"]
    agent_build.sh: ["build", "compile", "package"]
    agent_debug.sh: ["debug", "logging", "tracing"]
    agent_codegen.sh: ["code_generation", "refactoring"]

  # Agent priority (higher = more preferred)
  agent_priority:
    testing_agent.sh: 10
    agent_build.sh: 8
    agent_debug.sh: 6
    agent_codegen.sh: 5

  # Health monitoring
  health_check:
    interval: 60 # Health check interval (seconds)
    timeout: 10 # Health check timeout (seconds)
    unhealthy_threshold: 3 # Failures before marking unhealthy
```

**Environment Variables:**

```bash
AGENT_ORCHESTRATOR_ENABLED=true
MAX_PARALLEL_TASKS=3
TASK_TIMEOUT=300
AGENT_HEALTH_CHECK_INTERVAL=60
```

### Task Queue Configuration

```yaml
task_queue:
  persistence:
    enabled: true
    file: "task_queue.json" # Queue persistence file
    backup_interval: 300 # Backup interval (seconds)

  # Queue limits
  limits:
    max_queued_tasks: 1000 # Maximum queued tasks
    max_completed_history: 5000 # Maximum completed task history
    max_failed_history: 1000 # Maximum failed task history

  # Task prioritization
  priority:
    critical: 10 # Critical priority
    high: 7 # High priority
    normal: 5 # Normal priority
    low: 3 # Low priority

  # Task types and requirements
  task_requirements:
    unit_tests: "testing_agent.sh"
    integration_tests: "testing_agent.sh"
    build: "agent_build.sh"
    debug: "agent_debug.sh"
    code_generation: "agent_codegen.sh"
```

### Monitoring Configuration

```yaml
monitoring:
  enabled: true

  # Prometheus metrics
  prometheus:
    enabled: true
    port: 8080 # Metrics port
    path: "/metrics" # Metrics endpoint path

  # Grafana dashboards
  grafana:
    enabled: true
    url: "http://localhost:3000" # Grafana URL
    api_key: "" # Grafana API key (optional)

  # Uptime Kuma
  uptime_kuma:
    enabled: true
    url: "http://localhost:3001" # Uptime Kuma URL

  # Alerting
  alerting:
    enabled: true
    slack_webhook: "" # Slack webhook URL
    email_smtp: # Email SMTP configuration
      server: "smtp.gmail.com"
      port: 587
      username: ""
      password: ""
      use_tls: true

  # Metrics collection
  metrics:
    collection_interval: 30 # Metrics collection interval (seconds)
    retention_days: 90 # Metrics retention (days)

    # System metrics
    system:
      cpu: true
      memory: true
      disk: true
      network: true

    # Application metrics
    application:
      requests_total: true
      request_duration: true
      active_connections: true
      error_rate: true
```

**Environment Variables:**

```bash
MONITORING_ENABLED=true
PROMETHEUS_PORT=8080
GRAFANA_URL=http://localhost:3000
UPTIME_KUMA_URL=http://localhost:3001
METRICS_COLLECTION_INTERVAL=30
```

## 🤖 Agent Configuration

### Agent Base Configuration

```yaml
agents:
  base_config:
    log_level: "INFO" # Agent log level (DEBUG, INFO, WARNING, ERROR)
    log_file: "agents/{agent_name}.log" # Log file path
    pid_file: "agents/{agent_name}.pid" # PID file path
    working_directory: "." # Working directory

    # Resource limits
    resource_limits:
      cpu_percent: 80 # CPU usage limit (%)
      memory_mb: 512 # Memory limit (MB)
      timeout: 3600 # Execution timeout (seconds)

    # Health monitoring
    health:
      enabled: true
      check_interval: 30 # Health check interval (seconds)
      failure_threshold: 3 # Failures before restart

  # Specific agent configurations
  testing_agent:
    enabled: true
    test_frameworks: ["pytest", "unittest", "jest"]
    coverage_target: 85
    parallel_workers: 4

  build_agent:
    enabled: true
    build_tools: ["make", "cmake", "gradle", "maven"]
    artifact_storage: "/tmp/artifacts"

  debug_agent:
    enabled: true
    debug_tools: ["gdb", "lldb", "pdb"]
    log_levels: ["DEBUG", "INFO", "WARNING", "ERROR"]

  codegen_agent:
    enabled: true
    ai_providers: ["ollama", "openai", "anthropic"]
    code_languages: ["python", "javascript", "java", "go"]
```

### Agent Environment Variables

```bash
# Global agent settings
AGENT_LOG_LEVEL=INFO
AGENT_TIMEOUT=3600
AGENT_HEALTH_CHECK_INTERVAL=30

# Specific agent settings
TESTING_AGENT_ENABLED=true
TESTING_AGENT_COVERAGE_TARGET=85
BUILD_AGENT_ENABLED=true
DEBUG_AGENT_ENABLED=true
CODEGEN_AGENT_ENABLED=true
```

## 🔗 Integration Configuration

### AI/ML Integration

```yaml
ai_integration:
  enabled: true

  # Ollama configuration
  ollama:
    enabled: true
    base_url: "http://localhost:11434"
    default_model: "llama2:latest"
    timeout: 120
    retry_attempts: 3

  # OpenAI configuration
  openai:
    enabled: false
    api_key: "" # OpenAI API key
    base_url: "https://api.openai.com/v1"
    default_model: "gpt-4"
    timeout: 60

  # Anthropic configuration
  anthropic:
    enabled: false
    api_key: "" # Anthropic API key
    base_url: "https://api.anthropic.com"
    default_model: "claude-3-sonnet-20240229"
    timeout: 60

  # Model caching
  caching:
    enabled: true
    cache_dir: "/tmp/ai_cache"
    max_cache_size: "10GB"
    ttl_hours: 24

  # Rate limiting
  rate_limiting:
    requests_per_minute: 10
    burst_limit: 5
```

**Environment Variables:**

```bash
AI_INTEGRATION_ENABLED=true
OLLAMA_ENABLED=true
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_DEFAULT_MODEL=llama2:latest
OPENAI_ENABLED=false
ANTHROPIC_ENABLED=false
AI_CACHING_ENABLED=true
```

### Database Configuration

```yaml
database:
  # Redis configuration
  redis:
    enabled: true
    host: "localhost"
    port: 6379
    db: 0
    password: "" # Redis password (optional)
    ssl: false # Use SSL connection

    # Connection pool
    pool:
      max_connections: 20
      retry_on_timeout: true
      socket_timeout: 5
      socket_connect_timeout: 5

  # PostgreSQL configuration (future)
  postgresql:
    enabled: false
    host: "localhost"
    port: 5432
    database: "tools_automation"
    username: "tools_user"
    password: ""
    ssl_mode: "require"

  # SQLite fallback
  sqlite:
    enabled: true
    database_file: "data/tools_automation.db"
    journal_mode: "WAL"
    synchronous: "NORMAL"
```

**Environment Variables:**

```bash
REDIS_ENABLED=true
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_DB=0
POSTGRESQL_ENABLED=false
SQLITE_ENABLED=true
```

### External Service Integration

```yaml
external_services:
  # GitHub integration
  github:
    enabled: true
    token: "" # GitHub personal access token
    api_url: "https://api.github.com"
    webhook_secret: "" # Webhook secret for validation

  # Slack integration
  slack:
    enabled: false
    bot_token: "" # Slack bot token
    signing_secret: "" # Slack signing secret
    default_channel: "#automation"

  # Email integration
  email:
    enabled: false
    smtp:
      server: "smtp.gmail.com"
      port: 587
      username: ""
      password: ""
      use_tls: true
      use_ssl: false

  # Webhook endpoints
  webhooks:
    enabled: false
    endpoints:
      - url: "https://example.com/webhook"
        events: ["task_completed", "agent_failed"]
        secret: "webhook-secret"
```

## 🐳 Docker Configuration

### Docker Compose Configuration

```yaml
docker:
  compose:
    version: "3.8"
    services:
      # MCP Server
      mcp_server:
        image: "tools-automation/mcp-server:latest"
        ports:
          - "${MCP_PORT:-5005}:5005"
        environment:
          - MCP_DEBUG=${MCP_DEBUG:-false}
          - REDIS_URL=redis://redis:6379
        depends_on:
          - redis
        restart: unless-stopped

      # Redis
      redis:
        image: "redis:7-alpine"
        ports:
          - "6379:6379"
        volumes:
          - redis_data:/data
        restart: unless-stopped

      # Prometheus
      prometheus:
        image: "prom/prometheus:latest"
        ports:
          - "9090:9090"
        volumes:
          - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
          - prometheus_data:/prometheus
        restart: unless-stopped

      # Grafana
      grafana:
        image: "grafana/grafana:latest"
        ports:
          - "3000:3000"
        environment:
          - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-admin}
        volumes:
          - grafana_data:/var/lib/grafana
        restart: unless-stopped

volumes:
  redis_data:
  prometheus_data:
  grafana_data:
```

### Docker Environment Variables

```bash
# Docker settings
DOCKER_COMPOSE_FILE=docker-compose.yml
MCP_DOCKER_IMAGE=tools-automation/mcp-server:latest
REDIS_DOCKER_IMAGE=redis:7-alpine
PROMETHEUS_DOCKER_IMAGE=prom/prometheus:latest
GRAFANA_DOCKER_IMAGE=grafana/grafana:latest

# Container resource limits
MCP_CONTAINER_CPU=1.0
MCP_CONTAINER_MEMORY=512m
REDIS_CONTAINER_MEMORY=256m
GRAFANA_CONTAINER_MEMORY=256m
```

## 🔐 Security Configuration

### Authentication & Authorization

```yaml
security:
  # JWT configuration
  jwt:
    enabled: false
    secret_key: "change-me-in-production"
    algorithm: "HS256"
    expiration_hours: 24

  # OAuth2 configuration
  oauth2:
    enabled: false
    provider: "github" # github, google, azure
    client_id: ""
    client_secret: ""
    redirect_uri: "http://localhost:5005/auth/callback"

  # API key authentication
  api_keys:
    enabled: false
    keys:
      - name: "admin-key"
        key: "admin-api-key-here"
        permissions: ["read", "write", "admin"]

  # Role-based access control
  rbac:
    enabled: false
    roles:
      admin:
        permissions: ["*"]
      user:
        permissions: ["read", "write"]
      viewer:
        permissions: ["read"]

  # Security headers
  headers:
    enabled: true
    hsts: true # HTTP Strict Transport Security
    csp: "default-src 'self'" # Content Security Policy
    x_frame_options: "DENY" # Clickjacking protection
    x_content_type_options: "nosniff" # MIME type sniffing protection
```

### Encryption Configuration

```yaml
encryption:
  # Data at rest
  data_at_rest:
    enabled: true
    algorithm: "AES-256-GCM"
    key_rotation_days: 90

  # Data in transit
  data_in_transit:
    enabled: true
    min_tls_version: "1.2"
    cipher_suites:
      - "ECDHE-RSA-AES256-GCM-SHA384"
      - "ECDHE-RSA-AES128-GCM-SHA256"

  # Secrets management
  secrets:
    provider: "local" # local, vault, aws-secrets, azure-keyvault
    local:
      key_file: "config/master.key"
    vault:
      url: "https://vault.example.com"
      token: ""
    aws:
      region: "us-east-1"
      key_id: ""
```

## 📊 Logging Configuration

### Application Logging

```yaml
logging:
  # Global logging configuration
  global:
    level: "INFO" # DEBUG, INFO, WARNING, ERROR, CRITICAL
    format: "%(asctime)s [%(levelname)s] %(name)s: %(message)s"
    date_format: "%Y-%m-%d %H:%M:%S"

  # Log handlers
  handlers:
    console:
      enabled: true
      level: "INFO"
      format: "%(levelname)s: %(message)s"

    file:
      enabled: true
      level: "DEBUG"
      filename: "logs/tools_automation.log"
      max_bytes: 10485760 # 10MB
      backup_count: 5

    syslog:
      enabled: false
      level: "WARNING"
      address: "/dev/log"

  # Module-specific logging
  loggers:
    mcp_server:
      level: "DEBUG"
      handlers: ["console", "file"]

    agent_orchestrator:
      level: "INFO"
      handlers: ["file"]

    ai_integration:
      level: "WARNING"
      handlers: ["console", "file"]

  # Log rotation
  rotation:
    enabled: true
    when: "midnight" # daily rotation
    interval: 1
    backup_count: 30

  # External logging
  external:
    enabled: false
    provider: "datadog" # datadog, logstash, cloudwatch
    datadog:
      api_key: ""
      app_key: ""
      tags: ["env:development", "service:tools-automation"]
```

### Audit Logging

```yaml
audit:
  enabled: true
  log_file: "logs/audit.log"
  max_file_size: "100MB"
  retention_days: 365

  # Events to audit
  events:
    authentication: true # Login/logout events
    authorization: true # Permission checks
    api_calls: true # All API requests
    task_operations: true # Task creation/modification
    agent_operations: true # Agent start/stop/restart
    configuration_changes: true # Config file modifications

  # Audit format
  format:
    json: true # JSON format for parsing
    include_request_body: false # Include request bodies (privacy)
    include_response_body: false # Include response bodies (privacy)
    include_headers: true # Include HTTP headers
    include_query_params: true # Include query parameters
```

## 🔄 Environment Variables Reference

### Complete Environment Variables List

```bash
# Core System
DEBUG=false
LOG_LEVEL=INFO
CONFIG_FILE=config/automation_config.yaml

# MCP Server
MCP_HOST=0.0.0.0
MCP_PORT=5005
MCP_DEBUG=false
MCP_WORKERS=4
MCP_TIMEOUT=30
MCP_RATE_LIMIT_REQUESTS=50
MCP_AUTH_ENABLED=false
MCP_SSL_ENABLED=false

# Agent Orchestrator
AGENT_ORCHESTRATOR_ENABLED=true
MAX_PARALLEL_TASKS=3
TASK_TIMEOUT=300
AGENT_HEALTH_CHECK_INTERVAL=60

# Monitoring
MONITORING_ENABLED=true
PROMETHEUS_PORT=8080
GRAFANA_URL=http://localhost:3000
UPTIME_KUMA_URL=http://localhost:3001
METRICS_COLLECTION_INTERVAL=30

# AI Integration
AI_INTEGRATION_ENABLED=true
OLLAMA_ENABLED=true
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_DEFAULT_MODEL=llama2:latest
OPENAI_ENABLED=false
ANTHROPIC_ENABLED=false
AI_CACHING_ENABLED=true

# Database
REDIS_ENABLED=true
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_DB=0
POSTGRESQL_ENABLED=false
SQLITE_ENABLED=true

# Security
JWT_ENABLED=false
OAUTH2_ENABLED=false
API_KEYS_ENABLED=false
RBAC_ENABLED=false

# Docker
DOCKER_COMPOSE_FILE=docker-compose.yml
MCP_CONTAINER_CPU=1.0
MCP_CONTAINER_MEMORY=512m

# External Services
GITHUB_TOKEN=
SLACK_BOT_TOKEN=
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
```

## 📝 Configuration Validation

### Configuration Schema Validation

The system validates configuration files against a JSON schema:

```bash
# Validate configuration file
python3 -c "
import yaml
import jsonschema
import requests

# Load configuration
with open('config/automation_config.yaml') as f:
    config = yaml.safe_load(f)

# Load schema
schema_url = 'https://raw.githubusercontent.com/dboone323/tools-automation/main/config/schema.json'
schema = requests.get(schema_url).json()

# Validate
jsonschema.validate(config, schema)
print('Configuration is valid!')
"
```

### Configuration Testing

```bash
# Test configuration loading
python3 -c "
from config import load_config
config = load_config()
print('Configuration loaded successfully')
print(f'MCP Port: {config.mcp_server.port}')
print(f'Monitoring: {config.monitoring.enabled}')
"

# Test environment variable overrides
DEBUG=1 python3 -c "
from config import load_config
config = load_config()
print(f'Debug mode: {config.debug}')
"
```

## 🚀 Configuration Examples

### Development Configuration

```yaml
# config/development.yaml
mcp_server:
  debug: true
  port: 5005
  rate_limit:
    requests_per_minute: 100

monitoring:
  enabled: true

ai_integration:
  ollama:
    enabled: true

logging:
  global:
    level: "DEBUG"
```

### Production Configuration

```yaml
# config/production.yaml
mcp_server:
  host: "0.0.0.0"
  port: 5005
  workers: 8
  ssl:
    enabled: true
    cert_file: "/etc/ssl/certs/mcp.crt"
    key_file: "/etc/ssl/private/mcp.key"

security:
  jwt:
    enabled: true
    secret_key: "${JWT_SECRET}"

monitoring:
  alerting:
    enabled: true
    slack_webhook: "${SLACK_WEBHOOK}"

database:
  redis:
    password: "${REDIS_PASSWORD}"
  postgresql:
    enabled: true
    host: "${DB_HOST}"
    password: "${DB_PASSWORD}"
```

### CI/CD Configuration

```yaml
# config/ci.yaml
mcp_server:
  debug: true
  rate_limit:
    enabled: false

testing:
  parallel_workers: 8
  coverage_target: 95

monitoring:
  enabled: false

ai_integration:
  enabled: false
```

---

## 📞 Configuration Support

### Configuration Validation

```bash
# Validate configuration
./validate_config.sh

# Check for deprecated options
./check_deprecated_config.sh

# Generate configuration documentation
./generate_config_docs.sh
```

### Configuration Migration

```bash
# Migrate from old configuration format
./migrate_config.sh old_config.yaml new_config.yaml

# Backup current configuration
./backup_config.sh

# Restore configuration
./restore_config.sh backup.tar.gz
```

### Getting Help

- **Configuration Issues**: Check the [troubleshooting guide](../reference/troubleshooting.md)
- **Schema Reference**: View the [JSON schema](https://github.com/dboone323/tools-automation/blob/main/config/schema.json)
- **Examples**: Browse [configuration examples](https://github.com/dboone323/tools-automation/tree/main/config/examples)

---

_Built with ❤️ for flexible configuration_

**Last updated: November 12, 2025**</content>
<parameter name="filePath">/Users/danielstevens/Desktop/github-projects/tools-automation/docs/reference/configuration.md

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

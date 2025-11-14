# Hybrid Autonomy System - Cloud Deployment

This directory contains the complete cloud deployment setup for the Hybrid Autonomy System, including Docker containerization and AWS ECS configuration.

## Architecture Overview

The system is containerized using Docker with the following components:

- **Python MCP Server**: Core autonomous intelligence engine
- **Dashboard Server**: Web interface for monitoring and control
- **Health Monitor**: System health checking and alerting
- **Nginx**: Reverse proxy and load balancer
- **Supervisor**: Process management and orchestration

## Local Development

### Using Docker Compose

For local testing and development:

```bash
# Build and start all services
docker-compose up --build

# Run in background
docker-compose up -d --build

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### Direct Docker Build

```bash
# Build the image
docker build -t autonomy-system:latest .

# Run the container
docker run -p 8000:80 -p 3000:3000 autonomy-system:latest
```

## AWS ECS Deployment

### Prerequisites

1. **AWS CLI configured** with appropriate permissions
2. **ECR repository** created (or will be created by deployment script)
3. **ECS cluster** and **service** created
4. **EFS file system** for persistent storage (optional)

### Deployment Steps

1. **Set environment variables**:

   ```bash
   export AWS_ACCOUNT_ID=your-account-id
   export AWS_REGION=us-east-1
   ```

2. **Make deployment script executable**:

   ```bash
   chmod +x deploy-to-ecs.sh
   ```

3. **Run deployment**:
   ```bash
   ./deploy-to-ecs.sh
   ```

The script will:

- Build and push the Docker image to ECR
- Update the ECS task definition
- Deploy the new version to ECS
- Wait for the service to stabilize

### Manual Deployment

If you prefer manual control:

```bash
# Build and push image
docker build -t autonomy-system:latest .
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
docker tag autonomy-system:latest $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/autonomy-system:latest
docker push $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/autonomy-system:latest

# Update task definition
aws ecs register-task-definition --cli-input-json file://ecs-task-definition.json

# Update service
aws ecs update-service --cluster autonomy-system-cluster --service autonomy-system-service --task-definition autonomy-system-task --force-new-deployment
```

## Configuration

### Environment Variables

- `AUTONOMOUS_MODE`: Set to `cloud` for cloud deployment, `container` for local Docker
- `LOG_LEVEL`: Logging level (DEBUG, INFO, WARNING, ERROR)
- `PYTHONPATH`: Python path (usually `/app`)

### Persistent Storage

The ECS task definition includes EFS mount points for:

- `/app/logs`: Application logs
- `/app/config`: Configuration files
- `/app/agents`: Agent data and state
- `/app/monitoring`: Monitoring data and reports

## Health Checks

The system includes comprehensive health monitoring:

- **Container Health**: Built-in Docker health check every 30 seconds
- **Application Health**: HTTP endpoint at `/health` (port 8080)
- **Process Monitoring**: Supervisor ensures all services are running
- **Resource Monitoring**: Disk space and memory usage tracking

## Monitoring and Logs

### CloudWatch Logs

All application logs are sent to CloudWatch:

- Log Group: `/ecs/autonomy-system`
- Log Streams: `ecs/autonomy-system-service`

### Log Files

Internal log files (available via EFS):

- `/app/logs/supervisord.log`: Process manager logs
- `/app/logs/autonomous.log`: Main application logs
- `/app/logs/health_monitor.log`: Health monitoring logs
- `/app/logs/dashboard_server.log`: Web server logs

## Scaling

The system is designed for horizontal scaling:

- **ECS Service Auto Scaling**: Based on CPU/memory utilization
- **Load Balancing**: ALB distributes traffic across tasks
- **Health Checks**: Automatic replacement of unhealthy instances

## Security

- **VPC**: Services run in private subnets
- **Security Groups**: Minimal required ports open
- **IAM Roles**: Least-privilege access for ECS tasks
- **Secrets Management**: Use AWS Secrets Manager for sensitive data

## Troubleshooting

### Common Issues

1. **Service won't start**: Check CloudWatch logs for error messages
2. **Health check failures**: Verify all required processes are running
3. **Storage issues**: Check EFS mount points and permissions

### Debugging Commands

```bash
# Check service status
aws ecs describe-services --cluster autonomy-system-cluster --services autonomy-system-service

# View recent deployments
aws ecs list-task-definitions --family-prefix autonomy-system-task --sort DESC

# Check task logs
aws logs tail /ecs/autonomy-system --follow
```

## Cost Optimization

- **Fargate Spot**: Use spot instances for cost savings
- **Auto Scaling**: Scale down during low-usage periods
- **EFS Lifecycle**: Move old logs to cheaper storage classes

## Future Enhancements

- **CI/CD Pipeline**: Automated deployments with GitHub Actions
- **Blue-Green Deployments**: Zero-downtime updates
- **Multi-Region**: Cross-region failover capability
- **Monitoring Dashboard**: CloudWatch dashboards for metrics

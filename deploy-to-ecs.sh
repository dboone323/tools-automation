#!/bin/bash

# AWS ECS Deployment Script for Autonomous System
# This script deploys the containerized autonomy system to AWS ECS

set -e

# Configuration
CLUSTER_NAME="autonomy-system-cluster"
SERVICE_NAME="autonomy-system-service"
TASK_DEFINITION_FAMILY="autonomy-system-task"
ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
REGION="${AWS_REGION:-us-east-1}"
REPO_NAME="autonomy-system"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."

    if ! command -v aws &>/dev/null; then
        error "AWS CLI is not installed. Please install it first."
        exit 1
    fi

    if ! command -v docker &>/dev/null; then
        error "Docker is not installed. Please install it first."
        exit 1
    fi

    if [ -z "$ACCOUNT_ID" ]; then
        error "AWS Account ID not found. Please set AWS_ACCOUNT_ID or configure AWS CLI."
        exit 1
    fi

    log "Prerequisites check passed."
}

# Build and push Docker image
build_and_push_image() {
    log "Building and pushing Docker image..."

    # Build the image
    docker build -t $REPO_NAME:latest .

    # Tag for ECR
    ECR_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:latest"
    docker tag $REPO_NAME:latest $ECR_URI

    # Login to ECR
    aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

    # Create ECR repository if it doesn't exist
    aws ecr describe-repositories --repository-names $REPO_NAME --region $REGION 2>/dev/null ||
        aws ecr create-repository --repository-name $REPO_NAME --region $REGION

    # Push the image
    docker push $ECR_URI

    log "Docker image pushed to ECR: $ECR_URI"
}

# Update task definition
update_task_definition() {
    log "Updating ECS task definition..."

    # Replace ACCOUNT_ID placeholder in task definition
    sed -i.bak "s/ACCOUNT_ID/$ACCOUNT_ID/g" ecs-task-definition.json

    # Register new task definition
    TASK_DEFINITION_ARN=$(aws ecs register-task-definition \
        --cli-input-json file://ecs-task-definition.json \
        --region $REGION \
        --query 'taskDefinition.taskDefinitionArn' \
        --output text)

    log "Task definition updated: $TASK_DEFINITION_ARN"
}

# Deploy to ECS
deploy_to_ecs() {
    log "Deploying to ECS..."

    # Update service with new task definition
    aws ecs update-service \
        --cluster $CLUSTER_NAME \
        --service $SERVICE_NAME \
        --task-definition $TASK_DEFINITION_FAMILY \
        --region $REGION \
        --force-new-deployment

    log "Deployment initiated. Waiting for service to stabilize..."

    # Wait for service to stabilize
    aws ecs wait services-stable \
        --cluster $CLUSTER_NAME \
        --services $SERVICE_NAME \
        --region $REGION

    log "Deployment completed successfully!"
}

# Get service endpoint
get_service_endpoint() {
    log "Getting service endpoint..."

    # Get load balancer DNS name
    LB_DNS=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services $SERVICE_NAME \
        --region $REGION \
        --query 'services[0].loadBalancers[0].loadBalancerArn' \
        --output text)

    if [ "$LB_DNS" != "None" ] && [ -n "$LB_DNS" ]; then
        LB_DNS=$(aws elbv2 describe-load-balancers \
            --load-balancer-arns $LB_DNS \
            --region $REGION \
            --query 'LoadBalancers[0].DNSName' \
            --output text)

        log "Service endpoint: http://$LB_DNS"
    else
        warn "No load balancer found. Service may be accessible via ECS service discovery or direct IP."
    fi
}

# Main deployment function
main() {
    log "Starting AWS ECS deployment for Autonomous System..."

    check_prerequisites
    build_and_push_image
    update_task_definition
    deploy_to_ecs
    get_service_endpoint

    log "Autonomous System deployment completed!"
    log "Monitor the service at: https://$REGION.console.aws.amazon.com/ecs/home?region=$REGION#/clusters/$CLUSTER_NAME/services/$SERVICE_NAME"
}

# Run main function
main "$@"

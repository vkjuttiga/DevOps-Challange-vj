#!/bin/bash
# Rollback script for Jenkins pipeline
# Usage: ./rollback.sh <environment> <version>

set -euo pipefail

ENVIRONMENT=${1:-dev}
VERSION=${2:-}
AWS_REGION=${AWS_REGION:-ap-south-1}
CLUSTER_NAME="devops-challenge-${ENVIRONMENT}"
APP_NAME="devops-demo-app"

if [ -z "${VERSION}" ]; then
    echo "Usage: ./rollback.sh <environment> <version>"
    echo "Example: ./rollback.sh staging 42-abc1234"
    exit 1
fi

echo "⏪ Rolling back ${ENVIRONMENT} to version ${VERSION}..."

# Update kubeconfig
aws eks update-kubeconfig \
    --region "${AWS_REGION}" \
    --name "${CLUSTER_NAME}"

# Get ECR registry URL
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Update deployment image
echo "📦 Updating deployment image..."
kubectl set image deployment/${APP_NAME} \
    ${APP_NAME}=${ECR_REGISTRY}/devops-challenge-app:${VERSION} \
    -n "${ENVIRONMENT}"

# Wait for rollout
echo "⏳ Waiting for rollback to complete..."
kubectl rollout status deployment/${APP_NAME} -n "${ENVIRONMENT}" --timeout=300s

# Show status
echo "✅ Rollback complete!"
kubectl get pods -n "${ENVIRONMENT}" -l app=${APP_NAME}

# Show rollout history
echo ""
echo "📜 Deployment history:"
kubectl rollout history deployment/${APP_NAME} -n "${ENVIRONMENT}"

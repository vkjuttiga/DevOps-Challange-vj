#!/bin/bash
# Deploy script for Jenkins pipeline

set -euo pipefail

ENVIRONMENT=${1:-dev}
IMAGE_TAG=${2:-latest}
AWS_REGION=${AWS_REGION:-ap-south-1}
CLUSTER_NAME="devops-challenge-${ENVIRONMENT}"
APP_NAME="devops-demo-app"

echo "🚀 Deploying to ${ENVIRONMENT} environment..."
echo "   Image Tag: ${IMAGE_TAG}"
echo "   Cluster: ${CLUSTER_NAME}"

# Update kubeconfig
aws eks update-kubeconfig \
    --region "${AWS_REGION}" \
    --name "${CLUSTER_NAME}"

# Verify cluster connection
echo "📡 Verifying cluster connection..."
kubectl cluster-info

# Create namespace if not exists
kubectl create namespace "${ENVIRONMENT}" --dry-run=client -o yaml | kubectl apply -f -

# Get ECR registry URL
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Apply manifests
echo "📦 Applying Kubernetes manifests..."
cd "$(dirname "$0")/../kubernetes/manifests/${ENVIRONMENT}"

# Substitute placeholders
for file in *.yaml; do
    sed -e "s|IMAGE_TAG_PLACEHOLDER|${IMAGE_TAG}|g" \
        -e "s|ECR_REGISTRY_PLACEHOLDER|${ECR_REGISTRY}|g" \
        -e "s|ECR_REPOSITORY_PLACEHOLDER|devops-challenge-app|g" \
        "${file}" | kubectl apply -n "${ENVIRONMENT}" -f -
done

# Wait for rollout
echo "⏳ Waiting for deployment rollout..."
kubectl rollout status deployment/${APP_NAME} -n "${ENVIRONMENT}" --timeout=300s

# Show deployment status
echo "✅ Deployment complete!"
kubectl get pods -n "${ENVIRONMENT}" -l app=${APP_NAME}
kubectl get svc -n "${ENVIRONMENT}" -l app=${APP_NAME}

echo ""
echo "🔗 Access instructions:"
echo "   Port forward: kubectl port-forward svc/${APP_NAME} 8080:80 -n ${ENVIRONMENT}"
echo "   Then visit: http://localhost:8080"

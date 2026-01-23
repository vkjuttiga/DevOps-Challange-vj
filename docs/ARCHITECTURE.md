# Architecture Documentation

Technical decisions, trade-offs, and architectural patterns used in this DevOps challenge implementation.

## Overview

This project implements a production-grade DevOps infrastructure on AWS using:
- **Infrastructure**: Terraform with modular design (Staging/Production)
- **CI/CD**: Jenkins with 6-stage pipeline
- **Deployment**: Kubernetes on EKS (v1.30) with Kustomize overlays
- **Security**: tfsec, Trivy scanning, and IAM RBAC

---

## Architecture Decisions

### 1. Infrastructure as Code (Terraform)

**Decision**: Modular Terraform structure with environment separation

**Rationale**:
- Reusable modules (networking, eks, ecr)
- Environment-specific configurations in `/environments` (`staging`, `production`)
- Consistent infrastructure with environment-specific variables (scaling, sizing)
- Native S3 Backend locking (no DynamoDB dependency)

**Trade-offs**:
- More initial setup complexity
- Learning curve for module development
- Requires careful state management

### 2. Container Orchestration (EKS)

**Decision**: AWS EKS v1.30 with managed node groups

**Rationale**:
- Reduced operational overhead vs self-managed Kubernetes
- **ALB Ingress Controller**: Native AWS Load Balancer integration for traffic
- **Access Entries (RBAC)**: Modern API-based access management for IAM users
- Automatic security patches for control plane

**Trade-offs**:
- $0.10/hour control plane cost
- Less control over etcd and control plane
- AWS-specific configurations

### 3. CI/CD Pipeline (Jenkins)

**Decision**: Jenkins with declarative pipeline

**Rationale**:
- Industry-standard CI/CD tool
- **ECR Integration**: Dynamic repository selection (`-staging`, `-production`)
- Pipeline as code (Jenkinsfile)
- Flexible deployment options (Docker, K8s)

**Trade-offs**:
- Requires maintenance and updates
- Complex plugin management
- Resource-intensive

### 4. Deployment Strategy (Kustomize)

**Decision**: Kustomize overlays with environment-specific naming

**Rationale**:
- Native kubectl integration
- **Name Suffixes**: Explicit resource naming (`-staging`, `-production`)
- Simple patching mechanism
- Clear separation of base and overlays

**Trade-offs**:
- Less powerful than Helm templates
- No package management features
- Manual version tracking

---

## Security Implementation

### Infrastructure Security

```
┌─────────────────────────────────────────────┐
│              Security Layers                 │
├─────────────────────────────────────────────┤
│  tfsec/Trivy    →  Terraform Source Code    │
│  IAM Roles      →  Least Privilege Access   │
│  Security Groups →  Network Segmentation    │
│  Private Subnets →  EKS Node Isolation      │
│  NAT Gateway    →  Outbound-only Internet   │
└─────────────────────────────────────────────┘
```

### Container Security

- **Base Image**: node:20-alpine (minimal attack surface)
- **Non-root User**: Runs as UID 1001
- **Read-only Filesystem**: Where possible
- **Resource Limits**: CPU/Memory constraints
- **Security Context**: `allowPrivilegeEscalation: false`

### Secrets Management

- Kubernetes Secrets for application credentials
- IAM Roles for AWS service access (IRSA for ALB Controller)
- Jenkins Credentials Store for CI/CD secrets
- No secrets in version control

---

## Network Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                         VPC (10.0.0.0/16)                     │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────────┐      ┌─────────────────────┐        │
│  │   Public Subnets     │      │   Private Subnets    │        │
│  │   10.0.1.0/24       │      │   10.0.11.0/24       │        │
│  │   10.0.2.0/24       │      │   10.0.12.0/24       │        │
│  │   10.0.3.0/24       │      │   10.0.13.0/24       │        │
│  │                     │      │                      │        │
│  │  ┌──────────────┐   │      │  ┌──────────────┐   │        │
│  │  │     ALB      │◀──┼──────┼──┤  EKS Nodes   │   │        │
│  │  └──────────────┘   │      │  └──────────────┘   │        │
│  │  ┌──────────────┐   │      │                      │        │
│  │  │ NAT Gateway  │───┼──────┼──▶ Outbound Traffic  │        │
│  │  └──────────────┘   │      │                      │        │
│  │  └──────────────────┘      └─────────────────────┘        │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

---

## CI/CD Pipeline Architecture

### 1. Infrastructure Pipeline (`jenkins/Jenkinsfile`)
Provisions the AWS infrastructure (VPC, EKS, ECR).

```
┌─────────────────────────────────────────────────────────────┐
│                   Infrastructure Pipeline                    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Checkout        │ Clone repository, set environment     │
│         ▼           │                                        │
│  2. Setup Tools     │ Install tfsec, Terraform              │
│         ▼           │                                        │
│  3. Security Scan   │ Run tfsec on Terraform code           │
│         ▼           │                                        │
│  4. Terraform Plan  │ Generate execution plan               │
│         ▼           │                                        │
│  5. Approval        │ Manual gate to review plan            │
│         ▼           │                                        │
│  6. Terraform Apply │ Provision/Update resources            │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 2. Application Pipeline (`jenkins/Jenkinsfile.app`)
Builds and deploys the Node.js application.

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Pipeline                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Checkout        │ Clone repository, set environment     │
│         ▼           │                                        │
│  2. Static Analysis │ ESLint, checkov                       │
│         ▼           │                                        │
│  3. Docker Build    │ Build container image                 │
│         ▼           │                                        │
│  4. Security Scan   │ Trivy image scanning                  │
│         ▼           │                                        │
│  5. Push Image      │ Push to ECR (staging/production)      │
│         ▼           │                                        │
│  6. Deploy          │ kubectl apply (Kustomize)             │
│         ▼           │                                        │
│  7. Verify          │ Health checks and rollout status      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Scalability Considerations

### Horizontal Pod Autoscaling

- **Min Replicas**: 2 (staging), 3 (production)
- **Max Replicas**: 5 (staging), 10 (production)
- **CPU Threshold**: 70% (staging), 60% (production)
- **Scale-down Stabilization**: 5 minutes

### EKS Cluster Scaling

- **Node Group**: Managed with auto-scaling
- **Min Nodes**: 1 (staging), 3 (production)
- **Max Nodes**: 4 (staging), 6 (production)

---

## Cost Optimization

| Resource | Estimated Cost | Optimization |
|----------|----------------|--------------|
| EKS Control Plane | $0.10/hour | Use for intended purpose |
| EC2 Nodes (t3.medium) | ~$0.04/hour each | Right-size based on load |
| NAT Gateway | ~$0.045/hour | Shared across subnets |
| ALB | ~$0.025/hour | Shared across services |

**Total Staging Environment**: ~$150-200/month


---

## Future Improvements

1. **GitOps**: ArgoCD for declarative deployments
2. **Monitoring**: Prometheus + Grafana stack
3. **Service Mesh**: Istio for advanced traffic management
4. **Multi-region**: Disaster recovery setup
5. **Cost Monitoring**: AWS Cost Explorer integration

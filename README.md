# DevOps Challenge - AWS EKS Infrastructure

[![Terraform](https://img.shields.io/badge/Terraform-1.5+-purple.svg)](https://www.terraform.io/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28+-blue.svg)](https://kubernetes.io/)
[![Jenkins](https://img.shields.io/badge/Jenkins-LTS-red.svg)](https://www.jenkins.io/)

Production-ready DevOps infrastructure featuring Terraform, Jenkins CI/CD, and Kubernetes deployment on AWS EKS.

## Architecture

![Challenge-Architecture](https://github.com/user-attachments/assets/8b7d8b2a-80d4-4b1a-bde9-7fa0ed37959e)


## Project Structure

```
devops-challenge/
├── application/          # Sample Node.js application
├── terraform/            # Infrastructure as Code
│   ├── modules/          # Reusable Terraform modules
│   └── environments/     # Environment configs (staging/production)
├── jenkins/              # CI/CD pipeline configuration
├── kubernetes/           # K8s manifests with Kustomize
├── scripts/              # Automation scripts
└── docs/                 # Additional documentation
```

## Components

| Component | Technology | Purpose |
|-----------|------------|---------|
| Infrastructure | Terraform | VPC, EKS, ECR, IAM |
| CI/CD | Jenkins | 6-stage pipeline |
| Container Registry | AWS ECR | Docker image storage |
| Orchestration | Kubernetes | Application deployment |
| Security | tfsec, Trivy | IaC and image scanning |

## Documentation

- [**SETUP.md**](docs/SETUP.md) - Detailed setup instructions
- [**ARCHITECTURE.md**](ARCHITECTURE.md) - Technical decisions and diagrams



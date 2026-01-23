locals {
  cluster_name = "${var.project_name}-${var.environment}"
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Networking Module
module "networking" {
  source = "../../modules/networking"

  vpc_name             = "${var.project_name}-${var.environment}"
  vpc_cidr             = "10.1.0.0/16"
  availability_zones   = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  private_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24", "10.1.13.0/24"]
  environment          = var.environment
  tags                 = local.common_tags
}

# EKS Module
module "eks" {
  source = "../../modules/eks"

  cluster_name        = local.cluster_name
  cluster_version     = "1.30"
  vpc_id              = module.networking.vpc_id
  private_subnet_ids  = module.networking.private_subnet_ids
  public_subnet_ids   = module.networking.public_subnet_ids
  node_instance_types = ["t3.medium"]
  node_desired_size   = 1
  node_min_size       = 1
  node_max_size       = 4
  environment         = var.environment
  tags                = local.common_tags
  
  # Add ARNs of other users who need admin access here
  admin_users         = [] 
}

# ECR Module
module "ecr" {
  source = "../../modules/ecr"

  repository_name      = "${var.project_name}-app-${var.environment}"
  image_tag_mutability = "IMMUTABLE"
  scan_on_push         = true
  environment          = var.environment
  tags                 = local.common_tags
}

# AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.eks.aws_load_balancer_controller_role_arn
  }
}
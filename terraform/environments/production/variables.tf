variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "devops-challenge"
}

variable "environment" {
  description = "Deployment environment (e.g., staging, production)"
  type        = string
  default     = "production"
}

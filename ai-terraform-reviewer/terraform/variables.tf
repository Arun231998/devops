variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS Target Region"
}

variable "project_name" {
  type        = string
  default     = "ai-devops-core"
  description = "Name prefix for resources"
}

variable "environment" {
  type        = string
  default     = "production"
  description = "Deployment environment name"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "VPC CIDR block"
}

variable "cluster_name" {
  type        = string
  default     = "ai-ops-eks-cluster"
  description = "Name of the EKS Cluster"
}

variable "node_instance_types" {
  type        = list(string)
  default     = ["t3.medium"]
  description = "EC2 instance types for EKS nodes"
}

variable "node_desired_size" {
  type        = number
  default     = 2
  description = "Desired number of worker nodes"
}

variable "node_min_size" {
  type        = number
  default     = 1
  description = "Minimum number of worker nodes"
}

variable "node_max_size" {
  type        = number
  default     = 4
  description = "Maximum number of worker nodes"
}

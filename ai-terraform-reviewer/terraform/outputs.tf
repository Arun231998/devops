output "vpc_id" {
  value       = aws_vpc.eks_vpc.id
  description = "The ID of the VPC"
}

output "cluster_name" {
  value       = aws_eks_cluster.main.name
  description = "The Name of the EKS cluster"
}

output "cluster_endpoint" {
  value       = aws_eks_cluster.main.endpoint
  description = "The endpoint URL for the EKS control plane"
}

output "cluster_security_group_id" {
  value       = aws_security_group.eks_cluster.id
  description = "Security Group ID attached to EKS Cluster Control Plane"
}

output "kms_key_arn" {
  value       = aws_kms_key.eks_kms.arn
  description = "The ARN of the KMS Key used for Secrets Encryption"
}

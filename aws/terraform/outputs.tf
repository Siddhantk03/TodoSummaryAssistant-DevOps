output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_region" {
  description = "AWS region containing the cluster."
  value       = var.aws_region
}

output "cluster_endpoint" {
  description = "EKS Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}

output "vpc_id" {
  description = "VPC created for the EKS cluster."
  value       = module.vpc.vpc_id
}

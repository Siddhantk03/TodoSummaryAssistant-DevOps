variable "aws_region" {
  description = "AWS region for the EKS cluster."
  type        = string
  default     = "ap-south-1"
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "todo-summary-dev"
}

variable "kubernetes_version" {
  description = "Kubernetes minor version supported by EKS in the selected region."
  type        = string
  default     = "1.36"
}

variable "eks_public_access_cidrs" {
  description = "Operator public IP CIDRs allowed to reach the EKS Kubernetes API, e.g. [\"198.51.100.25/32\"]. Do not use 0.0.0.0/0."
  type        = list(string)
}

variable "vpc_cidr" {
  description = "CIDR for the new VPC. Must not overlap networks connected to this VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

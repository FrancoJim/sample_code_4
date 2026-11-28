variable "cluster_name" {
  description = "EKS cluster name — used to tag resources for K8s discovery"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

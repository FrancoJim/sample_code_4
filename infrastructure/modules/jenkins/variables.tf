variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider (for IRSA)"
  type        = string
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL of the EKS cluster (for IRSA trust policy)"
  type        = string
}

variable "dockerhub_username" {
  description = "DockerHub username stored as a K8s secret for JCasC credential injection"
  type        = string
  sensitive   = true
}

variable "dockerhub_password" {
  description = "DockerHub password or access token"
  type        = string
  sensitive   = true
}

variable "github_repo_url" {
  description = "GitHub repository URL for the auto-configured pipeline job"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for Jenkins"
  type        = string
  default     = "jenkins"
}

variable "helm_release_name" {
  description = "Helm release name (also becomes the Jenkins service account name)"
  type        = string
  default     = "jenkins"
}

variable "helm_chart_version" {
  description = "Jenkins Helm chart version"
  type        = string
  default     = "5.7.0"
}

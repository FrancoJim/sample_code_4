output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "worker_node_iam_role_arn" {
  description = "IAM role ARN for EKS worker nodes"
  value       = module.iam.worker_role_arn
}

output "jenkins_namespace" {
  description = "Kubernetes namespace where Jenkins is deployed"
  value       = module.jenkins.namespace
}

output "jenkins_get_password" {
  description = "Command to retrieve the Jenkins admin password"
  value       = module.jenkins.get_password_command
}

output "jenkins_port_forward" {
  description = "Command to port-forward Jenkins to localhost:8080"
  value       = module.jenkins.port_forward_command
}

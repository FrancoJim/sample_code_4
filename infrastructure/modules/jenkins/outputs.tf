output "namespace" {
  description = "Kubernetes namespace where Jenkins is deployed"
  value       = kubernetes_namespace.jenkins.metadata[0].name
}

output "get_password_command" {
  description = "kubectl command to retrieve the Jenkins admin password"
  value       = "kubectl exec --namespace ${var.namespace} -it svc/${var.helm_release_name} -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password && echo"
}

output "port_forward_command" {
  description = "kubectl command to port-forward Jenkins to localhost:8080"
  value       = "kubectl -n ${var.namespace} port-forward svc/${var.helm_release_name} 8080:8080"
}

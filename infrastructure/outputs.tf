output "cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

output "cluster_identity_oidc_issuer" {
  value = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

output "kubeconfig_certificate_authority_data" {
  value = aws_eks_cluster.eks_cluster.certificate_authority[0].data
}

data "aws_region" "current" {}

output "region" {
  value = data.aws_region.current.name
}

output "worker_node_iam_role_arn" {
  value = aws_iam_role.eks_worker_nodes.arn
}

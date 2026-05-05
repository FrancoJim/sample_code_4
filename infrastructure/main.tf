provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source = "./modules/vpc"

  cluster_name = var.cluster_name
  vpc_cidr     = var.vpc_cidr
}

module "iam" {
  source = "./modules/iam"

  cluster_name = var.cluster_name
}

module "eks" {
  source = "./modules/eks"

  cluster_name       = var.cluster_name
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.subnet_ids
  cluster_role_arn   = module.iam.cluster_role_arn
  worker_role_arn    = module.iam.worker_role_arn
  worker_role_name   = module.iam.worker_role_name
  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  node_max_size      = var.node_max_size
  node_min_size      = var.node_min_size
}

# Kubernetes and Helm providers use the exec auth plugin so no static
# credentials are stored in state. Requires aws CLI on the local machine.
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", module.eks.cluster_name,
      "--region", var.aws_region,
    ]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", module.eks.cluster_name,
        "--region", var.aws_region,
      ]
    }
  }
}

# EBS CSI driver — required for gp2/gp3 PersistentVolumes on EKS.
resource "helm_release" "ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  namespace  = "kube-system"
  version    = "2.26.0"

  depends_on = [module.eks]
}

module "jenkins" {
  source = "./modules/jenkins"

  cluster_name       = var.cluster_name
  aws_region         = var.aws_region
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_issuer_url    = module.eks.oidc_issuer_url
  dockerhub_username = var.dockerhub_username
  dockerhub_password = var.dockerhub_password
  github_repo_url    = var.github_repo_url

  depends_on = [module.eks, helm_release.ebs_csi_driver]
}

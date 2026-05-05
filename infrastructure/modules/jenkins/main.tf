locals {
  # Strip the https:// prefix for use in IAM condition keys
  oidc_host = replace(var.oidc_issuer_url, "https://", "")
}

# ── Namespaces ────────────────────────────────────────────────────────────────

resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = var.namespace
  }
}

# weather-service namespace is created here so the Jenkins RBAC binding below
# has a valid target before the first deployment runs.
resource "kubernetes_namespace" "weather_service" {
  metadata {
    name = "weather-service"
  }
}

# ── DockerHub credentials ─────────────────────────────────────────────────────

# Stored as a K8s secret and mounted into the Jenkins pod at
# /run/secrets/additional/. JCasC reads the values from those paths so
# credentials never appear in Terraform state in plain text.
resource "kubernetes_secret" "dockerhub" {
  metadata {
    name      = "jenkins-dockerhub"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
  }

  data = {
    username = var.dockerhub_username
    password = var.dockerhub_password
  }
}

# ── IRSA — Jenkins service account assumes an IAM role ───────────────────────

data "aws_iam_policy_document" "jenkins_trust" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.helm_release_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "jenkins" {
  name               = "${var.cluster_name}-jenkins-irsa"
  assume_role_policy = data.aws_iam_policy_document.jenkins_trust.json
}

# Minimal permission: Jenkins only needs DescribeCluster to obtain a token.
# Kubernetes RBAC controls what the token can actually do inside the cluster.
data "aws_iam_policy_document" "jenkins_eks" {
  statement {
    effect    = "Allow"
    actions   = ["eks:DescribeCluster"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "jenkins_eks" {
  name   = "${var.cluster_name}-jenkins-eks-policy"
  policy = data.aws_iam_policy_document.jenkins_eks.json
}

resource "aws_iam_role_policy_attachment" "jenkins_eks" {
  role       = aws_iam_role.jenkins.name
  policy_arn = aws_iam_policy.jenkins_eks.arn
}

# ── K8s RBAC — Jenkins can update deployments in weather-service ──────────────

resource "kubernetes_role" "jenkins_deployer" {
  metadata {
    name      = "jenkins-deployer"
    namespace = kubernetes_namespace.weather_service.metadata[0].name
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets"]
    verbs      = ["get", "list", "watch", "patch", "update"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding" "jenkins_deployer" {
  metadata {
    name      = "jenkins-deployer"
    namespace = kubernetes_namespace.weather_service.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.jenkins_deployer.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = var.helm_release_name
    namespace = var.namespace
  }
}

# ── Jenkins Helm release ──────────────────────────────────────────────────────

resource "helm_release" "jenkins" {
  name             = var.helm_release_name
  repository       = "https://charts.jenkins.io"
  chart            = "jenkins"
  version          = var.helm_chart_version
  namespace        = kubernetes_namespace.jenkins.metadata[0].name
  timeout          = 600
  wait             = true
  cleanup_on_fail  = true
  recreate_pods    = false

  values = [
    templatefile("${path.module}/helm-values.yaml.tpl", {
      irsa_role_arn   = aws_iam_role.jenkins.arn
      github_repo_url = var.github_repo_url
      aws_region      = var.aws_region
      cluster_name    = var.cluster_name
      sa_name         = var.helm_release_name
    })
  ]

  depends_on = [
    kubernetes_secret.dockerhub,
    aws_iam_role_policy_attachment.jenkins_eks,
  ]
}

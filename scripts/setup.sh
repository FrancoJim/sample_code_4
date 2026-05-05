#!/bin/bash
set -euo pipefail

# Navigate to repo root regardless of where the script is called from
while [ ! -f "LICENSE" ]; do cd ..; done

if [ ! -f "infrastructure/terraform.tfvars" ]; then
    echo "ERROR: infrastructure/terraform.tfvars not found."
    echo "Copy infrastructure/terraform.tfvars.example to infrastructure/terraform.tfvars and fill in values."
    exit 1
fi

cd infrastructure

echo "==> Initializing Terraform..."
terraform init

echo "==> Applying infrastructure (EKS + Jenkins)..."
terraform apply -var-file=terraform.tfvars

AWS_REGION=$(terraform output -raw region)
CLUSTER_NAME=$(terraform output -raw cluster_name)

echo
echo "==> Updating local kubeconfig for ${CLUSTER_NAME}..."
aws eks --region "${AWS_REGION}" update-kubeconfig --name "${CLUSTER_NAME}"

echo
echo "==> Done. Jenkins access:"
echo
terraform output -raw jenkins_get_password
echo
terraform output -raw jenkins_port_forward
echo

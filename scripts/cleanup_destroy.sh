#! /bin/bash
clear

while [ ! -f "LICENSE" ]; do cd ..; done

CONFIG_DIR=".configs"

echo "Destroying Kubernetes cluster..."
cd infrastructure
export TF_DATA_DIR=../${CONFIG_DIR}/.terraform
terraform destroy --auto-approve
cd ..
echo "Kubernetes cluster destroyed."
echo
echo "Cleanup done."
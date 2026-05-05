#!/bin/bash
set -euo pipefail

while [ ! -f "LICENSE" ]; do cd ..; done

cd infrastructure

echo "==> Destroying all infrastructure..."
terraform destroy -var-file=terraform.tfvars

echo "==> Done."

#!/bin/bash
set -euo pipefail

# Run from the repo root regardless of where the script is called from
cd "$(dirname "${BASH_SOURCE[0]}")/.."

cd infrastructure

echo "==> Destroying all infrastructure..."
terraform destroy -var-file=terraform.tfvars

echo "==> Done."

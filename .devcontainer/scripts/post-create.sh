#!/usr/bin/env bash
# Runs once after the devcontainer is created (postCreateCommand in devcontainer.json).
# Safe to re-run manually: every step is idempotent.
set -euo pipefail

WORKSPACE=/workspace
VENV="${WORKSPACE}/.venv"

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║         sample_code_4  —  devcontainer setup         ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── Python virtual environment ────────────────────────────────────────────────
echo "→ Setting up Python venv at ${VENV}..."
python3 -m venv "${VENV}"
"${VENV}/bin/pip" install --quiet --upgrade pip
"${VENV}/bin/pip" install --quiet -r "${WORKSPACE}/microservice/src/requirements.txt"
echo "  ✓ Python venv ready  (${VENV}/bin/python)"

# ── Terraform autocomplete ─────────────────────────────────────────────────────
echo "→ Installing Terraform shell completion..."
terraform -install-autocomplete 2>/dev/null || true
echo "  ✓ Terraform completion installed"

# ── Git — mark workspace as safe (avoids dubious ownership warnings) ──────────
echo "→ Configuring git safe directory..."
git config --global --add safe.directory "${WORKSPACE}" 2>/dev/null || true
echo "  ✓ git safe.directory set"

# ── Persist bash history across rebuilds ─────────────────────────────────────
HIST_DIR=/home/vscode/.bash_history_dir
mkdir -p "${HIST_DIR}"
HISTFILE_LINK=/home/vscode/.bash_history
if [[ ! -f "${HIST_DIR}/.bash_history" ]]; then
    touch "${HIST_DIR}/.bash_history"
fi
ln -sf "${HIST_DIR}/.bash_history" "${HISTFILE_LINK}" 2>/dev/null || true

# ── Tool version summary ───────────────────────────────────────────────────────
echo ""
echo "── Installed tools ───────────────────────────────────────"
printf "  %-14s %s\n" "terraform"  "$(terraform version -json 2>/dev/null | jq -r .terraform_version 2>/dev/null || terraform version | head -1)"
printf "  %-14s %s\n" "kubectl"    "$(kubectl version --client --short 2>/dev/null | head -1 || kubectl version --client 2>/dev/null | grep 'Client Version')"
printf "  %-14s %s\n" "helm"       "$(helm version --short 2>/dev/null)"
printf "  %-14s %s\n" "aws"        "$(aws --version 2>&1 | awk '{print $1}')"
printf "  %-14s %s\n" "docker"     "$(docker version --format '{{.Client.Version}}' 2>/dev/null || echo 'socket not yet available')"
printf "  %-14s %s\n" "k9s"        "$(k9s version --short 2>/dev/null | grep Version || echo 'installed')"
printf "  %-14s %s\n" "python"     "$("${VENV}/bin/python" --version)"
echo ""

# ── LocalStack bootstrap hint ─────────────────────────────────────────────────
echo "── LocalStack ────────────────────────────────────────────"
echo "  Endpoint : http://localstack:4566"
echo "  Alias    : awslocal s3 ls   (pre-configured in shell)"
echo "  S3 state bucket example:"
echo "    awslocal s3 mb s3://tfstate-local"
echo "    awslocal dynamodb create-table \\"
echo "      --table-name terraform-state-lock \\"
echo "      --attribute-definitions AttributeName=LockID,AttributeType=S \\"
echo "      --key-schema AttributeName=LockID,KeyType=HASH \\"
echo "      --billing-mode PAY_PER_REQUEST"
echo ""

# ── Local registry hint ───────────────────────────────────────────────────────
echo "── Local Docker registry ─────────────────────────────────"
echo "  Push : docker build -t registry:5000/sample_code_4:dev microservice/"
echo "       : docker push registry:5000/sample_code_4:dev"
echo ""

echo "✓ Setup complete. Open a new terminal to get the custom prompt."
echo ""

FROM ubuntu:24.04

# Tool versions — bump here to upgrade everything at once
ARG TERRAFORM_VERSION=1.9.8
ARG KUBECTL_VERSION=v1.30.6
ARG HELM_VERSION=v3.16.3
ARG K9S_VERSION=v0.32.5

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# ── Base packages ─────────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        bash-completion \
        build-essential \
        ca-certificates \
        curl \
        dnsutils \
        git \
        gnupg \
        iputils-ping \
        jq \
        less \
        lsb-release \
        make \
        netcat-openbsd \
        openssh-client \
        python3.12 \
        python3-pip \
        python3.12-venv \
        software-properties-common \
        sudo \
        unzip \
        vim \
        wget \
    && rm -rf /var/lib/apt/lists/*

# ── Docker CLI (no daemon — we mount the OrbStack socket from the host) ───────
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) \
        signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
        https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# ── AWS CLI v2 ────────────────────────────────────────────────────────────────
RUN ARCH=$(dpkg --print-architecture) \
    && case "$ARCH" in \
        amd64) AWS_ARCH=x86_64 ;; \
        arm64) AWS_ARCH=aarch64 ;; \
        *) echo "Unsupported arch: $ARCH" && exit 1 ;; \
    esac \
    && curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" \
        -o /tmp/awscli.zip \
    && unzip -q /tmp/awscli.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf /tmp/aws /tmp/awscli.zip

# ── Terraform ─────────────────────────────────────────────────────────────────
RUN ARCH=$(dpkg --print-architecture) \
    && curl -fsSL \
        "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip" \
        -o /tmp/terraform.zip \
    && unzip -q /tmp/terraform.zip -d /usr/local/bin \
    && rm /tmp/terraform.zip

# ── kubectl ───────────────────────────────────────────────────────────────────
RUN ARCH=$(dpkg --print-architecture) \
    && curl -fsSL \
        "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" \
        -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

# ── Helm ──────────────────────────────────────────────────────────────────────
RUN curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    | DESIRED_VERSION=${HELM_VERSION} bash

# ── k9s (Kubernetes TUI) ──────────────────────────────────────────────────────
RUN ARCH=$(dpkg --print-architecture) \
    && curl -fsSL \
        "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_${ARCH}.tar.gz" \
        | tar -xz -C /usr/local/bin k9s

# ── Non-root user ─────────────────────────────────────────────────────────────
# ubuntu:24.04 ships with ubuntu:ubuntu at uid/gid 1000 — rename them instead
# of trying to create a conflicting entry.
# daemon group (GID 1) matches OrbStack's docker.sock owner so Docker CLI works
# without sudo.
RUN groupmod -n vscode ubuntu \
    && usermod -l vscode -d /home/vscode -m -s /bin/bash ubuntu \
    && usermod -aG daemon,sudo vscode \
    && echo "vscode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vscode \
    && chmod 0440 /etc/sudoers.d/vscode

# ── Shell initialisation (sourced by every interactive bash session) ──────────
COPY .devcontainer/scripts/shell-init.sh /etc/devcontainer-init.sh
RUN chmod +x /etc/devcontainer-init.sh \
    && echo "" >> /etc/bash.bashrc \
    && echo "# devcontainer prompt + tools" >> /etc/bash.bashrc \
    && echo ". /etc/devcontainer-init.sh" >> /etc/bash.bashrc

USER vscode
WORKDIR /workspace

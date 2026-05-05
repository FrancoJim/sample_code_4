#!/usr/bin/env bash
# Sourced by every interactive bash session inside the devcontainer.
# (/etc/bash.bashrc appends `. /etc/devcontainer-init.sh`)

# Guard: non-interactive shells (scripts, scp, etc.) must not be affected.
[[ $- != *i* ]] && return

# ── Prompt ────────────────────────────────────────────────────────────────────
# Format:  repo_name | branch | /current/path $
# Outside a git repo the repo/branch segments are omitted.

__dc_git_repo() {
    local root
    root=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
    basename "$root"
}

__dc_git_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null || return 1
}

__dc_build_ps1() {
    local repo branch cwd
    # Colours (using \[ \] so readline counts them as zero-width)
    local CYAN='\[\e[36m\]'
    local YELLOW='\[\e[33m\]'
    local GREEN='\[\e[32m\]'
    local BOLD='\[\e[1m\]'
    local RESET='\[\e[0m\]'

    cwd="${PWD/#$HOME/~}"
    repo=$(__dc_git_repo 2>/dev/null)
    branch=$(__dc_git_branch 2>/dev/null)

    if [[ -n "$repo" && -n "$branch" ]]; then
        PS1="${CYAN}${BOLD}${repo}${RESET} | ${YELLOW}${branch}${RESET} | ${GREEN}${cwd}${RESET} \$ "
    else
        PS1="${GREEN}${cwd}${RESET} \$ "
    fi
}

# Append to PROMPT_COMMAND rather than overwriting it so other hooks survive.
PROMPT_COMMAND="__dc_build_ps1${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

# ── Tab completion ─────────────────────────────────────────────────────────────
# Load bash-completion if not already active
if ! declare -F _init_completion &>/dev/null; then
    [[ -f /usr/share/bash-completion/bash_completion ]] \
        && . /usr/share/bash-completion/bash_completion
fi

# Terraform
complete -C /usr/local/bin/terraform terraform 2>/dev/null || true

# kubectl  (generates ~10k lines of completion — cache it)
if command -v kubectl &>/dev/null; then
    if [[ ! -f /tmp/.kubectl_completion ]]; then
        kubectl completion bash > /tmp/.kubectl_completion 2>/dev/null || true
    fi
    [[ -f /tmp/.kubectl_completion ]] && . /tmp/.kubectl_completion
    complete -o default -F __start_kubectl k 2>/dev/null || true
fi

# Helm
if command -v helm &>/dev/null; then
    . <(helm completion bash 2>/dev/null) || true
fi

# AWS CLI
if command -v aws_completer &>/dev/null; then
    complete -C aws_completer aws 2>/dev/null || true
fi

# ── Activate Python venv if present ───────────────────────────────────────────
if [[ -f /workspace/.venv/bin/activate ]]; then
    . /workspace/.venv/bin/activate
fi

# ── Aliases ───────────────────────────────────────────────────────────────────
alias k='kubectl'
alias tf='terraform'
alias tfi='terraform init'
alias tfp='terraform plan'
alias tfa='terraform apply'
alias ll='ls -lAh --color=auto'
alias la='ls -A --color=auto'
alias ls='ls --color=auto'
alias ..='cd ..'
alias ...='cd ../..'

# Quickly reach LocalStack with the same profile as real AWS
alias awslocal='aws --endpoint-url http://localstack:4566'

# ── Useful environment hints ───────────────────────────────────────────────────
export EDITOR=vim
export KUBE_EDITOR=vim

# Silence the "use 'kubectl version'" nag in k9s
export K9S_SKIP_KUBE_CONNECTIVITY_CHECK=true

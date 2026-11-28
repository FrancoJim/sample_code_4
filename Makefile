# Weather Service — common tasks. Run `make` (or `make help`) to list them.
# Infra checks run in pinned containers, so only Docker and Python are needed locally.

PYTHON   ?= python3
SRC      := microservice/src
VENV     ?= .venv
BIN      := $(VENV)/bin
IMAGE    ?= weather-service
TAG      ?= local
PORT     ?= 5000

TF_IMAGE   ?= hashicorp/terraform:1.14
K8S_IMAGE  ?= alpine/k8s:1.34.1
K8S_VER    ?= 1.34.0
SC_IMAGE   ?= koalaman/shellcheck:stable
HADOLINT   ?= hadolint/hadolint:latest

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

# ── App (local) ───────────────────────────────────────────────────────────────

$(BIN)/activate: $(SRC)/requirements.txt $(SRC)/requirements-dev.txt
	$(PYTHON) -m venv $(VENV)
	$(BIN)/pip install --upgrade pip
	$(BIN)/pip install -r $(SRC)/requirements-dev.txt
	@touch $@

.PHONY: install
install: $(BIN)/activate ## Create .venv and install the app + dev tools

.PHONY: run
run: install ## Run the Flask app locally (http://localhost:5000)
	cd $(SRC) && PORT=$(PORT) ../../$(BIN)/python app.py

.PHONY: lint
lint: install ## Lint and check formatting of the app with ruff
	$(BIN)/ruff check --config microservice/ruff.toml $(SRC)
	$(BIN)/ruff format --config microservice/ruff.toml --check $(SRC)

.PHONY: fmt
fmt: install ## Auto-fix and format Python + Terraform
	$(BIN)/ruff check --config microservice/ruff.toml --fix $(SRC)
	$(BIN)/ruff format --config microservice/ruff.toml $(SRC)
	docker run --rm -v "$(CURDIR)/infrastructure:/src" -w /src $(TF_IMAGE) fmt -recursive

.PHONY: test
test: install ## Run the app tests with coverage (upstream API is mocked)
	cd $(SRC) && ../../$(BIN)/pytest -v --cov=app --cov-report=term-missing test_app.py

# ── Infra checks (containers; no cloud credentials, nothing is applied) ───────

.PHONY: tf-check
tf-check: ## terraform fmt -check + init -backend=false + validate
	docker run --rm -v "$(CURDIR)/infrastructure:/src:ro" --entrypoint sh $(TF_IMAGE) -c \
		'cp -r /src /tmp/i && cd /tmp/i && terraform fmt -check -recursive && \
		 terraform init -backend=false -input=false -lockfile=readonly >/dev/null && terraform validate'

.PHONY: k8s-check
k8s-check: ## Render the kustomization and validate it with kubeconform
	docker run --rm -v "$(CURDIR)/microservice/k8s:/src:ro" --entrypoint sh $(K8S_IMAGE) -c \
		'cp -r /src /tmp/k && kubectl kustomize /tmp/k | kubeconform -strict -summary -kubernetes-version $(K8S_VER)'

.PHONY: shellcheck
shellcheck: ## Lint shell scripts
	docker run --rm -v "$(CURDIR):/mnt:ro" -w /mnt $(SC_IMAGE) scripts/*.sh

.PHONY: hadolint
hadolint: ## Lint the Dockerfile
	docker run --rm -i $(HADOLINT) < microservice/Dockerfile

.PHONY: check
check: lint test tf-check k8s-check shellcheck hadolint ## Everything CI runs

# ── Docker ────────────────────────────────────────────────────────────────────

.PHONY: docker-build
docker-build: ## Build the service image
	docker build -t $(IMAGE):$(TAG) microservice

.PHONY: docker-run
docker-run: docker-build ## Run the image read-only (http://localhost:5000)
	docker run --rm -p $(PORT):5000 --read-only --tmpfs /tmp $(IMAGE):$(TAG)

# ── AWS (real cloud; costs money) ─────────────────────────────────────────────

.PHONY: deploy
deploy: ## terraform apply EKS + Jenkins (needs AWS creds + infrastructure/terraform.tfvars)
	./scripts/setup.sh

.PHONY: destroy
destroy: ## terraform destroy everything
	./scripts/cleanup_destroy.sh

# ── Housekeeping ──────────────────────────────────────────────────────────────

.PHONY: clean
clean: ## Remove .venv and caches
	rm -rf $(VENV) .coverage $(SRC)/.coverage
	find . -type d \( -name __pycache__ -o -name .pytest_cache -o -name .ruff_cache \) -prune -exec rm -rf {} +

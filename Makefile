.PHONY: help install start stop clean test dev go-service node-service quarkus-service python-service status \
	container-build container-build-go container-build-node container-build-quarkus container-build-python \
	container-clean container-push container-push-go container-push-node container-push-quarkus container-push-python \
	container-run container-stop container-status container-logs \
	python-env-help python-create-env python-check-env

# Configuration
GO_PORT ?= 4001
NODE_PORT ?= 4002
QUARKUS_PORT ?= 4003
PYTHON_PORT ?= 4004
JAVA_HOME ?= /opt/homebrew/opt/openjdk@21
MAVEN_PATH ?= /opt/apache-maven-3.8.8/bin
REGISTRY ?= quay.io/cldmnky
PLATFORMS ?= linux/amd64,linux/arm64

# Python/Conda Configuration
CONDA_ENV := observability-python
CONDA_BASE := $(HOME)/miniforge3

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(GREEN)Observability Developer Day 2025 - Service Stack$(NC)"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "Configuration:"
	@echo "  GO_PORT=$(GO_PORT)"
	@echo "  NODE_PORT=$(NODE_PORT)"
	@echo "  QUARKUS_PORT=$(QUARKUS_PORT)"
	@echo "  PYTHON_PORT=$(PYTHON_PORT)"
	@echo "  CONDA_ENV=$(CONDA_ENV)"

python-env-help: ## Show Python/Conda environment activation guide
	@echo "$(GREEN)🐍 Conda Environment Activation Guide$(NC)"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "Environment: $(CONDA_ENV)"
	@echo "Location:    $(CONDA_BASE)"
	@echo ""
	@if [ ! -d "$(CONDA_BASE)" ]; then \
		echo "$(RED)❌ Conda not installed. Please install miniforge3:$(NC)"; \
		echo "   brew install miniforge"; \
		exit 1; \
	fi
	@if ! eval "$$($(CONDA_BASE)/bin/conda shell.bash hook)" && conda env list | grep -q "^$(CONDA_ENV) "; then \
		echo "$(YELLOW)⚠️  Environment '$(CONDA_ENV)' not found. Run: make python-create-env$(NC)"; \
	else \
		echo "$(GREEN)✓ Environment '$(CONDA_ENV)' exists$(NC)"; \
	fi
	@echo ""
	@echo "To activate the conda environment manually:"
	@echo ""
	@echo "  eval \"\$$($(CONDA_BASE)/bin/conda shell.bash hook)\""
	@echo "  conda activate $(CONDA_ENV)"
	@echo ""
	@echo "Or in one line:"
	@echo ""
	@echo "  eval \"\$$($(CONDA_BASE)/bin/conda shell.bash hook)\" && conda activate $(CONDA_ENV)"
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

python-create-env: ## Create Python conda environment
	@echo "$(GREEN)Creating conda environment: $(CONDA_ENV)$(NC)"
	@if [ ! -d "$(CONDA_BASE)" ]; then \
		echo "$(RED)❌ Conda not installed. Please install miniforge3:$(NC)"; \
		echo "   brew install miniforge"; \
		exit 1; \
	fi
	@eval "$$($(CONDA_BASE)/bin/conda shell.bash hook)" && \
	conda create -n $(CONDA_ENV) python=3.12 -y && \
	conda activate $(CONDA_ENV) && \
	pip install -r python/requirements.txt
	@echo "$(GREEN)✓ Conda environment '$(CONDA_ENV)' created successfully$(NC)"
	@echo "$(YELLOW)Activate with: eval \"\$$($(CONDA_BASE)/bin/conda shell.bash hook)\" && conda activate $(CONDA_ENV)$(NC)"

python-check-env: ## Check if Python conda environment exists
	@if [ ! -d "$(CONDA_BASE)" ]; then \
		echo "$(RED)❌ Conda not installed$(NC)"; \
		exit 1; \
	fi
	@if ! eval "$$($(CONDA_BASE)/bin/conda shell.bash hook)" && conda env list | grep -q "^$(CONDA_ENV) "; then \
		echo "$(RED)❌ Environment '$(CONDA_ENV)' not found. Run: make python-create-env$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✓ Environment '$(CONDA_ENV)' exists$(NC)"

install: ## Install all dependencies for all services
	@echo "$(GREEN)Installing dependencies...$(NC)"
	@echo "$(YELLOW)Installing Go dependencies...$(NC)"
	cd go && go mod download
	@echo "$(YELLOW)Installing Node.js dependencies...$(NC)"
	cd node && npm install
	@echo "$(YELLOW)Setting up Python conda environment...$(NC)"
	@$(MAKE) python-check-env || $(MAKE) python-create-env
	@echo "$(YELLOW)Verifying Java/Maven setup...$(NC)"
	@export JAVA_HOME=$(JAVA_HOME) && export PATH=$(MAVEN_PATH):$$PATH && mvn --version
	@echo "$(GREEN)✓ All dependencies installed$(NC)"

test: ## Run tests for all services
	@echo "$(GREEN)Running tests...$(NC)"
	@echo "$(YELLOW)Testing Go service...$(NC)"
	cd go && go test ./...
	@echo "$(YELLOW)Testing Node.js service...$(NC)"
	cd node && npm test
	@echo "$(YELLOW)Testing Quarkus service...$(NC)"
	cd quarkus && export JAVA_HOME=$(JAVA_HOME) && export PATH=$(MAVEN_PATH):$$PATH && mvn test
	@echo "$(GREEN)✓ All tests passed$(NC)"

go-service: ## Start the Go name generator service
	@echo "$(GREEN)Starting Go service on port $(GO_PORT)...$(NC)"
	cd go && PORT=$(GO_PORT) go run ./cmd/api

node-service: ## Start the Node.js web application
	@echo "$(GREEN)Starting Node.js service on port $(NODE_PORT)...$(NC)"
	cd node && PORT=$(NODE_PORT) npm start

quarkus-service: ## Start the Quarkus lolcat service
	@echo "$(GREEN)Starting Quarkus service on port $(QUARKUS_PORT)...$(NC)"
	cd quarkus && export JAVA_HOME=$(JAVA_HOME) && export PATH=$(MAVEN_PATH):$$PATH && mvn quarkus:dev

python-service: python-check-env ## Start the Python seed generator service
	@echo "$(GREEN)Starting Python service on port $(PYTHON_PORT)...$(NC)"
	@eval "$$($(CONDA_BASE)/bin/conda shell.bash hook)" && \
	conda activate $(CONDA_ENV) && \
	cd python && PORT=$(PYTHON_PORT) python app.py

dev: python-check-env ## Start all services in development mode (requires tmux)
	@echo "$(GREEN)Starting all services in development mode...$(NC)"
	@if ! command -v tmux &> /dev/null; then \
		echo "$(RED)Error: tmux is not installed. Please install tmux first.$(NC)"; \
		echo "Run: brew install tmux"; \
		exit 1; \
	fi
	@tmux new-session -d -s observability-dev
	@tmux rename-window -t observability-dev:0 'services'
	@tmux split-window -h -t observability-dev:0
	@tmux split-window -v -t observability-dev:0.0
	@tmux split-window -v -t observability-dev:0.1
	@tmux send-keys -t observability-dev:0.0 'cd go && PORT=$(GO_PORT) go run ./cmd/api' C-m
	@tmux send-keys -t observability-dev:0.1 'cd quarkus && export JAVA_HOME=$(JAVA_HOME) && export PATH=$(MAVEN_PATH):$$PATH && PORT=$(QUARKUS_PORT) mvn quarkus:dev' C-m
	@tmux send-keys -t observability-dev:0.2 'eval "$$($(CONDA_BASE)/bin/conda shell.bash hook)" && conda activate $(CONDA_ENV) && cd python && PORT=$(PYTHON_PORT) python app.py' C-m
	@tmux send-keys -t observability-dev:0.3 'cd node && PORT=$(NODE_PORT) GO_API_BASE=http://localhost:$(GO_PORT) PYTHON_API_BASE=http://localhost:$(PYTHON_PORT) QUARKUS_API_BASE=http://localhost:$(QUARKUS_PORT) npm start' C-m
	@tmux select-layout -t observability-dev:0 tiled
	@echo "$(GREEN)✓ All services started in tmux session 'observability-dev'$(NC)"
	@echo "$(YELLOW)Attach to session: tmux attach -t observability-dev$(NC)"
	@echo "$(YELLOW)Detach from session: Ctrl+B then D$(NC)"
	@echo "$(YELLOW)Kill session: tmux kill-session -t observability-dev$(NC)"
	@echo ""
	@echo "$(YELLOW)Waiting for services to start...$(NC)"
	@sleep 2
	@make status

start: python-check-env ## Start all services in background (requires tmux)
	@make dev

stop: ## Stop all services running in tmux
	@echo "$(YELLOW)Stopping all services...$(NC)"
	@tmux kill-session -t observability-dev 2>/dev/null || echo "$(YELLOW)No tmux session found$(NC)"
	@echo "$(GREEN)✓ All services stopped$(NC)"

status: ## Check the status of all services
	@echo "$(GREEN)Service Status:$(NC)"
	@echo ""
	@echo -n "$(YELLOW)Go Service (port $(GO_PORT)):$(NC) "
	@curl -s http://localhost:$(GO_PORT)/healthz > /dev/null 2>&1 && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not running$(NC)"
	@echo -n "$(YELLOW)Python Service (port $(PYTHON_PORT)):$(NC) "
	@curl -s http://localhost:$(PYTHON_PORT)/healthz > /dev/null 2>&1 && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not running$(NC)"
	@echo -n "$(YELLOW)Node Service (port $(NODE_PORT)):$(NC) "
	@curl -s http://localhost:$(NODE_PORT) > /dev/null 2>&1 && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not running$(NC)"
	@echo -n "$(YELLOW)Quarkus Service (port $(QUARKUS_PORT)):$(NC) "
	@for i in 1 2 3; do \
		curl -s -X POST http://localhost:$(QUARKUS_PORT)/api/lolcat -H "Content-Type: application/json" -d '{"text":"test","seed":0.0,"spread":3.0,"freq":0.1}' > /dev/null 2>&1 && { echo "$(GREEN)✓ Running$(NC)"; break; } || { \
			if [ $$i -eq 3 ]; then \
				echo "$(RED)✗ Not running$(NC)"; \
			else \
				sleep 1; \
			fi; \
		}; \
	done
	@echo ""
	@echo "$(YELLOW)Service URLs:$(NC)"
	@echo "  Go API:        http://localhost:$(GO_PORT)"
	@echo "  Python API:    http://localhost:$(PYTHON_PORT)"
	@echo "  Node Web UI:   http://localhost:$(NODE_PORT)"
	@echo "  Quarkus API:   http://localhost:$(QUARKUS_PORT)"

clean: ## Clean build artifacts
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	cd quarkus && export JAVA_HOME=$(JAVA_HOME) && export PATH=$(MAVEN_PATH):$$PATH && mvn clean
	@echo "$(GREEN)✓ Clean complete$(NC)"

build: ## Build all services
	@echo "$(GREEN)Building all services...$(NC)"
	@echo "$(YELLOW)Building Go service...$(NC)"
	cd go && go build -o bin/api ./cmd/api
	@echo "$(YELLOW)Building Quarkus service...$(NC)"
	cd quarkus && export JAVA_HOME=$(JAVA_HOME) && export PATH=$(MAVEN_PATH):$$PATH && mvn clean package -DskipTests
	@echo "$(GREEN)✓ All services built$(NC)"

logs: ## Show logs from tmux session
	@tmux capture-pane -t observability-dev:0.0 -p || echo "$(RED)No tmux session found$(NC)"

demo: ## Run a quick demo of the stack
	@echo "$(GREEN)Running demo...$(NC)"
	@echo ""
	@echo "$(YELLOW)1. Fetching name from Go service:$(NC)"
	@curl -s http://localhost:$(GO_PORT)/api/name | jq .
	@echo ""
	@echo "$(YELLOW)2. Getting seed from Python service:$(NC)"
	@curl -s http://localhost:$(PYTHON_PORT)/api/seed | jq .
	@echo ""
	@echo "$(YELLOW)3. Generating figlet art from Go service:$(NC)"
	@curl -s -X POST http://localhost:$(GO_PORT)/api/figlet \
		-H "Content-Type: application/json" \
		-d '{"names":["happy-hippo"]}'
	@echo ""
	@echo "$(YELLOW)4. Colorizing text with Quarkus service:$(NC)"
	@curl -s -X POST http://localhost:$(QUARKUS_PORT)/api/lolcat \
		-H "Content-Type: application/json" \
		-d '{"text":"Hello from the stack!"}' | jq .
	@echo ""
	@echo "$(GREEN)✓ Demo complete!$(NC)"
	@echo "$(YELLOW)Open http://localhost:$(NODE_PORT) in your browser to see the full UI$(NC)"

container-clean: ## Clean all cached container images and manifests
	@echo "$(YELLOW)Cleaning all cached container images and manifests...$(NC)"
	@echo "$(YELLOW)Removing manifests...$(NC)"
	-podman manifest rm $(REGISTRY)/observability-go-api:latest 2>/dev/null || true
	-podman manifest rm $(REGISTRY)/observability-node-app:latest 2>/dev/null || true
	-podman manifest rm $(REGISTRY)/observability-quarkus-api:latest 2>/dev/null || true
	-podman manifest rm $(REGISTRY)/observability-python-api:latest 2>/dev/null || true
	@echo "$(YELLOW)Removing images...$(NC)"
	-podman rmi $(REGISTRY)/observability-go-api:latest 2>/dev/null || true
	-podman rmi $(REGISTRY)/observability-node-app:latest 2>/dev/null || true
	-podman rmi $(REGISTRY)/observability-quarkus-api:latest 2>/dev/null || true
	-podman rmi $(REGISTRY)/observability-python-api:latest 2>/dev/null || true
	@echo "$(YELLOW)Pruning dangling images...$(NC)"
	-podman image prune -f 2>/dev/null || true
	@echo "$(GREEN)✓ Container cleanup complete$(NC)"

container-build-go: ## Build multi-arch Go service container
	@echo "$(GREEN)Building multi-arch Go service container...$(NC)"
	podman build --no-cache --platform=$(PLATFORMS) --manifest=$(REGISTRY)/observability-go-api:latest -f Containerfile.go-app .
	@echo "$(GREEN)✓ Go service container built$(NC)"

container-build-node: ## Build multi-arch Node.js service container
	@echo "$(GREEN)Building multi-arch Node.js service container...$(NC)"
	podman build --no-cache --platform=$(PLATFORMS) --manifest=$(REGISTRY)/observability-node-app:latest -f Containerfile.node-app .
	@echo "$(GREEN)✓ Node.js service container built$(NC)"

container-build-quarkus: ## Build multi-arch Quarkus service container
	@echo "$(GREEN)Building multi-arch Quarkus service container...$(NC)"
	podman build --no-cache --platform=$(PLATFORMS) --manifest=$(REGISTRY)/observability-quarkus-api:latest -f Containerfile.quarkus-app .
	@echo "$(GREEN)✓ Quarkus service container built$(NC)"

container-build-python: ## Build multi-arch Python service container
	@echo "$(GREEN)Building multi-arch Python service container...$(NC)"
	podman build --no-cache --platform=$(PLATFORMS) --manifest=$(REGISTRY)/observability-python-api:latest -f Containerfile.python-app .
	@echo "$(GREEN)✓ Python service container built$(NC)"

container-build: container-clean container-build-go container-build-node container-build-quarkus container-build-python ## Build all multi-arch containers

container-push-go: ## Push Go service container to registry
	@echo "$(GREEN)Pushing Go service container...$(NC)"
	podman manifest push $(REGISTRY)/observability-go-api:latest
	@echo "$(GREEN)✓ Go service container pushed$(NC)"

container-push-node: ## Push Node.js service container to registry
	@echo "$(GREEN)Pushing Node.js service container...$(NC)"
	podman manifest push $(REGISTRY)/observability-node-app:latest
	@echo "$(GREEN)✓ Node.js service container pushed$(NC)"

container-push-quarkus: ## Push Quarkus service container to registry
	@echo "$(GREEN)Pushing Quarkus service container...$(NC)"
	podman manifest push $(REGISTRY)/observability-quarkus-api:latest
	@echo "$(GREEN)✓ Quarkus service container pushed$(NC)"

container-push-python: ## Push Python service container to registry
	@echo "$(GREEN)Pushing Python service container...$(NC)"
	podman manifest push $(REGISTRY)/observability-python-api:latest
	@echo "$(GREEN)✓ Python service container pushed$(NC)"

container-push: container-push-go container-push-node container-push-quarkus container-push-python ## Push all containers to registry

container-run: ## Run all container images locally for testing
	@echo "$(GREEN)Starting all containers locally...$(NC)"
	@echo "$(YELLOW)Stopping any existing containers...$(NC)"
	@-podman stop observability-go-api observability-node-app observability-quarkus-api observability-python-api 2>/dev/null || true
	@-podman rm observability-go-api observability-node-app observability-quarkus-api observability-python-api 2>/dev/null || true
	@echo "$(YELLOW)Starting Go service container...$(NC)"
	podman run -d --name observability-go-api \
		-p $(GO_PORT):4001 \
		-e PORT=4001 \
		$(REGISTRY)/observability-go-api:latest
	@echo "$(YELLOW)Starting Python service container...$(NC)"
	podman run -d --name observability-python-api \
		-p $(PYTHON_PORT):4004 \
		-e PORT=4004 \
		$(REGISTRY)/observability-python-api:latest
	@echo "$(YELLOW)Starting Quarkus service container...$(NC)"
	podman run -d --name observability-quarkus-api \
		-p $(QUARKUS_PORT):4003 \
		-e PORT=4003 \
		$(REGISTRY)/observability-quarkus-api:latest
	@echo "$(YELLOW)Starting Node.js service container...$(NC)"
	podman run -d --name observability-node-app \
		-p $(NODE_PORT):4002 \
		-e PORT=4002 \
		-e GO_API_BASE=http://host.containers.internal:$(GO_PORT) \
		-e PYTHON_API_BASE=http://host.containers.internal:$(PYTHON_PORT) \
		-e QUARKUS_API_BASE=http://host.containers.internal:$(QUARKUS_PORT) \
		$(REGISTRY)/observability-node-app:latest
	@echo "$(GREEN)✓ All containers started$(NC)"
	@echo ""
	@echo "$(YELLOW)Waiting for services to become ready...$(NC)"
	@sleep 3
	@make container-status

container-stop: ## Stop all running containers
	@echo "$(YELLOW)Stopping all containers...$(NC)"
	@-podman stop observability-go-api observability-node-app observability-quarkus-api observability-python-api 2>/dev/null || true
	@-podman rm observability-go-api observability-node-app observability-quarkus-api observability-python-api 2>/dev/null || true
	@echo "$(GREEN)✓ All containers stopped and removed$(NC)"

container-status: ## Check status of running containers
	@echo "$(GREEN)Container Status:$(NC)"
	@echo ""
	@echo -n "$(YELLOW)Go Service Container:$(NC) "
	@podman ps --filter "name=observability-go-api" --format "{{.Status}}" 2>/dev/null | grep -q "Up" && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not running$(NC)"
	@echo -n "$(YELLOW)Python Service Container:$(NC) "
	@podman ps --filter "name=observability-python-api" --format "{{.Status}}" 2>/dev/null | grep -q "Up" && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not running$(NC)"
	@echo -n "$(YELLOW)Node Service Container:$(NC) "
	@podman ps --filter "name=observability-node-app" --format "{{.Status}}" 2>/dev/null | grep -q "Up" && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not running$(NC)"
	@echo -n "$(YELLOW)Quarkus Service Container:$(NC) "
	@podman ps --filter "name=observability-quarkus-api" --format "{{.Status}}" 2>/dev/null | grep -q "Up" && echo "$(GREEN)✓ Running$(NC)" || echo "$(RED)✗ Not running$(NC)"
	@echo ""
	@echo "$(YELLOW)Testing service endpoints...$(NC)"
	@echo -n "  Go API (port $(GO_PORT)):        "
	@curl -s http://localhost:$(GO_PORT)/healthz > /dev/null 2>&1 && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(RED)✗ Not responding$(NC)"
	@echo -n "  Python API (port $(PYTHON_PORT)):   "
	@curl -s http://localhost:$(PYTHON_PORT)/healthz > /dev/null 2>&1 && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(RED)✗ Not responding$(NC)"
	@echo -n "  Node Web UI (port $(NODE_PORT)):   "
	@curl -s http://localhost:$(NODE_PORT) > /dev/null 2>&1 && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(RED)✗ Not responding$(NC)"
	@echo -n "  Quarkus API (port $(QUARKUS_PORT)):   "
	@curl -s -X POST http://localhost:$(QUARKUS_PORT)/api/lolcat -H "Content-Type: application/json" -d '{"text":"test"}' > /dev/null 2>&1 && echo "$(GREEN)✓ Healthy$(NC)" || echo "$(RED)✗ Not responding$(NC)"
	@echo ""
	@echo "$(YELLOW)Service URLs:$(NC)"
	@echo "  Go API:        http://localhost:$(GO_PORT)"
	@echo "  Python API:    http://localhost:$(PYTHON_PORT)"
	@echo "  Node Web UI:   http://localhost:$(NODE_PORT)"
	@echo "  Quarkus API:   http://localhost:$(QUARKUS_PORT)"

container-logs: ## Show logs from all running containers
	@echo "$(GREEN)Container Logs:$(NC)"
	@echo ""
	@echo "$(YELLOW)=== Go Service Logs ====$(NC)"
	@podman logs --tail 20 observability-go-api 2>/dev/null || echo "$(RED)Container not running$(NC)"
	@echo ""
	@echo "$(YELLOW)=== Python Service Logs ====$(NC)"
	@podman logs --tail 20 observability-python-api 2>/dev/null || echo "$(RED)Container not running$(NC)"
	@echo ""
	@echo "$(YELLOW)=== Node Service Logs ====$(NC)"
	@podman logs --tail 20 observability-node-app 2>/dev/null || echo "$(RED)Container not running$(NC)"
	@echo ""
	@echo "$(YELLOW)=== Quarkus Service Logs ====$(NC)"
	@podman logs --tail 20 observability-quarkus-api 2>/dev/null || echo "$(RED)Container not running$(NC)"

.DEFAULT_GOAL := help

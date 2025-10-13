.PHONY: help install start stop clean test dev go-service node-service quarkus-service status \
	container-build container-build-go container-build-node container-build-quarkus \
	container-push container-push-go container-push-node container-push-quarkus

# Configuration
GO_PORT ?= 4001
NODE_PORT ?= 4002
QUARKUS_PORT ?= 4003
JAVA_HOME ?= /opt/homebrew/opt/openjdk@21
MAVEN_PATH ?= /opt/apache-maven-3.8.8/bin
REGISTRY ?= quay.io/cldmnk
PLATFORMS ?= linux/amd64,linux/arm64

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

install: ## Install all dependencies for all services
	@echo "$(GREEN)Installing dependencies...$(NC)"
	@echo "$(YELLOW)Installing Go dependencies...$(NC)"
	cd go && go mod download
	@echo "$(YELLOW)Installing Node.js dependencies...$(NC)"
	cd node && npm install
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

dev: ## Start all services in development mode (requires tmux)
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
	@tmux send-keys -t observability-dev:0.0 'cd go && PORT=$(GO_PORT) go run ./cmd/api' C-m
	@tmux send-keys -t observability-dev:0.1 'cd quarkus && export JAVA_HOME=$(JAVA_HOME) && export PATH=$(MAVEN_PATH):$$PATH && PORT=$(QUARKUS_PORT) mvn quarkus:dev' C-m
	@tmux send-keys -t observability-dev:0.2 'cd node && PORT=$(NODE_PORT) npm start' C-m
	@tmux select-layout -t observability-dev:0 even-horizontal
	@echo "$(GREEN)✓ All services started in tmux session 'observability-dev'$(NC)"
	@echo "$(YELLOW)Attach to session: tmux attach -t observability-dev$(NC)"
	@echo "$(YELLOW)Detach from session: Ctrl+B then D$(NC)"
	@echo "$(YELLOW)Kill session: tmux kill-session -t observability-dev$(NC)"
	@echo ""
	@echo "$(YELLOW)Waiting for services to start...$(NC)"
	@sleep 2
	@make status

start: ## Start all services in background (requires tmux)
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
	@echo "$(YELLOW)2. Generating figlet art from Go service:$(NC)"
	@curl -s -X POST http://localhost:$(GO_PORT)/api/figlet \
		-H "Content-Type: application/json" \
		-d '{"names":["happy-hippo"]}'
	@echo ""
	@echo "$(YELLOW)3. Colorizing text with Quarkus service:$(NC)"
	@curl -s -X POST http://localhost:$(QUARKUS_PORT)/api/lolcat \
		-H "Content-Type: application/json" \
		-d '{"text":"Hello from the stack!"}' | jq .
	@echo ""
	@echo "$(GREEN)✓ Demo complete!$(NC)"
	@echo "$(YELLOW)Open http://localhost:$(NODE_PORT) in your browser to see the full UI$(NC)"

container-build-go: ## Build multi-arch Go service container
	@echo "$(GREEN)Building multi-arch Go service container...$(NC)"
	podman build --platform=$(PLATFORMS) --manifest=$(REGISTRY)/observability-go-api:latest -f Containerfile.go-app .
	@echo "$(GREEN)✓ Go service container built$(NC)"

container-build-node: ## Build multi-arch Node.js service container
	@echo "$(GREEN)Building multi-arch Node.js service container...$(NC)"
	podman build --platform=$(PLATFORMS) --manifest=$(REGISTRY)/observability-node-app:latest -f Containerfile.node-app .
	@echo "$(GREEN)✓ Node.js service container built$(NC)"

container-build-quarkus: ## Build multi-arch Quarkus service container
	@echo "$(GREEN)Building multi-arch Quarkus service container...$(NC)"
	podman build --platform=$(PLATFORMS) --manifest=$(REGISTRY)/observability-quarkus-api:latest -f Containerfile.quarkus-app .
	@echo "$(GREEN)✓ Quarkus service container built$(NC)"

container-build: container-build-go container-build-node container-build-quarkus ## Build all multi-arch containers

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

container-push: container-push-go container-push-node container-push-quarkus ## Push all containers to registry

.DEFAULT_GOAL := help

# Setup Guide - Observability Developer Day 2025

## Prerequisites

- **Go** 1.24+ (for Go service)
- **Node.js** 20+ (for Node.js service)
- **Java** 21 (for Quarkus service)
- **Maven** 3.8+ (for Quarkus builds)
- **Miniforge** (for Python conda environment)
- **tmux** (for development mode)
- **Podman** (for container builds)

## Quick Start

### 1. Install System Dependencies

```bash
# macOS
brew install go node openjdk@21 maven miniforge tmux podman

# Set Java home (add to your shell profile)
export JAVA_HOME=/opt/homebrew/opt/openjdk@21
```

### 2. Clone and Setup

```bash
# Clone the repository
git clone https://github.com/cldmnky/observability-developer-day-2025.git
cd observability-developer-day-2025

# Install all dependencies (creates conda env automatically)
make install
```

### 3. Start All Services

```bash
# Start all services in tmux
make dev

# Attach to tmux session to see all services
tmux attach -t observability-dev

# Detach from tmux: Ctrl+B then D
```

### 4. Access the Services

- **Web UI**: http://localhost:4002
- **Go API**: http://localhost:4001
- **Python API**: http://localhost:4004
- **Quarkus API**: http://localhost:4003

## Python Conda Environment

The Python service uses a dedicated conda environment for isolation and reproducibility.

### Environment Details

- **Name**: `observability-python`
- **Python Version**: 3.12
- **Location**: `~/miniforge3/envs/observability-python`

### Manual Environment Management

```bash
# Create environment
make python-create-env

# Check if environment exists
make python-check-env

# View environment info
make python-env-help

# Activate manually
eval "$(~/miniforge3/bin/conda shell.bash hook)"
conda activate observability-python

# Deactivate
conda deactivate
```

### Installing New Python Packages

```bash
# Activate the environment
eval "$(~/miniforge3/bin/conda shell.bash hook)"
conda activate observability-python

# Install packages
pip install <package-name>

# Update requirements.txt
cd python
pip freeze > requirements.txt
```

## Service Architecture

```
┌─────────────────────────────────────────────┐
│  Node.js Web App (4002)                     │
│  ├─ Proxies to Go API (4001)                │
│  ├─ Proxies to Python API (4004)            │
│  ├─ Proxies to Quarkus API (4003)           │
│  └─ Background worker (continuous load)     │
└─────────────────────────────────────────────┘
         ↓           ↓           ↓
    ┌────────┐  ┌────────┐  ┌────────┐
    │   Go   │  │ Python │  │Quarkus │
    │  4001  │  │  4004  │  │  4003  │
    │        │  │ (conda)│  │        │
    └────────┘  └────────┘  └────────┘
```

## Makefile Targets

### Development
- `make help` - Show all available targets
- `make install` - Install all dependencies
- `make dev` - Start all services in tmux
- `make start` - Alias for `make dev`
- `make stop` - Stop all services
- `make status` - Check service health
- `make demo` - Run API demo

### Individual Services
- `make go-service` - Run Go service only
- `make python-service` - Run Python service only (with conda)
- `make node-service` - Run Node.js service only
- `make quarkus-service` - Run Quarkus service only

### Testing
- `make test` - Run all tests
- `make clean` - Clean build artifacts

### Containers
- `make container-build` - Build all containers
- `make container-build-go` - Build Go container
- `make container-build-python` - Build Python container
- `make container-build-node` - Build Node.js container
- `make container-build-quarkus` - Build Quarkus container
- `make container-push` - Push all containers to registry
- `make container-run` - Run all containers locally
- `make container-stop` - Stop all running containers
- `make container-status` - Check container status
- `make container-logs` - View container logs

### Python/Conda
- `make python-env-help` - Show conda activation guide
- `make python-create-env` - Create conda environment
- `make python-check-env` - Validate conda environment exists

## Configuration

All service ports can be customized via environment variables:

```bash
export GO_PORT=4001
export NODE_PORT=4002
export QUARKUS_PORT=4003
export PYTHON_PORT=4004

make dev
```

## Observability Features

### Background Worker

The Node.js service includes a background worker that continuously:
- Queries the Python seed API (with 0.1-5s random delay)
- Generates names from the Go API
- Logs all activity
- Tracks statistics

**View worker stats:**
```bash
curl http://localhost:4002/api/worker/stats
```

### Web UI Auto-Refresh

The web UI at http://localhost:4002 includes:
- Manual name generation button
- **Auto Refresh** checkbox for continuous generation
- Terminal display with 160-column width
- Optional lolcat colorization
- Real-time API interaction visualization

### Variable Latency

The Python seed API includes random delays (0.1-5s) to simulate:
- Realistic processing time
- Variable network conditions
- Load testing scenarios
- Distributed tracing demonstrations

## Troubleshooting

### Python Service Won't Start

```bash
# Check if conda is installed
which conda

# Install miniforge if needed
brew install miniforge

# Create conda environment
make python-create-env

# Verify it exists
make python-check-env
```

### Services Not Responding

```bash
# Stop everything
make stop

# Check for processes using the ports
lsof -i :4001
lsof -i :4002
lsof -i :4003
lsof -i :4004

# Restart
make dev
```

### Tmux Session Issues

```bash
# List all tmux sessions
tmux ls

# Kill stuck session
tmux kill-session -t observability-dev

# Restart services
make dev
```

### Java/Maven Issues

```bash
# Verify Java version
java -version

# Should be Java 21
export JAVA_HOME=/opt/homebrew/opt/openjdk@21

# Verify Maven
mvn --version
```

## Container Development

### Building Multi-Arch Images

All Containerfiles support both amd64 and arm64 architectures:

```bash
# Build all images
make container-build

# Build specific service
make container-build-python

# Push to registry (requires authentication)
make container-push
```

### Testing Containers Locally

```bash
# Build all containers
make container-build

# Run all containers
make container-run

# Check status
make container-status

# View logs
make container-logs

# Stop all containers
make container-stop
```

### Container Registry

Images are pushed to `quay.io/cldmnky/`:
- `observability-go-api:latest`
- `observability-python-api:latest`
- `observability-node-app:latest`
- `observability-quarkus-api:latest`

## Development Tips

### Viewing Logs

```bash
# Attach to tmux to see all service logs
tmux attach -t observability-dev

# Navigate between panes:
# Ctrl+B then arrow keys

# Copy mode:
# Ctrl+B then [
# Use arrow keys to scroll
# Press q to exit
```

### Restarting Individual Services

In the tmux session:
1. Attach: `tmux attach -t observability-dev`
2. Navigate to the service pane
3. `Ctrl+C` to stop the service
4. Press Up arrow to get the last command
5. Press Enter to restart

### Monitoring Background Worker

```bash
# Watch worker stats in real-time
watch -n 1 'curl -s http://localhost:4002/api/worker/stats | python3 -m json.tool'
```

## License

See LICENSE file for details.

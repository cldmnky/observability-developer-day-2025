# Observability Developer Day 2025

Demo showcasing auto-instrumentation in OpenShift with OpenTelemetry for distributed tracing and metrics without code changes.

## 🚀 Quick Start

### Run the Demo

```bash
# Install operators and observability stack (5-10 minutes)
./demo-prep.sh

# Run interactive demo (10-12 minutes)
./demo.sh

# Clean up demo resources
./demo-cleanup.sh
```

### Local Development

```bash
# Install dependencies
make install

# Start all services (requires tmux)
make dev

# Stop services
make stop
```

## Architecture

Four microservices demonstrating auto-instrumentation:

- **Go API** (port 8080) - Name generator with ASCII art
- **Python API** (port 8000) - Seed generator with variable latency
- **Quarkus API** (port 4003) - Lolcat colorization service
- **Node.js App** (port 3000) - Web UI with background worker

## What's Demonstrated

✅ **Zero-code observability** - OpenTelemetry auto-instrumentation  
✅ **Distributed tracing** - Request flow across all services  
✅ **Metrics collection** - Prometheus via ServiceMonitors  
✅ **RED metrics** - Auto-generated from traces (Rate, Errors, Duration)  
✅ **OpenShift integration** - Native observability in Console UI

## Prerequisites

### For Demo (OpenShift)

- OpenShift 4.19+
- Cluster admin access
- `oc` CLI configured

### For Local Development

- Go 1.20+
- Node.js 18+
- Java 21
- Maven 3.8.8

## Demo Scripts

| Script | Purpose | Duration |
|--------|---------|----------|
| `demo-prep.sh` | Install operators and stacks | 5-10 min |
| `demo.sh` | Interactive live demo | 10-12 min |
| `demo-cleanup.sh` | Remove demo resources | 1 min |

## Key Endpoints

- **Web UI**: <http://localhost:3000> (or OpenShift Route)
- **Go API**: <http://localhost:8080/api/name>
- **Python API**: <http://localhost:8000/api/seed>
- **Quarkus API**: <http://localhost:4003/api/lolcat>

## Container Images

Build and push images:

```bash
make container-build
make container-push
```

Pre-built images available at:

- `quay.io/cldmnky/observability-go-api:latest`
- `quay.io/cldmnky/observability-python-api:latest`
- `quay.io/cldmnky/observability-quarkus-api:latest`
- `quay.io/cldmnky/observability-node-app:latest`

## Documentation

- [DEMO.md](./DEMO.md) - Complete demo guide with architecture diagrams
- [DEMO_QUICK_START.md](./DEMO_QUICK_START.md) - Quick reference guide
- [SETUP.md](./SETUP.md) - Manual installation instructions

## Key Technologies

- **OpenTelemetry** - Auto-instrumentation for all languages
- **Tempo** - Distributed tracing backend
- **Prometheus** - Metrics collection and storage
- **Cluster Observability Operator** - OpenShift observability stack
- **Perses** - Modern dashboard framework

## Project Structure

```text
.
├── demo-prep.sh          # Pre-demo setup
├── demo.sh               # Interactive demo script
├── demo-cleanup.sh       # Cleanup script
├── DEMO.md               # Full demo guide
├── manifests/            # Kubernetes/OpenShift manifests
│   ├── 1-apps/           # Application deployments
│   ├── 2-observability-stack/  # COO and Tempo
│   ├── 3-servicemonitors/      # Prometheus scraping
│   ├── 4-opentelemetry/        # OTel collectors
│   └── 5-coo-setup/            # Dashboards
├── go/                   # Go service source
├── python/               # Python service source
├── quarkus/              # Quarkus service source
└── node/                 # Node.js service source
```

## License

See individual service directories for licensing information.

---

**Prepared for Observability Developer Day 2025**  


# OpenShift Observability Demo Guide

**Session:** Seamless tracing, metrics, and logs without touching a single line of code  
**Presenters:** Roger Florén, Magnus Bengtsson  
**Duration:** 10-12 minutes

This demo showcases OpenShift's auto-instrumentation capabilities using OpenTelemetry, Tempo, and the Cluster Observability Operator (COO) to achieve full-stack observability without modifying application code.

---

## 🚀 Quick Start

### Before the Demo (Pre-requisites)

Run the preparation script to install operators and observability stacks:

```bash
./demo-prep.sh
```

This installs (takes ~5-10 minutes):
- Cluster Observability Operator (COO)
- Tempo Operator
- OpenTelemetry Operator
- MonitoringStack (Prometheus + Thanos)
- TempoStack (Tempo with MinIO storage)
- OpenShift Console UI Plugins

### Demo Execution

Run the interactive demo script:

```bash
./demo.sh
```

### After the Demo

Clean up demo resources (keeps operators and stacks):

```bash
./demo-cleanup.sh
```

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture Diagrams](#architecture-diagrams)
- [Demo Flow (10-12 minutes)](#demo-flow-10-12-minutes)
- [Detailed Steps](#detailed-steps)
- [Verification & Troubleshooting](#verification--troubleshooting)
- [Key Talking Points](#key-talking-points)

---

## Overview

### The Application Stack

A multi-service microservices application consisting of:

1. **Go API** (port 8080) - Name generator service that creates whimsical adjective-animal combinations and ASCII art (figlet)
2. **Python API** (port 8000) - Seed generator service that provides random seed values for colorization (with variable latency simulation)
3. **Quarkus API** (port 4003) - Lolcat colorization service that adds rainbow ANSI colors to text
4. **Node.js Web App** (port 3000) - Web frontend with terminal UI that orchestrates all services
   - Proxies requests to backend APIs
   - Runs continuous background worker polling Python API → Go API
   - Demonstrates service mesh communication patterns

### What We'll Demonstrate

✅ **Zero-code instrumentation** - OpenTelemetry auto-instrumentation without touching application code  
✅ **Distributed tracing** - Request flow visualization across all services  
✅ **Metrics collection** - Prometheus metrics from all services via ServiceMonitors  
✅ **Span metrics (RED)** - Request rate, Error rate, Duration metrics auto-generated from traces  
✅ **OpenShift Console integration** - Native observability UI in OpenShift Console

---

## Architecture Diagrams

### High-Level Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           User Browser                                   │
│                                                                           │
│                    https://node-app-route.apps.cluster.com              │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    observability-demo namespace                          │
│                                                                           │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                       Node.js Web App                             │  │
│  │                          (port 3000)                              │  │
│  │                                                                   │  │
│  │  • Web UI with terminal emulator                                 │  │
│  │  • Proxies requests to backend APIs                              │  │
│  │  • Background worker: Python API → Go API (continuous polling)   │  │
│  └────────┬────────────────────┬────────────────────┬───────────────┘  │
│           │                    │                    │                   │
│           ▼                    ▼                    ▼                   │
│  ┌────────────────┐   ┌─────────────────┐   ┌───────────────────────┐ │
│  │   Go API       │   │  Python API     │   │   Quarkus API         │ │
│  │   (port 8080)  │   │  (port 8000)    │   │   (port 4003)         │ │
│  │                │   │                 │   │                       │ │
│  │ • Name gen     │   │ • Seed gen      │   │ • Lolcat colorize     │ │
│  │ • ASCII art    │   │ • Random delay  │   │ • Rainbow ANSI        │ │
│  │ • /metrics     │   │ • /metrics      │   │ • /metrics            │ │
│  └────────────────┘   └─────────────────┘   └───────────────────────┘ │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘
```

### Observability Stack Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      APPLICATION PODS (observability-demo)                  │
│                                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   go-api    │  │ python-api  │  │ quarkus-api │  │  node-app   │         │
│  │             │  │             │  │             │  │             │         │
│  │  [app code] │  │  [app code] │  │  [app code] │  │  [app code] │         │
│  │      ↓      │  │      ↓      │  │      ↓      │  │      ↓      │         │
│  │ Auto-Instr  │  │ Auto-Instr  │  │ Auto-Instr  │  │ Auto-Instr  │         │
│  │   (init)    │  │   (init)    │  │   (init)    │  │   (init)    │         │
│  │      ↓      │  │      ↓      │  │      ↓      │  │      ↓      │         │
│  │   OTLP →    │  │   OTLP →    │  │   OTLP →    │  │   OTLP →    │         │
│  │  localhost  │  │  localhost  │  │  localhost  │  │  localhost  │         │
│  │    :4318    │  │    :4318    │  │    :4318    │  │    :4318    │         │
│  │      ↓      │  │      ↓      │  │      ↓      │  │      ↓      │         │
│  │  [Sidecar]  │  │  [Sidecar]  │  │  [Sidecar]  │  │  [Sidecar]  │         │
│  │  Collector  │  │  Collector  │  │  Collector  │  │  Collector  │         │
│  │  :4317/:18  │  │  :4317/:18  │  │  :4317/:18  │  │  :4317/:18  │         │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘         │
│         │                │                │                │                │
│         └────────────────┴────────────────┴────────────────┘                │
│                                  │                                          │
│                                  ▼                                          │
│                    ┌──────────────────────────────┐                         │
│                    │   Central Collector          │                         │
│                    │   (Deployment, 2 replicas)   │                         │
│                    │                              │                         │
│                    │  Receives: OTLP gRPC/HTTP    │                         │
│                    │  Processes:                  │                         │
│                    │   • Resource detection       │                         │
│                    │   • K8s attributes           │                         │
│                    │   • Batching                 │                         │
│                    │                              │                         │
│                    │  Connectors:                 │                         │
│                    │   • Span→Metrics (RED)       │                         │
│                    │                              │                         │
│                    │  Exports:                    │                         │
│                    │   • Traces → Tempo           │                         │
│                    │   • Metrics → Prometheus     │                         │
│                    └───────┬──────────────┬───────┘                         │
│                            │              │                                 │
└────────────────────────────┼──────────────┼─────────────────────────────────┘
                             │              │
            ┌────────────────┘              └──────────────────┐
            ▼                                                  ▼
┌───────────────────────────┐                  ┌─────────────────────────────┐
│  openshift-tempo-operator │                  │   observability-demo        │
│                           │                  │                             │
│  ┌─────────────────────┐  │                  │  ┌───────────────────────┐  │
│  │    TempoStack       │  │                  │  │   MonitoringStack     │  │
│  │                     │  │                  │  │                       │  │
│  │  • Distributor      │  │                  │  │  • Prometheus (x3)    │  │
│  │  • Ingester         │  │                  │  │  • Alertmanager (x2)  │  │
│  │  • Querier          │  │                  │  │  • Thanos Querier     │  │
│  │  • Query Frontend   │  │                  │  │                       │  │
│  │                     │  │                  │  │  ServiceMonitors:     │  │
│  │  Storage: MinIO S3  │  │                  │  │   • go-api            |  │
│  │  Retention: 48h     │  │                  │  │   • python-api        │  │
│  │  Tenants: dev,prod  │  │                  │  │   • quarkus-api       │  │
│  │                     │  │                  │  │   • node-app          │  │
│  │  Jaeger UI: ✓       │  │                  │  │   • central-collector │  │
│  └─────────────────────┘  │                  │  └───────────────────────┘  │
└───────────────────────────┘                  └─────────────────────────────┘
            │                                                  │
            ▼                                                  ▼
┌───────────────────────────┐                  ┌─────────────────────────────┐
│  OpenShift Console        │                  │  OpenShift Console          │
│                           │                  │                             │
│  Observe → Traces         │                  │  Observe → Metrics          │
│  (Distributed Tracing UI) │                  │  (Monitoring UI + Perses)   │
└───────────────────────────┘                  └─────────────────────────────┘
```

### Request Flow with Instrumentation

```
User Request
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│ Node.js App Pod                                                 │
│                                                                 │
│  HTTP Request                                                   │
│       ↓                                                         │
│  ┌────────────────────────────────────────┐                     │
│  │ Auto-Instrumentation (init container)  │                     │
│  │ • Injects OpenTelemetry SDK            │                     │
│  │ • Sets OTEL_* env vars                 │                     │
│  │ • Configures OTLP endpoint             │                     │
│  └────────────────────────────────────────┘                     │
│       ↓                                                         │
│  ┌────────────────────────────────────────┐                     │
│  │ Express.js App (instrumented)          │                     │
│  │ • Automatic span creation              │                     │
│  │ • Context propagation (W3C)            │                     │
│  │ • Trace ID in logs                     │                     │
│  └────────────────────────────────────────┘                     │
│       ↓ (OTLP to localhost:4318)                                │
│  ┌────────────────────────────────────────┐                     │
│  │ Sidecar Collector                      │                     │
│  │ • Receives OTLP                        │                     │
│  │ • Adds K8s metadata                    │                     │
│  │ • Forwards to central                  │                     │
│  └────────────────────────────────────────┘                     │
│       ↓                                                         │
└───────┼─────────────────────────────────────────────────────────┘
        │
        │ (calls Python API)
        ▼
┌─────────────────────────────────────────────────────────────────┐
│ Python API Pod                                                  │
│                                                                 │
│  HTTP Request (with trace context in headers)                   │
│       ↓                                                         │
│  ┌────────────────────────────────────────┐                     │
│  │ Auto-Instrumentation                   │                     │
│  │ • Python OpenTelemetry agent           │                     │
│  │ • Extracts parent trace context        │                     │
│  │ • Creates child span                   │                     │
│  └────────────────────────────────────────┘                     │
│       ↓                                                         │
│  ┌────────────────────────────────────────┐                     │
│  │ FastAPI App (instrumented)             │                     │
│  │ • GET /api/seed                        │                     │
│  │ • Random delay (0.1s - 5s)             │                     │
│  │ • Returns seed value                   │                     │
│  └────────────────────────────────────────┘                     │
│       ↓ (OTLP to localhost:4318)                                │
│  ┌────────────────────────────────────────┐                     │
│  │ Sidecar Collector                      │                     │
│  └────────────────────────────────────────┘                     │
│       ↓                                                         │
└───────┼─────────────────────────────────────────────────────────┘
        │
        ▼
    [Central Collector → Tempo/Prometheus]
    
    Complete Distributed Trace:
    └─ node-app: GET /api/seed (proxy)
       └─ python-api: GET /api/seed
          ├─ duration: 2.3s
          ├─ span attributes: http.method, http.status_code, k8s.pod.name
          └─ exemplar linked to metric: traces_spanmetrics_latency
```

### Metrics & Traces Integration (RED Metrics)

```
┌─────────────────────────────────────────────────────────────────┐
│              Central Collector - Span Metrics                    │
│                                                                   │
│  Traces Pipeline:                                                │
│                                                                   │
│    OTLP Receiver                                                 │
│         ↓                                                         │
│    Processors (k8s attrs, resource detection)                    │
│         ↓                                                         │
│    ┌────────────────────────────────┐                           │
│    │  Tempo Exporter (traces)       │                           │
│    └────────────────────────────────┘                           │
│         ↓                                                         │
│    ┌────────────────────────────────┐                           │
│    │  SpanMetrics Connector         │                           │
│    │                                │                           │
│    │  Generates RED Metrics:        │                           │
│    │                                │                           │
│    │  ✓ Rate (Requests/sec)         │                           │
│    │    traces_spanmetrics_calls    │                           │
│    │    _total                      │                           │
│    │                                │                           │
│    │  ✓ Errors (by status code)     │                           │
│    │    traces_spanmetrics_calls    │                           │
│    │    _total{status_code="500"}   │                           │
│    │                                │                           │
│    │  ✓ Duration (latency p50/p95)  │                           │
│    │    traces_spanmetrics_latency  │                           │
│    │    _bucket                     │                           │
│    │                                │                           │
│    │  With Exemplars:               │                           │
│    │    trace_id, span_id           │                           │
│    │    (click metric → view trace) │                           │
│    └────────────────────────────────┘                           │
│         ↓                                                         │
│    Metrics Transform (rename)                                    │
│         ↓                                                         │
│    Prometheus Remote Write                                       │
│         ↓                                                         │
│    MonitoringStack (Prometheus)                                  │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘

Query in Prometheus:
┌─────────────────────────────────────────────────────────────────┐
│                                                                   │
│  # Request rate per service                                      │
│  rate(traces_spanmetrics_calls_total[5m])                       │
│                                                                   │
│  # P95 latency                                                   │
│  histogram_quantile(0.95,                                        │
│    rate(traces_spanmetrics_latency_bucket[5m])                  │
│  )                                                               │
│                                                                   │
│  # Error rate                                                    │
│  rate(traces_spanmetrics_calls_total{status_code="500"}[5m])   │
│                                                                   │
│  Click on data point → View exemplar → Jump to trace in Tempo   │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites (Pre-Demo Setup)

These steps should be completed **before** the demo session to save time:

### 1. Operator Installations

```bash
# Cluster Observability Operator
oc apply -f manifests/2-observability-stack/coo-namespace.yaml
oc apply -f manifests/2-observability-stack/coo-operatorgroup.yaml
oc apply -f manifests/2-observability-stack/coo-subscription.yaml

# Tempo Operator
oc apply -f manifests/2-observability-stack/tempo-namespace.yaml
oc apply -f manifests/2-observability-stack/tempo-operatorgroup.yaml
oc apply -f manifests/2-observability-stack/tempo-subscription.yaml

# OpenTelemetry Operator
oc apply -f manifests/4-opentelemetry/subscription.yaml

# Wait for operators to be ready
oc wait --for=condition=Available csv -n openshift-cluster-observability-operator \
  --selector=operators.coreos.com/cluster-observability-operator.openshift-cluster-observability-operator \
  --timeout=300s

oc wait --for=condition=Available csv -n openshift-tempo-operator \
  --selector=operators.coreos.com/tempo-operator.openshift-tempo-operator \
  --timeout=300s

oc wait --for=condition=Available csv -n openshift-operators \
  --selector=operators.coreos.com/opentelemetry-operator.openshift-operators \
  --timeout=300s
```

### 2. Observability Stack Deployment

```bash
# Deploy MonitoringStack (Prometheus + Thanos Querier)
oc apply -f manifests/2-observability-stack/coo-monitoring-stack.yaml

# Deploy TempoStack (distributed tracing backend)
oc apply -f manifests/2-observability-stack/tempo-secret.yaml
oc apply -f manifests/2-observability-stack/tempo-rbac.yaml
oc apply -f manifests/2-observability-stack/tempostack.yaml

# Verify stacks are ready
oc wait --for=condition=Available monitoringstack/observability-stack \
  -n observability-demo --timeout=300s

oc wait --for=condition=Ready tempostack/tempo \
  -n openshift-tempo-operator --timeout=300s
```

### 3. UI Plugins (Optional but Recommended)

```bash
# Enable monitoring UI with Perses dashboards
oc apply -f manifests/5-coo-setup/uiplugin-monitoring.yaml

# Enable distributed tracing UI
oc apply -f manifests/5-coo-setup/uiplugin-distributed-tracing.yaml

# Configure Perses datasource for observability-demo MonitoringStack
oc apply -f manifests/5-coo-setup/perses-datasource.yaml

# Verify console plugins are registered
oc get console.operator.openshift.io cluster -o jsonpath='{.spec.plugins}'

# Verify Perses datasource is available
oc get persesdatasource -n openshift-cluster-observability-operator
```

### 4. Container Images

Ensure container images are built and pushed:

```bash
# Build and push all container images
make container-build-go && make container-push-go
make container-build-python && make container-push-python
make container-build-quarkus && make container-push-quarkus
make container-build-node && make container-push-node

# Or use pre-built images from quay.io/cldmnky/
```

---

## Demo Flow (10-12 minutes)

The demo is divided into 4 phases, all automated via `./demo.sh`:

### Phase 1: Deploy Applications (2 minutes)

- Deploy 4 microservices (Go, Python, Quarkus, Node.js)
- Access web UI and demonstrate functionality
- **Prove zero instrumentation code** in applications

### Phase 2: Enable Metrics Collection (2 minutes)

- Deploy ServiceMonitors with label selectors
- Verify Prometheus is scraping targets
- Query built-in framework metrics

### Phase 3: Enable Distributed Tracing (4 minutes)

- Deploy OpenTelemetry collectors (central + sidecar)
- Deploy auto-instrumentation configuration
- **Add 2 annotations** to each deployment (only change!)
- Verify sidecars and instrumentation are injected

### Phase 4: Visualize & Query (2-4 minutes)

- View distributed traces in Jaeger UI
- Query RED metrics auto-generated from traces
- Show Perses dashboard in OpenShift Console
- Demonstrate trace-to-metric correlation

---

## Detailed Steps

### Phase 1: Deploy Applications

#### Step 1.1: Create Namespace and Deploy Services

```bash
# Create namespace
oc apply -f manifests/1-apps/namespace.yaml

# Deploy all applications
oc apply -f manifests/1-apps/go-api-deployment.yaml
oc apply -f manifests/1-apps/python-api-deployment.yaml
oc apply -f manifests/1-apps/quarkus-api-deployment.yaml
oc apply -f manifests/1-apps/node-app-deployment.yaml

# Wait for all pods to be ready
oc wait --for=condition=Ready pods --all -n observability-demo --timeout=120s
```

**Demo Talk Track:**
- "We have 4 microservices: Go, Python, Java/Quarkus, and Node.js"
- "Each service is written in a different language and framework"
- "Notice: **No OpenTelemetry SDK imports in the code**"
- "Let's look at the Python service to prove it..."

#### Step 1.2: Show Clean Application Code

```bash
# Show Python app has no instrumentation code
oc exec -n observability-demo deployment/python-api -- cat /app/app.py | grep -i otel
# (No results - show this to audience)

# Show Go app has no instrumentation
oc exec -n observability-demo deployment/go-api -- cat /app/main.go | grep -i otel
# (No results)
```

**Demo Talk Track:**
- "See? Zero lines of OpenTelemetry code"
- "No SDK imports, no manual span creation, nothing"
- "Yet we'll get full distributed tracing in minutes"

#### Step 1.3: Access the Web Application

```bash
# Get the route URL
oc get route node-app -n observability-demo -o jsonpath='{.spec.host}'

# Or port-forward for local access
oc port-forward -n observability-demo svc/node-app 3000:8080
```

**Demo Actions:**
1. Open the web UI in browser
2. Show the terminal interface generating names
3. Enable "🌈 Use Lolcat Colors" checkbox
4. Demonstrate the multi-service interaction:
   - Frontend (Node.js) → Python API (seed) → Go API (name) → Quarkus API (colorize)

**Demo Talk Track:**
- "This is a simple name generator with ASCII art and rainbow colors"
- "Behind the scenes: 4 services communicating via REST APIs"
- "Background worker continuously polls Python → Go services"
- "Perfect for demonstrating distributed tracing"

---

### Phase 2: Enable Metrics Collection

#### Step 2.1: Deploy ServiceMonitors

```bash
# Deploy ServiceMonitors for all applications
oc apply -f manifests/3-servicemonitors/

# Verify ServiceMonitors are created
oc get servicemonitor -n observability-demo
```

**Expected Output:**
```
NAME          AGE
go-api        10s
node-app      10s
python-api    10s
quarkus-api   10s
```

**Demo Talk Track:**
- "ServiceMonitors tell Prometheus what to scrape"
- "Each ServiceMonitor has the label: `monitoring.rhobs/stack: observability-stack`"
- "Prometheus automatically discovers them via label selector"

#### Step 2.2: Verify Prometheus is Scraping

```bash
# Port-forward to Prometheus
oc port-forward -n observability-demo svc/prometheus-observability-stack 9090:9090
```

**Demo Actions:**
1. Open http://localhost:9090/targets
2. Show all 4 applications as targets (State: UP)
3. Navigate to Graph tab
4. Run queries:

```promql
# Show all scraped metrics
{job=~"go-api|python-api|quarkus-api|node-app"}

# Request rate (built-in metrics, no custom code!)
rate(http_request_duration_seconds_count[5m])

# Memory usage
process_resident_memory_bytes{job=~".*-api|node-app"}
```

**Demo Talk Track:**
- "Prometheus is now scraping all 4 services"
- "These metrics are built-in from the frameworks"
- "Go: prometheus client library exposes process metrics automatically"
- "Python: FastAPI + prometheus_client"
- "Node.js: prom-client"
- "Quarkus: Micrometer metrics"
- "**No custom metric code needed!**"

---

### Phase 3: Enable Distributed Tracing

#### Step 3.1: Deploy OpenTelemetry RBAC

```bash
# Create service accounts and permissions
oc apply -f manifests/4-opentelemetry/rbac.yaml
oc apply -f manifests/4-opentelemetry/tempo-writer-rbac.yaml

# Verify service accounts
oc get sa -n observability-demo | grep otel
```

**Demo Talk Track:**
- "OpenTelemetry collectors need permissions to:"
- "  1. Read Kubernetes metadata (pod, namespace, labels)"
- "  2. Write traces to Tempo"
- "This is just RBAC setup - no app changes"

#### Step 3.2: Deploy Auto-Instrumentation Configuration

```bash
# Deploy Instrumentation CR
oc apply -f manifests/4-opentelemetry/instrumentation.yaml

# View the configuration
oc get instrumentation demo-instrumentation -n observability-demo -o yaml
```

**Demo Talk Track:**
- "The Instrumentation CR defines how to auto-instrument apps"
- "It supports Python, Node.js, Java, and Go"
- "Configures OTLP endpoint, sampling rate, propagators"
- "This is declarative - operator does the work"

#### Step 3.3: Deploy Sidecar Collector

```bash
# Deploy sidecar collector definition
oc apply -f manifests/4-opentelemetry/sidecar-collector.yaml

# Verify OpenTelemetryCollector CR
oc get opentelemetrycollector sidecar -n observability-demo
```

**Demo Talk Track:**
- "Sidecar collector runs alongside each application pod"
- "Receives OTLP from the instrumented app (localhost:4318)"
- "Adds Kubernetes metadata: pod name, namespace, labels"
- "Forwards telemetry to central collector"

#### Step 3.4: Deploy Central Collector

```bash
# Deploy central collector
oc apply -f manifests/4-opentelemetry/central-collector.yaml

# Wait for central collector to be ready
oc wait --for=condition=Ready pods -l app.kubernetes.io/name=central-collector \
  -n observability-demo --timeout=120s

# Verify central collector service
oc get svc central-collector -n observability-demo
```

**Demo Talk Track:**
- "Central collector aggregates telemetry from all sidecars"
- "Key features:"
- "  1. Generates RED metrics from traces (spanmetrics connector)"
- "  2. Exports traces to Tempo"
- "  3. Exports metrics to Prometheus"
- "  4. Correlates traces and metrics with exemplars"

#### Step 3.5: Enable Auto-Instrumentation via Annotations

```bash
# Enable sidecar injection for all applications
oc patch deployment go-api -n observability-demo \
  -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.opentelemetry.io/inject":"sidecar"}}}}}'

oc patch deployment python-api -n observability-demo \
  -p '{"spec":{"template":{"metadata":{"annotations":{
    "sidecar.opentelemetry.io/inject":"sidecar",
    "instrumentation.opentelemetry.io/inject-python":"demo-instrumentation"
  }}}}}'

oc patch deployment quarkus-api -n observability-demo \
  -p '{"spec":{"template":{"metadata":{"annotations":{
    "sidecar.opentelemetry.io/inject":"sidecar",
    "instrumentation.opentelemetry.io/inject-java":"demo-instrumentation"
  }}}}}'

oc patch deployment node-app -n observability-demo \
  -p '{"spec":{"template":{"metadata":{"annotations":{
    "sidecar.opentelemetry.io/inject":"sidecar",
    "instrumentation.opentelemetry.io/inject-nodejs":"demo-instrumentation"
  }}}}}'
```

**Demo Talk Track:**
- "We're adding two annotations to each deployment:"
- "  1. `sidecar.opentelemetry.io/inject: sidecar` - Injects sidecar collector"
- "  2. `instrumentation.opentelemetry.io/inject-<lang>: demo-instrumentation` - Injects auto-instrumentation"
- "**This is the ONLY change to the deployment manifests**"
- "No code changes, just Kubernetes annotations"
- "The operator handles everything else"

#### Step 3.6: Verify Instrumentation

```bash
# Check that pods have been restarted with sidecars
oc get pods -n observability-demo

# Verify each pod has 2 containers (app + sidecar)
oc get pods -n observability-demo -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
```

**Expected Output:**
```
go-api-xxx          go-api otc-container
python-api-xxx      python-api otc-container
quarkus-api-xxx     quarkus-api otc-container
node-app-xxx        node-app otc-container
```

**Demo Talk Track:**
- "Each pod now has 2 containers:"
- "  1. Application container (original)"
- "  2. `otc-container` (OpenTelemetry Collector sidecar)"
- "The sidecar was injected automatically by the operator"

#### Step 3.7: Verify OTLP Environment Variables

```bash
# Check that OTEL environment variables are set
oc exec -n observability-demo deployment/python-api -- env | grep OTEL_
```

**Expected Output:**
```
OTEL_SERVICE_NAME=python-api
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
OTEL_TRACES_SAMPLER=parentbased_traceidratio
OTEL_TRACES_SAMPLER_ARG=1.0
OTEL_PROPAGATORS=tracecontext,baggage
...
```

**Demo Talk Track:**
- "The instrumentation init container sets all OTLP configuration"
- "Application receives these as environment variables"
- "Auto-instrumentation libraries read them automatically"
- "**Still zero code changes!**"

---

### Phase 4: Visualize & Query Observability Data

#### Step 4.1: View Traces in Jaeger UI

```bash
# Port-forward to Jaeger UI (via Tempo)
oc port-forward -n openshift-tempo-operator svc/tempo-tempo-query-frontend 16686:16686
```

**Demo Actions:**
1. Open http://localhost:16686
2. Select service: `node-app`
3. Click "Find Traces"
4. Show a trace spanning multiple services:
   - `node-app` → `python-api` → `go-api`
5. Expand trace to show spans with:
   - Duration
   - HTTP status codes
   - Kubernetes metadata (pod name, namespace)
   - Trace context propagation

**Demo Talk Track:**
- "Here's a distributed trace showing the request flow"
- "Frontend called Python API to get a seed, then Go API to generate a name"
- "Each span has Kubernetes context: pod name, namespace, labels"
- "Notice the parent-child relationship - context propagation works!"
- "This is the variable latency from Python's random delay (0.1s-5s)"
- "**All automatic - no manual span creation in code**"

#### Step 4.2: Query RED Metrics (Auto-Generated from Traces)

```bash
# Port-forward to Prometheus (if not already)
oc port-forward -n observability-demo svc/prometheus-observability-stack 9090:9090
```

**Demo Actions:**
1. Open http://localhost:9090
2. Run queries:

```promql
# Request rate per service
rate(traces_spanmetrics_calls_total[5m])

# P95 latency
histogram_quantile(0.95, 
  rate(traces_spanmetrics_latency_bucket[5m])
)

# Error rate (by status code)
rate(traces_spanmetrics_calls_total{status_code=~"5.*"}[5m])
```

3. Show metrics have trace exemplars attached

**Demo Talk Track:**
- "These RED metrics (Rate, Errors, Duration) are auto-generated from traces"
- "The central collector's spanmetrics connector creates them"
- "No custom metric code needed - just traces!"
- "Each metric has exemplars - links back to the original trace"

#### Step 4.3: Demonstrate Trace-to-Metric Correlation (Exemplars)

**Demo Actions:**
1. In Prometheus graph view, execute:
   ```promql
   histogram_quantile(0.95, rate(traces_spanmetrics_latency_bucket[5m]))
   ```
2. In the "Graph" tab, hover over a data point
3. Show the exemplar tooltip with trace_id
4. Click "Query with Exemplars" or copy trace_id
5. Paste trace_id in Jaeger to find the exact trace

**Demo Talk Track:**
- "Exemplars link metrics back to traces"
- "When you see a latency spike, click to view the actual slow trace"
- "This is the holy grail of observability: seamless correlation"
- "**All automatic with OpenTelemetry + Tempo + Prometheus**"

#### Step 4.4: OpenShift Console Integration (if UI plugins enabled)

```bash
# Get OpenShift console URL
oc whoami --show-console
```

**Demo Actions:**
1. Log into OpenShift Console
2. Navigate to **Observe → Metrics**
   - Show Perses dashboards (if enabled)
   - Run PromQL queries
3. Navigate to **Observe → Traces**
   - Select TempoStack: `tempo`
   - Search for traces
   - View trace details inline

**Demo Talk Track:**
- "With COO UI plugins, observability is native to OpenShift Console"
- "No need to port-forward or remember URLs"
- "Developers can troubleshoot without leaving the platform"
- "Perses dashboards provide modern, declarative visualization"

#### Step 4.5: Show Background Worker Metrics

```bash
# Port-forward to Node.js app
oc port-forward -n observability-demo svc/node-app 3000:8080

# View worker statistics
curl http://localhost:3000/api/worker/stats | jq
```

**Expected Output:**
```json
{
  "totalRequests": 15234,
  "successfulRequests": 14892,
  "failedRequests": 342,
  "lastSeed": 732.45,
  "lastGeneratedName": "happy-hippo",
  "lastTimestamp": "2025-10-13T10:15:30.123Z",
  "uptime": 1823,
  "successRate": "97.76%",
  "requestsPerSecond": "8.36"
}
```

**Demo Talk Track:**
- "The Node.js app runs a continuous background worker"
- "It polls Python API → Go API in a loop"
- "This generates constant traffic for tracing visualization"
- "Real-world scenario: async job processor or event consumer"

---

## Verification & Troubleshooting

### Quick Health Checks

```bash
# Check all pods are running
oc get pods -n observability-demo

# Check operators are healthy
oc get csv -n openshift-cluster-observability-operator
oc get csv -n openshift-tempo-operator
oc get csv -n openshift-operators | grep opentelemetry

# Check observability stacks
oc get monitoringstack -n observability-demo
oc get tempostack -n openshift-tempo-operator

# Check collectors
oc get opentelemetrycollector -n observability-demo
```

### Verify Traces are Flowing

```bash
# Check central collector logs for trace exports
oc logs -n observability-demo -l app.kubernetes.io/name=central-collector \
  -c otc-container --tail=50 | grep -i tempo

# Check sidecar collector in a pod
oc logs -n observability-demo deployment/python-api -c otc-container --tail=20

# Check Tempo distributor is receiving traces
oc logs -n openshift-tempo-operator -l app.kubernetes.io/component=distributor --tail=30
```

### Verify Metrics are Scraping

```bash
# Check Prometheus targets via API
oc exec -n observability-demo prometheus-observability-stack-0 -c prometheus -- \
  wget -qO- http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Query for spanmetrics
oc exec -n observability-demo prometheus-observability-stack-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=traces_spanmetrics_calls_total' | jq
```

### Common Issues

#### Issue: Sidecar Not Injected

**Symptoms:** Pod has only 1 container

**Fix:**
```bash
# Verify OpenTelemetry Operator is running
oc get pods -n openshift-operators | grep opentelemetry

# Verify sidecar collector CR exists
oc get opentelemetrycollector sidecar -n observability-demo

# Check mutation webhook
oc get mutatingwebhookconfiguration | grep opentelemetry

# Re-apply annotation
oc patch deployment <app> -n observability-demo \
  -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.opentelemetry.io/inject":"sidecar"}}}}}'
```

#### Issue: No Traces in Tempo

**Symptoms:** Jaeger UI shows no traces

**Troubleshooting:**
```bash
# Check central collector is exporting to Tempo
oc logs -n observability-demo -l app.kubernetes.io/name=central-collector \
  -c otc-container | grep -A5 "otlp/tempo"

# Check Tempo distributor logs
oc logs -n openshift-tempo-operator -l app.kubernetes.io/component=distributor

# Verify bearer token secret exists
oc get secret tempo-tempo-token -n openshift-tempo-operator

# Test OTLP endpoint
oc run test-tempo --rm -i --restart=Never --image=curlimages/curl -- \
  curl -v http://tempo-tempo-distributor.openshift-tempo-operator.svc:4318/v1/traces
```

#### Issue: No Span Metrics

**Symptoms:** `traces_spanmetrics_*` metrics not found in Prometheus

**Troubleshooting:**
```bash
# Check central collector has spanmetrics connector
oc get opentelemetrycollector central -n observability-demo -o yaml | grep -A10 spanmetrics

# Check metrics pipeline in central collector logs
oc logs -n observability-demo -l app.kubernetes.io/name=central-collector \
  -c otc-container | grep -i "metrics.*pipeline"

# Verify Prometheus remote write endpoint
oc get svc prometheus-observability-stack -n observability-demo
```

#### Issue: Auto-Instrumentation Not Working

**Symptoms:** No OTEL env vars, no instrumentation

**Troubleshooting:**
```bash
# Check Instrumentation CR exists
oc get instrumentation demo-instrumentation -n observability-demo -o yaml

# Verify init container is injected
oc get pod <pod-name> -n observability-demo -o jsonpath='{.spec.initContainers[*].name}'
# Should show: opentelemetry-auto-instrumentation-*

# Check environment variables
oc exec deployment/<app> -n observability-demo -- env | grep OTEL_

# Check operator logs
oc logs -n openshift-operators -l app.kubernetes.io/name=opentelemetry-operator --tail=100
```

---

## Key Talking Points

### For the Audience

1. **Zero Code Changes**
   - "Not a single line of OpenTelemetry code was added to any application"
   - "Auto-instrumentation via operator and annotations"
   - "Developers can focus on business logic, not observability plumbing"

2. **Polyglot Support**
   - "We demonstrated Go, Python, Java/Quarkus, and Node.js"
   - "Same approach works for .NET, Ruby, PHP, etc."
   - "Consistent observability across your entire stack"

3. **Automatic Correlation**
   - "Traces, metrics, and logs are automatically correlated"
   - "Exemplars link metrics to traces"
   - "Trace context propagation works out of the box"

4. **OpenShift Native**
   - "All observability integrated into OpenShift Console"
   - "No external tools to manage"
   - "Kubernetes metadata automatically added to all telemetry"

5. **Production Ready**
   - "Tempo provides scalable, cost-effective trace storage"
   - "Prometheus for metrics with long-term storage via Thanos"
   - "Multi-tenancy support in TempoStack"
   - "Retention policies, RBAC, everything you need"

### Technical Highlights

- **OpenTelemetry Collector Architecture**
  - Sidecar pattern for minimal blast radius
  - Central collector for aggregation and processing
  - Modular pipelines: receivers → processors → exporters

- **Span Metrics (RED)**
  - Automatically generated from traces
  - No manual instrumentation needed
  - Reduces metric cardinality vs. per-endpoint metrics

- **W3C Trace Context**
  - Standard context propagation
  - Works across languages and frameworks
  - Integrates with external services

- **Kubernetes-Native**
  - Automatic service discovery via ServiceMonitors
  - Pod annotations for configuration
  - Operator-driven lifecycle management

---

## Summary

This demo showcases how OpenShift's observability suite enables:

✅ **Full distributed tracing** without writing trace code  
✅ **Comprehensive metrics** from framework defaults and auto-generated span metrics  
✅ **Unified observability** in the OpenShift Console  
✅ **Developer productivity** - focus on features, not instrumentation  
✅ **Production-grade** scalability and multi-tenancy

**Time to observability: ~15 minutes** (after operator pre-deployment)  
**Lines of code changed: 0**  
**Annotations added: 2 per deployment**

---

## Additional Resources

- [Red Hat OpenTelemetry Documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/4.19/html/red_hat_build_of_opentelemetry/)
- [Cluster Observability Operator](https://docs.redhat.com/en/documentation/openshift_container_platform/4.17/html-single/cluster_observability_operator/)
- [Tempo Operator](https://github.com/grafana/tempo-operator)
- [OpenTelemetry Auto-Instrumentation](https://opentelemetry.io/docs/instrumentation/)
- [Workshop Repository](https://github.com/cldmnky/observability-developer-day-2025)

---

**Demo prepared for Observability Developer Day 2025**  
*Roger Florén & Magnus Bengtsson*

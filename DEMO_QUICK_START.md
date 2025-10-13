# Observability Developer Day 2025 - Demo Scripts

Quick-start guide for the OpenShift observability auto-instrumentation demo.

## Demo Overview

**Duration:** 10-12 minutes  
**Topic:** Zero-code observability with OpenTelemetry auto-instrumentation  
**Technologies:** OpenShift, COO, Tempo, OpenTelemetry, Prometheus, Perses

## 🚀 Quick Start

### 1. Pre-Demo Setup (Run Once)

Install operators and observability stacks:

```bash
./demo-prep.sh
```

**What it does:**
- Installs Cluster Observability Operator (COO)
- Installs Tempo Operator
- Installs OpenTelemetry Operator
- Deploys MonitoringStack (Prometheus + Thanos)
- Deploys TempoStack (Tempo with MinIO storage)
- Enables OpenShift Console UI plugins

**Time:** ~5-10 minutes (run before your demo session)

### 2. Run the Demo

Execute the interactive demo script:

```bash
./demo.sh
```

**What it demonstrates:**
- Phase 1: Deploy 4 microservices (0 lines of OTel code)
- Phase 2: Enable metrics via ServiceMonitors
- Phase 3: Enable tracing via 2 annotations per app
- Phase 4: View traces, metrics, and dashboards

**Time:** 10-12 minutes

### 3. Clean Up (Optional)

Remove demo resources but keep infrastructure:

```bash
./demo-cleanup.sh
```

**What it removes:**
- Applications
- ServiceMonitors
- OpenTelemetry collectors
- Perses dashboards

**What it keeps:**
- Operators (COO, Tempo, OpenTelemetry)
- MonitoringStack
- TempoStack
- UI plugins

## 📁 Repository Structure

```
.
├── demo-prep.sh          # Pre-demo setup script
├── demo-cleanup.sh       # Demo cleanup script
├── demo.sh               # Interactive demo script
├── DEMO.md               # Full demo guide with detailed steps
├── manifests/
│   ├── 1-apps/           # Application deployments
│   ├── 2-observability-stack/  # COO and Tempo stacks
│   ├── 3-servicemonitors/      # Prometheus ServiceMonitors
│   ├── 4-opentelemetry/        # OTel collectors & instrumentation
│   └── 5-coo-setup/            # Perses datasources & dashboards
├── go/                   # Go API source
├── python/               # Python API source
├── quarkus/              # Quarkus API source
└── node/                 # Node.js app source
```

## 🎯 Demo Flow

### Phase 1: Deploy Applications (2 min)

Deploy 4 microservices without instrumentation code:

```bash
oc apply -f manifests/1-apps/
```

Access the web UI and show it works.

### Phase 2: Enable Metrics (2 min)

Deploy ServiceMonitors to enable Prometheus scraping:

```bash
oc apply -f manifests/3-servicemonitors/
```

Show Prometheus targets and query metrics.

### Phase 3: Enable Tracing (4 min)

Deploy OpenTelemetry infrastructure:

```bash
oc apply -f manifests/4-opentelemetry/rbac.yaml
oc apply -f manifests/4-opentelemetry/instrumentation.yaml
oc apply -f manifests/4-opentelemetry/sidecar-collector.yaml
oc apply -f manifests/4-opentelemetry/central-collector.yaml
```

Add 2 annotations to each deployment to enable auto-instrumentation:

```bash
oc patch deployment go-api -n observability-demo \
  -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.opentelemetry.io/inject":"sidecar"}}}}}'
  
oc patch deployment python-api -n observability-demo \
  -p '{"spec":{"template":{"metadata":{"annotations":{
    "sidecar.opentelemetry.io/inject":"sidecar",
    "instrumentation.opentelemetry.io/inject-python":"demo-instrumentation"
  }}}}}'
```

### Phase 4: Visualize (2-4 min)

Deploy Perses dashboard:

```bash
oc apply -f manifests/5-coo-setup/perses-datasource.yaml
oc apply -f manifests/5-coo-setup/working-dashboard.yaml
```

View traces in Jaeger UI and metrics in OpenShift Console.

## 🔍 Verification

Check everything is working:

```bash
# Check pods
oc get pods -n observability-demo

# Check ServiceMonitors
oc get servicemonitors.monitoring.rhobs -n observability-demo

# Check collectors
oc get opentelemetrycollector -n observability-demo

# Check stacks
oc get monitoringstack -n observability-demo
oc get tempostack -n openshift-tempo-operator
```

Access UIs:

```bash
# Web application
oc get route node-app -n observability-demo -o jsonpath='{.spec.host}'

# Prometheus
oc port-forward -n observability-demo svc/observability-stack-prometheus 9090:9090

# Jaeger (via Tempo)
oc port-forward -n openshift-tempo-operator svc/tempo-tempo-query-frontend 16686:16686

# OpenShift Console
oc whoami --show-console
```

## 📚 Additional Resources

- [Full Demo Guide](./DEMO.md) - Detailed step-by-step instructions
- [Setup Guide](./SETUP.md) - Manual setup instructions
- [COO Documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/4.17/html-single/cluster_observability_operator/)
- [OpenTelemetry Operator](https://github.com/open-telemetry/opentelemetry-operator)
- [Tempo Operator](https://github.com/grafana/tempo-operator)

## 🎤 Key Talking Points

- **Zero Code Changes**: No OpenTelemetry SDK in application code
- **Polyglot Support**: Go, Python, Java/Quarkus, Node.js
- **Two Annotations**: Only deployment manifest change required
- **Automatic Correlation**: Traces → Metrics → Logs
- **OpenShift Native**: Everything integrated in OpenShift Console
- **Production Ready**: Scalable with Tempo + Prometheus + Thanos

## 🏁 Demo Summary

**Time to observability:** ~10 minutes  
**Lines of code changed:** 0  
**Annotations added:** 2 per deployment  
**Services instrumented:** 4 (Go, Python, Java, Node.js)  
**Metrics collected:** Built-in framework metrics + RED metrics from traces  
**Traces collected:** Distributed traces with full context propagation

---

**Demo prepared for Observability Developer Day 2025**  
*Roger Florén & Magnus Bengtsson*

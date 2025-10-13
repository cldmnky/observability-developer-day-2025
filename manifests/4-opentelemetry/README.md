# OpenTelemetry Configuration for Observability Demo

This directory contains OpenTelemetry Collector and auto-instrumentation configurations for the observability demo applications.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Application Pods                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  go-api      │  │ python-api   │  │ quarkus-api  │  ...     │
│  │              │  │              │  │              │          │
│  │ Auto-instr.  │  │ Auto-instr.  │  │ Auto-instr.  │          │
│  │     ↓        │  │     ↓        │  │     ↓        │          │
│  │  Sidecar     │  │  Sidecar     │  │  Sidecar     │          │
│  │  Collector   │  │  Collector   │  │  Collector   │          │
│  │  (OTLP recv) │  │  (OTLP recv) │  │  (OTLP recv) │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                 │                 │                   │
│         └─────────────────┴─────────────────┘                   │
│                           │                                      │
└───────────────────────────┼──────────────────────────────────────┘
                            ▼
            ┌───────────────────────────────┐
            │   Central Collector           │
            │   (Deployment in ns)          │
            │                               │
            │  • Receives OTLP              │
            │  • Processes telemetry        │
            │  • Generates span metrics     │
            │  • Exports to backends        │
            └───────┬─────────────┬─────────┘
                    │             │
         ┌──────────▼─┐       ┌───▼──────────────┐
         │   Tempo    │       │  Prometheus      │
         │ (Traces)   │       │  (Metrics)       │
         └────────────┘       └──────────────────┘
```

## Components

### 1. RBAC Configuration (`rbac.yaml`)

Creates necessary service accounts and permissions:
- `otel-collector-sidecar` - for sidecar collectors
- `otel-central-collector` - for central collector
- ClusterRole with permissions for k8sattributes and resourcedetection processors
- Tempo write permissions for trace export

### 2. Sidecar Collector (`sidecar-collector.yaml`)

**Mode**: Sidecar (injected into application pods)

**Purpose**: Receives telemetry from instrumented applications

**Configuration**:
- **Receivers**: OTLP (gRPC on 4317, HTTP on 4318)
- **Processors**:
  - `memory_limiter` - prevents OOM
  - `resourcedetection` - adds OpenShift resource attributes
  - `k8sattributes` - adds Kubernetes metadata
  - `batch` - batches telemetry for efficiency
- **Exporters**: OTLP to central collector

**Pipelines**:
- Traces: otlp → processors → central collector
- Metrics: otlp → processors → central collector
- Logs: otlp → processors → central collector

### 3. Central Collector (`central-collector.yaml`)

**Mode**: Deployment (2 replicas)

**Purpose**: Central aggregation point for all telemetry

**Configuration**:
- **Extensions**:
  - `bearertokenauth` - for Tempo authentication
  
- **Receivers**: OTLP (gRPC/HTTP)

- **Connectors**:
  - `spanmetrics` - generates RED metrics from traces
    - Request rate (calls_total)
    - Error rate (by status code)
    - Duration (latency histogram)
    - Exemplars enabled for trace-metric correlation

- **Processors**:
  - `memory_limiter` - prevents OOM (1800 MiB limit)
  - `resourcedetection` - OpenShift metadata
  - `k8sattributes` - Kubernetes metadata
  - `metricstransform` - renames span metrics
  - `batch` - batching for efficiency

- **Exporters**:
  - `otlp/tempo` - traces to TempoStack (with mTLS and X-Scope-OrgID header)
  - `prometheusremotewrite` - metrics to Prometheus (COO monitoring stack)
  - `debug` - troubleshooting output

**Pipelines**:
1. **Traces**: otlp → processors → [Tempo, spanmetrics connector]
2. **Span Metrics**: spanmetrics → transform → Prometheus
3. **App Metrics**: otlp → processors → Prometheus
4. **Logs**: otlp → processors → debug (for now)

### 4. Auto-Instrumentation (`instrumentation.yaml`)

**Purpose**: Configures automatic instrumentation injection

**Features**:
- Zero-code instrumentation for Python, Node.js, Java, Go
- Uses sidecar collector endpoint (localhost:4318)
- Configures OTLP exporters for traces, metrics, logs
- 100% sampling for demo purposes
- Language-specific environment variables

**Supported Languages**:
- **Python**: FastAPI apps (python-api)
- **Node.js**: Express apps (node-app)
- **Java**: Quarkus apps (quarkus-api)
- **Go**: Standard apps (go-api)

## Deployment

### Prerequisites

1. Red Hat build of OpenTelemetry Operator installed
2. Tempo Operator and TempoStack deployed
3. Cluster Observability Operator with MonitoringStack deployed
## Deployment Steps

### Step 1: Install Red Hat build of OpenTelemetry Operator

The OpenTelemetry Operator is required to manage the collectors and instrumentation.

```bash
# Install the operator subscription
oc apply -f manifests/3-opentelemetry/subscription.yaml

# Wait for the operator to be ready
oc get csv -n openshift-operators | grep opentelemetry

# Verify operator pod is running
oc get pods -n openshift-operators | grep opentelemetry
```
### Step 2: Deploy Auto-Instrumentation

```bash
# Apply instrumentation configuration
oc apply -f manifests/3-opentelemetry/instrumentation.yaml

# Verify instrumentation
oc get instrumentation -n observability-demo
```

### Step 3: Enable Sidecar Injection

Add annotation to application deployments to inject sidecar collector:

```bash
# For each application deployment
oc patch deployment go-api -n observability-demo -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.opentelemetry.io/inject":"sidecar"}}}}}'

oc patch deployment python-api -n observability-demo -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.opentelemetry.io/inject":"sidecar"}}}}}'

oc patch deployment quarkus-api -n observability-demo -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.opentelemetry.io/inject":"sidecar"}}}}}'

oc patch deployment node-app -n observability-demo -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.opentelemetry.io/inject":"sidecar"}}}}}'
```

### Step 4: Enable Auto-Instrumentation (Optional)

Add annotation for automatic instrumentation injection:

```bash
# Python app
oc patch deployment python-api -n observability-demo -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-python":"demo-instrumentation"}}}}}'

# Node.js app
oc patch deployment node-app -n observability-demo -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-nodejs":"demo-instrumentation"}}}}}'

# Java/Quarkus app
oc patch deployment quarkus-api -n observability-demo -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-java":"demo-instrumentation"}}}}}'

# Go app (requires special permissions)
oc patch deployment go-api -n observability-demo -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-go":"demo-instrumentation","instrumentation.opentelemetry.io/otel-go-auto-target-exe":"/usr/local/bin/api"}}}}}'
```

## Verification

### Check Sidecar Injection

```bash
# Verify sidecars are injected
oc get pods -n observability-demo -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'

# Should show: <app-name>  otc-container <app-container>
```

### Check Central Collector

```bash
# Check central collector pods
oc get pods -n observability-demo -l app.kubernetes.io/component=opentelemetry-collector

# Check central collector service
oc get svc central-collector -n observability-demo

# View collector logs
oc logs -n observability-demo -l app.kubernetes.io/name=central-collector -c otc-container --tail=50
```

### Verify Telemetry Flow

```bash
# Check if traces reach Tempo
oc port-forward -n openshift-tempo-operator svc/tempo-tempo-query-frontend 16686:16686
# Open http://localhost:16686 and search for traces

# Check if metrics reach Prometheus
oc port-forward -n observability-demo svc/observability-stack-prometheus 9090:9090
# Open http://localhost:9090 and query: traces_spanmetrics_calls_total
```

### Debug Sidecar

```bash
# Check sidecar logs
oc logs <pod-name> -n observability-demo -c otc-container

# Check application logs for OTEL variables
oc logs <pod-name> -n observability-demo -c <app-container> | grep OTEL
```

## Configuration Details

### Tempo Integration

The central collector sends traces to Tempo with:
- Endpoint: `tempo-tempo-distributor.openshift-tempo-operator.svc:4317`
- TLS enabled with service CA
- Bearer token authentication
- X-Scope-OrgID: "dev" (tenant header)

### Prometheus Integration

The central collector sends metrics to Prometheus with:
- Endpoint: `http://observability-stack-prometheus.observability-demo.svc:9090/api/v1/write`
- Remote write protocol
- Resource-to-telemetry conversion enabled

### Span Metrics

Generated metrics from traces:
- `traces_spanmetrics_calls_total` - total request count by method, status
- `traces_spanmetrics_latency` - request duration histogram
- Labels: http.method, http.status_code, span.name
- Exemplars link metrics back to traces

## Troubleshooting

### Sidecar Not Injected

Check:
1. OpenTelemetry Operator is running: `oc get pods -n openshift-opentelemetry-operator`
2. Sidecar collector CR exists: `oc get opentelemetrycollector sidecar -n observability-demo`
3. Annotation is correct: `sidecar.opentelemetry.io/inject: "sidecar"`
4. Webhook is active: `oc get mutatingwebhookconfigurations | grep opentelemetry`

### No Traces in Tempo

Check:
1. Central collector is running: `oc get pods -l app.kubernetes.io/name=central-collector -n observability-demo`
2. Central collector logs: `oc logs -l app.kubernetes.io/name=central-collector -n observability-demo -c otc-container`
3. Tempo distributor endpoint: `oc get svc -n openshift-tempo-operator tempo-tempo-distributor`
4. Bearer token auth: Check service account has correct permissions

### No Metrics in Prometheus

Check:
1. Prometheus remote write endpoint: `oc get svc observability-stack-prometheus -n observability-demo`
2. Central collector exporters in logs
3. ServiceMonitor for central collector: `oc get servicemonitor -n observability-demo`

### Auto-Instrumentation Not Working

Check:
1. Instrumentation CR exists: `oc get instrumentation demo-instrumentation -n observability-demo`
2. Correct annotation on deployment
3. Init container injected: `oc get pod <pod> -o jsonpath='{.spec.initContainers[*].name}'`
4. Environment variables set: `oc exec <pod> -- env | grep OTEL`

## References

- [Red Hat build of OpenTelemetry Documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/4.19/html/red_hat_build_of_opentelemetry/)
- [OpenTelemetry Collector Configuration](https://opentelemetry.io/docs/collector/configuration/)
- [Auto-Instrumentation](https://opentelemetry.io/docs/instrumentation/)

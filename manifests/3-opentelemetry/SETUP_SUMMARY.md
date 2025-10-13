# OpenTelemetry Setup Summary

## What Was Created

Based on the latest Red Hat OpenTelemetry documentation, I've created a complete OpenTelemetry configuration with:

### 1. Sidecar Architecture
- **Sidecar collectors** inject into each application pod
- **Central collector** aggregates telemetry from all sidecars
- Applications send OTLP to localhost:4318 (sidecar)
- Sidecars forward to central collector
- Central collector exports to Tempo (traces) and Prometheus (metrics)

### 2. Key Features

#### Automatic Sidecar Injection
- Annotation-based: `sidecar.opentelemetry.io/inject: "sidecar"`
- No code changes needed
- Collector runs as sidecar container in app pods

#### Auto-Instrumentation Support
- Python (FastAPI/python-api)
- Node.js (Express/node-app)
- Java (Quarkus/quarkus-api)  
- Go (go-api) - requires special permissions

#### Span Metrics Generation
- Central collector generates RED metrics from traces:
  - `traces_spanmetrics_calls_total` - request rate
  - `traces_spanmetrics_latency` - duration histogram
  - Labeled by http.method, http.status_code, span.name
  - Exemplars enabled (links metrics → traces)

#### Integration Points
- **Tempo**: Traces exported via OTLP with bearer token auth
- **Prometheus**: Metrics via remote write to COO monitoring stack
- **Logs**: Debug exporter (can add LokiStack later)

## Files Created

```
manifests/3-opentelemetry/
├── rbac.yaml                   # Service accounts and permissions
├── sidecar-collector.yaml      # Sidecar collector config
├── central-collector.yaml      # Central aggregation collector
├── instrumentation.yaml        # Auto-instrumentation config
└── README.md                   # Complete documentation
```

## Deployment Steps

### 1. Install Red Hat build of OpenTelemetry Operator

```bash
# Via OperatorHub or CLI
oc create -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: opentelemetry-operator
  namespace: openshift-operators
spec:
  channel: stable
  name: opentelemetry-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
```

### 2. Deploy OpenTelemetry Components

```bash
# Apply RBAC
oc apply -f manifests/3-opentelemetry/rbac.yaml

# Deploy collectors
oc apply -f manifests/3-opentelemetry/sidecar-collector.yaml
oc apply -f manifests/3-opentelemetry/central-collector.yaml

# Deploy instrumentation
oc apply -f manifests/3-opentelemetry/instrumentation.yaml

# Verify
oc get opentelemetrycollector,instrumentation -n observability-demo
```

### 3. Enable Sidecar Injection

Patch deployments to inject sidecar collector:

```bash
# Go API
oc patch deployment go-api -n observability-demo -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.opentelemetry.io/inject":"sidecar"}}}}}'

# Python API
oc patch deployment python-api -n observability-demo -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.opentelemetry.io/inject":"sidecar"}}}}}'

# Quarkus API
oc patch deployment quarkus-api -n observability-demo -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.opentelemetry.io/inject":"sidecar"}}}}}'

# Node App
oc patch deployment node-app -n observability-demo -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.opentelemetry.io/inject":"sidecar"}}}}}'
```

### 4. Enable Auto-Instrumentation (Optional)

Add instrumentation annotations:

```bash
# Python
oc patch deployment python-api -n observability-demo -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-python":"demo-instrumentation"}}}}}'

# Node.js
oc patch deployment node-app -n observability-demo -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-nodejs":"demo-instrumentation"}}}}}'

# Java/Quarkus
oc patch deployment quarkus-api -n observability-demo -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-java":"demo-instrumentation"}}}}}'
```

**Note**: Go auto-instrumentation requires:
1. SCC with SYS_PTRACE capability
2. OTEL_GO_AUTO_TARGET_EXE annotation pointing to binary
3. Manual SDK integration may be easier for Go apps

## Verification

### Check Sidecar Injection

```bash
# List all pods with containers
oc get pods -n observability-demo -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'

# Should show: <pod-name>  otc-container <app-container>
```

### Check Central Collector

```bash
# Central collector pods
oc get pods -n observability-demo -l app.kubernetes.io/name=central-collector

# Central collector logs
oc logs -n observability-demo -l app.kubernetes.io/name=central-collector -c otc-container --tail=100
```

### Verify Telemetry Flow

```bash
# Traces in Jaeger UI (via Tempo)
oc port-forward -n openshift-tempo-operator svc/tempo-tempo-query-frontend 16686:16686
# http://localhost:16686

# Metrics in Prometheus
oc port-forward -n observability-demo svc/observability-stack-prometheus 9090:9090
# http://localhost:9090
# Query: traces_spanmetrics_calls_total
```

## Architecture Diagram

```
Application Pods (with sidecars)
┌────────────────────────────────┐
│  go-api                        │
│  ┌──────────┐  ┌─────────────┐ │
│  │ go-api   │→ │  Sidecar    │ │
│  │ :4001    │  │  Collector  │ │
│  └──────────┘  │  OTLP:4318  │ │
│                └──────┬──────┘ │
└───────────────────────┼────────┘
                        │
                        ▼
            ┌───────────────────────┐
            │  Central Collector    │
            │  (Deployment x2)      │
            │                       │
            │  ┌─────────────────┐  │
            │  │ OTLP Receiver   │  │
            │  └────────┬────────┘  │
            │           │           │
            │  ┌────────▼────────┐  │
            │  │  Processors:    │  │
            │  │  - k8sattributes│  │
            │  │  - batch        │  │
            │  │  - resourcedet. │  │
            │  └────────┬────────┘  │
            │           │           │
            │  ┌────────▼────────┐  │
            │  │  Connectors:    │  │
            │  │  - spanmetrics  │  │
            │  └────────┬────────┘  │
            │           │           │
            │  ┌────────▼────────┐  │
            │  │  Exporters:     │  │
            │  │  - tempo (OTLP) │  │
            │  │  - prometheus   │  │
            │  └─────────────────┘  │
            └───────────────────────┘
                     │        │
          ┌──────────▼─┐  ┌───▼──────────┐
          │   Tempo    │  │  Prometheus  │
          │  (Traces)  │  │  (Metrics)   │
          └────────────┘  └──────────────┘
```

## Key Differences from Examples

### ✅ What's Correct (per Red Hat docs)

1. **No custom images** - uses Operator-managed images
2. **Correct namespaces** - `observability-demo` for apps and collectors
3. **Proper RBAC** - k8sattributes and resourcedetection permissions
4. **Bearer token auth** - for Tempo OTLP export
5. **Service CA TLS** - using OpenShift service CA for Tempo
6. **Resource detection** - OpenShift-specific detector
7. **Sidecar mode** - proper annotation-based injection

### 🔄 Changes from Examples

1. **Removed hardcoded images** - Operator manages versions
2. **Updated collector endpoint** - `tempo-tempo-distributor` for TempoStack
3. **Fixed Prometheus endpoint** - remote write to COO monitoring stack
4. **Added spanmetrics connector** - generates RED metrics from traces
5. **Proper pipeline structure** - follows Red Hat best practices
6. **TLS configuration** - uses service CA, not custom certs (unless needed)

## Next Steps

### Immediate
1. Install OpenTelemetry Operator
2. Deploy collectors and instrumentation
3. Enable sidecar injection on deployments
4. Verify telemetry flow

### Optional Enhancements
1. **Auto-instrumentation**: Enable for automatic code instrumentation
2. **Custom metrics**: Add application-specific metrics
3. **Sampling**: Adjust sampling rates for production
4. **TLS**: Add mutual TLS between collectors if needed
5. **Multi-tenant**: Configure different tenants in Tempo

### Monitoring
1. Enable metrics for collectors themselves
2. Create alerts for collector health
3. Monitor span metrics in Grafana
4. Set up dashboards for trace analysis

## Troubleshooting

See the [README.md](./README.md) for detailed troubleshooting steps including:
- Sidecar injection issues
- Missing traces in Tempo
- Missing metrics in Prometheus
- Auto-instrumentation problems
- Collector configuration errors

## References

- [Red Hat build of OpenTelemetry 4.19](https://docs.redhat.com/en/documentation/openshift_container_platform/4.19/html-single/red_hat_build_of_opentelemetry/)
- [Auto-instrumentation Configuration](https://docs.redhat.com/en/documentation/openshift_container_platform/4.19/html-single/red_hat_build_of_opentelemetry/index#otel-autoinstrumentation_otel-configuration-of-instrumentation)
- [Sidecar Injection](https://docs.redhat.com/en/documentation/openshift_container_platform/4.19/html-single/red_hat_build_of_opentelemetry/index#otel-collector-mode-deployment_otel-configuration-of-the-collector)

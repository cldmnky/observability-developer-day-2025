# OpenTelemetry Deployment Order

## Current Status

✅ **OpenTelemetry Operator Installed**
- Version: v0.135.0-1
- Namespace: openshift-operators
- Status: Running

## Next Steps

### 1. Deploy RBAC Resources

```bash
oc apply -f manifests/3-opentelemetry/rbac.yaml
```

This creates:
- `otel-collector-sidecar` ServiceAccount
- `otel-central-collector` ServiceAccount  
- ClusterRole with permissions for k8s API and Tempo
- ClusterRoleBindings

### 2. Deploy Auto-Instrumentation

```bash
oc apply -f manifests/3-opentelemetry/instrumentation.yaml
```

This creates the Instrumentation CR for Python, Node.js, Java, and Go applications.

### 3. Deploy Sidecar Collector

```bash
oc apply -f manifests/3-opentelemetry/sidecar-collector.yaml
```

This creates the OpenTelemetryCollector in sidecar mode that will be injected into application pods.

### 4. Deploy Central Collector

```bash
oc apply -f manifests/3-opentelemetry/central-collector.yaml
```

This creates the central OpenTelemetryCollector deployment that:
- Receives OTLP from sidecar collectors
- Generates span metrics (RED metrics)
- Exports traces to Tempo
- Exports metrics to Prometheus

### 5. Enable Sidecar Injection on Applications

Patch each deployment to inject the sidecar collector:

```bash
# Go API
oc patch deployment go-api -n observability-demo \
  -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.opentelemetry.io/inject":"sidecar"}}}}}'

# Python API
oc patch deployment python-api -n observability-demo \
  -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.opentelemetry.io/inject":"sidecar"}}}}}'

# Quarkus API
oc patch deployment quarkus-api -n observability-demo \
  -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.opentelemetry.io/inject":"sidecar"}}}}}'

# Node App
oc patch deployment node-app -n observability-demo \
  -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.opentelemetry.io/inject":"sidecar"}}}}}'
```

### 6. (Optional) Enable Auto-Instrumentation

Add language-specific auto-instrumentation annotations:

```bash
# Python API - auto-instrumentation
oc patch deployment python-api -n observability-demo \
  -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-python":"demo-instrumentation"}}}}}'

# Node App - auto-instrumentation  
oc patch deployment node-app -n observability-demo \
  -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-nodejs":"demo-instrumentation"}}}}}'

# Quarkus API - auto-instrumentation
oc patch deployment quarkus-api -n observability-demo \
  -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-java":"demo-instrumentation"}}}}}'
```

**Note**: Go auto-instrumentation requires additional permissions (SYS_PTRACE) and may be easier to implement via manual SDK integration.

## Verification

### Check Operator

```bash
oc get csv -n openshift-operators | grep opentelemetry
oc get pods -n openshift-operators | grep opentelemetry
```

### Check Collectors

```bash
# Sidecar collector definition
oc get opentelemetrycollector sidecar -n observability-demo

# Central collector
oc get opentelemetrycollector central -n observability-demo
oc get pods -l app.kubernetes.io/name=central-collector -n observability-demo
```

### Check Instrumentation

```bash
oc get instrumentation demo-instrumentation -n observability-demo
```

### Check Application Pods

```bash
# Should show sidecar container (otc-container) in each pod
oc get pods -n observability-demo -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
```

### Check Telemetry

```bash
# Port forward to Jaeger UI (via Tempo)
oc port-forward -n openshift-tempo-operator svc/tempo-tempo-query-frontend 16686:16686
# Open http://localhost:16686

# Port forward to Prometheus
oc port-forward -n observability-demo svc/observability-stack-prometheus 9090:9090
# Open http://localhost:9090
# Query: traces_spanmetrics_calls_total
```

## Architecture Flow

```
Application (instrumented)
         │
         ↓ OTLP (localhost:4318)
    Sidecar Collector (injected)
         │
         ↓ OTLP (grpc:4317)
    Central Collector (deployment)
         │
         ├──→ Tempo (traces via OTLP)
         │
         └──→ Prometheus (metrics via remote write)
              ├── Application metrics
              └── Span metrics (RED)
```

## Troubleshooting

### Operator Issues

```bash
# Check operator logs
oc logs -n openshift-operators -l app.kubernetes.io/name=opentelemetry-operator

# Check subscription status
oc get subscription.operators.coreos.com opentelemetry-operator -n openshift-operators -o yaml
```

### Collector Issues

```bash
# Check central collector logs
oc logs -n observability-demo -l app.kubernetes.io/name=central-collector -c otc-container

# Check sidecar logs in an app pod
oc logs -n observability-demo <pod-name> -c otc-container
```

### Sidecar Not Injected

```bash
# Check OpenTelemetryCollector CR
oc get opentelemetrycollector sidecar -n observability-demo -o yaml

# Check deployment annotations
oc get deployment <name> -n observability-demo -o jsonpath='{.spec.template.metadata.annotations}'
```

### No Traces in Tempo

```bash
# Check central collector is exporting
oc logs -n observability-demo -l app.kubernetes.io/name=central-collector -c otc-container | grep -i tempo

# Check Tempo distributor
oc get pods -n openshift-tempo-operator | grep distributor
oc logs -n openshift-tempo-operator <tempo-distributor-pod>

# Verify bearer token secret
oc get secret tempo-tempo-token -n openshift-tempo-operator
```

### No Metrics in Prometheus

```bash
# Check central collector is exporting metrics
oc logs -n observability-demo -l app.kubernetes.io/name=central-collector -c otc-container | grep -i prometheus

# Check Prometheus targets
oc port-forward -n observability-demo svc/observability-stack-prometheus 9090:9090
# Open http://localhost:9090/targets
```

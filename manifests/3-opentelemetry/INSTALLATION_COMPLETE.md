# OpenTelemetry Installation Complete ✅

## What's Deployed

### 1. Red Hat build of OpenTelemetry Operator
- **Version**: v0.135.0-1
- **Namespace**: openshift-operators
- **Status**: ✅ Running

```bash
$ oc get csv -n openshift-operators | grep opentelemetry
opentelemetry-operator.v0.135.0-1   Red Hat build of OpenTelemetry   0.135.0-1   Succeeded
```

### 2. RBAC Resources
- ✅ `otel-collector-sidecar` ServiceAccount
- ✅ `otel-central-collector` ServiceAccount
- ✅ ClusterRole with permissions for:
  - pods, namespaces, nodes (for k8sattributes processor)
  - replicasets (for resource detection)
  - infrastructures (for OpenShift detection)
  - tempo traces (for trace export)

### 3. OpenTelemetry Collectors

#### Sidecar Collector
- **Name**: `sidecar`
- **Mode**: sidecar (injected via annotation)
- **Function**: Receives OTLP from applications, forwards to central collector
- **Receivers**: OTLP gRPC (4317), HTTP (4318)
- **Exporters**: OTLP to central-collector:4317

#### Central Collector
- **Name**: `central`
- **Mode**: deployment
- **Replicas**: 2
- **Status**: ✅ Running
- **Function**:
  - Receives OTLP from sidecar collectors
  - Generates span metrics (RED metrics)
  - Exports traces to Tempo
  - Exports metrics to Prometheus

```bash
$ oc get pods -n observability-demo -l app.kubernetes.io/name=central-collector
NAME                                 READY   STATUS    RESTARTS   AGE
central-collector-6db968648b-qwlhf   1/1     Running   0          2m
central-collector-6db968648b-vgh7n   1/1     Running   0          2m
```

### 4. Auto-Instrumentation Configuration
- **Name**: `demo-instrumentation`
- **Endpoint**: http://localhost:4318 (sidecar)
- **Sampler**: parentbased_traceidratio @ 100%
- **Supported Languages**:
  - Python (FastAPI, Django, Flask)
  - Node.js (Express, etc.)
  - Java (Quarkus, Spring Boot)
  - Go (requires additional config)

## Architecture

```
┌─────────────────────────────────────────┐
│  Application Pod                        │
│  ┌──────────┐         ┌──────────────┐  │
│  │   App    │ OTLP    │   Sidecar    │  │
│  │          │─────────→│  Collector   │  │
│  │   :4001  │ :4318   │              │  │
│  └──────────┘         └──────┬───────┘  │
└────────────────────────────────┼─────────┘
                                 │
                                 ↓ OTLP :4317
                    ┌────────────────────────┐
                    │  Central Collector     │
                    │  (Deployment x2)       │
                    │                        │
                    │  ┌──────────────────┐  │
                    │  │ Spanmetrics      │  │
                    │  │ Connector        │  │
                    │  └─────┬───────┬────┘  │
                    └────────┼───────┼────────┘
                             │       │
                   ┌─────────▼─┐ ┌───▼────────────┐
                   │   Tempo   │ │  Prometheus    │
                   │ (Traces)  │ │  (Metrics)     │
                   └───────────┘ └────────────────┘
```

## Next Steps

### Enable Sidecar Injection

Patch deployments to inject the sidecar collector:

```bash
# All at once
for app in go-api python-api quarkus-api node-app; do
  oc patch deployment $app -n observability-demo \
    -p '{"spec":{"template":{"metadata":{"annotations":{"sidecar.opentelemetry.io/inject":"sidecar"}}}}}'
done
```

Or individually:

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

### (Optional) Enable Auto-Instrumentation

For automatic code instrumentation without code changes:

```bash
# Python API
oc patch deployment python-api -n observability-demo \
  -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-python":"demo-instrumentation"}}}}}'

# Node App
oc patch deployment node-app -n observability-demo \
  -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-nodejs":"demo-instrumentation"}}}}}'

# Quarkus/Java API
oc patch deployment quarkus-api -n observability-demo \
  -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-java":"demo-instrumentation"}}}}}'
```

## Verification

### Check Sidecar Injection

After patching deployments:

```bash
# Check that pods have the sidecar container
oc get pods -n observability-demo -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'

# Should show: <pod-name>  otc-container <app-container>
```

### Check Telemetry Flow

```bash
# Central collector logs
oc logs -n observability-demo -l app.kubernetes.io/name=central-collector -c otc-container --tail=50

# Sidecar logs (after injection)
oc logs -n observability-demo <app-pod-name> -c otc-container --tail=50
```

### Access Observability UIs

#### Jaeger (Traces via Tempo)

```bash
oc port-forward -n openshift-tempo-operator svc/tempo-tempo-query-frontend 16686:16686
```

Open: http://localhost:16686

#### Prometheus (Metrics)

```bash
oc port-forward -n observability-demo svc/observability-stack-prometheus 9090:9090
```

Open: http://localhost:9090

Query for span metrics:
- `traces_spanmetrics_calls_total`
- `traces_spanmetrics_latency`

## Troubleshooting

### Sidecar Not Injecting

1. Check the sidecar collector exists:
   ```bash
   oc get opentelemetrycollector sidecar -n observability-demo
   ```

2. Check the deployment annotation:
   ```bash
   oc get deployment <name> -n observability-demo -o jsonpath='{.spec.template.metadata.annotations}'
   ```

3. Check operator logs:
   ```bash
   oc logs -n openshift-operators -l app.kubernetes.io/name=opentelemetry-operator
   ```

### No Traces in Tempo

1. Check central collector is receiving:
   ```bash
   oc logs -n observability-demo -l app.kubernetes.io/name=central-collector -c otc-container | grep -i tempo
   ```

2. Check Tempo distributor:
   ```bash
   oc get pods -n openshift-tempo-operator | grep distributor
   oc logs -n openshift-tempo-operator <distributor-pod>
   ```

3. Verify bearer token:
   ```bash
   oc get secret tempo-tempo-token -n openshift-tempo-operator
   ```

### No Metrics in Prometheus

1. Check central collector metrics export:
   ```bash
   oc logs -n observability-demo -l app.kubernetes.io/name=central-collector -c otc-container | grep -i prometheus
   ```

2. Check Prometheus remote write endpoint:
   ```bash
   oc get svc observability-stack-prometheus -n observability-demo
   ```

3. Check for errors in Prometheus:
   ```bash
   oc logs -n observability-demo -l app.kubernetes.io/name=prometheus
   ```

## Configuration Files

All configuration is in `manifests/3-opentelemetry/`:

- `subscription.yaml` - Operator installation
- `rbac.yaml` - Service accounts and permissions
- `sidecar-collector.yaml` - Sidecar collector config
- `central-collector.yaml` - Central collector config
- `instrumentation.yaml` - Auto-instrumentation config
- `README.md` - Detailed documentation
- `DEPLOYMENT_ORDER.md` - Step-by-step guide
- `SETUP_SUMMARY.md` - Overview and architecture

## Key Changes Made

### Fixed Issues:
1. ❌ `metricstransform` processor → ✅ `transform` processor (v0.135.0 compatible)
2. ❌ Missing KUBE_NODE_NAME env var → ✅ Removed node filter, using passthrough
3. ❌ Missing nodes RBAC → ✅ Added nodes permissions to ClusterRole
4. ❌ Invalid OTTL statements → ✅ Simplified to name transformations only

### Working Configuration:
- ✅ Spanmetrics connector generates `calls_total` and `latency` metrics
- ✅ Transform processor renames to `traces_spanmetrics_calls_total` and `traces_spanmetrics_latency`
- ✅ OTLP export to Tempo with bearer token auth
- ✅ Prometheus remote write for metrics
- ✅ K8s attributes processor with service account auth
- ✅ Resource detection for OpenShift metadata

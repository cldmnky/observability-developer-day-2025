# Observability Stack - Complete Guide

This guide covers the complete observability stack for the demo applications, including metrics, tracing, and querying.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    observability-demo                        │
│                                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │  go-api  │  │python-api│  │quarkus-  │  │ node-app │   │
│  │  :8080   │  │  :8000   │  │  api     │  │  :3000   │   │
│  │          │  │          │  │  :4003   │  │          │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
│       │             │             │             │          │
│       └─────────────┴─────────────┴─────────────┘          │
│                          │                                  │
│                    ServiceMonitors                          │
│                          │                                  │
│       ┌──────────────────┴──────────────────┐              │
│       ▼                                      ▼              │
│  ┌─────────────┐                      ┌──────────────┐     │
│  │ Prometheus  │◄─────────────────────│ Alertmanager │     │
│  │ (3 replicas)│                      │ (2 replicas) │     │
│  └──────┬──────┘                      └──────────────┘     │
│         │                                                   │
│         ▼                                                   │
│  ┌──────────────┐                                          │
│  │Thanos Querier│                                          │
│  └──────────────┘                                          │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│           openshift-tempo-operator                          │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │                  TempoStack                         │    │
│  │  ┌─────────────┐  ┌──────────────┐  ┌───────────┐ │    │
│  │  │ Distributor │  │   Ingester   │  │  Querier  │ │    │
│  │  └─────────────┘  └──────────────┘  └───────────┘ │    │
│  │         │                  │              │        │    │
│  │         └──────────────────┴──────────────┘        │    │
│  │                          │                         │    │
│  │                   MinIO Storage                    │    │
│  │            (storage.blahonga.me:9199)              │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Components

### 1. Applications (observability-demo namespace)

All applications expose Prometheus metrics on `/metrics`:

| Application | Port | Framework | Metrics Library |
|------------|------|-----------|-----------------|
| go-api | 8080 | Go/net/http | Prometheus Go client |
| python-api | 8000 | FastAPI | prometheus_client |
| quarkus-api | 4003 | Quarkus | Micrometer |
| node-app | 3000 | Express | prom-client |

### 2. Monitoring Stack (observability-demo namespace)

Deployed via **Cluster Observability Operator v1.2.2**:

- **MonitoringStack**: Custom resource managing Prometheus, Alertmanager, and Thanos Querier
  - Label selector: `monitoring.rhobs/stack: observability-stack`
  - Resource: `coo-monitoring-stack.yaml`

- **Prometheus**: 
  - 3 replicas (statefulset)
  - Scrapes metrics from ServiceMonitors every 30s
  - Remote write receiver enabled
  - External labels: `cluster=local, environment=dev`

- **Alertmanager**:
  - 2 replicas (1 pending on single-node due to anti-affinity)
  - Alert routing and notification

- **Thanos Querier**:
  - 1 replica
  - Unified query interface across Prometheus instances
  - PromQL query API

### 3. ServiceMonitors (observability-demo namespace)

ServiceMonitor resources configure Prometheus scrape targets:

```yaml
# All ServiceMonitors use this label for discovery
labels:
  monitoring.rhobs/stack: observability-stack
```

Files in `manifests/3-servicemonitors/`:
- `go-api-servicemonitor.yaml`
- `python-api-servicemonitor.yaml`
- `quarkus-api-servicemonitor.yaml`
- `node-app-servicemonitor.yaml`

### 4. Distributed Tracing (openshift-tempo-operator namespace)

Deployed via **Tempo Operator v0.18.0-1**:

- **TempoStack**: Multi-tenant tracing backend
  - Storage: MinIO S3 at `storage.blahonga.me:9199`
  - Bucket: `borg-tempo`
  - Retention: 48 hours
  - Tenants: `dev` and `prod`
  - Jaeger Query UI enabled

- **OTLP Endpoints**:
  - HTTP: `tempo-tempo-distributor.openshift-tempo-operator.svc:4318`
  - gRPC: `tempo-tempo-distributor.openshift-tempo-operator.svc:4317`

## Quick Start

### Verify Deployments

```bash
# Check all application pods
oc get pods -n observability-demo

# Check monitoring stack
oc get monitoringstack,thanosquerier -n observability-demo

# Check Prometheus/Alertmanager pods
oc get pods -n observability-demo | grep -E "prometheus|alertmanager|thanos"

# Check Tempo stack
oc get tempostack -n openshift-tempo-operator
```

### Access Prometheus UI

```bash
# Port-forward to Prometheus
oc port-forward -n observability-demo svc/prometheus-observability-stack 9090:9090

# Open http://localhost:9090
```

**Query Examples**:
```promql
# HTTP request rate per service
rate(http_requests_total[5m])

# P95 request duration
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# CPU usage by pod
rate(process_cpu_seconds_total[5m])
```

### Access Thanos Querier

```bash
# Port-forward to Thanos Querier
oc port-forward -n observability-demo svc/thanos-querier-observability-stack 9090:9090

# Open http://localhost:9090
# Queries all Prometheus instances with deduplication
```

### Access Jaeger UI (Tempo)

```bash
# Get Jaeger Query route
oc get route -n openshift-tempo-operator

# Port-forward if route not available
oc port-forward -n openshift-tempo-operator svc/tempo-tempo-query-frontend 16686:16686

# Open http://localhost:16686
```

### Check Metrics Targets

```bash
# List Prometheus targets via API
oc exec -n observability-demo prometheus-observability-stack-0 -c prometheus -- \
  wget -qO- http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Or view in Prometheus UI: http://localhost:9090/targets
```

### Test Metric Scraping

```bash
# Test metrics endpoint for each service
oc exec -n observability-demo $(oc get pod -n observability-demo -l app=go-api -o name | head -1) -- \
  curl -s http://localhost:8080/metrics | head -20

oc exec -n observability-demo $(oc get pod -n observability-demo -l app=python-api -o name | head -1) -- \
  curl -s http://localhost:8000/metrics | head -20

oc exec -n observability-demo $(oc get pod -n observability-demo -l app=quarkus-api -o name | head -1) -- \
  curl -s http://localhost:4003/metrics | head -20

oc exec -n observability-demo $(oc get pod -n observability-demo -l app=node-app -o name | head -1) -- \
  curl -s http://localhost:3000/metrics | head -20
```

## API Documentation Sources

All components were configured using latest API documentation from Context7:

- **Tempo/TempoStack**: Retrieved from `/grafana/tempo` (Trust Score: 9.7, 3781 snippets)
  - TempoStack CRD configuration
  - Storage configuration (MinIO, S3, Azure, GCS, ODF)
  - Multi-tenancy setup
  - Jaeger Query integration

- **Thanos Querier**: Retrieved from `/thanos-io/thanos` (Trust Score: 8.2, 619 snippets)
  - ThanosQuerier deployment patterns
  - Service configuration
  - Endpoint discovery via DNS SRV

- **MonitoringStack**: RHOBS (Red Hat Observability Stack) patterns
  - ResourceSelector using `monitoring.rhobs/stack` label
  - Prometheus configuration with remote write
  - Alertmanager integration

## Troubleshooting

### ServiceMonitors Not Being Scraped

```bash
# Verify ServiceMonitor has correct label
oc get servicemonitor -n observability-demo -o yaml | grep -A2 "monitoring.rhobs/stack"

# Check MonitoringStack resourceSelector
oc get monitoringstack observability-stack -n observability-demo -o yaml | grep -A2 resourceSelector

# Check Prometheus config
oc exec -n observability-demo prometheus-observability-stack-0 -c prometheus -- \
  cat /etc/prometheus/config_out/prometheus.env.yaml | grep -A10 servicemonitor
```

### Alertmanager Pod Pending

The `alertmanager-observability-stack-1` pod is pending due to pod anti-affinity rules on a single-node cluster. This is expected and acceptable. One Alertmanager instance is sufficient for the demo.

### Missing Metrics

```bash
# Check if metrics endpoint is accessible
oc port-forward -n observability-demo svc/go-api 8080:8080
curl http://localhost:8080/metrics

# Check Prometheus logs
oc logs -n observability-demo prometheus-observability-stack-0 -c prometheus --tail=50
```

### Tempo Trace Ingestion

```bash
# Verify TempoStack is ready
oc get tempostack tempo -n openshift-tempo-operator -o jsonpath='{.status.conditions[?(@.type=="Ready")]}'

# Test OTLP endpoint
oc run test-tempo --rm -i --restart=Never --image=curlimages/curl -- \
  curl -v http://tempo-tempo-distributor.openshift-tempo-operator.svc:4318/v1/traces
```

## Configuration Files

### Key Resources

```
manifests/
├── 1-apps/                           # Application deployments
│   ├── namespace.yaml
│   ├── go-api-deployment.yaml
│   ├── python-api-deployment.yaml
│   ├── quarkus-api-deployment.yaml
│   └── node-app-deployment.yaml
│
├── 2-observability-stack/            # Monitoring stack
│   ├── coo-namespace.yaml
│   ├── coo-operatorgroup.yaml
│   ├── coo-subscription.yaml
│   ├── coo-monitoring-stack.yaml     # MonitoringStack CR
│   ├── coo-thanos-querier.yaml       # ThanosQuerier CR
│   ├── tempo-namespace.yaml
│   ├── tempo-operatorgroup.yaml
│   ├── tempo-subscription.yaml
│   ├── tempo-secret.yaml             # MinIO S3 credentials
│   ├── tempo-rbac.yaml
│   └── tempostack.yaml               # TempoStack CR
│
└── 3-servicemonitors/                # Prometheus scrape config
    ├── go-api-servicemonitor.yaml
    ├── python-api-servicemonitor.yaml
    ├── quarkus-api-servicemonitor.yaml
    └── node-app-servicemonitor.yaml
```

## Label Strategy

The observability stack uses a consistent labeling strategy:

### For Discovery
```yaml
# ServiceMonitors use this label to be discovered by MonitoringStack
labels:
  monitoring.rhobs/stack: observability-stack
```

### For Application Identification
```yaml
# Applications use these labels
labels:
  app: <app-name>                          # Service selector
  app.kubernetes.io/name: <app-name>       # Standard k8s label
  app.kubernetes.io/component: backend|frontend
```

### MonitoringStack Selector
```yaml
# MonitoringStack discovers resources with this label
resourceSelector:
  matchLabels:
    monitoring.rhobs/stack: observability-stack
```

## Next Steps

1. **Add Custom Alerts**: Create PrometheusRule resources for alerting
2. **Instrument Tracing**: Add OpenTelemetry SDK to applications
3. **Create Dashboards**: Deploy Grafana and import dashboards
4. **Configure Alert Routing**: Update Alertmanager configuration
5. **Set Up Remote Write**: Configure long-term storage with Thanos Store

## References

- [Cluster Observability Operator](https://github.com/rhobs/cluster-observability-operator)
- [Tempo Operator](https://github.com/grafana/tempo-operator)
- [Prometheus Operator CRDs](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api.md)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)

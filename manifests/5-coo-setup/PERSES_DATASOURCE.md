# Perses Datasource Configuration

This directory contains the PersesDatasource configuration for integrating the `observability-demo` MonitoringStack with Perses dashboards in the OpenShift Console.

## Overview

The PersesDatasource connects Perses (the next-generation dashboarding system used by COO) to the Thanos Querier in the `observability-demo` namespace, allowing you to:

- Create Perses dashboards that query metrics from your demo applications
- Visualize application metrics in the OpenShift Console (Observe → Metrics)
- Build modern, declarative dashboards with better performance than traditional Grafana

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  OpenShift Console (Observe → Metrics)                      │
│                                                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Perses Dashboards                                     │  │
│  │  (defined via PersesDashboard CRs)                    │  │
│  └────────────────┬──────────────────────────────────────┘  │
│                   │                                          │
│                   ▼                                          │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  PersesDatasource                                      │  │
│  │  (observability-demo-thanos-querier)                  │  │
│  │                                                        │  │
│  │  URL: http://thanos-querier-observability-stack.     │  │
│  │       observability-demo.svc.cluster.local:10902      │  │
│  └────────────────┬──────────────────────────────────────┘  │
└───────────────────┼──────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│  observability-demo namespace                                │
│                                                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Thanos Querier (port 10902)                          │  │
│  │  Service: thanos-querier-observability-stack          │  │
│  │                                                        │  │
│  │  Queries:                                             │  │
│  │    • Prometheus (3 replicas)                          │  │
│  │    • Application metrics via ServiceMonitors          │  │
│  │    • Span metrics from OpenTelemetry                  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Deployment

### Prerequisites

1. Cluster Observability Operator installed with Monitoring UI Plugin enabled
2. MonitoringStack deployed in `observability-demo` namespace
3. ThanosQuerier deployed and running

### Apply the Datasource

```bash
# Apply the PersesDatasource and secret
oc apply -f manifests/5-coo-setup/perses-datasource.yaml

# Verify the datasource is created
oc get persesdatasource -n openshift-cluster-observability-operator
```

**Expected Output:**
```
NAME                                AGE
observability-demo-thanos-querier   10s
```

### Check Datasource Status

```bash
# View datasource details
oc get persesdatasource observability-demo-thanos-querier \
  -n openshift-cluster-observability-operator -o yaml

# Check if datasource is available
oc get persesdatasource observability-demo-thanos-querier \
  -n openshift-cluster-observability-operator \
  -o jsonpath='{.status.conditions[?(@.type=="Available")].status}'
```

Should return: `True`

## Using the Datasource

### In OpenShift Console

1. Navigate to **Observe → Metrics**
2. The datasource will be available for Perses dashboards
3. You can now create PersesDashboard resources that reference this datasource

### Create a Simple Dashboard

Example PersesDashboard using this datasource:

```yaml
apiVersion: perses.dev/v1alpha1
kind: PersesDashboard
metadata:
  name: observability-demo-apps
  namespace: openshift-cluster-observability-operator
spec:
  datasources:
    - observability-demo-thanos-querier
  panels:
    - title: "Request Rate"
      queries:
        - expr: 'rate(http_request_duration_seconds_count{namespace="observability-demo"}[5m])'
      visualizations:
        - type: timeseries
```

### Query Examples

Once the datasource is configured, you can query metrics like:

```promql
# Application request rate
rate(http_request_duration_seconds_count{namespace="observability-demo"}[5m])

# Span metrics (RED metrics from traces)
rate(traces_spanmetrics_calls_total{namespace="observability-demo"}[5m])

# P95 latency
histogram_quantile(0.95, 
  rate(traces_spanmetrics_latency_bucket{namespace="observability-demo"}[5m])
)

# Memory usage by pod
container_memory_working_set_bytes{namespace="observability-demo"}

# CPU usage by pod
rate(container_cpu_usage_seconds_total{namespace="observability-demo"}[5m])
```

## Configuration Details

### Datasource Spec

```yaml
spec:
  client:
    tls:
      enable: false  # HTTP connection (no TLS)
  config:
    default: false   # Not the default datasource
    display:
      name: "Observability Demo - Thanos Querier"
    plugin:
      kind: PrometheusDatasource  # Prometheus-compatible API
      spec:
        proxy:
          kind: HTTPProxy
          spec:
            url: 'http://thanos-querier-observability-stack.observability-demo.svc.cluster.local:10902'
```

### Key Fields

- **URL**: Points to Thanos Querier service (port 10902 is the HTTP API)
- **TLS**: Disabled for internal HTTP communication
- **Proxy**: HTTPProxy allows COO to proxy requests from the console to Thanos
- **Secret**: Empty secret (authentication handled by service accounts)

## Troubleshooting

### Datasource Not Available

```bash
# Check datasource status
oc describe persesdatasource observability-demo-thanos-querier \
  -n openshift-cluster-observability-operator

# Check Perses operator logs
oc logs -n openshift-cluster-observability-operator \
  -l app.kubernetes.io/name=perses-operator

# Verify Thanos Querier is accessible
oc run test-thanos --rm -i --restart=Never --image=curlimages/curl -- \
  curl -s http://thanos-querier-observability-stack.observability-demo.svc:10902/api/v1/query?query=up
```

### No Data in Dashboards

```bash
# Test Thanos Querier directly
oc port-forward -n observability-demo svc/thanos-querier-observability-stack 10902:10902

# Query from local machine
curl 'http://localhost:10902/api/v1/query?query=up'

# Check Prometheus is scraping targets
oc port-forward -n observability-demo svc/prometheus-observability-stack 9090:9090
# Open http://localhost:9090/targets
```

### Secret Issues

```bash
# Verify secret exists
oc get secret observability-demo-thanos-querier-secret \
  -n openshift-cluster-observability-operator

# Check secret is referenced correctly
oc get persesdatasource observability-demo-thanos-querier \
  -n openshift-cluster-observability-operator \
  -o jsonpath='{.spec.config.plugin.spec.proxy.spec.secret}'
```

## Making This the Default Datasource

To make this datasource the default for all Perses dashboards:

```bash
oc patch persesdatasource observability-demo-thanos-querier \
  -n openshift-cluster-observability-operator \
  --type=merge \
  -p '{"spec":{"config":{"default":true}}}'
```

**Note**: Only one datasource should be marked as default.

## Integration with Demo

This datasource enables:

1. **Real-time monitoring** of demo applications in OpenShift Console
2. **Perses dashboards** showing:
   - Request rates and error rates
   - Latency percentiles (p50, p95, p99)
   - Resource usage (CPU, memory)
   - Span metrics from distributed traces
3. **Unified observability** - metrics and traces in one place

## References

- [Perses Documentation](https://perses.dev/)
- [COO Monitoring UI Plugin](https://docs.redhat.com/en/documentation/openshift_container_platform/4.17/html-single/cluster_observability_operator/index#monitoring-ui-plugin)
- [Thanos Querier API](https://thanos.io/tip/components/query.md/)
- [PromQL Query Language](https://prometheus.io/docs/prometheus/latest/querying/basics/)

# Perses Datasource Setup - Quick Reference

## What is This?

A **PersesDatasource** configuration that connects Perses dashboards in the OpenShift Console to the Thanos Querier in your `observability-demo` namespace.

## Files Created

1. **manifests/5-coo-setup/perses-datasource.yaml** - The datasource and secret manifest
2. **manifests/5-coo-setup/PERSES_DATASOURCE.md** - Detailed documentation

## Quick Deployment

```bash
# Deploy the datasource
oc apply -f manifests/5-coo-setup/perses-datasource.yaml

# Verify it's created
oc get persesdatasource -n openshift-cluster-observability-operator

# Check status
oc get persesdatasource observability-demo-thanos-querier \
  -n openshift-cluster-observability-operator \
  -o jsonpath='{.status.conditions[?(@.type=="Available")].status}'
# Should return: True
```

## What Does It Do?

Connects Perses to your demo environment:

```
OpenShift Console (Observe → Metrics)
         ↓
    PersesDatasource
         ↓
    Thanos Querier (observability-demo)
         ↓
    Prometheus + ServiceMonitors
         ↓
    Application Metrics
```

## Configuration Details

- **Name**: `observability-demo-thanos-querier`
- **Namespace**: `openshift-cluster-observability-operator`
- **URL**: `http://thanos-querier-observability-stack.observability-demo.svc.cluster.local:10902`
- **Type**: PrometheusDatasource (Prometheus-compatible API)
- **TLS**: Disabled (internal HTTP)

## Usage in Dashboards

Create a PersesDashboard that references this datasource:

```yaml
apiVersion: perses.dev/v1alpha1
kind: PersesDashboard
metadata:
  name: my-dashboard
  namespace: openshift-cluster-observability-operator
spec:
  datasources:
    - observability-demo-thanos-querier
  # ... panels and queries
```

## Example Queries

Once configured, you can query:

```promql
# Request rate
rate(http_request_duration_seconds_count{namespace="observability-demo"}[5m])

# Span metrics from traces
rate(traces_spanmetrics_calls_total[5m])

# P95 latency
histogram_quantile(0.95, rate(traces_spanmetrics_latency_bucket[5m]))
```

## Troubleshooting

```bash
# Check datasource status
oc describe persesdatasource observability-demo-thanos-querier \
  -n openshift-cluster-observability-operator

# Test Thanos Querier connectivity
oc run test-thanos --rm -i --restart=Never --image=curlimages/curl -- \
  curl -s http://thanos-querier-observability-stack.observability-demo.svc:10902/api/v1/query?query=up

# View Perses operator logs
oc logs -n openshift-cluster-observability-operator \
  -l app.kubernetes.io/name=perses-operator --tail=50
```

## Make It Default (Optional)

To make this the default datasource for all Perses dashboards:

```bash
oc patch persesdatasource observability-demo-thanos-querier \
  -n openshift-cluster-observability-operator \
  --type=merge \
  -p '{"spec":{"config":{"default":true}}}'
```

## Integration with Demo

This datasource enables you to:

1. ✅ Create custom Perses dashboards for demo applications
2. ✅ Visualize metrics directly in OpenShift Console
3. ✅ Query both application metrics and span metrics (RED metrics from traces)
4. ✅ Build production-ready dashboards as code (GitOps-friendly)

## Next Steps

- See [PERSES_DATASOURCE.md](./PERSES_DATASOURCE.md) for detailed documentation
- Check out [Perses documentation](https://perses.dev/) for dashboard examples
- Review [COO Monitoring UI Plugin docs](https://docs.redhat.com/en/documentation/openshift_container_platform/4.17/html-single/cluster_observability_operator/index#monitoring-ui-plugin)

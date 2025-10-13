# Perses Schema Verification

This document summarizes the verification of Perses datasource and dashboard manifests against official documentation and schemas.

## Documentation References

1. **Red Hat Observability Operator Guide**: https://github.com/rhobs/observability-operator/blob/main/docs/user-guides/perses-dashboards.md
2. **PersesDashboard CRD Schema**: https://github.com/perses/perses-operator/blob/main/config/crd/bases/perses.dev_persesdashboards.yaml
3. **PersesDatasource CRD Schema**: https://github.com/perses/perses-operator/blob/main/config/crd/bases/perses.dev_persesdatasources.yaml

## API Version

**Cluster Support**: The OpenShift cluster with COO 1.2+ supports `perses.dev/v1alpha1` only.

```bash
$ oc api-versions | grep perses
perses.dev/v1alpha1
```

Both our manifests use `apiVersion: perses.dev/v1alpha1` which is correct for this cluster.

## PersesDatasource Structure

### Schema Compliance (v1alpha1)

```yaml
apiVersion: perses.dev/v1alpha1
kind: PersesDatasource
metadata:
  name: <datasource-name>
  namespace: <namespace>
spec:
  client:              # OPTIONAL - authentication/TLS config
    tls:
      enable: boolean
      caCert:
        certPath: string
        type: file|secret|configmap
    basicAuth:         # OPTIONAL
    oauth:             # OPTIONAL
    kubernetesAuth:    # OPTIONAL
  config:              # REQUIRED
    default: boolean   # REQUIRED
    display:           # OPTIONAL
      name: string
      description: string
    plugin:            # REQUIRED
      kind: string     # e.g., "PrometheusDatasource"
      spec:            # REQUIRED - plugin-specific config
        proxy:
          kind: HTTPProxy
          spec:
            url: string
            secret: string  # Perses-internal secret name (NOT K8s Secret)
```

### Key Findings

1. **No Kubernetes Secret Required**: The `secret` field in the proxy spec is NOT a reference to a Kubernetes Secret. According to the official docs:
   > "The name `thanos-querier-datasource-secret` in the example isn't a Kubernetes secret. It's a reference to a Perses secret that the Perses Operator automatically generates from the datasource name and stores in the Perses backend."

2. **TLS Configuration**: For HTTP endpoints (like our Thanos Querier on port 10902), no TLS configuration is needed. Remove `client.tls` section entirely.

3. **Secret Field**: Can be omitted for internal service-to-service communication without authentication.

### Our Implementation

```yaml
apiVersion: perses.dev/v1alpha1
kind: PersesDatasource
metadata:
  name: observability-demo-thanos-querier
  namespace: openshift-cluster-observability-operator
spec:
  config:
    default: false
    display:
      name: "Observability Demo - Thanos Querier"
      description: "Thanos Querier for observability-demo MonitoringStack"
    plugin:
      kind: PrometheusDatasource
      spec:
        proxy:
          kind: HTTPProxy
          spec:
            url: 'http://thanos-querier-observability-stack.observability-demo.svc.cluster.local:10902'
```

**Status**: ✅ Schema compliant, validated successfully

## PersesDashboard Structure

### Schema Compliance (v1alpha1)

```yaml
apiVersion: perses.dev/v1alpha1
kind: PersesDashboard
metadata:
  name: <dashboard-name>
  namespace: <namespace>
spec:
  datasources:       # OPTIONAL - inline datasource definitions
    <name>:
      default: boolean
      plugin:
        kind: string
        spec: object
  display:           # OPTIONAL
    name: string
    description: string
  duration: string   # REQUIRED - e.g., "1h", "24h"
  refreshInterval:   # OPTIONAL - e.g., "1m"
  variables:         # OPTIONAL
    - kind: string
      spec: object
  panels:            # REQUIRED - map of panel definitions
    "<key>":         # String keys like "0_0", "0_1"
      kind: Panel    # Always "Panel"
      spec:
        display:
          name: string
        plugin:
          kind: string
          spec: object
        queries:
          - kind: TimeSeriesQuery
            spec:
              plugin:
                kind: PrometheusTimeSeriesQuery
                spec:
                  datasource:
                    kind: PrometheusDatasource
                    name: string  # References PersesDatasource by name
                  query: string
                  seriesNameFormat: string
  layouts:           # REQUIRED
    - kind: Grid
      spec:
        display:
          title: string
          collapse:
            open: boolean
        items:
          - x: number
            y: number
            width: number
            height: number
            content:
              $ref: "#/spec/panels/<key>"  # JSON pointer reference
```

### Key Findings

1. **Panels Structure**: Must be a map with string keys (e.g., "0_0", "0_1"), NOT a list
2. **Panel Kind**: Always "Panel" (not the plugin type)
3. **Grid Layout**: Uses JSON pointer references (`$ref: "#/spec/panels/<key>"`)
4. **Datasource Reference**: Panels reference datasources by `name`, not by inline definition
5. **Duration Format**: String with units (h, m, s, etc.) - e.g., "1h" not just "1"

### Our Implementation

```yaml
apiVersion: perses.dev/v1alpha1
kind: PersesDashboard
metadata:
  name: observability-demo-overview
  namespace: openshift-cluster-observability-operator
spec:
  display:
    name: "Observability Demo - Application Overview"
    description: "Overview of Go, Python, Quarkus, and Node.js microservices"
  duration: 1h
  variables:
    - kind: ListVariable
      spec:
        name: namespace
        # ... variable configuration
  panels:
    "0_0":
      kind: Panel
      spec:
        display:
          name: "HTTP Request Rate"
        plugin:
          kind: TimeSeriesChart
          spec:
            # ... chart configuration
        queries:
          - kind: TimeSeriesQuery
            spec:
              plugin:
                kind: PrometheusTimeSeriesQuery
                spec:
                  datasource:
                    kind: PrometheusDatasource
                    name: observability-demo-thanos-querier  # ✅ References datasource by name
                  query: 'sum by (job) (rate(http_request_duration_seconds_count{namespace="$namespace"}[5m]))'
    # ... 7 more panels (0_1 through 3_1)
  layouts:
    - kind: Grid
      spec:
        display:
          title: "Application Metrics"
          collapse:
            open: true
        items:
          - x: 0
            y: 0
            width: 12
            height: 7
            content:
              $ref: "#/spec/panels/0_0"  # ✅ JSON pointer reference
          # ... more grid items
```

**Status**: ✅ Schema compliant, validated successfully

## Validation Results

```bash
# Datasource validation
$ oc apply --dry-run=client -f manifests/5-coo-setup/perses-datasource.yaml
persesdatasource.perses.dev/observability-demo-thanos-querier created (dry run)

# Dashboard validation
$ oc apply --dry-run=client -f manifests/5-coo-setup/example-dashboard.yaml
persesdashboard.perses.dev/observability-demo-overview created (dry run)
```

## Changes Made

### perses-datasource.yaml

**Before**:
- ❌ Created a Kubernetes Secret (not needed)
- ❌ Included `client.tls` config with `enable: false` but still had cert paths
- ❌ Had `secret` field in proxy spec referencing the K8s Secret

**After**:
- ✅ Removed Kubernetes Secret entirely
- ✅ Removed `client` section (no TLS needed for HTTP)
- ✅ Removed `secret` field (not needed for internal communication)
- ✅ Clean, minimal configuration

### example-dashboard.yaml

**Before**:
- ✅ Structure was already correct
- ✅ All 8 panels already referenced datasource by name
- ✅ Grid layout with JSON pointers was correct

**After**:
- ✅ No structural changes needed (only updated API version comment)
- ✅ Maintained all 8 panel configurations
- ✅ All datasource references intact

## Deployment

Deploy in order:

```bash
# 1. Deploy datasource (no dependencies)
oc apply -f manifests/5-coo-setup/perses-datasource.yaml

# 2. Wait for datasource to be ready
oc get persesdatasource -n openshift-cluster-observability-operator

# 3. Deploy dashboard
oc apply -f manifests/5-coo-setup/example-dashboard.yaml

# 4. Verify dashboard
oc get persesdashboard -n openshift-cluster-observability-operator
```

## Access

Navigate to OpenShift Console:
- **Observe** → **Metrics** → Select "Observability Demo - Application Overview" dashboard
- Use namespace selector to filter by `observability-demo`

## References

- [Perses Documentation](https://perses.dev/)
- [COO Perses Dashboards Guide](https://github.com/rhobs/observability-operator/blob/main/docs/user-guides/perses-dashboards.md)
- [Community Dashboards Repository](https://github.com/perses/community-dashboards)
- [OpenShift Sample Dashboard](https://github.com/perses/perses-operator/blob/main/config/samples/openshift/openshift-cluster-sample-dashboard.yaml)

## Verification Date

October 13, 2025

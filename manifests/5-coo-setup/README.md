# Cluster Observability Operator UI Plugins

This directory contains the UI plugin configurations for the Cluster Observability Operator (COO).

## Components

### Monitoring UI Plugin
- **File**: `uiplugin-monitoring.yaml`
- **Purpose**: Enables the monitoring UI plugin with Perses dashboard support
- **Features**:
  - Perses dashboards for visualizing metrics from the MonitoringStack
  - Integration with OpenShift Console
  - Enhanced monitoring capabilities in the web console

### Distributed Tracing UI Plugin
- **File**: `uiplugin-distributed-tracing.yaml`
- **Purpose**: Enables distributed tracing visualization in the OpenShift Console
- **Features**:
  - View traces from TempoStack instances
  - Scatter plot visualization of trace data
  - Gantt chart for span details
  - Integration with the Tempo backend deployed in `openshift-tempo-operator` namespace

### Perses Datasource
- **File**: `perses-datasource.yaml`
- **Purpose**: Configures Perses datasource pointing to the observability-demo Thanos Querier
- **Features**:
  - Enables Perses dashboards to query metrics from the demo MonitoringStack
  - Provides access to application metrics and span metrics
  - Allows creation of custom PersesDashboard resources in OpenShift Console
- **Schema Compliance**: Verified against official Perses v1alpha1 CRD schema
- **Documentation**: 
  - [PERSES_DATASOURCE.md](./PERSES_DATASOURCE.md) - Detailed usage guide
  - [SCHEMA_VERIFICATION.md](./SCHEMA_VERIFICATION.md) - Schema compliance verification
  - [PERSES_QUICKSTART.md](./PERSES_QUICKSTART.md) - Quick start guide

### Example Perses Dashboard
- **File**: `example-dashboard.yaml`
- **Purpose**: Pre-built dashboard visualizing the 4 demo microservices
- **Features**:
  - 8 panels covering HTTP metrics, span metrics, and resource usage
  - Go API, Python API, Quarkus API, and Node.js Web App visualization
  - Namespace variable for filtering
  - Grid layout with proper panel positioning
- **Schema Compliance**: Verified against official Perses v1alpha1 CRD schema

## Installation

Apply the UI plugins and datasource after the COO and related operators are installed:

```bash
# Apply the monitoring UI plugin with Perses
oc apply -f manifests/5-coo-setup/uiplugin-monitoring.yaml

# Apply the distributed tracing UI plugin
oc apply -f manifests/5-coo-setup/uiplugin-distributed-tracing.yaml

# Apply the Perses datasource for observability-demo MonitoringStack
oc apply -f manifests/5-coo-setup/perses-datasource.yaml
```

## Verification

1. **Check UIPlugin status**:
   ```bash
   oc get uiplugin -n openshift-cluster-observability-operator
   ```

2. **Verify Console Plugins are enabled**:
   ```bash
   oc get console.operator.openshift.io cluster -o jsonpath='{.spec.plugins}'
   ```

3. **Check PersesDatasource**:
   ```bash
   oc get persesdatasource -n openshift-cluster-observability-operator
   ```

4. **Access the OpenShift Console**:
   - Navigate to **Observe → Metrics** to see Perses dashboards
   - Navigate to **Observe → Traces** to view distributed traces
   - Create PersesDashboard resources using the observability-demo datasource

## Perses Dashboards

Perses is a next-generation dashboarding system that provides:
- Modern, declarative dashboard definitions
- Better performance than traditional Grafana
- Native integration with Prometheus and other data sources
- Version control friendly YAML configuration

With the monitoring UI plugin enabled and Perses configured, you can:
1. View pre-built accelerator dashboards
2. Create custom dashboards for your MonitoringStack
3. Share dashboards across teams

## Distributed Tracing

The distributed tracing UI plugin connects to the TempoStack instance deployed in the `openshift-tempo-operator` namespace and allows you to:
1. Select a TempoStack instance
2. Query traces by time range and filters
3. View trace spans in a Gantt chart
4. Inspect span attributes and tags
5. Navigate from traces to related logs and metrics (when troubleshooting panel is also installed)

## Architecture Integration

The UI plugins integrate with the observability stack:

```
Applications (observability-demo namespace)
    ↓ (metrics via ServiceMonitors)
MonitoringStack (observability-demo namespace)
    ↓ (visualized via)
Monitoring UI Plugin → Perses Dashboards
    ↓ (displayed in)
OpenShift Console (Observe → Metrics)

Applications (observability-demo namespace)
    ↓ (traces via OpenTelemetry)
TempoStack (openshift-tempo-operator namespace)
    ↓ (visualized via)
Distributed Tracing UI Plugin
    ↓ (displayed in)
OpenShift Console (Observe → Traces)
```

## Notes

- The monitoring UI plugin requires Prometheus >= v2.26.0
- Distributed tracing UI plugin requires a multi-tenant TempoStack or TempoMonolithic instance
- UI plugins are automatically registered with the OpenShift Console
- You may need to refresh the console after plugin installation
- Perses dashboards are deployed by default in COO 1.2+

## References

- [COO Documentation - Monitoring UI Plugin](https://docs.redhat.com/en/documentation/openshift_container_platform/4.17/html-single/cluster_observability_operator/index#monitoring-ui-plugin)
- [COO Documentation - Distributed Tracing UI Plugin](https://docs.redhat.com/en/documentation/openshift_container_platform/4.17/html-single/cluster_observability_operator/index#distributed-tracing-ui-plugin)
- [Perses Project](https://perses.dev/)

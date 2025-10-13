# Observability Stack Installation

This directory contains manifests for installing and configuring the OpenShift observability stack with metrics and distributed tracing.

## Components

### Metrics Stack
1. **Cluster Observability Operator** - Red Hat's operator for managing monitoring stacks
2. **MonitoringStack** - Prometheus, Alertmanager, and related components for the observability-demo namespace

### Distributed Tracing Stack
3. **Tempo Operator** - Red Hat's operator for distributed tracing
4. **TempoStack** - Distributed tracing backend with S3 storage and Jaeger UI

See [TEMPO.md](TEMPO.md) for detailed Tempo installation and configuration instructions.

## Prerequisites

- OpenShift cluster with cluster-admin access
- `oc` CLI tool installed and configured
- The observability-demo namespace must exist (created in step 1-apps)

## Installation Order

The manifests must be applied in the following order:

### Step 1: Install Cluster Observability Operator

```bash
# Create the operator namespace
oc apply -f namespace.yaml

# Create the OperatorGroup
oc apply -f operatorgroup.yaml

# Create the Subscription (this installs the operator)
oc apply -f subscription.yaml
```

### Step 2: Wait for Operator Installation

Wait for the operator to be installed and running:

```bash
# Watch the operator installation
oc get csv -n openshift-cluster-observability-operator -w

# Verify the operator is running
oc get pods -n openshift-cluster-observability-operator

# Check operator status
oc get subscription cluster-observability-operator -n openshift-cluster-observability-operator
```

The operator should show as `Succeeded` or `InstallSucceeded`.

### Step 3: Deploy MonitoringStack

Once the operator is ready, deploy the monitoring stack:

```bash
# Deploy the MonitoringStack to observability-demo namespace
oc apply -f monitoring-stack.yaml

# Verify the monitoring stack is created
oc get monitoringstack -n observability-demo

# Check that Prometheus and Alertmanager are running
oc get pods -n observability-demo -l app.kubernetes.io/managed-by=monitoring-operator
```

## Quick Deploy (All at Once)

If the operator is already installed:

```bash
# Deploy all manifests
oc apply -f .
```

> **Note**: The MonitoringStack will not be created until the operator is fully installed and running.

## Verify Installation

### Check Operator Status

```bash
# View operator CSV (ClusterServiceVersion)
oc get csv -n openshift-cluster-observability-operator

# Expected output should show cluster-observability-operator.v1.2.2 as Succeeded
```

### Check MonitoringStack

```bash
# Get the MonitoringStack status
oc get monitoringstack observability-stack -n observability-demo -o yaml

# Check Prometheus pods
oc get pods -n observability-demo -l app.kubernetes.io/name=prometheus

# Check Alertmanager pods
oc get pods -n observability-demo -l app.kubernetes.io/name=alertmanager
```

### Access Prometheus UI

```bash
# Port-forward to Prometheus
oc port-forward -n observability-demo svc/prometheus-observability-stack 9090:9090

# Access at http://localhost:9090
```

### Access Alertmanager UI

```bash
# Port-forward to Alertmanager
oc port-forward -n observability-demo svc/alertmanager-observability-stack 9093:9093

# Access at http://localhost:9093
```

## MonitoringStack Configuration

The MonitoringStack is configured with:

- **Retention**: 1 day (suitable for demo/development)
- **Resource Selector**: Monitors resources labeled with `app.kubernetes.io/part-of: observability-stack`
- **Log Level**: info
- **Prometheus Resources**: 100m CPU / 256Mi memory (requests), 500m CPU / 512Mi memory (limits)
- **Alertmanager**: 1 replica with minimal resources

### Resource Selector

The MonitoringStack will automatically discover and scrape metrics from:
- ServiceMonitors
- PodMonitors
- PrometheusRules

All resources must have the label `app.kubernetes.io/part-of: observability-stack` to be monitored.

## What Gets Installed

### In openshift-cluster-observability-operator namespace:
- OperatorGroup
- Subscription (installs the operator)
- Operator pods and related resources

### In observability-demo namespace:
- MonitoringStack custom resource
- Prometheus StatefulSet
- Alertmanager StatefulSet
- Related ConfigMaps and Services

## Troubleshooting

### Operator Not Installing

```bash
# Check operator subscription status
oc describe subscription cluster-observability-operator -n openshift-cluster-observability-operator

# Check install plan
oc get installplan -n openshift-cluster-observability-operator

# Check operator pod logs
oc logs -n openshift-cluster-observability-operator -l app.kubernetes.io/name=cluster-observability-operator
```

### MonitoringStack Not Creating Resources

```bash
# Check MonitoringStack status
oc describe monitoringstack observability-stack -n observability-demo

# Check operator logs
oc logs -n openshift-cluster-observability-operator deployment/cluster-observability-operator-manager

# Verify the operator is watching the correct namespace
oc get monitoringstack --all-namespaces
```

### Prometheus Not Starting

```bash
# Check Prometheus StatefulSet
oc get statefulset -n observability-demo

# Check Prometheus pod logs
oc logs -n observability-demo -l app.kubernetes.io/name=prometheus

# Check for resource issues
oc describe pod -n observability-demo -l app.kubernetes.io/name=prometheus
```

### No Metrics Being Scraped

```bash
# Verify ServiceMonitors exist and are labeled correctly
oc get servicemonitor -n observability-demo

# Check if services have the correct labels
oc get svc -n observability-demo --show-labels

# View Prometheus targets (port-forward to Prometheus first)
# Then visit http://localhost:9090/targets
```

## Next Steps

After the observability stack is running:

1. **Create ServiceMonitors** - Define which services to scrape for metrics
2. **Create PrometheusRules** - Define alerting rules
3. **Configure Alertmanager** - Set up alert routing and receivers
4. **Create Dashboards** - Use Grafana or OpenShift Console for visualization

See the application manifests in `../1-apps/` for examples of services ready to be monitored.

## Cleanup

To remove the observability stack:

```bash
# Delete the MonitoringStack
oc delete monitoringstack observability-stack -n observability-demo

# Delete the operator subscription (this will uninstall the operator)
oc delete subscription cluster-observability-operator -n openshift-cluster-observability-operator

# Delete the operator namespace
oc delete namespace openshift-cluster-observability-operator
```

## References

- [Cluster Observability Operator Documentation](https://docs.openshift.com/container-platform/latest/observability/cluster_observability_operator/cluster-observability-operator-overview.html)
- [MonitoringStack API Reference](https://github.com/rhobs/observability-operator)
- [Prometheus Operator Documentation](https://prometheus-operator.dev/)

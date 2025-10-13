# ServiceMonitors for Application Metrics

This directory contains ServiceMonitor resources that configure Prometheus to scrape metrics from the demo applications.

## Overview

Each application exposes metrics on the `/metrics` endpoint:

- **go-api** (port 8080): Go metrics with custom counters/histograms
- **python-api** (port 8000): FastAPI metrics via `prometheus_client`
- **quarkus-api** (port 4003): Quarkus Micrometer metrics
- **node-app** (port 3000): Node.js metrics via `prom-client`

## Label Strategy

All ServiceMonitors use the label `monitoring.rhobs/stack: observability-stack` to be discovered by the MonitoringStack resource. This ensures Prometheus will automatically create scrape configurations for these services.

## Apply ServiceMonitors

```bash
# Apply all ServiceMonitors
oc apply -f manifests/3-servicemonitors/

# Verify ServiceMonitors are created
oc get servicemonitors -n observability-demo

# Check if Prometheus has picked them up
oc exec -n observability-demo prometheus-observability-stack-0 -c prometheus -- wget -qO- http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job | contains("api") or contains("app"))'
```

## Verify Metrics Collection

```bash
# Port-forward to Prometheus UI
oc port-forward -n observability-demo svc/prometheus-observability-stack 9090:9090

# Then open http://localhost:9090 in your browser and query:
# - http_requests_total
# - http_request_duration_seconds
# - process_cpu_seconds_total
```

## Configuration Details

- **Scrape Interval**: 30 seconds
- **Scrape Path**: `/metrics`
- **Scheme**: HTTP
- **Target Selection**: Matches services with `app: <app-name>` labels

## Integration with MonitoringStack

The MonitoringStack resource at `manifests/2-observability-stack/coo-monitoring-stack.yaml` uses:

```yaml
resourceSelector:
  matchLabels:
    monitoring.rhobs/stack: observability-stack
```

This selector automatically discovers and configures any ServiceMonitor with the matching label.

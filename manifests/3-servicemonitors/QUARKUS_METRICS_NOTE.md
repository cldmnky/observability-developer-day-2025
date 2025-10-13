# Quarkus API Metrics Configuration

## Why No ServiceMonitor for Quarkus?

The `quarkus-api` application uses **OpenTelemetry Java auto-instrumentation** instead of Prometheus direct scraping.

### Configuration

The quarkus-api deployment has these annotations:
```yaml
annotations:
  instrumentation.opentelemetry.io/inject-java: demo-instrumentation
  sidecar.opentelemetry.io/inject: sidecar
```

This means:
1. OpenTelemetry Java agent is automatically injected into the pod
2. Metrics are exported via **OTLP protocol** to the sidecar collector
3. The metrics are then forwarded to the central collector and ultimately to Tempo/Prometheus

### Why /metrics Returns 404

Even though the `pom.xml` includes `quarkus-micrometer-registry-prometheus`, the OpenTelemetry auto-instrumentation takes precedence and the application doesn't expose Prometheus-format metrics at `/metrics`.

### Metrics Flow

```
Quarkus App (OTLP) → Sidecar Collector → Central Collector → Tempo (traces) / Prometheus (via remote write)
```

### Alternatives

If you need Prometheus metrics from Quarkus:

1. **Remove OpenTelemetry auto-instrumentation**:
   - Remove the `instrumentation.opentelemetry.io/inject-java` annotation
   - The Micrometer Prometheus endpoint will then work at `/q/metrics`

2. **Use OpenTelemetry Collector's Prometheus exporter**:
   - Configure the collector to expose metrics in Prometheus format
   - Point ServiceMonitor at the collector's Prometheus port

3. **Dual export** (complex):
   - Configure both Micrometer and OpenTelemetry
   - Export metrics via both paths

### Current Status

The quarkus-api is successfully instrumented with OpenTelemetry and sending metrics via OTLP. 
The ServiceMonitor has been removed since it's not needed for this configuration.

### Verification

Check that metrics are being sent via OpenTelemetry:
```bash
# Check sidecar collector logs
oc logs -n observability-demo deployment/quarkus-api -c otc-container

# Check central collector for quarkus metrics
oc logs -n observability-demo deployment/central-collector | grep quarkus
```

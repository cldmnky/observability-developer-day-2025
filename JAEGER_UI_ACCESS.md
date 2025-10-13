# Accessing the Jaeger UI for Tempo

## Overview
The Tempo TempoStack is configured with Jaeger Query UI enabled and exposed via an OpenShift route through the gateway.

## Configuration
The TempoStack (`tempo`) in namespace `openshift-tempo-operator` has:
- **Jaeger Query UI**: Enabled
- **Gateway**: Enabled with edge-terminated route
- **Multi-tenancy**: OpenShift mode with tenants `dev` and `prod`

## Accessing the Jaeger UI

### Route Information
```bash
# Get the Jaeger UI URL
oc get route tempo-tempo-gateway -n openshift-tempo-operator -o jsonpath='{.spec.host}'
```

**URL**: `https://tempo-tempo-gateway-openshift-tempo-operator.apps.borg.blahonga.me`

### Authentication
The gateway uses OpenShift OAuth for authentication. You'll need to:
1. Log in with your OpenShift credentials
2. The tenant is automatically selected based on your OpenShift namespace/project

### Available Tenants
- **dev**: Tenant ID `1610b0c3-c509-4592-a256-a1871353dbfa`
- **prod**: Tenant ID `6094b0f1-711d-4395-82c0-30c2720c6648`

## Viewing Traces

### Via OpenShift Console (Recommended)
1. Navigate to **Observe** → **Traces** in the OpenShift Console
2. Select TempoStack: **tempo**
3. Select tenant: **dev** or **prod**
4. Search for traces by:
   - Service name (e.g., `go-api`, `node-app`, `python-api`, `quarkus-api`)
   - Operation name
   - Tags
   - Duration

### Via Jaeger UI (Gateway)
Access the Jaeger Query UI directly:
```
https://tempo-tempo-gateway-openshift-tempo-operator.apps.borg.blahonga.me
```

The UI provides:
- Trace search and filtering
- Service dependency graph
- Trace timeline visualization
- Span details and tags

## Services Generating Traces
All application services are instrumented and sending traces:

1. **Node.js** (`node-app`)
   - Auto-instrumentation via OpenTelemetry Operator
   - Sidecar collector pattern

2. **Python** (`python-api`)
   - Auto-instrumentation via OpenTelemetry Operator
   - Sidecar collector pattern

3. **Quarkus** (`quarkus-api`)
   - Auto-instrumentation via OpenTelemetry Operator
   - Sidecar collector pattern

4. **Go** (`go-api`)
   - Manual instrumentation with OpenTelemetry SDK v1.32.0
   - OTLP HTTP exporter to sidecar collector
   - Trace propagation enabled

## Trace Flow
```
Application → Sidecar Collector → Central Collector → Tempo (via gateway)
                                                           ↓
                                                   Jaeger UI (Query)
```

## Troubleshooting

### No traces appearing
1. Check application logs for OpenTelemetry initialization
2. Verify sidecar collector is running:
   ```bash
   oc get pods -n observability-demo -l app=<service-name>
   ```
3. Check central collector logs:
   ```bash
   oc logs -n observability-demo deployment/central-collector
   ```
4. Verify Tempo gateway is running:
   ```bash
   oc get pods -n openshift-tempo-operator -l app.kubernetes.io/component=gateway
   ```

### Authentication issues
- Ensure you're logged into OpenShift
- Check RBAC permissions for the tempo-tempo namespace

### Tenant not showing traces
- Verify you're using the correct tenant (dev/prod)
- Check that the central collector is configured to use the correct tenant headers

## Configuration Files
- **TempoStack**: `manifests/2-observability-stack/tempostack.yaml`
- **Central Collector**: `manifests/3-opentelemetry/central-collector.yaml`
- **Sidecar Collector**: `manifests/3-opentelemetry/sidecar-collector.yaml`

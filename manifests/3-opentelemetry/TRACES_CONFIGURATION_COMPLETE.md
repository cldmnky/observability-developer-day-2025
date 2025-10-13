# OpenTelemetry Traces Configuration - COMPLETE ✅

## Overview
The distributed tracing pipeline is now fully configured and operational with OpenShift tenant-based authentication.

## Architecture

```
Applications (instrumented)
    ↓ (localhost:4318)
Sidecar Collectors (init containers)
    ↓ (OTLP GRPC :4317)
Central Collector (2 replicas)
    ↓ (GRPC :8090 with bearer token + service CA)
Tempo Gateway
    ↓ (internal routing)
Tempo Distributor → Ingester → S3 Storage
    ↓ (query path)
Tempo Querier → Query Frontend
```

## Key Configuration Components

### 1. **Auto-Instrumentation** ✅
All applications have auto-instrumentation enabled:
- **Node.js**: `instrumentation.opentelemetry.io/inject-nodejs: "demo-instrumentation"`
- **Python**: `instrumentation.opentelemetry.io/inject-python: "demo-instrumentation"`  
- **Java/Quarkus**: `instrumentation.opentelemetry.io/inject-java: "demo-instrumentation"`
- **Go**: `instrumentation.opentelemetry.io/inject-go: "demo-instrumentation"`

### 2. **Sidecar Collectors** ✅
- Injected via annotation: `sidecar.opentelemetry.io/inject: sidecar`
- Receive traces from instrumented apps on `localhost:4318`
- Forward to central collector

### 3. **Central Collector** ✅
**CRITICAL TLS Configuration:**
```yaml
exporters:
  otlp/tempo:
    endpoint: tempo-tempo-gateway.openshift-tempo-operator.svc:8090
    tls:
      ca_file: "/var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt"  # KEY!
    auth:
      authenticator: bearertokenauth
    headers:
      X-Scope-OrgID: "dev"
```

**Key Points:**
- Uses GRPC to Tempo gateway (port 8090)
- Authenticates with service account bearer token
- **MUST** use service CA certificate (`service-ca.crt`) for TLS verification
- Routes traces to "dev" tenant via `X-Scope-OrgID` header

### 4. **RBAC for OpenShift Tenants** ✅
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: tempostack-traces-write
rules:
  - apiGroups: ['tempo.grafana.com']
    resources: ['dev']
    resourceNames: ['traces']
    verbs: ['create']
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: otel-central-collector-tempo-writer
roleRef:
  kind: ClusterRole
  name: tempostack-traces-write
subjects:
  - kind: ServiceAccount
    name: otel-central-collector
    namespace: observability-demo
```

### 5. **TempoStack Configuration** ✅
- **Mode**: `openshift` (tenant-based RBAC)
- **Tenants**: 
  - `dev` (ID: `1610b0c3-c509-4592-a256-a1871353dbfa`)
  - `prod` (ID: `6094b0f1-711d-4395-82c0-30c2720c6648`)
- **Storage**: MinIO S3 at `storage.blahonga.me:9199` (HTTPS with TLS)

## Verification Steps

### 1. Check Collector Status
```bash
# Verify central collector is running
oc get pods -n observability-demo -l app.kubernetes.io/component=opentelemetry-collector

# Check for errors (should be empty)
oc logs -n observability-demo deployment/central-collector --since=2m | grep -i error
```

### 2. Check Application Instrumentation
```bash
# Verify auto-instrumentation init containers are present
oc get pod -n observability-demo <pod-name> -o jsonpath='{.spec.initContainers[*].name}'

# Should show: otc-container opentelemetry-auto-instrumentation-<language>
```

### 3. Generate Traffic
```bash
# Send requests to the application
for i in {1..10}; do 
  curl -s http://node-app-observability-demo.apps.borg.blahonga.me/ > /dev/null
  echo "Request $i sent"
  sleep 1
done
```

### 4. Query Traces in OpenShift Console
1. Navigate to: **Observe → Traces**
2. Select **TempoStack**: `tempo (openshift-tempo-operator)`
3. Select **Tenant**: `dev`
4. Query traces by:
   - Service name (e.g., `node-app`, `go-api`)
   - Time range
   - Tags

### 5. Query Traces via API (Alternative)
```bash
# Get a bearer token
TOKEN=$(oc whoami -t)

# Query recent traces
curl -H "Authorization: Bearer $TOKEN" \
  "https://tempo-tempo-gateway-openshift-tempo-operator.apps.borg.blahonga.me/api/search?tags=service.name=node-app&limit=10"
```

## Troubleshooting

### No Traces Appearing?

**1. Check Central Collector Logs**
```bash
oc logs -n observability-demo deployment/central-collector --tail=100
```
Look for:
- ❌ `PermissionDenied` → RBAC issue
- ❌ `certificate required` → Missing service CA
- ❌ `404` or `Unimplemented` → Wrong endpoint
- ✅ No errors = traces flowing!

**2. Verify RBAC**
```bash
oc get clusterrole tempostack-traces-write
oc get clusterrolebinding otel-central-collector-tempo-writer
```

**3. Check Tempo Status**
```bash
oc get tempostack tempo -n openshift-tempo-operator
# Status should show: Ready=True
```

**4. Verify TLS Configuration**
```bash
# Ensure service CA is mounted
oc get pod -n observability-demo <central-collector-pod> \
  -o jsonpath='{.spec.volumes[?(@.name=="kube-api-access-*")].projected.sources[?(@.serviceAccountToken)].serviceAccountToken}'
```

## Key Learnings

### Why Service CA is Critical
- Tempo gateway in OpenShift uses **service serving certificates**
- The gateway's TLS certificate is signed by OpenShift's service CA
- Collectors MUST trust this CA by specifying: `ca_file: "/var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt"`
- Using `insecure_skip_verify: true` bypasses this but is NOT recommended for production

### Tenant Header Format
- Use tenant **NAME** (`dev`) not ID in `X-Scope-OrgID` header
- Tempo gateway maps the name to the tenant ID internally
- Both work, but name is more readable

### RBAC Pattern
- ClusterRole defines permission to write to specific tenant (`dev`)
- Must use `tempo.grafana.com` API group
- Resource name format: `<tenant-name>` with verb `create` for `traces` resource

## Files Modified

1. `manifests/1-apps/*-deployment.yaml` - Added instrumentation annotations
2. `manifests/3-opentelemetry/central-collector.yaml` - Updated Tempo exporter with service CA
3. `manifests/3-opentelemetry/tempo-writer-rbac.yaml` - RBAC for dev tenant access
4. `manifests/2-observability-stack/tempostack.yaml` - TLS enabled for S3 storage

## Next Steps

1. ✅ **Traces UI**: Access traces in OpenShift Console (Observe → Traces)
2. 🔄 **Dashboards**: Create Perses dashboards showing trace metrics
3. 📊 **Span Metrics**: Use `traces_spanmetrics_*` metrics in Prometheus
4. 🔗 **Service Graph**: Visualize service dependencies
5. 🎯 **Sampling**: Adjust sampling rates for production (currently 100%)

## Status: OPERATIONAL ✅

All components are configured and traces should now be visible in the OpenShift Console!

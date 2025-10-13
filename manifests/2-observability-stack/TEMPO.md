# Tempo Distributed Tracing Stack

This section contains manifests for installing Red Hat's Tempo Operator and configuring a TempoStack for distributed tracing.

## Components

- **Tempo Operator** - Red Hat's operator for managing TempoStack instances
- **TempoStack** - Distributed tracing backend with S3-compatible storage
- **Jaeger Query UI** - Query interface for viewing traces
- **Multi-tenancy** - Configured with dev and prod tenants

## Prerequisites

- OpenShift cluster with cluster-admin access
- S3-compatible object storage (MinIO configured at `storage.blahonga.me:9199`)
- Storage credentials for the S3 bucket `borg-tempo`

## Installation Order

### Step 1: Install Tempo Operator

```bash
# Create namespace
oc apply -f tempo-namespace.yaml

# Create OperatorGroup
oc apply -f tempo-operatorgroup.yaml

# Install the operator
oc apply -f tempo-subscription.yaml
```

### Step 2: Wait for Operator Installation

```bash
# Watch operator installation
oc get csv -n openshift-tempo-operator -w

# Verify operator is running
oc get pods -n openshift-tempo-operator
```

### Step 3: Create Storage Secret

```bash
# Create the S3 storage secret
oc apply -f tempo-secret.yaml

# Verify secret was created
oc get secret tempostack-dev-minio -n openshift-tempo-operator
```

### Step 4: Configure RBAC

```bash
# Create cluster role and binding for trace access
oc apply -f tempo-rbac.yaml

# Verify RBAC resources
oc get clusterrole tempostack-traces-reader
oc get clusterrolebinding tempostack-traces-reader
```

### Step 5: Deploy TempoStack

```bash
# Deploy the TempoStack instance
oc apply -f tempostack.yaml

# Watch TempoStack deployment
oc get tempostack -n openshift-tempo-operator -w

# Check all pods are running
oc get pods -n openshift-tempo-operator
```

## Quick Deploy (All at Once)

```bash
# Deploy all Tempo manifests
oc apply -f tempo-namespace.yaml
oc apply -f tempo-operatorgroup.yaml
oc apply -f tempo-subscription.yaml

# Wait for operator, then deploy stack
oc apply -f tempo-secret.yaml
oc apply -f tempo-rbac.yaml
oc apply -f tempostack.yaml
```

## Verify Installation

### Check Operator Status

```bash
# View operator CSV
oc get csv -n openshift-tempo-operator

# Check operator logs
oc logs -n openshift-tempo-operator deployment/tempo-operator-controller
```

### Check TempoStack Status

```bash
# Get TempoStack details
oc get tempostack tempo -n openshift-tempo-operator -o yaml

# Check all component pods
oc get pods -n openshift-tempo-operator -l app.kubernetes.io/instance=tempo
```

### Expected Pods

The TempoStack deployment should create the following pods:

- **tempo-distributor-\*** - Receives traces from applications
- **tempo-ingester-\*** - Writes traces to storage
- **tempo-querier-\*** - Queries traces from storage
- **tempo-query-frontend-\*** - Frontend for query processing
- **tempo-compactor-\*** - Compacts trace data in storage
- **tempo-gateway-\*** - Gateway with authentication/authorization

### Access Jaeger UI

```bash
# Get the Jaeger Query route
oc get route -n openshift-tempo-operator

# Expected route: tempo-tempo-gateway
TEMPO_ROUTE=$(oc get route tempo-tempo-gateway -n openshift-tempo-operator -o jsonpath='{.spec.host}')
echo "Jaeger UI: https://${TEMPO_ROUTE}"
```

## TempoStack Configuration

### Storage Backend

- **Type**: S3-compatible (MinIO)
- **Endpoint**: `https://storage.blahonga.me:9199`
- **Bucket**: `borg-tempo`
- **Size**: 1Gi (persistent volume for local cache)

### Retention

- **Traces**: 48 hours
- Traces older than 48h are automatically deleted by the compactor

### Multi-Tenancy

Two tenants are configured:

1. **dev** - Tenant ID: `1610b0c3-c509-4592-a256-a1871353dbfa`
2. **prod** - Tenant ID: `6094b0f1-711d-4395-82c0-30c2720c6648`

Each tenant has isolated trace storage and query capabilities.

### Resource Limits

- **Total CPU**: 2 cores
- **Total Memory**: 2Gi
- **Replication Factor**: 1 (single replica for dev/demo)

### Components

- **Distributor**: 1 replica - Receives traces
- **Ingester**: 1 replica - Writes to storage
- **Querier**: Auto-scaled - Queries traces
- **Query Frontend**: Auto-scaled - Query optimization
- **Compactor**: 1 instance - Data compaction
- **Gateway**: Enabled - Authentication/authorization with OpenShift

## RBAC Configuration

The `tempostack-traces-reader` ClusterRole grants:

- **Permission**: `get` on `traces` resource
- **Tenants**: dev and prod
- **Subjects**: All authenticated users (`system:authenticated`)

This allows any authenticated OpenShift user to query traces from both tenants.

## Sending Traces to Tempo

Applications can send traces to Tempo using OTLP (OpenTelemetry Protocol):

### OTLP Endpoints

```bash
# Get the distributor service
oc get svc -n openshift-tempo-operator -l app.kubernetes.io/component=distributor

# OTLP gRPC endpoint: tempo-tempo-distributor:4317
# OTLP HTTP endpoint: tempo-tempo-distributor:4318
```

### Example: Send Traces via OTLP

```yaml
# In your application deployment
env:
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://tempo-tempo-distributor.openshift-tempo-operator.svc.cluster.local:4318"
  - name: OTEL_EXPORTER_OTLP_PROTOCOL
    value: "http/protobuf"
  - name: OTEL_SERVICE_NAME
    value: "my-app"
```

### Jaeger Agent Endpoint

For legacy Jaeger clients:

```yaml
env:
  - name: JAEGER_AGENT_HOST
    value: "tempo-tempo-distributor.openshift-tempo-operator.svc.cluster.local"
  - name: JAEGER_AGENT_PORT
    value: "6831"
```

## Troubleshooting

### Operator Not Installing

```bash
# Check subscription status
oc describe subscription tempo-product -n openshift-tempo-operator

# Check install plan
oc get installplan -n openshift-tempo-operator

# View operator logs
oc logs -n openshift-tempo-operator -l app.kubernetes.io/name=tempo-operator
```

### TempoStack Not Creating Pods

```bash
# Check TempoStack status
oc describe tempostack tempo -n openshift-tempo-operator

# Check for errors in status
oc get tempostack tempo -n openshift-tempo-operator -o jsonpath='{.status.conditions}'

# Check operator logs
oc logs -n openshift-tempo-operator deployment/tempo-operator-controller --tail=100
```

### Storage Issues

```bash
# Verify secret exists
oc get secret tempostack-dev-minio -n openshift-tempo-operator -o yaml

# Check compactor logs (handles storage)
oc logs -n openshift-tempo-operator -l app.kubernetes.io/component=compactor

# Check ingester logs (writes to storage)
oc logs -n openshift-tempo-operator -l app.kubernetes.io/component=ingester
```

### Query Issues

```bash
# Check querier logs
oc logs -n openshift-tempo-operator -l app.kubernetes.io/component=querier

# Check query-frontend logs
oc logs -n openshift-tempo-operator -l app.kubernetes.io/component=query-frontend

# Test query via port-forward
oc port-forward -n openshift-tempo-operator svc/tempo-tempo-query-frontend 3200:3200
```

### Gateway/Authentication Issues

```bash
# Check gateway logs
oc logs -n openshift-tempo-operator -l app.kubernetes.io/component=gateway

# Verify route
oc get route tempo-tempo-gateway -n openshift-tempo-operator

# Check RBAC
oc auth can-i get traces --as=system:authenticated -n openshift-tempo-operator
```

### No Traces Appearing

1. **Verify application is sending traces**:
   ```bash
   # Check distributor logs for incoming traces
   oc logs -n openshift-tempo-operator -l app.kubernetes.io/component=distributor
   ```

2. **Check network connectivity**:
   ```bash
   # From your app namespace
   oc run test -it --rm --image=curlimages/curl -- \
     curl -v http://tempo-tempo-distributor.openshift-tempo-operator.svc:4318/v1/traces
   ```

3. **Verify storage**:
   ```bash
   # Check if traces are being written to S3
   oc logs -n openshift-tempo-operator -l app.kubernetes.io/component=ingester | grep -i "writing"
   ```

## Integration with Applications

To integrate your applications with Tempo:

1. **Add OpenTelemetry SDK** to your application
2. **Configure OTLP exporter** to point to Tempo distributor
3. **Set tenant header** (if using multi-tenancy):
   ```
   X-Scope-OrgID: dev  # or prod
   ```

Example for the observability-demo apps, add to deployment env:

```yaml
env:
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://tempo-tempo-distributor.openshift-tempo-operator.svc.cluster.local:4318"
  - name: OTEL_EXPORTER_OTLP_HEADERS
    value: "X-Scope-OrgID=dev"
  - name: OTEL_SERVICE_NAME
    value: "go-api"  # or python-api, quarkus-api, node-app
```

## Cleanup

```bash
# Delete TempoStack
oc delete tempostack tempo -n openshift-tempo-operator

# Delete RBAC
oc delete -f tempo-rbac.yaml

# Delete secret
oc delete secret tempostack-dev-minio -n openshift-tempo-operator

# Uninstall operator
oc delete subscription tempo-product -n openshift-tempo-operator

# Delete namespace
oc delete namespace openshift-tempo-operator
```

## References

- [Red Hat Tempo Operator Documentation](https://docs.openshift.com/container-platform/latest/observability/distr_tracing/distr_tracing_tempo/distr-tracing-tempo-installing.html)
- [Grafana Tempo Documentation](https://grafana.com/docs/tempo/latest/)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)

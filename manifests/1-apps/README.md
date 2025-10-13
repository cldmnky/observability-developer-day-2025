# OpenShift Deployment Manifests

This directory contains Kubernetes/OpenShift manifests for deploying the observability demo stack.

## Architecture

The stack consists of four microservices:

1. **Go API** - Name generator and ASCII art service
2. **Python API** - Seed generator service
3. **Quarkus API** - Lolcat colorization service
4. **Node.js App** - Web UI frontend with terminal emulator

## Prerequisites

- OpenShift cluster with cluster-admin or namespace admin access
- `oc` CLI tool installed and configured
- Container images pushed to `quay.io/cldmnky/` (or update image references)

## Quick Deploy

Deploy all services to the `observability-demo` namespace:

```bash
# Deploy in order
oc apply -f namespace.yaml
oc apply -f go-api-deployment.yaml
oc apply -f python-api-deployment.yaml
oc apply -f quarkus-api-deployment.yaml
oc apply -f node-app-deployment.yaml

# Or deploy all at once
oc apply -f .
```

## Verify Deployment

```bash
# Check namespace
oc get namespace observability-demo

# Check all resources
oc get all -n observability-demo

# Check pod status
oc get pods -n observability-demo

# Check services
oc get svc -n observability-demo

# Check route (for Node.js web UI)
oc get route -n observability-demo

# Get the web UI URL
oc get route node-app -n observability-demo -o jsonpath='{.spec.host}'
```

## Access the Application

Once deployed, access the web UI through the OpenShift route:

```bash
# Get the route URL
echo "https://$(oc get route node-app -n observability-demo -o jsonpath='{.spec.host}')"
```

Open the URL in your browser to access the web terminal interface.

## Service Architecture

```
┌──────────────────────────────────────┐
│     OpenShift Route (HTTPS)          │
│     node-app.apps.cluster.com        │
└──────────────┬───────────────────────┘
               │
               ▼
┌──────────────────────────────────────┐
│   Node.js Web UI (node-app)          │
│   Service: node-app:8080              │
│   Pod Port: 4002                      │
└──────────────┬───────────────────────┘
               │
    ┌──────────┴────────────┬────────────────┐
    │                       │                │
    ▼                       ▼                ▼
┌────────────┐      ┌──────────────┐  ┌─────────────┐
│  Go API    │      │  Python API  │  │ Quarkus API │
│  (go-api)  │      │ (python-api) │  │(quarkus-api)│
│            │      │              │  │             │
│ Svc: :8080 │      │  Svc: :8080  │  │ Svc: :8080  │
│ Pod: :4001 │      │  Pod: :4004  │  │ Pod: :4003  │
└────────────┘      └──────────────┘  └─────────────┘
```

## Service Details

### Go API Service
- **Purpose**: Name generator and ASCII art (figlet) generation
- **Service**: `go-api.observability-demo.svc.cluster.local:8080`
- **Endpoints**:
  - `GET /healthz` - Health check
  - `GET /api/name?count=N&seed=S` - Generate names
  - `POST /api/figlet` - Generate ASCII art

### Python API Service
- **Purpose**: Random seed generation for lolcat colorization
- **Service**: `python-api.observability-demo.svc.cluster.local:8080`
- **Endpoints**:
  - `GET /healthz` - Health check
  - `GET /api/seed` - Generate random seed

### Quarkus API Service
- **Purpose**: Lolcat rainbow colorization
- **Service**: `quarkus-api.observability-demo.svc.cluster.local:8080`
- **Endpoints**:
  - `GET /q/health/live` - Liveness check
  - `GET /q/health/ready` - Readiness check
  - `POST /api/lolcat` - Colorize text

### Node.js Web UI
- **Purpose**: Browser-based terminal UI
- **Service**: `node-app.observability-demo.svc.cluster.local:8080`
- **Route**: HTTPS with edge TLS termination
- **Environment Variables**:
  - `GO_API_BASE=http://go-api:8080`
  - `PYTHON_API_BASE=http://python-api:8080`
  - `QUARKUS_API_BASE=http://quarkus-api:8080`

## Resource Specifications

All deployments include:
- **Health Probes**: Liveness and readiness checks
- **Resource Limits**: CPU and memory constraints
- **Labels**: Proper Kubernetes labels for organization
- **Image Pull Policy**: Always (for development)

### Resource Allocation

| Service | CPU Request | CPU Limit | Memory Request | Memory Limit |
|---------|-------------|-----------|----------------|--------------|
| Go API | 100m | 500m | 128Mi | 256Mi |
| Python API | 100m | 500m | 128Mi | 256Mi |
| Quarkus API | 200m | 1000m | 256Mi | 512Mi |
| Node.js App | 100m | 500m | 128Mi | 256Mi |

## OpenShift-Specific Features

### Security Context Constraints (SCC)
The container images are built using Red Hat UBI9 base images with proper OpenShift compatibility:
- Runs as non-root user
- Proper file permissions for arbitrary UIDs
- No privileged escalation required

### Route Configuration
The Node.js app uses an OpenShift Route with:
- **Edge TLS termination**: Encrypts traffic from clients to the router
- **Insecure redirect**: HTTP requests automatically redirect to HTTPS
- **Default certificates**: Uses OpenShift's default wildcard certificate

To use a custom certificate:
```bash
oc create route edge node-app \
  --service=node-app \
  --cert=path/to/cert.crt \
  --key=path/to/cert.key \
  --ca-cert=path/to/ca.crt \
  -n observability-demo
```

## Troubleshooting

### Check Pod Logs
```bash
# View logs for a specific service
oc logs -f deployment/go-api -n observability-demo
oc logs -f deployment/python-api -n observability-demo
oc logs -f deployment/quarkus-api -n observability-demo
oc logs -f deployment/node-app -n observability-demo
```

### Check Pod Status
```bash
# Describe pod for detailed information
oc describe pod -l app=go-api -n observability-demo
oc describe pod -l app=python-api -n observability-demo
oc describe pod -l app=quarkus-api -n observability-demo
oc describe pod -l app=node-app -n observability-demo
```

### Test Service Connectivity
```bash
# Port-forward to test services locally
oc port-forward -n observability-demo svc/go-api 8080:8080
oc port-forward -n observability-demo svc/python-api 8081:8080
oc port-forward -n observability-demo svc/quarkus-api 8082:8080
oc port-forward -n observability-demo svc/node-app 8083:8080

# Test endpoints
curl http://localhost:8080/healthz
curl http://localhost:8081/healthz
curl -X POST http://localhost:8082/api/lolcat -H "Content-Type: application/json" -d '{"text":"test"}'
curl http://localhost:8083/
```

### Common Issues

**Pods not starting:**
- Check image pull status: `oc describe pod <pod-name> -n observability-demo`
- Verify image exists: `podman pull quay.io/cldmnky/observability-go-api:latest`
- Check SCC permissions: `oc get pod <pod-name> -o yaml | grep scc`

**Service connectivity issues:**
- Verify services exist: `oc get svc -n observability-demo`
- Check endpoints: `oc get endpoints -n observability-demo`
- Test DNS resolution from a pod: `oc run -it --rm debug --image=registry.access.redhat.com/ubi9/ubi-minimal --restart=Never -- sh`

**Route not accessible:**
- Check route status: `oc get route node-app -n observability-demo`
- Verify route hostname: `oc describe route node-app -n observability-demo`
- Check router logs: `oc logs -n openshift-ingress -l ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default`

## Scaling

Scale individual services:

```bash
# Scale Go API to 3 replicas
oc scale deployment/go-api --replicas=3 -n observability-demo

# Scale all services
oc scale deployment --all --replicas=2 -n observability-demo
```

## Cleanup

Remove all resources:

```bash
# Delete all resources in namespace
oc delete all --all -n observability-demo

# Delete the namespace
oc delete namespace observability-demo

# Or delete by manifest files
oc delete -f .
```

## CI/CD Integration

These manifests can be integrated with:
- **OpenShift Pipelines (Tekton)**: For automated deployments
- **ArgoCD**: For GitOps-based continuous delivery
- **Jenkins**: For traditional CI/CD pipelines

Example ArgoCD Application:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: observability-demo
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/cldmnky/observability-developer-day-2025
    targetRevision: HEAD
    path: manifests/1-apps
  destination:
    server: https://kubernetes.default.svc
    namespace: observability-demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Monitoring and Observability

To enable monitoring (covered in subsequent exercises):
- ServiceMonitor for Prometheus metrics
- Distributed tracing with OpenTelemetry
- Logging aggregation
- Dashboard creation in Grafana

See the main workshop documentation for observability configuration.

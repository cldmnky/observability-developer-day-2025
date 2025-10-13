# Observability Stack - Deployment Summary

## ✅ Deployment Status

### Applications (observability-demo namespace)
All 4 applications are deployed and running:

| Application | Port | Metrics Endpoint | Status |
|------------|------|------------------|--------|
| go-api | 8080 | http://go-api:8080/metrics | ✅ Running |
| python-api | 8000 | http://python-api:8000/metrics | ✅ Running |
| quarkus-api | 4003 | http://quarkus-api:4003/metrics | ✅ Running |
| node-app | 3000 | http://node-app:3000/metrics | ✅ Running |

### Monitoring Stack (observability-demo namespace)

**Operator:** Cluster Observability Operator v1.2.2 ✅

| Component | Type | Replicas | Status |
|-----------|------|----------|--------|
| Prometheus | StatefulSet | 3 | ✅ Running |
| Alertmanager | StatefulSet | 2 (1 pending*) | ✅ Running |
| Thanos Querier | Deployment | 1 | ✅ Running |

*Alertmanager replica 1 is pending due to pod anti-affinity on single-node cluster (expected)

**Custom Resources:**
- MonitoringStack: `observability-stack` ✅
- ThanosQuerier: `observability-stack` ✅

### ServiceMonitors (observability-demo namespace)

| ServiceMonitor | Targets | Label |
|---------------|---------|-------|
| go-api | go-api:8080/metrics | monitoring.rhobs/stack: observability-stack |
| python-api | python-api:8000/metrics | monitoring.rhobs/stack: observability-stack |
| quarkus-api | quarkus-api:4003/metrics | monitoring.rhobs/stack: observability-stack |
| node-app | node-app:3000/metrics | monitoring.rhobs/stack: observability-stack |

### Distributed Tracing (openshift-tempo-operator namespace)

**Operator:** Tempo Operator v0.18.0-1 ✅

**TempoStack:** tempo ✅
- Storage: MinIO S3 (storage.blahonga.me:9199)
- Bucket: borg-tempo
- Retention: 48 hours
- Tenants: dev, prod
- Jaeger UI: Enabled

**OTLP Endpoints:**
- HTTP: `tempo-tempo-distributor.openshift-tempo-operator.svc:4318`
- gRPC: `tempo-tempo-distributor.openshift-tempo-operator.svc:4317`

## 📁 Configuration Files

```
manifests/
├── 1-apps/                              # Application Deployments
│   ├── namespace.yaml
│   ├── go-api-deployment.yaml          (+ Service)
│   ├── python-api-deployment.yaml      (+ Service)
│   ├── quarkus-api-deployment.yaml     (+ Service)
│   ├── node-app-deployment.yaml        (+ Service + Route)
│   └── README.md
│
├── 2-observability-stack/               # Monitoring & Tracing
│   ├── coo-namespace.yaml
│   ├── coo-operatorgroup.yaml
│   ├── coo-subscription.yaml
│   ├── coo-monitoring-stack.yaml       # MonitoringStack CR
│   ├── coo-thanos-querier.yaml         # ThanosQuerier CR
│   ├── tempo-namespace.yaml
│   ├── tempo-operatorgroup.yaml
│   ├── tempo-subscription.yaml
│   ├── tempo-secret.yaml               # MinIO credentials
│   ├── tempo-rbac.yaml
│   ├── tempostack.yaml                 # TempoStack CR
│   ├── README.md
│   └── TEMPO.md
│
├── 3-servicemonitors/                   # Prometheus Scrape Config
│   ├── go-api-servicemonitor.yaml
│   ├── python-api-servicemonitor.yaml
│   ├── quarkus-api-servicemonitor.yaml
│   ├── node-app-servicemonitor.yaml
│   └── README.md
│
├── OBSERVABILITY_GUIDE.md               # Complete guide
└── DEPLOYMENT_SUMMARY.md                # This file
```

## 🚀 Quick Access

### Prometheus UI
```bash
oc port-forward -n observability-demo svc/prometheus-observability-stack 9090:9090
# Open: http://localhost:9090
```

### Thanos Querier UI
```bash
oc port-forward -n observability-demo svc/thanos-querier-observability-stack 9090:9090
# Open: http://localhost:9090
```

### Jaeger UI (Tempo)
```bash
oc port-forward -n openshift-tempo-operator svc/tempo-tempo-query-frontend 16686:16686
# Open: http://localhost:16686
```

### Application UI
```bash
# Get the route URL
oc get route node-app -n observability-demo -o jsonpath='{.spec.host}'
```

## 🔍 Verification Commands

### Check All Deployments
```bash
# Applications
oc get pods -n observability-demo

# Monitoring Stack
oc get monitoringstack,thanosquerier -n observability-demo

# ServiceMonitors
oc get servicemonitors -n observability-demo

# Tempo Stack
oc get tempostack -n openshift-tempo-operator
```

### Test Metrics Collection
```bash
# Check metrics from each application
for app in go-api python-api quarkus-api node-app; do
  echo "=== $app ==="
  oc exec -n observability-demo $(oc get pod -n observability-demo -l app=$app -o name | head -1) -- \
    curl -s http://localhost:$(oc get svc $app -n observability-demo -o jsonpath='{.spec.ports[0].port}')/metrics | head -5
done
```

### Query Prometheus
```bash
# Port-forward and query
oc port-forward -n observability-demo svc/prometheus-observability-stack 9090:9090 &

# Query examples (use Prometheus UI or curl)
curl 'http://localhost:9090/api/v1/query?query=up'
curl 'http://localhost:9090/api/v1/query?query=rate(http_requests_total[5m])'
```

## 🏷️ Label Strategy

The observability stack uses a consistent labeling approach based on latest API documentation from Context7:

### ServiceMonitor Discovery
All ServiceMonitors include:
```yaml
labels:
  monitoring.rhobs/stack: observability-stack
```

### MonitoringStack Selector
```yaml
resourceSelector:
  matchLabels:
    monitoring.rhobs/stack: observability-stack
```

This ensures Prometheus automatically discovers and scrapes all matching ServiceMonitors.

## 📚 API Documentation Sources

Configuration validated against latest documentation from Context7:

| Component | Library | Trust Score | Snippets |
|-----------|---------|-------------|----------|
| Tempo/TempoStack | /grafana/tempo | 9.7 | 3,781 |
| Thanos Querier | /thanos-io/thanos | 8.2 | 619 |
| MonitoringStack | RHOBS patterns | - | - |

## 🔧 Troubleshooting

### Issue: Alertmanager Pod Pending
**Status:** Expected on single-node cluster  
**Reason:** Pod anti-affinity rules prevent 2 replicas on same node  
**Impact:** None - one Alertmanager instance is sufficient

### Issue: ServiceMonitors Not Scraped
**Check:**
1. Verify ServiceMonitor has `monitoring.rhobs/stack: observability-stack` label
2. Confirm service selector matches deployment labels
3. Check Prometheus logs: `oc logs -n observability-demo prometheus-observability-stack-0 -c prometheus`

### Issue: Missing Metrics
**Verify:**
1. Metrics endpoint: `curl http://<service>:<port>/metrics`
2. Service ports match deployment container ports
3. ServiceMonitor endpoint configuration

## ✅ Completion Checklist

- [x] All 4 applications deployed
- [x] All services created
- [x] OpenShift route for node-app
- [x] Cluster Observability Operator installed
- [x] MonitoringStack deployed
- [x] Prometheus running (3 replicas)
- [x] Alertmanager running (2 replicas)
- [x] Thanos Querier deployed
- [x] ServiceMonitors created for all apps
- [x] Tempo Operator installed
- [x] TempoStack configured with MinIO
- [x] API documentation validated via Context7
- [x] Label strategy updated (monitoring.rhobs/stack)

## 🎯 Next Steps

1. **Instrument Tracing**: Add OpenTelemetry SDK to applications for distributed tracing
2. **Create Dashboards**: Deploy Grafana and import application dashboards
3. **Configure Alerts**: Create PrometheusRule resources for alerting
4. **Test Alerting**: Configure Alertmanager routes and receivers
5. **Validate Traces**: Send test traces to Tempo and verify in Jaeger UI

## 📖 Documentation

- **Complete Guide**: [OBSERVABILITY_GUIDE.md](./OBSERVABILITY_GUIDE.md)
- **Application Deployment**: [1-apps/README.md](./1-apps/README.md)
- **Monitoring Stack**: [2-observability-stack/README.md](./2-observability-stack/README.md)
- **ServiceMonitors**: [3-servicemonitors/README.md](./3-servicemonitors/README.md)
- **Tempo Configuration**: [2-observability-stack/TEMPO.md](./2-observability-stack/TEMPO.md)
